import 'dart:io';
import 'package:cli/utils/cli_confirm.dart';
import 'package:cli/utils/cli_log_until.dart';
import 'package:cli/utils/cli_project_files.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pool/pool.dart';

/// 成功转换的 .png 路径（相对项目根目录，使用 / 分隔）
final Set<String> convertedPngPaths = {};

/// 转换当前目录下的 PNG 为 WebP，删除原图并更新 lib 和 pubspec.yaml 中的引用。
///
/// 删除原图前需经 [confirm] 同意；全部成功（或无需转换）时返回 true。
Future<bool> flutterConvertAssetsToWebp({Confirm confirm = askUser}) async {
  final currentDir = Directory.current;
  final root = findProjectRoot(currentDir);

  final skipped = <File>[];
  final byTarget = <String, List<File>>{};
  for (final file in collectProjectFiles(currentDir, _isPng)) {
    final webpPath = _webpPathOf(file.path);
    if (File(webpPath).existsSync()) {
      skipped.add(file);
    } else {
      (byTarget[webpPath] ??= []).add(file);
    }
  }
  // a.png 和 a.PNG 会转换成同一个 a.webp，转换后两张原图都会被删，必须跳过
  final conflicts = [
    for (final group in byTarget.values)
      if (group.length > 1) ...group,
  ];
  final pngFiles = [
    for (final group in byTarget.values)
      if (group.length == 1) group.single,
  ];

  if (skipped.isNotEmpty) {
    logWarning('⏭️ 以下 ${skipped.length} 个 PNG 已有同名 WebP，已跳过（原图和代码引用保持不变）:');
    for (final file in skipped) {
      logWarning('  - ${file.path}');
    }
  }
  for (final file in conflicts) {
    logError('❌ 与其他 PNG 会转换成同一个 WebP（仅扩展名大小写不同），已跳过: ${file.path}');
  }
  if (pngFiles.isEmpty) {
    logWarning('⚠️ 没有需要转换的 PNG');
    return conflicts.isEmpty;
  }

  // 先检查一次 cwebp，避免逐个文件失败刷屏
  if (!await _hasCwebp()) {
    logError('❌ 错误: 未找到 cwebp 命令');
    logInfoInstallInstructions();
    return false;
  }

  if (!confirm('将把 ${pngFiles.length} 个 PNG 转为 WebP（质量 80）并删除原 PNG，是否继续？')) {
    logWarning('❎ 已取消，未修改任何文件。');
    return true;
  }

  logInfo('🔍 开始转换 PNG 为 WebP...');
  final failed = await convertPngToWebp(pngFiles, root) + conflicts.length;

  logInfo('🔁 开始修改图片引用...');
  final libDir = Directory(p.join(root.path, 'lib'));
  if (libDir.existsSync()) {
    await updateLibImageReferences(libDir);
  }
  _updatePubspecReferences(File(p.join(root.path, 'pubspec.yaml')));

  if (failed > 0) {
    logError('❌ $failed 个文件转换失败或被跳过');
    return false;
  }
  logSuccess('✅ 全部完成！');
  return true;
}

/// 排除旧版本中断后残留在原图旁的临时文件 `xxx.png.tmp.png`
bool _isPng(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.png') && !lower.endsWith('.png.tmp.png');
}

String _webpPathOf(String pngPath) =>
    pngPath.replaceAll(RegExp(r'\.png$', caseSensitive: false), '.webp');

String _toWebpPath(String pngPath) => p.posix.setExtension(pngPath, '.webp');

Future<bool> _hasCwebp() async {
  try {
    return (await Process.run('cwebp', ['-version'])).exitCode == 0;
  } on ProcessException {
    return false;
  }
}

