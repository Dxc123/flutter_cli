import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

Future<void> flutterConvertAssetsToWebp() async {
  final assetsDir = Directory('assets');
  final libDir = Directory('lib');

  if (!assetsDir.existsSync()) {
    print('❌ assets 文件夹不存在');
    return;
  }

  print('🔍 开始转换 PNG 为 WebP...');
  await convertPngToWebp(assetsDir);

  print('🔁 开始修改 lib 中图片引用...');
  await updateLibImageReferences(libDir);

  print('✅ 全部完成！');
}

Future<void> convertPngToWebp(Directory dir) async {
  await for (var entity in dir.list(recursive: true)) {
    if (entity is File && entity.path.toLowerCase().endsWith('.png')) {
      final bytes = await entity.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image != null) {
        final pngPath = entity.path;
        final webpPath = pngPath.replaceAll('.png', '.webp');

        // 保存为临时 PNG 文件
        final tempPngPath = '$pngPath.tmp.png';
        final pngBytes = img.encodePng(image);
        await File(tempPngPath).writeAsBytes(pngBytes);
        // Dart 库 image 无法编码 WebP 或存在兼容性问题
        // 调用 cwebp 命令行工具转换为 WebP
        // 前提条件:必须 安装 cwebp 工具
        //macOS使用命令: brew install webp
        final result = await Process.run('cwebp', ['-q', '80', tempPngPath, '-o', webpPath]);
        if (result.exitCode == 0) {
          print('✅ $pngPath → $webpPath');
        } else {
          print('❌ 转换失败: ${result.stderr}');
        }

        await File(tempPngPath).delete(); // 清理临时文件
      }
    }
  }
}


Future<void> updateLibImageReferences(Directory dir) async {
  await for (var entity in dir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      String content = await entity.readAsString();
      final regExp = RegExp(r'(["\']assets/[^"\']+?)\.png(["\'])') ; //// 实际运行没问题，但 IDE 报错
      final updatedContent = content.replaceAllMapped(
        regExp,
            (match) => '${match[1]}.webp${match[2]}',
      );

      if (content != updatedContent) {
        await entity.writeAsString(updatedContent);
        print('✏️ 更新路径: ${entity.path}');
      }
    }
  }
}
