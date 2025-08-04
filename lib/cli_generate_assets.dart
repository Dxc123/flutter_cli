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
  for (var path in currentAssets.toList()..sort()) {
    final variableName = _generateVariableName(path);
    buffer.writeln("  static const String $variableName = '$path';");
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

String _generateVariableName(String path) {
  final name = path.replaceAll(RegExp(r'[^a-zA-Z0-9/_]'), '_').replaceAll('/', '_').replaceAll('__', '_').replaceAll(RegExp(r'\.([a-zA-Z0-9]+)$'), '');
  return name.startsWith(RegExp(r'\d')) ? '_$name' : name;
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
