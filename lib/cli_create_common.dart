import 'dart:io';
import 'package:path/path.dart' as path;

import 'utils/cli_confirm.dart';
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

/// 创建 common 目录结构并拉取模板；没有出错（包括用户取消）时返回 true。
Future<bool> createCommonStructure({
  Confirm confirm = askUser,
  TemplateLoader loader = loadTemplateFromGithub,
}) {
  final baseDir = path.join(Directory.current.path, 'common');
  final files = {
    for (final entry in templateStructure.entries)
      for (final fileName in entry.value)
        path.join(baseDir, entry.key, fileName):
            '${entry.key}/${fileName.replaceAll('.dart', '.template')}',
    // 顶层 index.dart
    path.join(baseDir, 'index.dart'): 'index.template',
  };
  return writeTemplates(files, githubBaseUrl, confirm: confirm, loader: loader);
}
