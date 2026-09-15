import 'dart:io';
import 'package:cli/utils/cli_log_until.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pool/pool.dart';

final Set<String> convertedPngPaths = {}; // 只记录成功转换的 .png 文件路径

Future<void> flutterConvertAssetsToWebp() async {
  final currentDir = Directory.current;
  final libDir = Directory('lib');

  if (!currentDir.existsSync()) {
    logError('❌ 当前目录不存在');
    return;
  }

  logInfo('🔍 开始转换 PNG 为 WebP...');
  await convertPngToWebp(currentDir);

  logInfo('🔁 开始修改 lib 中图片引用...');
  await updateLibImageReferences(libDir);

  logSuccess('✅ 全部完成！');
}

Future<void> convertPngToWebp(Directory dir, {int concurrency = 6}) async {
  int total = 0, success = 0, fail = 0;
  final pool = Pool(concurrency);
  final tasks = <Future<void>>[];

  await for (var entity in dir.list(recursive: true)) {
    if (entity is File && entity.path.toLowerCase().endsWith('.png')) {
      total++;
      final pngPath = entity.path;
      final webpPath =
          pngPath.replaceAll(RegExp(r'\.png$', caseSensitive: false), '.webp');

      final task = pool.withResource(() async {
        if (File(webpPath).existsSync()) {
          logInfo('⚠️ 已存在，跳过: $webpPath');
          return;
        }

        try {
          final bytes = await entity.readAsBytes();
          final image = img.decodeImage(bytes);
          if (image == null) {
            logError('❌ 解码失败: $pngPath');
            fail++;
            return;
          }

          final tempPngPath = '$pngPath.tmp.png';
          final pngBytes = img.encodePng(image);
          await File(tempPngPath).writeAsBytes(pngBytes);

          try {
            final result = await Process.run(
                'cwebp', ['-q', '80', tempPngPath, '-o', webpPath]);

            try {
              await File(tempPngPath).delete();
            } catch (e) {
              logInfo('⚠️ 无法删除临时文件 $tempPngPath - $e');
            }

            if (result.exitCode == 0) {
              logInfo('✅ $pngPath → $webpPath');
              success++;
              //pngPath加入convertedPngPaths数组(忽略倍图的路径 eg: xxx@2x.png)
              // 忽略倍图路径（如 xxx@2x.png 或 xxx@3x.png）
              if (!RegExp(r'@[\dx]+\.png$', caseSensitive: false)
                  .hasMatch(pngPath)) {
                convertedPngPaths.add(pngPath);
              }

              try {
                await entity.delete();
                logInfo('🗑️ 已删除原 PNG 文件: $pngPath');
              } catch (e) {
                logInfo('⚠️ 删除失败: $pngPath - $e');
              }
            } else {
              logError('❌ 转换失败: ${result.stderr}');
              fail++;
            }
          } on ProcessException {
            logError('❌ 错误: 未找到 cwebp 命令');
            logInfoInstallInstructions();
            try {
              await File(tempPngPath).delete();
            } catch (_) {}
            fail++;
          }
        } catch (e) {
          logError('❌ 异常: $pngPath - $e');
          fail++;
        }
      });

      tasks.add(task);
    }
  }

  await Future.wait(tasks);
  await pool.close();

  logInfo('\n📊 转换统计: 总数 $total, 成功 $success, 失败 $fail\n');
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
  final regExp = RegExp(r'''(["'])(assets[\\/][^"']+?\.png)\1''');

  await for (var entity in dir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      String content = await entity.readAsString();

      final updatedContent = content.replaceAllMapped(regExp, (match) {
        final quote = match[1]!;
        final pngPath = p.normalize(match[2]!);

        if (convertedPngPaths.contains(pngPath)) {
          final webpPath = pngPath.replaceAll('.png', '.webp');
          return '$quote$webpPath$quote';
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
