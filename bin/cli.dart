import 'dart:io';

import 'package:cli/cli_create_common.dart';
import 'package:cli/cli_create_page.dart';
import 'package:args/args.dart';
import 'package:cli/cli_flutter_cleaner.dart';
import 'package:cli/cli_load_template_utils.dart';

void main(List<String> arguments) async{
  final parser =
      ArgParser()
        ..addFlag('help', abbr: 'h', help: 'Show usage information.', negatable: false)
        ..addFlag('version', abbr: 'v', help: 'Show version information.', negatable: false)
        ..addFlag('clear', abbr: 'c', help: '清理本地模板缓存.', negatable: false)
        ..addFlag('clean', abbr: 'l', help: '清理当前目录下所有Flutter项目以便释放更多磁盘空间', negatable: false);

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
