import 'dart:io';

import 'package:cli/cli_create_common.dart';
import 'package:cli/cli_create_page.dart';
import 'package:args/args.dart';
import 'package:cli/cli_delete_unused_assets.dart';
import 'package:cli/cli_flutter_cleaner.dart';
import 'package:cli/cli_flutter_gen_index.dart';
import 'package:cli/cli_image_modify_md5.dart';
import 'package:cli/utils/cli_load_template_util.dart';
import 'package:cli/utils/cli_log_until.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', help: '打印命令帮助信息', negatable: false)
    ..addFlag('version', abbr: 'v', help: '打印 CLI 工具版本', negatable: false)
    ..addFlag('clear', abbr: 'c', help: '删除 .template_cache 本地模板缓存', negatable: false)
    ..addFlag('clean', abbr: 'l', help: '清理所有 Flutter 项目', negatable: false)
    ..addFlag('generate', abbr: 'g', help: '导出所有 Dart 头文件生成 index.dart', negatable: false)
    ..addFlag('md5', abbr: 'm', help: '批量修改图片 MD5 值', negatable: false)
    ..addFlag('delete', abbr: 'd', help: '自动删除未使用资源', negatable: false);

  final createCommand = ArgParser()
    ..addOption('page', help: '创建 Flutter GetX 页面')
    ..addOption('common', help: '生成 common 目录');

  // 添加子命令
  parser.addCommand('create', createCommand);

  if (arguments.isEmpty) {
    logError('未检测到参数，使用 --help 查看命令帮助');
    print(parser.usage);
    exit(0);
  }

  final results = parser.parse(arguments);

  if (results.wasParsed('help')) {
    logInfo(parser.usage);
    exit(0);
  }

  if (results.wasParsed('version')) {
    logInfo('CLI 版本: v1.0.0');
    exit(0);
  }

  if (results.wasParsed('clear')) {
    await clearTemplateCache();
    exit(0);
  }

  if (results.wasParsed('clean')) {
    await flutterClean();
    exit(0);
  }

  if (results.wasParsed('generate')) {
    generateIndex();
    exit(0);
  }

  if (results.wasParsed('md5')) {
    await imagesModifyMD5();
    exit(0);
  }

  if (results.wasParsed('delete')) {
    await flutterDeleteUnusedAssets();
    exit(0);
  }

  if (results.command?.name == 'create') {
    final String? page = results.command!['page'];
    final String? common = results.command!['common'];
    logSuccess('Create Command Called');
    if (page != null) {
      logSuccess('  → 创建页面: $page');
      createPage(page);
    }
    if (common != null) {
      logSuccess('  → 创建 common 目录');
      await createCommonStructure();
    }
  }
}
