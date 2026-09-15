import 'dart:io';

import 'package:cli/cli_convert_assets_to_webp.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

void main() {
  test('converts PNG files from the current directory', () async {
    final tempDirectory = await Directory.systemTemp.createTemp('webp_test_');
    final originalDirectory = Directory.current;

    try {
      Directory.current = tempDirectory.path;
      await Directory('lib').create();
      final pngFile = File('sample.png');
      await pngFile.writeAsBytes(img.encodePng(img.Image(width: 1, height: 1)));

      await flutterConvertAssetsToWebp();

      expect(pngFile.existsSync(), isFalse);
      expect(File('sample.webp').existsSync(), isTrue);
    } finally {
      Directory.current = originalDirectory.path;
      await tempDirectory.delete(recursive: true);
    }
  });
}
