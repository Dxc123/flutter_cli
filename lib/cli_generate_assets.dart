import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'utils/cli_log_until.dart';

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
    logError('⚠️ 未在 pubspec.yaml 中配置 assets');
    exit(0);
  }

  final assetFiles = <String>{};

  for (var assetPath in assetsList) {
    final dir = Directory(assetPath);
    if (!dir.existsSync()) continue;

    final files = dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) {
      final relative = p.relative(file.path, from: assetPath);
      final parts = p.split(relative);
      return !parts.any((part) => part.endsWith('x'));
    })
        .map((file) => p.join(assetPath, p.relative(file.path, from: assetPath)).replaceAll(r'\', '/'));

    assetFiles.addAll(files);
  }

  final buffer = StringBuffer();
  buffer.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
  buffer.writeln('// ignore_for_file: constant_identifier_names');
  buffer.writeln('');
  buffer.writeln('class Assets {');
  for (var path in assetFiles.toList()..sort()) {
    final variableName = _generateVariableName(path);
    buffer.writeln("  static const String $variableName = '$path';");
  }
  buffer.writeln('}');

  final outputDir = Directory('lib/generated');
  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }

  final outputFile = File(p.join(outputDir.path, 'assets.dart'));
  outputFile.writeAsStringSync(buffer.toString());

  logSuccess('✅ 成功生成: lib/generated/assets.dart');
}

/// 将路径转为合法的 Dart 静态变量名
String _generateVariableName(String path) {
  final fileName = path
      .replaceAll(RegExp(r'[^a-zA-Z0-9/_]'), '_')
      .replaceAll('/', '_')
      .replaceAll('__', '_');
  final name = fileName.replaceAll(RegExp(r'\.([a-zA-Z0-9]+)$'), '');
  return name.startsWith(RegExp(r'[0-9]')) ? '_$name' : name;
}
