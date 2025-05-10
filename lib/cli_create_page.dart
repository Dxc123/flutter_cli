import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;

/// GitHub 原始模板地址（可替换为你的仓库）
/// raw.githubusercontent.com 是访问 GitHub 原始文件的推荐方式。
const githubBaseUrl = 'https://raw.githubusercontent.com/Dxc123/flutter_getx_template/main/lib/templates/page';

/// 所有目录及模板文件的映射
const Map<String, List<String>> templateStructure = {
  'bindings': ['binding.dart'],
  'views': ['view.dart'],
  'controllers': ['controller.dart'],
};

void createPage(String pageName) async {
  final className = toPascalCase(pageName);

  final currentPath = Directory.current.path;
  final modulesPath = path.join(currentPath, 'modules');
  final modulesDir = Directory(modulesPath);

  if (modulesDir.existsSync()) {
    print('✅ 使用已存在的 "modules" 目录：$modulesPath');
  }else {
    modulesDir.createSync(recursive: true);
    print('📁 创建 "modules" 目录：$modulesPath');
  }

  for (final entry in templateStructure.entries) {
    final baseDir = Directory(path.join(modulesPath, pageName));
    final folderPath = path.join(baseDir.path, entry.key);
    Directory(folderPath).createSync(recursive: true);
    print('📁 Created folder: $folderPath');

    for (final fileName in entry.value) {
      final content = await loadTemplateFromGithub('${entry.key}/${fileName.replaceAll('.dart', '.template')}');

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

//// 尝试从 GitHub 加载模板文件
Future<String?> loadTemplateFromGithub(String templateName) async {
  final url = '$githubBaseUrl/$templateName';
  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      print('✅ 从 GitHub 成功加载模板: $templateName');
      return response.body;
    } else {
      print('❌ GitHub 模板加载失败（${response.statusCode}）: $url');
      return null;
    }
  } catch (e) {
    print('❌ 加载 GitHub 模板出错: $e');
    return null;
  }
}
