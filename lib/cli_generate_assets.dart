import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'dart:convert'; // for utf8 and md5
import 'package:crypto/crypto.dart'; // 需要添加依赖：crypto

import 'utils/cli_log_until.dart';

const snapshotPath = '.asset_snapshot.json';

Future<void> generateAssets() async {
  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    logError('❌ pubspec.yaml 文件不存在');
    exit(1);
  }

  final pubspec = loadYaml(pubspecFile.readAsStringSync());
  final flutterSection = pubspec['flutter'] as YamlMap?;
  final assetsList = flutterSection?['assets'] as YamlList?;

  if (assetsList == null || assetsList.isEmpty) {
    logError('⚠️ pubspec.yaml 中未配置 flutter.assets');
    exit(0);
  }

  final currentAssets = <String>{};

  for (var assetPath in assetsList) {
    final dir = Directory(assetPath);
    if (!dir.existsSync()) continue;

    final files = dir.listSync(recursive: true).whereType<File>().where((file) {
      final relative = p.relative(file.path, from: assetPath);
      final parts = p.split(relative);
      return !parts.any((part) => RegExp(r'^\d+(\.\d+)?x$').hasMatch(part));
    }).map((file) => p.join(assetPath, p.relative(file.path, from: assetPath)).replaceAll(r'\', '/'));

    currentAssets.addAll(files);
  }

  // 检测新增资源
  final previousAssets = _loadPreviousSnapshot();
  final newAssets = currentAssets.difference(previousAssets);

  if (newAssets.isNotEmpty) {
    logInfo('🆕 检测到 ${newAssets.length} 个新增资源:');
    for (final a in newAssets) {
      print('  - $a');
    }
  }

  // 生成 Dart 类内容
  final buffer = StringBuffer();
  buffer.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
  buffer.writeln('// ignore_for_file: constant_identifier_names');
  buffer.writeln('');
  buffer.writeln('class Assets {');
  final variableNames = generateAssetVariableNames(currentAssets);
  for (var path in currentAssets.toList()..sort()) {
    final literal = path.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll(r'$', r'\$');
    buffer.writeln("  static const String ${variableNames[path]} = '$literal';");
  }
  buffer.writeln('}');

  // 输出路径
  final outputDir = Directory('lib/generated');
  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }

  final outputFile = File(p.join(outputDir.path, 'assets.dart'));
  final newContent = buffer.toString();

  // 若内容未变化则跳过写入
  if (outputFile.existsSync()) {
    final oldContent = outputFile.readAsStringSync();
    if (_md5(oldContent) == _md5(newContent)) {
      logSuccess('✅ 资源文件未变更，无需更新: ${outputFile.path}');
      _saveSnapshot(currentAssets);
      return;
    }
  }

  outputFile.writeAsStringSync(newContent);
  logSuccess('✅ 资源文件已更新: ${outputFile.path}');
  _saveSnapshot(currentAssets);
}

const _reservedWords = {
  'abstract', 'as', 'assert', 'async', 'await', 'break', 'case', 'catch',
  'class', 'const', 'continue', 'covariant', 'default', 'deferred', 'do',
  'dynamic', 'else', 'enum', 'export', 'extends', 'extension', 'external',
  'factory', 'false', 'final', 'finally', 'for', 'function', 'get', 'hide',
  'if', 'implements', 'import', 'in', 'interface', 'is', 'late', 'library',
  'mixin', 'new', 'null', 'of', 'on', 'operator', 'part', 'required',
  'rethrow', 'return', 'set', 'show', 'static', 'super', 'switch', 'sync',
  'this', 'throw', 'true', 'try', 'typedef', 'var', 'void', 'while', 'with',
  'yield',
};

/// 为资源路径生成合法且互不重复的常量名。
///
/// 默认去掉扩展名（`home.png` → `home`）；去掉后重名的保留扩展名
/// （`a_png`、`a_webp`），仍重名的按路径排序追加序号（`a_png_2`）。
Map<String, String> generateAssetVariableNames(Iterable<String> paths) {
  final sorted = paths.toSet().toList()..sort();
  final baseNames = {for (final path in sorted) path: _variableName(p.posix.withoutExtension(path))};

  final counts = <String, int>{};
  for (final name in baseNames.values) {
    counts[name] = (counts[name] ?? 0) + 1;
  }

  final result = <String, String>{};
  final used = <String>{};
  for (final path in sorted) {
    if (counts[baseNames[path]] == 1) {
      result[path] = baseNames[path]!;
      used.add(baseNames[path]!);
    }
  }
  for (final path in sorted) {
    if (result.containsKey(path)) continue;
    final candidate = _variableName(path);
    var name = candidate;
    for (var i = 2; !used.add(name); i++) {
      name = '${candidate}_$i';
    }
    result[path] = name;
  }
  return result;
}

String _variableName(String path) {
  final noAssetsPrefix = path.startsWith('assets/') ? path.substring(7) : path;
  final name = noAssetsPrefix.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
  if (name.isEmpty || name.startsWith(RegExp(r'\d'))) return 'asset_$name';
  return _reservedWords.contains(name) ? '${name}_asset' : name;
}

String _md5(String input) => md5.convert(utf8.encode(input)).toString();

Set<String> _loadPreviousSnapshot() {
  final file = File(snapshotPath);
  if (!file.existsSync()) return {};
  final list = jsonDecode(file.readAsStringSync()) as List<dynamic>;
  return list.map((e) => e.toString()).toSet();
}

void _saveSnapshot(Set<String> assets) {
  final file = File(snapshotPath);
  file.writeAsStringSync(jsonEncode(assets.toList()..sort()));
}
