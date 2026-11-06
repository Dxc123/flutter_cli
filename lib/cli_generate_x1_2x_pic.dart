import 'dart:io';
import 'package:cli/utils/cli_log_until.dart';
import 'package:image/image.dart';
import 'package:path/path.dart' as p;

Future<void> generateX1_2xPic() async {
  final baseDir = Directory.current;

  logInfo('🔍 正在扫描 ${baseDir.path} 下的 3.0x 图片...');

  final files = _findImagesIn3x(baseDir);

  if (files.isEmpty) {
    logError('⚠️ 未找到任何 3.0x 图片。');
    return;
  }

  logInfo('✅ 共找到 ${files.length} 张图片，开始处理...\n');

  for (final file in files) {
    try {
      await _processImage(file);
    } catch (e) {
      logError('❌ 处理失败: ${file.path} => $e');
    }
  }

  logInfo('\n🎉 所有图片处理完成。');
}

List<File> _findImagesIn3x(Directory dir) {
  final List<File> imageFiles = [];

  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File &&
        (entity.path.contains('${p.separator}3.0x${p.separator}')) &&
        (entity.path.endsWith('.png') || entity.path.endsWith('.jpg'))) {
      imageFiles.add(entity);
    }
  }

  return imageFiles;
}

Future<void> _processImage(File file) async {
  final imgBytes = await file.readAsBytes();
  final image = decodeImage(imgBytes);

  if (image == null) throw '无法解析图片：${file.path}';

  final originPath = file.path;

  // 构造输出路径
  final parentDir = Directory(p.dirname(p.dirname(originPath)));
  final relPath = p.relative(originPath, from: p.join(parentDir.path, '3.0x'));
  final filename = p.basename(relPath);

  final x1Path = p.join(parentDir.path, filename);
  final x2Path = p.join(parentDir.path, '2.0x', relPath);

  final image1x = copyResize(image, width: (image.width / 3).round());
  final image2x = copyResize(image, width: (image.width * 2 / 3).round());

  await File(x1Path).create(recursive: true);
  await File(x2Path).create(recursive: true);

  await File(x1Path).writeAsBytes(encodeImage(image1x, originPath));
  await File(x2Path).writeAsBytes(encodeImage(image2x, originPath));

  logSuccess('✅ $relPath => 1.0x / 2.0x 生成成功');
}

List<int> encodeImage(Image image, String path) {
  if (path.endsWith('.png')) return encodePng(image);
  if (path.endsWith('.jpg')) return encodeJpg(image);
  throw '不支持的图片格式: $path';
}
