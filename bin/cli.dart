import 'dart:io';

import 'package:cli/cli_convert_assets_to_webp.dart';
import 'package:cli/cli_create_common.dart';
import 'package:cli/cli_create_page.dart';
import 'package:args/args.dart';
import 'package:cli/cli_delete_unused_assets.dart';
import 'package:cli/cli_flutter_cleaner.dart';
import 'package:cli/cli_flutter_gen_index.dart';
import 'package:cli/cli_generate_assets.dart';
import 'package:cli/cli_generate_languages.dart';
import 'package:cli/cli_generate_scan_add_asset_folders.dart';
import 'package:cli/cli_image_modify_md5.dart';
import 'package:cli/utils/cli_load_template_util.dart';
import 'package:cli/utils/cli_log_until.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', help: '打印 CLI 工具帮助信息', negatable: false)
    ..addFlag('version', abbr: 'v', help: '打印 CLI 工具版本', negatable: false)
    ..addFlag('clear', abbr: 'c', help: '清除模板缓存 .template_cache', negatable: false)
    ..addFlag('clean', abbr: 'l', help: '清理所有 Flutter 项目', negatable: false)
    ..addFlag('generate', abbr: 'g', help: '生成 index.dart（导出 Dart 头文件）', negatable: false)
    ..addFlag('md5', abbr: 'm', help: '批量修改图片 MD5 值', negatable: false)
    ..addFlag('webp',abbr: 'w', help: '批量修改asset目录下图片格式:png->webp,同时修改lib目录下代码引用', negatable: false)
    ..addFlag('delete', abbr: 'd', help: '自动删除未使用资源', negatable: false)
    ..addFlag('excel', abbr: 'e', help: '读取Excel表格翻译内容生成对应的语言文件', negatable: false)
    ..addFlag('scan', abbr: 's', help: '自动扫描资源assets文件夹以及其子文件夹并写入 pubspec.yaml', negatable: false)
    ..addFlag('assets', abbr: 'a', help: '读取 pubspec.yaml 中 flutter.assets 配，并将assets下的资源生成 Dart 静态资源类 Assets', negatable: false);

  // 子命令：create
  final createCommand = ArgParser()
    ..addOption('page', abbr: 'p', help: '创建 Flutter GetX 页面')
    ..addOption('common', abbr: 'o', help: '生成 common 目录结构')
    ..addFlag('help', abbr: 'h', help: '显示 create 子命令帮助', negatable: false);
  parser.addCommand('create', createCommand);

  if (arguments.isEmpty) {
    logError('未检测到参数，使用 --help 查看帮助');
    printGlobalHelp(parser);
    exit(0);
  }

  final results = parser.parse(arguments);

  // 全局帮助
  if (results.wasParsed('help')) {
    printGlobalHelp(parser);
    exit(0);
  }

  // 全局版本
  if (results.wasParsed('version')) {
    logInfo('CLI 版本: v1.0.0');
    exit(0);
  }

  // 具体命令执行
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
  if (results.wasParsed('webp')) {
    await flutterConvertAssetsToWebp();
    exit(0);
  }

  if (results.wasParsed('delete')) {
    await flutterDeleteUnusedAssets();
    exit(0);
  }

  if (results.wasParsed('excel')) {
    await generatedLanguages();
    exit(0);
  }
  if (results.wasParsed('scan')) {
    await scanAndAddAssetFolders();
    exit(0);
  }
  if (results.wasParsed('assets')) {
    await generateAssets();
    exit(0);
  }

  // 子命令解析
  if (results.command?.name == 'create') {
    final command = results.command!;
    final page = command['page'] as String?;
    final common = command['common'] as String?;

    // 子命令帮助
    if (command.wasParsed('help')) {
      logInfo('create 子命令使用说明:');
      logInfo(parser.commands['create']!.usage);
      exit(0);
    }

    logSuccess('执行 create 命令');

    // 校验冲突（可选）
    if (page != null && common != null) {
      logWarning('不能同时指定 --page 和 --common，请分开执行。');
      exit(1);
    }

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

/// 打印全局帮助信息
void printGlobalHelp(ArgParser parser) {
  logInfo('CLI 工具支持以下命令：\n');
  logInfo(parser.usage);
  logInfo('''
子命令：
  create           创建页面或目录
    -p, --page     创建 Flutter GetX 页面
    -o, --common   创建 common 目录
    -h, --help     显示 create 子命令帮助

用法示例：
  cli --clean
  cli create --page home
  cli create --common
  cli create --help
''');
}
