import 'dart:io';

import 'package:cli/cli_convert_assets_to_webp.dart';
import 'package:cli/cli_create_common.dart';
import 'package:cli/cli_create_page.dart';
import 'package:cli/cli_create_target.dart';
import 'package:args/args.dart';
import 'package:cli/cli_delete_unused_assets.dart';
import 'package:cli/cli_flutter_cleaner.dart';
import 'package:cli/cli_flutter_gen_index.dart';
import 'package:cli/cli_gen_icon/icon_gen.dart';
import 'package:cli/cli_generate_assets.dart';
import 'package:cli/cli_generate_languages.dart';
import 'package:cli/cli_generate_scan_add_asset_folders.dart';
import 'package:cli/cli_generate_x1_2x_pic.dart';
import 'package:cli/cli_image_modify_md5.dart';
import 'package:cli/cli_obfuscate/obfuscate.dart';
import 'package:cli/utils/cli_confirm.dart';
import 'package:cli/utils/cli_load_template_util.dart';
import 'package:cli/utils/cli_log_until.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', help: '打印 CLI 工具帮助信息', negatable: false)
    ..addFlag('version', abbr: 'v', help: '打印 CLI 工具版本', negatable: false)
    ..addFlag('clear', abbr: 'c', help: '清除模板缓存 .template_cache', negatable: false)
    ..addFlag('clean', abbr: 'l', help: '清理所有 Flutter 项目', negatable: false)
    ..addFlag('generate', abbr: 'g', help: '生成 index.dart(导出Dart头文件)', negatable: false)
    ..addFlag('md5', abbr: 'm', help: '批量修改asset目录下图片MD5值', negatable: false)
    ..addFlag('webp',abbr: 'w', help: '批量修改asset目录下图片格式:png->webp,同时修改lib目录下代码引用', negatable: false)
    ..addFlag('x1x2',abbr: 'x', help: '根据x3图片自动生成x1和x2图片', negatable: false)
    ..addFlag('delete', abbr: 'd', help: '批量删除asset目录下未使用资源', negatable: false)
    ..addFlag('excel', abbr: 'e', help: '读取assets目录下Excel表格(assets/languages.xlsx)翻译内容生成对应的语言文件', negatable: false)
    ..addFlag('scan', abbr: 's', help: '将assets路径自动加入pubspec.yaml', negatable: false)
    ..addFlag('assets', abbr: 'a', help: '将assets下的资源生成Dart静态资源类文件Assets.dart', negatable: false)
    ..addFlag('yes', abbr: 'y', help: '跳过确认提示，直接执行删除或覆盖', negatable: false);

  // 子命令：create
  final createCommand = ArgParser()
    ..addOption('page', abbr: 'p', help: '创建 Flutter GetX 页面')
    ..addFlag('common', abbr: 'o', help: '生成 common 目录结构', negatable: false)
    ..addFlag('yes', abbr: 'y', help: '已存在的文件直接覆盖，不再确认', negatable: false)
    ..addFlag('help', abbr: 'h', help: '显示 create 子命令帮助', negatable: false);
  parser.addCommand('create', createCommand);

  // 子命令：generate
  parser.addCommand('generate');

  // 子命令：obfuscate
  parser.addCommand(
    'obfuscate',
    ArgParser()
      ..addOption('api-dir', help: '接口定义目录（相对 lib）', defaultsTo: defaultApiDir)
      ..addFlag('dry-run', help: 'apply 时只预览，不写入文件', negatable: false),
  );

  if (arguments.isEmpty) {
    logError('未检测到参数，使用 --help 查看帮助');
    printGlobalHelp(parser);
    exit(64);
  }

  final ArgResults results;
  try {
    results = parser.parse(arguments);
  } on FormatException catch (e) {
    logError(e.message);
    printGlobalHelp(parser);
    exit(64);
  }

  try {
    await _run(parser, results);
  } on ConfirmationRequired catch (e) {
    logError(e.toString());
    exit(1);
  }
}

Future<void> _run(ArgParser parser, ArgResults results) async {
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

  final confirm = confirmer(yes: results['yes'] as bool);

  // 具体命令执行
  if (results.wasParsed('clear')) {
    await clearTemplateCache(confirm: confirm);
    exit(0);
  }

  if (results.wasParsed('clean')) {
    exit(await flutterClean() ? 0 : 1);
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
    exit(await flutterConvertAssetsToWebp(confirm: confirm) ? 0 : 1);
  }
  if (results.wasParsed('x1x2')) {
    exit(await generateX1_2xPic(confirm: confirm) ? 0 : 1);
  }

  if (results.wasParsed('delete')) {
    await flutterDeleteUnusedAssets(confirm: confirm);
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

  // 子命令：generate icons
  if (results.command?.name == 'generate') {
    if (results.command!.rest.join(' ') != 'icons') {
      logError('用法: cli generate icons');
      exit(64);
    }
    await const IconGen().gen();
    exit(0);
  }

  // 子命令：obfuscate config / apply
  if (results.command?.name == 'obfuscate') {
    final command = results.command!;
    try {
      switch (command.rest.join(' ')) {
        case 'config':
          generateObfuscateConfig(apiDir: command['api-dir'] as String);
        case 'apply':
          applyObfuscation(dryRun: command['dry-run'] as bool);
        default:
          logError('用法: cli obfuscate config [--api-dir 目录] | cli obfuscate apply [--dry-run]');
          exit(64);
      }
    } on ObfuscateException catch (e) {
      logError(e.message);
      exit(1);
    }
    exit(0);
  }

  // 子命令解析
  if (results.command?.name == 'create') {
    final command = results.command!;

    // 子命令帮助
    if (command.wasParsed('help')) {
      logInfo('create 子命令使用说明:');
      logInfo(parser.commands['create']!.usage);
      exit(0);
    }

    final CreateTarget target;
    try {
      target = resolveCreateTarget(
        page: command['page'] as String?,
        common: command['common'] as bool,
        rest: command.rest,
      );
    } on FormatException catch (e) {
      logError(e.message);
      logInfo(parser.commands['create']!.usage);
      exit(64);
    }

    final createConfirm =
        command['yes'] as bool ? alwaysYes : confirm;
    final bool ok;
    if (target.isCommon) {
      logSuccess('  → 创建 common 目录');
      ok = await createCommonStructure(confirm: createConfirm);
    } else {
      logSuccess('  → 创建页面: ${target.pageName}');
      ok = await createPage(target.pageName!, confirm: createConfirm);
    }
    exit(ok ? 0 : 1);
  }

  // 没有匹配到任何命令（如只传了 -y）
  logError('未指定要执行的命令');
  printGlobalHelp(parser);
  exit(64);
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
    -y, --yes      已存在的文件直接覆盖
    -h, --help     显示 create 子命令帮助

  generate icons   根据 iconfont 压缩包生成图标类

  obfuscate config 生成或补全 lib/app_config.json
  obfuscate apply  按配置混淆接口和模型

用法示例：
  cli --clean
  cli create page:home（或 cli create --page home）
  cli create common（或 cli create --common）
  cli create --help
  cli -w -y（跳过确认，直接转换并删除原 PNG）
''');
}
