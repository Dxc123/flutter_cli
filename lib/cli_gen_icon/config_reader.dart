import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';
import '../../../../common/utils/logger/log_utils.dart';
import '../../../../common/utils/pubspec/pubspec_utils.dart';
import 'icon_font_gen_config.dart';

class ConfigReader {
  Future<(IconFontGenConfig?, String)> readIconConfig() async {
    try {
      final projectPath = Directory.current.path;
      print("当前目录路径 = $projectPath");
      final yamlFilePath = path.join(projectPath, 'pubspec.yaml');
      if (!_fileExists(yamlFilePath)) {
        return (null, '当前目录中没有 pubspec.yaml 文件');
      }
      print("当前yamlFilePath = $yamlFilePath");

      final iconsZipPath = path.join(projectPath, 'assets/icons_download.zip');
      if (!_fileExists(iconsZipPath)) {
        return (null, '当前目录中没有 $iconsZipPath 文件');
      }
      print("当前iconsZipPath = $iconsZipPath");

      // final configValues = await _readYamlConfig(yamlFilePath);
      // 读取 pubspec.yaml 中的 flutter_icons 设置配置
      Map<String, dynamic> configValues = {};
      String assetsDist = "assets/icon_font";
      String fileDist = "lib/app/data/utils/icon_until.dart";
      final doc = PubspecUtils.pubspecJson;
      LogService.info("pubspecJson = $doc");
      Map<String, dynamic> docMap = {};
      try {
        docMap = json.decode(doc);
      } catch (e) {
        print("docMap解析失败,使用默认配置");
      }
      LogService.info("pubspecMap = $docMap");
      if (docMap.containsKey('flutter_icons')) {
        configValues = docMap['flutter_icons'];
        if ((docMap['flutter_icons'] as Map).containsKey('src_zip')) {
          assetsDist = configValues['assets_dir'] ?? 'assets/icon_font';
        } else if ((docMap['flutter_icons'] as Map).containsKey('dist_file')) {
          fileDist = configValues['dist_file'] ?? 'lib/icon_until.dart';
        } else {
          return (null, '当前目录中没有 flutter_icons 下缺少 src_zip 或 dist_file 配置使用默认配置 ');
        }
      } else {
        print("pubspec.yaml 中的 flutter_icons 没有配置,使用默认配置");
      }
      print("pubspec.yaml 文件中配置configValues = $configValues");
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

// Future<Map<String, dynamic>> _readYamlConfig(String yamlFilePath) async {
//   // final yaml = await File(yamlFilePath).readAsString();
//   // final doc = loadYaml(yaml);
//   // return doc?['toly'] ?? {};
//   final doc = PubspecUtils.pubspecJson;
//   LogService.info("pubspecJson = $doc");
//   if (doc.containsKey('toly')) {
//     if ((doc['toly'] as Map).containsKey('src_zip')) {
//       return (doc['toly'] as Map<String, dynamic>);
//     }
//   }
//   return {};
// }
//
// Future<String> _getConfigValue(String yamlFilePath, String key, String defaultValue) async {
//   final configValues = await _readYamlConfig(yamlFilePath);
//   return configValues[key] ?? defaultValue;
// }
}