/// 转换 [pngFiles]，成功的删除原图并记录到 [convertedPngPaths]。返回失败数。
Future<int> convertPngToWebp(List<File> pngFiles, Directory root,
    {int concurrency = 6}) async {
  int success = 0, fail = 0;
  final pool = Pool(concurrency);
  // 临时文件放在系统临时目录，避免中断后残留在项目里被当作待转换图片
  final tempDir = Directory.systemTemp.createTempSync('cli_webp_');

  try {
    await Future.wait([
      for (final (index, entity) in pngFiles.indexed)
        pool.withResource(() async {
          final pngPath = entity.path;
          final webpPath = _webpPathOf(pngPath);
          final tempPngPath = p.join(tempDir.path, '$index.png');
          try {
            final image = img.decodeImage(await entity.readAsBytes());
            if (image == null) {
              logError('❌ 解码失败: $pngPath');
              fail++;
              return;
            }

            await File(tempPngPath).writeAsBytes(img.encodePng(image));
            final result = await Process.run(
                'cwebp', ['-q', '80', tempPngPath, '-o', webpPath]);

            if (result.exitCode != 0) {
              logError('❌ 转换失败: $pngPath ${result.stderr}');
              fail++;
              return;
            }
            logInfo('✅ $pngPath → $webpPath');
            success++;
            // 忽略倍图路径（如 xxx@2x.png 或 xxx@3x.png）
            if (!RegExp(r'@[\dx]+\.png$', caseSensitive: false)
                .hasMatch(pngPath)) {
              convertedPngPaths
                  .add(p.split(p.relative(pngPath, from: root.path)).join('/'));
            }

            try {
              await entity.delete();
              logInfo('🗑️ 已删除原 PNG 文件: $pngPath');
            } catch (e) {
              logWarning('⚠️ 删除失败: $pngPath - $e');
            }
          } catch (e) {
            logError('❌ 异常: $pngPath - $e');
            fail++;
          } finally {
            try {
              final temp = File(tempPngPath);
              if (temp.existsSync()) await temp.delete();
            } catch (e) {
              logWarning('⚠️ 无法删除临时文件 $tempPngPath - $e');
            }
          }
        }),
    ]);
  } finally {
    await pool.close();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  }

  logInfo('\n📊 转换统计: 总数 ${pngFiles.length}, 成功 $success, 失败 $fail\n');
  return fail;
}

void logInfoInstallInstructions() {
  logInfo('💡 请安装 `cwebp` 命令行工具以启用 WebP 转换功能：');
  if (Platform.isMacOS) {
    logInfo('👉 macOS: brew install webp');
  } else if (Platform.isWindows) {
    logInfo('👉 Windows (使用 Chocolatey): choco install webp');
  } else if (Platform.isLinux) {
    logInfo('👉 Ubuntu/Debian: sudo apt install webp');
    logInfo('👉 RedHat/CentOS: sudo yum install libwebp-tools');
  } else {
    logInfo(
        '👉 请前往 https://developers.google.com/speed/webp/download 下载并安装适合你平台的 WebP 工具。');
  }
}

Future<void> updateLibImageReferences(Directory dir) async {
  logInfo('convertedPngPaths = $convertedPngPaths');
  final regExp = RegExp(r'''(["'])([^"'\n]+?\.png)\1''', caseSensitive: false);

  await for (var entity in dir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      String content = await entity.readAsString();

      final updatedContent = content.replaceAllMapped(regExp, (match) {
        final quote = match[1]!;
        final pngPath = p.posix.normalize(match[2]!);

        if (convertedPngPaths.contains(pngPath)) {
          return '$quote${_toWebpPath(pngPath)}$quote';
        }
        return match.group(0)!;
      });

      if (content != updatedContent) {
        await entity.writeAsString(updatedContent);
        logInfo('✏️ 更新路径: ${entity.path}');
      }
    }
  }
}

/// 更新 pubspec.yaml 中单独声明的图片路径，否则 flutter build 会找不到资源
void _updatePubspecReferences(File pubspec) {
  if (!pubspec.existsSync()) return;
  final content = pubspec.readAsStringSync();
  var updated = content;
  for (final pngPath in convertedPngPaths) {
    updated = updated.replaceAllMapped(
      RegExp('^(\\s*-\\s*["\']?)${RegExp.escape(pngPath)}(["\']?\\s*)\$',
          multiLine: true),
      (m) => '${m[1]}${_toWebpPath(pngPath)}${m[2]}',
    );
  }
  if (updated != content) {
    pubspec.writeAsStringSync(updated);
    logInfo('✏️ 更新路径: ${pubspec.path}');
  }
}
