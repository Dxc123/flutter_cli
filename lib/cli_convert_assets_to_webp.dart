import 'dart:io';
import 'package:image/image.dart' as img;

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
  int total = 0, success = 0, fail = 0;

  await for (var entity in dir.list(recursive: true)) {
    if (entity is File && entity.path.toLowerCase().endsWith('.png')) {
      total++;
      final pngPath = entity.path;
      final webpPath = pngPath.replaceAll(RegExp(r'\.png$', caseSensitive: false), '.webp');

      if (File(webpPath).existsSync()) {
        print('⚠️ 已存在，跳过: $webpPath');
        continue;
      }

      final bytes = await entity.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image != null) {
        final tempPngPath = '$pngPath.tmp.png';
        final pngBytes = img.encodePng(image);
        await File(tempPngPath).writeAsBytes(pngBytes);

        final result = await Process.run('cwebp', ['-q', '80', tempPngPath, '-o', webpPath]);

        await File(tempPngPath).delete(); // 清理临时文件

        if (result.exitCode == 0) {
          print('✅ $pngPath → $webpPath');
          success++;

          // 删除原始 PNG 文件
          try {
            await entity.delete();
            print('🗑️ 已删除原 PNG 文件: $pngPath');
          } catch (e) {
            print('⚠️ 删除失败: $pngPath - $e');
          }
        } else {
          print('❌ 转换失败: ${result.stderr}');
          fail++;
        }
      } else {
        print('❌ 解码失败: $pngPath');
        fail++;
      }
    }
  }

  print('\n📊 转换统计: 总数 $total, 成功 $success, 失败 $fail\n');
}

Future<void> updateLibImageReferences(Directory dir) async {
  final regExp = RegExp(r'''(["']assets[\/\\][^"']+?)\.png(["'])''');

  await for (var entity in dir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      String content = await entity.readAsString();

      final updatedContent = content.replaceAllMapped(
        regExp,
            (match) => '${match[1]}.webp${match[2]}',
      );

      if (content != updatedContent) {
        final backupPath = '${entity.path}.bak';
        await File(entity.path).copy(backupPath);

        await entity.writeAsString(updatedContent);
        print('✏️ 更新路径: ${entity.path}（已备份为 .bak）');
      }
    }
  }
}
