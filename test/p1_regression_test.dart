import 'dart:io';

import 'package:archive/archive.dart';
import 'package:cli/cli_flutter_cleaner.dart';
import 'package:cli/cli_gen_icon/icon_gen.dart';
import 'package:cli/cli_generate_languages.dart';
import 'package:cli/cli_generate_scan_add_asset_folders.dart';
import 'package:cli/cli_image_modify_md5.dart';
import 'package:test/test.dart';

void write(String path, String content) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsStringSync(content);
}

void main() {
  late Directory temp;
  late Directory original;

  setUp(() {
    original = Directory.current;
    temp = Directory.systemTemp.createTempSync('p1_test_');
    Directory.current = temp.path;
  });

  tearDown(() {
    Directory.current = original.path;
    temp.deleteSync(recursive: true);
  });

  test('generate icons honours flutter_icons config', () async {
    write('pubspec.yaml', '''
name: x
flutter:
  uses-material-design: true
flutter_icons:
  src_zip: assets/download.zip
  assets_dir: assets/fonts/
  dist_file: lib/gen/my_icon.dart
''');
    const json = '{"glyphs":[{"font_class":"a-b","unicode":"e600"}]}';
    final archive = Archive()
      ..addFile(ArchiveFile('i/iconfont.ttf', 3, [1, 2, 3]))
      ..addFile(ArchiveFile('i/iconfont.json', json.length, json.codeUnits));
    Directory('assets').createSync();
    File('assets/download.zip').writeAsBytesSync(ZipEncoder().encode(archive)!);

    await const IconGen().gen();

    final code = File('lib/gen/my_icon.dart').readAsStringSync();
    expect(code, contains('class MyIcon'));
    expect(code, contains('a_b = IconData(0xe600'));
    expect(File('assets/fonts/my_icon.ttf').existsSync(), isTrue);
    expect(File('pubspec.yaml').readAsStringSync(),
        contains('- asset: assets/fonts/my_icon.ttf'));
  });

  test('clean scan skips ignored directories', () async {
    const pubspec = 'dependencies:\n  flutter:\n    sdk: flutter\n';
    write('app/pubspec.yaml', pubspec);
    write('build/cached/pubspec.yaml', pubspec);

    final projects = await findFlutterProjects(Directory('.'));

    expect(projects.map((d) => d.path.split('/').last), ['app']);
  });

  test('excel output escapes values and normalises language ids', () {
    expect(languageFileName('zh-CN'), 'language_zh_cn.dart');
    final code = renderLanguageFile('zh-CN', {r"it's": r'$1 C:\a' '\n'});
    expect(code, contains('languageZh_CN ='));
    expect(code, contains(r"'it\'s': '\$1 C:\\a\n',"));
  });

  test('md5 leaves platform directories alone', () async {
    write('pubspec.yaml', 'name: x\n');
    write('assets/a.png', 'a');
    write('android/ic.png', 'b');

    await imagesModifyMD5();

    expect(File('assets/a.png').lengthSync(), 9);
    expect(File('android/ic.png').lengthSync(), 1);
  });

  test('scan skips resolution folders and their children', () async {
    write('pubspec.yaml', 'name: x\nflutter:\n  uses-material-design: true\n');
    for (final d in ['assets/img/1.5x', 'assets/img/2.0x/sub', 'assets/img/3x']) {
      Directory(d).createSync(recursive: true);
    }

    await scanAndAddAssetFolders();

    final content = File('pubspec.yaml').readAsStringSync();
    expect(content, contains('assets/img/'));
    expect(content, isNot(contains('x/')));
  });
}
