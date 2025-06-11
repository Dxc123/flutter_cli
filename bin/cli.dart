import 'dart:io';

import 'package:cli/cli_create_common.dart';
import 'package:cli/cli_create_page.dart';
import 'package:args/args.dart';
import 'package:cli/cli_delete_unused_assets.dart';
import 'package:cli/cli_flutter_cleaner.dart';
import 'package:cli/cli_flutter_gen_index.dart';
import 'package:cli/cli_image_modify_md5.dart';
import 'package:cli/utils/cli_load_template_util.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', help: '打印命令帮助信息', negatable: false)
    ..addFlag('version', abbr: 'v', help: '打印 CLI 工具版本', negatable: false)
    ..addFlag('clear', abbr: 'c', help: '删除 .template_cache 本地模板缓存', negatable: false)
    ..addFlag('clean', abbr: 'l', help: '清理当前目录下所有Flutter项目以便释放更多磁盘空间', negatable: false)
    ..addFlag('generate', abbr: 'g', help: '导出当前目录下所有dart头文件生成index.dart', negatable: false)
    ..addFlag('md5', abbr: 'm', help: '批量修改当前目录下所有图片的MD5值', negatable: false)
    ..addFlag('delete', abbr: 'd', help: '自动删除未使用资源', negatable: false)
    ..addFlag('create page:<pageName>', help: '创建flutter getX page', negatable: false)
    ..addFlag('create common', help: '生成common目录命令', negatable: false);

  final results = parser.parse(arguments);

  if (results['help']) {
    printUsage(parser);
    exit(0);
  }

  if (results['version']) {
    printVersion();
    exit(0);
  }

  if (results['clear']) {
    await clearTemplateCache();
    exit(0); // 清理完直接退出
  }

  if (results['clean']) {
    await flutterClean();
    exit(0); // 清理完直接退出
  }
  if (results['generate']) {
    generateIndex();
    exit(0); // 清理完直接退出
  }
  if (results['md5']) {
    await imagesModifyMD5();
    exit(0); // 清理完直接退出
  }
  if (results['delete']) {
    await flutterDeleteUnusedAssets();
    exit(0); // 清理完直接退出
  }

  if (arguments.length < 2 || arguments.first != 'create') {
    printUsage(parser);
    exit(1);
  }

  final command = arguments.sublist(1).join(' ');

  if (command.startsWith('page:')) {
    final pageName = command.split(':')[1];
    createPage(pageName);
  } else if (command.startsWith('common')) {
    await createCommonStructure();
  } else {
    print('Invalid command format. Expected: create page:<pagename>');
    printUsage(parser);
    exit(1);
  }
}

void printUsage(ArgParser parser) {
  print('Usage:');
  print('  cli [options] create page:<pagename>');
  print('');
  print(parser.usage);
}

void printVersion() {
  print('cli version v1.0.0');
}
