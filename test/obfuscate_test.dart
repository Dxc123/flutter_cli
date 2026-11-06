import 'dart:convert';
import 'dart:io';

import 'package:cli/cli_obfuscate/obfuscate.dart';
import 'package:test/test.dart';

void write(String path, String content) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsStringSync(content);
}

Map<String, dynamic> readConfig() =>
    jsonDecode(File('lib/app_config.json').readAsStringSync());

void main() {
  late Directory temp;
  late Directory original;

  setUp(() {
    original = Directory.current;
    temp = Directory.systemTemp.createTempSync('obfuscate_test_');
    Directory.current = temp.path;
    write('pubspec.yaml', 'name: demo\n');
    write('lib/app/common/api/api.dart', '''
// '/commented/path'
const a = '/user/info';
const b = "/user/{id}/detail";
''');
    write('lib/model.dart', '''
import 'v_import_v.dart';
// v_comment_v
final partner = json['v_userName_v'];
final code = json['r_code_r'];
const other = '/user/info';
const web = '/not/an/api';
''');
  });

  tearDown(() {
    Directory.current = original.path;
    temp.deleteSync(recursive: true);
  });

  test('config maps only code in scope and keeps placeholders', () {
    generateObfuscateConfig();
    final config = readConfig();

    expect(config['packageGroup'], 'Demo');
    expect(config['pathMapping'].keys, ['/user/info', '/user/{id}/detail']);
    expect(config['pathMapping']['/user/{id}/detail'], endsWith('/{id}'));
    expect(config['propMapping'].keys, ['v_userName_v']);
    expect(config['rootMapping'].keys,
        containsAll(['r_code_r', 'r_data_r', 'r_message_r', 'r_success_r']));
  });

  test('config keeps existing mappings', () {
    write('lib/app_config.json',
        '{"packageGroup":"Keep","propMapping":{"v_userName_v":"fixedName"}}');
    generateObfuscateConfig();
    final config = readConfig();

    expect(config['packageGroup'], 'Keep');
    expect(config['propMapping']['v_userName_v'], 'fixedName');
    expect(config['pathMapping'], hasLength(2));
  });

  test('apply rewrites mapped tokens and is idempotent', () {
    generateObfuscateConfig();
    final config = readConfig();

    expect(applyObfuscation(), 2);
    final model = File('lib/model.dart').readAsStringSync();

    expect(model, contains("json['${config['propMapping']['v_userName_v']}']"));
    expect(model, contains("json['${config['rootMapping']['r_code_r']}']"));
    expect(model, contains("'${config['pathMapping']['/user/info']}'"));
    expect(model, contains("'/not/an/api'"));
    expect(model, contains('v_import_v'));
    expect(model, contains('v_comment_v'));
    expect(model, endsWith('\n'));
    expect(applyObfuscation(), 0);
  });

  test('config after apply does not obfuscate paths again', () {
    generateObfuscateConfig();
    final before = readConfig();
    applyObfuscation();

    generateObfuscateConfig();

    expect(readConfig(), before);
    expect(applyObfuscation(), 0);
  });

  test('apply writes nothing on dry run or unmapped properties', () {
    generateObfuscateConfig();
    final before = File('lib/model.dart').readAsStringSync();

    expect(applyObfuscation(dryRun: true), 2);
    expect(File('lib/model.dart').readAsStringSync(), before);

    write('lib/zzz.dart', "final x = 'v_unknown_v';\n");
    expect(applyObfuscation, throwsA(isA<ObfuscateException>()));
    expect(File('lib/model.dart').readAsStringSync(), before);
  });

  test('reports missing config and api directory', () {
    expect(applyObfuscation, throwsA(isA<ObfuscateException>()));
    expect(() => generateObfuscateConfig(apiDir: 'nope'),
        throwsA(isA<ObfuscateException>()));
  });
}
