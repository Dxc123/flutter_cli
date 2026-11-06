import 'dart:io';
import 'package:path/path.dart' as path;
import 'icon_font_gen_config.dart';
import 'pubspec_utils.dart';

class ConfigReader {
  Future<(IconFontGenConfig?, String)> readIconConfig() async {
    try {
      final projectPath = Directory.current.path;
      final yamlFilePath = path.join(projectPath, 'pubspec.yaml');
      if (!_fileExists(yamlFilePath)) {
        return (null, '当前目录中没有 pubspec.yaml 文件');
      }

      // 读取 pubspec.yaml 中的 flutter_icons 配置，缺失的项使用默认值
      final doc = PubspecUtils.pubspecJson;
      final section = doc is Map ? doc['flutter_icons'] : null;
      final config = section is Map ? section : const {};
      final srcZip = (config['src_zip'] as String?) ?? 'assets/icons_download.zip';
      final assetsDist = ((config['assets_dir'] as String?) ?? 'assets/icon_font').replaceAll(RegExp(r'/+$'), '');
      final fileDist = (config['dist_file'] as String?) ?? 'lib/app/data/utils/icon_until.dart';

      final iconsZipPath = path.join(projectPath, srcZip);
      if (!_fileExists(iconsZipPath)) {
        return (null, '找不到图标压缩包: $iconsZipPath');
      }
      return (
        IconFontGenConfig(
          assetsDist: assetsDist,
          fileDist: fileDist,
          srcZip: iconsZipPath,
          projectPath: projectPath,
        ),
        '准备生成'
      );
    } catch (e) {
      return (null, '读取配置文件时发生错误: $e');
    }
  }

  bool _fileExists(String filePath) {
    return File(filePath).existsSync();
  }

}
