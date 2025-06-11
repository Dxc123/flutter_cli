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

Future<void> flutterDeleteUnusedAssets() async {
  final imageExtensions = ['.png', '.jpg', '.jpeg', '.svg', '.webp'];
  final assetFolder = Directory('assets');
  final codeFolder = Directory('lib');

  if (!assetFolder.existsSync()) {
    logInfo('❌ assets/ 文件夹不存在');
    exit(1);
  }

  if (!codeFolder.existsSync()) {
    logError('❌ lib/ 文件夹不存在');
    exit(1);
  }

  final imageFiles = assetFolder.listSync(recursive: true).whereType<File>().where((f) => imageExtensions.any((ext) => f.path.toLowerCase().endsWith(ext))).toList();

  logInfo('🔍 共找到 ${imageFiles.length} 个图片资源...');

  final dartFiles = codeFolder.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList();

  final codeContent = dartFiles.map((f) => f.readAsStringSync()).join('\n');

  final unusedImages = <File>[];

  for (var imageFile in imageFiles) {
    final relativePath = imageFile.path.replaceFirst(RegExp(r'^.*assets[\/\\]'), 'assets/');
    final fileName = relativePath.split(Platform.pathSeparator).last;

    if (!codeContent.contains(relativePath) && !codeContent.contains(fileName)) {
      unusedImages.add(imageFile);
    }
  }

  logInfo('\n🚫 未使用的图片资源 (${unusedImages.length}):');
  for (var file in unusedImages) {
    logInfo(' - ${file.path}');
  }

  if (unusedImages.isEmpty) {
    logSuccess('✅ 所有图片资源均被使用，无需删除。');
    return;
  }

  // 导出列表
  final output = File('unused_assets.txt');
  output.writeAsStringSync(unusedImages.map((f) => f.path).join('\n'));
  logInfo('\n📄 未使用资源路径已导出到 unused_assets.txt');

  // 是否删除
  stdout.write('\n⚠️ 是否删除这些未使用图片？（y/N）: ');
  final response = stdin.readLineSync()?.toLowerCase().trim();

  if (response == 'y') {
    int deleted = 0;
    for (var file in unusedImages) {
      try {
        file.deleteSync();
        logSuccess('🗑️ 已删除: ${file.path}');
        deleted++;
      } catch (e) {
        logError('❌ 删除失败: ${file.path} → $e');
      }
    }
    logSuccess('\n✅ 已删除 $deleted 个未使用图片文件。');
  } else {
    logWarning('❎ 未执行删除操作。');
  }
}
