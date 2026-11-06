import 'dart:io';

import 'package:cli/cli_convert_assets_to_webp.dart';
import 'package:cli/cli_create_target.dart';
import 'package:cli/cli_delete_unused_assets.dart';
import 'package:cli/cli_generate_assets.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

void writePng(String path) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(img.encodePng(img.Image(width: 1, height: 1)));
}

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
    temp = Directory.systemTemp.createTempSync('p0_test_');
    Directory.current = temp.path;
    convertedPngPaths.clear();
  });

  tearDown(() {
    Directory.current = original.path;
    temp.deleteSync(recursive: true);
  });

  group('--webp', () {
    test('updates references in lib and pubspec', () async {
      write('pubspec.yaml',
          'name: x\nflutter:\n  assets:\n    - assets/images/home.png\n');
      write('lib/main.dart', "const a = 'assets/images/home.png';\n"
          "const b = 'assets/other.png';\n");
      writePng('assets/images/home.png');

      await flutterConvertAssetsToWebp();

      expect(File('lib/main.dart').readAsStringSync(),
          "const a = 'assets/images/home.webp';\n"
          "const b = 'assets/other.png';\n");
      expect(File('pubspec.yaml').readAsStringSync(),
          contains('- assets/images/home.webp'));
    });

    test('updates references when run from an assets subdirectory', () async {
      write('pubspec.yaml', 'name: x\n');
      write('lib/main.dart', "const a = 'assets/images/home.png';\n");
      writePng('assets/images/home.png');

      Directory.current = 'assets/images';
      await flutterConvertAssetsToWebp();
      Directory.current = temp.path;

      expect(File('assets/images/home.webp').existsSync(), isTrue);
      expect(File('lib/main.dart').readAsStringSync(),
          contains('assets/images/home.webp'));
    });

    test('leaves platform and build directories alone', () async {
      const kept = [
        'android/app/src/main/res/mipmap-hdpi/ic_launcher.png',
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/icon.png',
        'build/out.png',
      ];
      kept.forEach(writePng);
      Directory('lib').createSync();

      await flutterConvertAssetsToWebp();

      for (final path in kept) {
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    });
  });

  group('--delete', () {
    void project(String code) {
      write('lib/generated/assets.dart', '''
class Assets {
  static const String images_home = 'assets/images/home.png';
  static const String images_old = 'assets/images/old.png';
}
''');
      write('lib/main.dart', code);
      writePng('assets/images/home.png');
      writePng('assets/images/old.png');
    }

    test('keeps assets used through generated constants', () {
      project('final s = Assets.images_home;');
      expect(findUnusedAssets().map((f) => f.path),
          ['assets/images/old.png']);
    });

    test('keeps assets generated files use in other ways', () {
      project('');
      write('lib/generated/table.dart',
          "final table = ['assets/images/home.png'];");
      expect(findUnusedAssets().map((f) => f.path),
          ['assets/images/old.png']);
    });
  });

  group('--assets', () {
    test('strips extensions and resolves collisions', () {
      expect(
        generateAssetVariableNames([
          'assets/images/home.png',
          'assets/images/a.png',
          'assets/images/a.webp',
          'assets/images/b.c.png',
          'assets/images/b_c.png',
          'assets/1.png',
          'assets/class.png',
        ]),
        {
          'assets/images/home.png': 'images_home',
          'assets/images/a.png': 'images_a_png',
          'assets/images/a.webp': 'images_a_webp',
          'assets/images/b.c.png': 'images_b_c_png',
          'assets/images/b_c.png': 'images_b_c_png_2',
          'assets/1.png': 'asset_1',
          'assets/class.png': 'class_asset',
        },
      );
    });
  });

  group('create', () {
    test('accepts documented forms', () {
      expect(resolveCreateTarget(rest: ['common']).isCommon, isTrue);
      expect(resolveCreateTarget(common: true).isCommon, isTrue);
      expect(resolveCreateTarget(rest: ['page:zt_home']).pageName, 'zt_home');
      expect(resolveCreateTarget(page: 'home').pageName, 'home');
    });

    test('rejects missing, unknown, conflicting and invalid input', () {
      final invalid = <void Function()>[
        () => resolveCreateTarget(),
        () => resolveCreateTarget(rest: ['foo']),
        () => resolveCreateTarget(page: 'home', common: true),
        () => resolveCreateTarget(rest: ['page:']),
        () => resolveCreateTarget(page: 'a__b'),
        () => resolveCreateTarget(page: '../evil'),
      ];
      for (final call in invalid) {
        expect(call, throwsFormatException);
      }
    });
  });
}
