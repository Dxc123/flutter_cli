import 'dart:io';

import 'package:cli/cli_convert_assets_to_webp.dart';
import 'package:cli/cli_create_common.dart';
import 'package:cli/cli_create_page.dart';
import 'package:cli/cli_generate_x1_2x_pic.dart';
import 'package:cli/utils/cli_confirm.dart';
import 'package:cli/utils/cli_load_template_util.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void writeImage(String path, {int width = 30}) {
  final image = img.Image(width: width, height: width);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(path.endsWith('.png') ? img.encodePng(image) : img.encodeJpg(image));
}

void write(String path, String content) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsStringSync(content);
}

int widthOf(String path) => img.decodeImage(File(path).readAsBytesSync())!.width;

bool alwaysNo(String message) => false;

final hasCwebp = () {
  try {
    return Process.runSync('cwebp', ['-version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}();
final cwebpSkip = hasCwebp ? false : 'cwebp not installed';

/// 当前临时目录所在文件系统是否区分大小写
bool caseSensitiveFs() {
  File('probe').createSync();
  final sensitive = !File('PROBE').existsSync();
  File('probe').deleteSync();
  return sensitive;
}

Future<String?> fakeLoader(String template, String baseUrl) async =>
    '{{className}} {{pageName}} $template';

void main() {
  late Directory temp;
  late Directory original;

  setUp(() {
    original = Directory.current;
    temp = Directory.systemTemp.createTempSync('safety_test_');
    Directory.current = temp.path;
    convertedPngPaths.clear();
  });

  tearDown(() {
    Directory.current = original.path;
    temp.deleteSync(recursive: true);
  });

  group('--x1x2', () {
    test('generates 1x and 2x next to 3.0x and 3x folders', () async {
      writeImage('assets/images/3.0x/a.png');
      writeImage('assets/icons/3x/b.jpg');

      expect(await generateX1_2xPic(confirm: alwaysNo), isTrue);

      expect(widthOf('assets/images/a.png'), 10);
      expect(widthOf('assets/images/2.0x/a.png'), 20);
      expect(widthOf('assets/icons/b.jpg'), 10);
      expect(widthOf('assets/icons/2x/b.jpg'), 20);
      expect(widthOf('assets/images/3.0x/a.png'), 30);
    });

    test('never touches images nested below a 3.0x folder', () async {
      writeImage('assets/3.0x/sub/a.png');
      final before = File('assets/3.0x/sub/a.png').readAsBytesSync();

      expect(await generateX1_2xPic(confirm: alwaysYes), isTrue);

      expect(File('assets/3.0x/sub/a.png').readAsBytesSync(), before);
      expect(File('assets/3.0x/a.png').existsSync(), isFalse);
      expect(Directory('assets/3.0x/2.0x').existsSync(), isFalse);
    });

    test('skips 3.0x and 3x sources that share an output', () async {
      writeImage('assets/3.0x/a.png', width: 30);
      writeImage('assets/3x/a.png', width: 60);
      writeImage('assets/3.0x/ok.png', width: 30);

      expect(await generateX1_2xPic(confirm: alwaysYes), isFalse);

      expect(File('assets/a.png').existsSync(), isFalse);
      expect(File('assets/2.0x/a.png').existsSync(), isFalse);
      expect(File('assets/2x/a.png').existsSync(), isFalse);
      expect(widthOf('assets/3x/a.png'), 60);
      expect(widthOf('assets/ok.png'), 10);
    });

    test('keeps existing outputs unless confirmed', () async {
      writeImage('assets/3.0x/a.png');
      writeImage('assets/a.png', width: 7);

      String? asked;
      await generateX1_2xPic(confirm: (m) {
        asked = m;
        return false;
      });
      expect(asked, isNotNull);
      expect(widthOf('assets/a.png'), 7);
      expect(widthOf('assets/2.0x/a.png'), 20);

      await generateX1_2xPic(confirm: alwaysYes);
      expect(widthOf('assets/a.png'), 10);
    });
  });

  group('--webp', () {
    test('ignores leftover temp files and leaves none behind', () async {
      write('pubspec.yaml', 'name: x\n');
      writeImage('assets/a.png', width: 1);
      writeImage('assets/a.png.tmp.png', width: 1);

      expect(await flutterConvertAssetsToWebp(confirm: alwaysYes), isTrue);

      expect(File('assets/a.webp').existsSync(), isTrue);
      expect(File('assets/a.png.tmp.webp').existsSync(), isFalse);
      expect(Directory('assets').listSync().map((e) => p.basename(e.path)).toSet(),
          {'a.webp', 'a.png.tmp.png'});
    }, skip: cwebpSkip);

    test('keeps PNG files whose names differ only in case', () async {
      if (!caseSensitiveFs()) {
        markTestSkipped('file system is case-insensitive');
        return;
      }
      write('pubspec.yaml', 'name: x\n');
      writeImage('assets/a.png', width: 1);
      writeImage('assets/a.PNG', width: 2);

      expect(await flutterConvertAssetsToWebp(confirm: alwaysYes), isFalse);

      expect(File('assets/a.png').existsSync(), isTrue);
      expect(File('assets/a.PNG').existsSync(), isTrue);
      expect(File('assets/a.webp').existsSync(), isFalse);
    }, skip: cwebpSkip);

    test('keeps PNG files when not confirmed', () async {
      write('pubspec.yaml', 'name: x\n');
      write('lib/main.dart', "const a = 'assets/home.png';\n");
      writeImage('assets/home.png', width: 1);

      expect(await flutterConvertAssetsToWebp(confirm: alwaysNo), isTrue);

      expect(File('assets/home.png').existsSync(), isTrue);
      expect(File('assets/home.webp').existsSync(), isFalse);
      expect(File('lib/main.dart').readAsStringSync(), contains('home.png'));
    }, skip: cwebpSkip);
  });

  group('create', () {
    String page(String dir, String file) => p.join('modules', 'zt_home', dir, file);

    test('page renders templates', () async {
      expect(await createPage('zt_home', loader: fakeLoader), isTrue);
      expect(File(page('views', 'zt_home_view.dart')).readAsStringSync(),
          'ZtHome zt_home views/view.template');
      expect(File(page('bindings', 'zt_home_binding.dart')).existsSync(), isTrue);
      expect(File(page('controllers', 'zt_home_controller.dart')).existsSync(), isTrue);
    });

    test('page keeps existing files and writes nothing when declined', () async {
      write(page('views', 'zt_home_view.dart'), 'mine');

      expect(await createPage('zt_home', confirm: alwaysNo, loader: fakeLoader), isTrue);

      expect(File(page('views', 'zt_home_view.dart')).readAsStringSync(), 'mine');
      expect(File(page('bindings', 'zt_home_binding.dart')).existsSync(), isFalse);
    });

    test('page overwrites existing files when confirmed', () async {
      write(page('views', 'zt_home_view.dart'), 'mine');

      expect(await createPage('zt_home', confirm: alwaysYes, loader: fakeLoader), isTrue);

      expect(File(page('views', 'zt_home_view.dart')).readAsStringSync(), isNot('mine'));
    });

    test('common writes nothing when a template fails to load', () async {
      Future<String?> loader(String template, String baseUrl) async =>
          template == 'index.template' ? null : 'x';

      expect(await createCommonStructure(loader: loader), isFalse);
      expect(Directory('common').existsSync(), isFalse);
    });

    test('writes nothing when a target is a directory', () async {
      Directory('out/b.dart').createSync(recursive: true);

      expect(
          await writeTemplates({'out/a.dart': 'a', 'out/b.dart': 'b'}, '',
              confirm: alwaysYes, loader: fakeLoader),
          isFalse);
      expect(File('out/a.dart').existsSync(), isFalse);
    });

    test('common writes root index.dart', () async {
      expect(await createCommonStructure(loader: fakeLoader), isTrue);
      expect(File(p.join('common', 'index.dart')).readAsStringSync(), endsWith('index.template'));
      expect(File(p.join('common', 'routers', 'pages.dart')).existsSync(), isTrue);
    });
  });

  group('cli exit codes', () {
    final script = p.join(Directory.current.path, 'bin', 'cli.dart');

    Future<ProcessResult> runCli(List<String> args) async {
      final process = await Process.start(
          Platform.resolvedExecutable, [script, ...args],
          workingDirectory: temp.path);
      await process.stdin.close();
      final out = process.stdout.transform(systemEncoding.decoder).join();
      final err = process.stderr.transform(systemEncoding.decoder).join();
      return ProcessResult(process.pid, await process.exitCode, await out, await err);
    }

    test('fails instead of silently cancelling when stdin is closed', () async {
      write(p.join(temp.path, 'modules/home/views/home_view.dart'), 'mine');

      final result = await runCli(['create', 'page:home']);

      expect(result.exitCode, 1, reason: '${result.stdout}');
      expect(result.stdout, contains('-y'));
      expect(File(p.join(temp.path, 'modules/home/views/home_view.dart')).readAsStringSync(), 'mine');
    });

    test('prints help when only -y is given', () async {
      final result = await runCli(['-y']);
      expect(result.exitCode, 64);
    });
  });
}
