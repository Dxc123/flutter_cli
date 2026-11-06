import 'dart:io';

import 'package:path/path.dart' as path;

import 'utils/cli_load_template_util.dart';

/// GitHub 原始模板地址（可替换为你的仓库）
/// raw.githubusercontent.com 是访问 GitHub 原始文件的推荐方式。
const githubBaseUrl = 'https://raw.githubusercontent.com/Dxc123/flutter_getx_template/main/lib/templates/page';

/// 所有目录及模板文件的映射
const Map<String, List<String>> templateStructure = {
  'bindings': ['binding.dart'],
  'views': ['view.dart'],
  'controllers': ['controller.dart'],
};

Future<void> createPage(String pageName) async {
  final className = toPascalCase(pageName);

  final currentPath = Directory.current.path;
  final modulesPath = path.join(currentPath, 'modules');
  final modulesDir = Directory(modulesPath);

  if (modulesDir.existsSync()) {
    print('✅ 使用已存在的 "modules" 目录：$modulesPath');
  } else {
    modulesDir.createSync(recursive: true);
    print('📁 创建 "modules" 目录：$modulesPath');
  }

  for (final entry in templateStructure.entries) {
    final baseDir = Directory(path.join(modulesPath, pageName));
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

      final finalContent = content.replaceAll('{{className}}', className);
      final finalContent22 = finalContent.replaceAll('{{pageName}}', pageName);

      final filePath = path.join(folderPath, "${pageName}_$fileName");
      File(filePath).writeAsStringSync(finalContent22);
      print('✅ Created file: $filePath');
    }
  }
}

String toPascalCase(String str) {
  return str.split('_').map((word) => word.substring(0, 1).toUpperCase() + word.substring(1)).join('');
}
