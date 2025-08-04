import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'dart:convert'; // for utf8 and md5
import 'package:crypto/crypto.dart'; // 需要添加依赖：crypto

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
    logError('⚠️ pubspec.yaml 中未配置 flutter.assets');
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
      return !parts.any((part) => RegExp(r'^\d+(\.\d+)?x$').hasMatch(part));
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
  final newContent = buffer.toString();

  // 如果已有文件内容一致，则跳过写入
  if (outputFile.existsSync()) {
    final oldContent = outputFile.readAsStringSync();
    if (_md5(oldContent) == _md5(newContent)) {
      logInfo('✅ 资源文件未变更，无需更新: ${outputFile.path}');
      return;
    }
  }

  outputFile.writeAsStringSync(newContent);
  logSuccess('✅ 资源文件已更新: ${outputFile.path}');
}

String _generateVariableName(String path) {
  final name = path
      .replaceAll(RegExp(r'[^a-zA-Z0-9/_]'), '_')
      .replaceAll('/', '_')
      .replaceAll('__', '_')
      .replaceAll(RegExp(r'\.([a-zA-Z0-9]+)$'), '');
  return name.startsWith(RegExp(r'\d')) ? '_$name' : name;
}

String _md5(String input) => md5.convert(utf8.encode(input)).toString();