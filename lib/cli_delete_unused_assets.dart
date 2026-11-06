//✅ 功能说明：
//扫描 assets/ 目录下的图片资源；
//判断是否在 lib/ 中的 Dart 代码中被使用；
//输出未使用的图片资源；
//支持用户确认后自动删除未使用资源。

// ⚠️ 注意事项：
// 删除不可恢复，请确保使用版本控制（如 Git）或备份；
// 动态拼接的路径无法被该脚本识别；
// 删除后请运行项目确认无误：
// flutter clean
// flutter pub get

import 'utils/cli_log_until.dart';
import 'dart:io';

final _generatedConstant = RegExp(
    r'''(?:static\s+)?const\s+(?:String\s+)?(\w+)\s*=\s*['"]([^'"]+)['"]\s*;''');

/// 找出 assets/ 中未被 lib/ 使用的主图（忽略倍图和自动生成目录中的图片）。
///
/// 自动生成的代码不能算作“使用”，否则生成的 Assets 类会让所有图片都显示为已用；
/// 但也不能忽略它：只有生成常量没有被业务代码引用时，对应图片才算未使用。
/// 生成文件中以常量以外的形式出现的图片，一律保守地视为已使用。
List<File> findUnusedAssets() {
  final imageExtensions = ['.png', '.jpg', '.jpeg', '.svg', '.webp'];
  final ignoreDirs = ['gen_a', 'generated', '.dart_tool'];

  bool isInResolutionFolder(String path) {
    return RegExp(r'[\\/](\d+(\.\d+)?x)[\\/]').hasMatch(path);
  }

  bool shouldIgnorePath(String path) {
    return ignoreDirs.any((dir) => path.contains('${Platform.pathSeparator}$dir${Platform.pathSeparator}'));
  }

  final imageFiles = Directory('assets')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) =>
          imageExtensions.any((ext) => f.path.toLowerCase().endsWith(ext)) &&
          !isInResolutionFolder(f.path) &&
          !shouldIgnorePath(f.path))
      .toList();

  logInfo('🔍 共找到 ${imageFiles.length} 个主图资源（已忽略倍图和自动生成目录）...');

  final dartFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  String joinContent(Iterable<File> files) => files.map((f) => f.readAsStringSync()).join('\n');

  final codeContent = joinContent(dartFiles.where((f) => !shouldIgnorePath(f.path)));
  final generatedContent = joinContent(dartFiles.where((f) => shouldIgnorePath(f.path)));

  final constants = _generatedConstant.allMatches(generatedContent).toList();
  final generatedWithoutConstants = generatedContent.replaceAll(_generatedConstant, '');

  bool isUsedThroughGenerated(String fileName) {
    if (generatedWithoutConstants.contains(fileName)) return true;
    return constants.any((c) =>
        c[2]!.split('/').last == fileName &&
        RegExp('\\b${RegExp.escape(c[1]!)}\\b').hasMatch(codeContent));
  }

  final unusedImages = <File>[];

  for (var imageFile in imageFiles) {
    final relativePath = imageFile.path.replaceFirst(RegExp(r'^.*assets[\\/]+'), 'assets/');
    final fileName = relativePath.split(Platform.pathSeparator).last;

    if (!codeContent.contains(relativePath) && !codeContent.contains(fileName) && !isUsedThroughGenerated(fileName)) {
      unusedImages.add(imageFile);
    }
  }

  return unusedImages;
}

Future<void> flutterDeleteUnusedAssets() async {
  if (!Directory('assets').existsSync()) {
    logError('❌ assets/ 文件夹不存在');
    exit(1);
  }

  if (!Directory('lib').existsSync()) {
    logError('❌ lib/ 文件夹不存在');
    exit(1);
  }

  final unusedImages = findUnusedAssets();

  logInfo('\n🚫 未使用的主图资源 (${unusedImages.length}):');
  for (var file in unusedImages) {
    logInfo(' - ${file.path}');
  }

  if (unusedImages.isEmpty) {
    logSuccess('✅ 所有图片资源均被使用，无需删除。');
    return;
  }

  final output = File('unused_assets.txt');
  output.writeAsStringSync(unusedImages.map((f) => f.path).join('\n'));
  logInfo('\n📄 未使用主图列表已导出到 unused_assets.txt');

  stdout.write('\n⚠️ 是否删除这些未使用主图及其倍图？（y/N）: ');
  final response = stdin.readLineSync()?.toLowerCase().trim();

  if (response == 'y') {
    int deleted = 0;

    for (var file in unusedImages) {
      final basePath = file.path;
      final dirName = File(basePath).parent.path;
      final fileName = basePath.split(Platform.pathSeparator).last;

      try {
        file.deleteSync();
        logSuccess('🗑️ 已删除主图: ${file.path}');
        deleted++;
      } catch (e) {
        logError('❌ 删除主图失败: ${file.path} → $e');
      }

      final resolutionDirs = ['1.5x', '2.0x', '2x', '3.0x', '3x', '4.0x'];
      for (var res in resolutionDirs) {
        final resPath = '$dirName${Platform.pathSeparator}$res${Platform.pathSeparator}$fileName';
        final resFile = File(resPath);
        if (resFile.existsSync()) {
          try {
            resFile.deleteSync();
            logSuccess('   ↳ 同步删除倍图: $resPath');
            deleted++;
          } catch (e) {
            logError('   ↳ 删除倍图失败: $resPath → $e');
          }
        }
      }
    }

    logSuccess('\n✅ 总共删除 $deleted 个文件（包括主图和倍图）。');
  } else {
    logWarning('❎ 未执行删除操作。');
  }
}

