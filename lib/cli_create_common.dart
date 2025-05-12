import 'dart:io';
import 'package:path/path.dart' as path;

import 'utils/cli_load_template_util.dart';

/// GitHub 原始模板地址（可替换为你的仓库）
const githubBaseUrl = 'https://raw.githubusercontent.com/Dxc123/flutter_getx_template/main/lib/templates/common';

/// 所有目录及模板文件的映射
const Map<String, List<String>> templateStructure = {
  'api': ['index.dart'],
  'components': ['index.dart'],
  'extension': [
    'index.dart',
    'align_extension.dart',
    'container_extension.dart',
    'date_time_extension.dart',
    'positioned_extension.dart',
    'size_box_extension.dart',
    'widget_padding_extension.dart',
  ],
  'i18n': ['index.dart'],
  'models': ['index.dart'],
  'routers': [
    'index.dart',
    'names.dart',
    'pages.dart',
  ],
  'services': ['index.dart'],
  'style': ['index.dart'],
  'utils': ['index.dart'],
  'values': [
    'index.dart',
    'constants.dart',
    'images.dart',
    'svgs.dart',
    'enums.dart',
  ],
  'widgets': ['index.dart'],
};

/// 创建 common 目录结构并拉取模板
Future<void> createCommonStructure() async {
  final baseDir = Directory(path.join(Directory.current.path, 'common'));

  for (final entry in templateStructure.entries) {
    final folderPath = path.join(baseDir.path, entry.key);
    Directory(folderPath).createSync(recursive: true);
    print('📁 Created folder: $folderPath');

    for (final fileName in entry.value) {
      final content = await loadTemplateFromGithub(
        '${entry.key}/${fileName.replaceAll('.dart', '.template')}',
        githubBaseUrl,
      );
      if (content == null) {
        print('❌ Failed to fetch template: ${entry.key}/$fileName');
        exit(1);
      }

      final filePath = path.join(folderPath, fileName);
      File(filePath).writeAsStringSync(content);
      print('✅ Created file: $filePath');
    }
  }

  // 顶层 index.dart
  final indexContent = await loadTemplateFromGithub(
    'index.template',
    githubBaseUrl,
  );
  if (indexContent == null) {
    print('❌ Failed to fetch root index.template');
    exit(1);
  }

  final indexFilePath = path.join(baseDir.path, 'index.dart');
  File(indexFilePath).writeAsStringSync(indexContent);
  print('🚀 Created file: $indexFilePath');
}
