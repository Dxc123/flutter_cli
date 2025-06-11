import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';

import 'icon_font_gen_config.dart';
import 'package:path/path.dart' as path;

class IconFontClassParser {
  void gen(IconFontGenConfig config) {
    print('开始解析...srcZip = ${config.srcZip}');
    print('开始解析...assetsDist = ${config.assetsDist}');
    print('开始解析...fileDist = ${config.fileDist}');
    print('开始解析...projectPath = ${config.projectPath}');
    final inputStream = InputFileStream(config.srcZip);
    // 将压缩包有用资源解压到目标文件
    final archive = ZipDecoder().decodeBuffer(inputStream);
    // print('压缩包解压...files = ${archive.files}');
    for (var file in archive.files) {
      if (file.isFile) {
        if (file.name.endsWith('.ttf')) {
          final outputStream = OutputFileStream(config.ttfDistPath);
          file.writeContent(outputStream);
          outputStream.close();
        }
        if (file.name.endsWith('.json')) {
          dynamic data = file.content;
          String jsonContent = utf8.decode(data);
          String resultCode = parser(jsonContent, config.fontFamily);
          File distFile = File(config.distFilePath);
          if (!distFile.existsSync()) {
            distFile.createSync(recursive: true);
          }
          distFile.writeAsStringSync(resultCode);
          setYaml(config);
        }
      }
    }
  }

  String parser(String input, String fontFamily) {
    dynamic map = json.decode(input);
    List<dynamic> glyphs = map['glyphs'] as List<dynamic>;
    String code = '';
    for (int i = 0; i < glyphs.length; i++) {
      String fieldName = suitFieldName(glyphs[i]['font_class']);
      String unicode = glyphs[i]['unicode'];
      String lineCode = """static const IconData $fieldName = IconData(0x$unicode, fontFamily: "$fontFamily");\n""";
      code += lineCode;
    }

    String result = """
import 'package:flutter/widgets.dart';

class $fontFamily {
    $fontFamily._();
    $code
}  
""";
    return result;
  }

  /// 将不合规范的名称合法化
  String suitFieldName(String input) {
    String output = input.replaceAll('-', '_');
    return output;
  }

  // 修改 pubspec.yaml
  void setYaml(IconFontGenConfig config) {
    String familyName = config.fontFamily;
    String fontAssetsDist = config.yamlAssetDist;
    final String filePath = path.join(config.projectPath, 'pubspec.yaml');
    File pubspecFile = File(filePath);

    List<String> lines = pubspecFile.readAsLinesSync();
    RegExp fontsRegex = RegExp(r'^  fonts:', multiLine: true);
    bool hasFonts = fontsRegex.hasMatch(lines.join('\n'));

    if (!hasFonts) {
      // 当前没有 fonts 节点，需要添加到 flutter 节点下
      int index = lines.indexWhere((e) => e.startsWith('flutter:'));
      List<String> fonts = [
        '  fonts:',
        '    - family: $familyName',
        '      fonts:',
        '        - asset: $fontAssetsDist',
      ];

      lines.insertAll(index + 1, fonts);
      pubspecFile.writeAsStringSync(lines.join('\n'));
      return;
    }
    // 存在 fonts 节点，查询 family ，有没有当前字体图标
    bool hasTargetFamily = false;
    RegExp regExp = RegExp(r'^ +- family: +(\w+)');

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];
      if (line.startsWith(regExp)) {
        String family = regExp.allMatches(line).first.group(1) ?? '';
        if (family == familyName) {
          hasTargetFamily = true;
          break;
        }
      }
    }
    if (!hasTargetFamily) {
      int index = lines.indexWhere((e) => e.startsWith(fontsRegex));
      List<String> fonts = [
        '    - family: $familyName',
        '      fonts:',
        '        - asset: $fontAssetsDist',
      ];
      lines.insertAll(index + 1, fonts);
      pubspecFile.writeAsStringSync(lines.join('\n'));
    }
  }
}
