import 'dart:io';

import 'package:path/path.dart' as path;

import 'utils/cli_confirm.dart';
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

/// 在 modules/[pageName] 下生成页面；没有出错（包括用户取消）时返回 true。
Future<bool> createPage(
  String pageName, {
  Confirm confirm = askUser,
  TemplateLoader loader = loadTemplateFromGithub,
}) {
  final className = toPascalCase(pageName);
  final pageDir = path.join(Directory.current.path, 'modules', pageName);
  final files = {
    for (final entry in templateStructure.entries)
      for (final fileName in entry.value)
        path.join(pageDir, entry.key, '${pageName}_$fileName'):
            '${entry.key}/${fileName.replaceAll('.dart', '.template')}',
  };
  return writeTemplates(
    files,
    githubBaseUrl,
    transform: (content) => content
        .replaceAll('{{className}}', className)
        .replaceAll('{{pageName}}', pageName),
    confirm: confirm,
    loader: loader,
  );
}

String toPascalCase(String str) {
  return str.split('_').map((word) => word.substring(0, 1).toUpperCase() + word.substring(1)).join('');
}
