/// `create` 子命令解析后的目标：页面或 common 目录。
class CreateTarget {
  final String? pageName;
  final bool isCommon;

  const CreateTarget.page(String this.pageName) : isCommon = false;

  const CreateTarget.common()
      : pageName = null,
        isCommon = true;
}

final _pageNamePattern = RegExp(r'^[a-z][a-z0-9]*(_[a-z0-9]+)*$');

/// 解析 `create` 的参数，支持：
/// `page:name`、`common`、`--page name`、`--common`。
/// 参数缺失、未知、冲突或页面名不合法时抛出 [FormatException]。
CreateTarget resolveCreateTarget({
  String? page,
  bool common = false,
  List<String> rest = const [],
}) {
  var pageName = page;
  var isCommon = common;

  for (final arg in rest) {
    if (arg == 'common') {
      isCommon = true;
    } else if (arg.startsWith('page:') && pageName == null) {
      pageName = arg.substring('page:'.length);
    } else {
      throw FormatException('无法识别的参数: $arg');
    }
  }

  if (pageName != null && isCommon) {
    throw const FormatException('不能同时创建页面和 common，请分开执行。');
  }
  if (isCommon) return const CreateTarget.common();
  if (pageName == null) {
    throw const FormatException('请指定要创建的内容：page:<页面名> 或 common');
  }
  if (!_pageNamePattern.hasMatch(pageName)) {
    throw FormatException('页面名不合法: "$pageName"，请使用小写蛇形命名，如 zt_home');
  }
  return CreateTarget.page(pageName);
}
