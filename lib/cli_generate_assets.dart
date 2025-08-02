import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'utils/cli_log_until.dart';

Future<void> scanAndAddAssetFolders() async {
  final currentDir = Directory.current;
  logInfo('Scanning directory: ${currentDir.path}');
  final allAssetFolders = <String>{};

  await for (final entity in currentDir.list(recursive: true, followLinks: false)) {
    if (entity is Directory && p.basename(entity.path) == 'assets') {
      // 扫描该 assets 文件夹及其子目录
      final assetFolders = await _collectSubFolders(entity);
      allAssetFolders.addAll(assetFolders);
    }
  }

  if (allAssetFolders.isEmpty) {
    logError('⚠️ 未找到任何 assets 文件夹');
    return;
  }

  await addAssetsToPubspec(allAssetFolders.toList());
}

Future<List<String>> _collectSubFolders(Directory baseDir) async {
  final folders = <String>{};

  await for (final entity in baseDir.list(recursive: true, followLinks: false)) {
    if (entity is Directory) {
      final relativePath = p.relative(entity.path, from: Directory.current.path);
      if (!_isResolutionFolder(relativePath)) {
        folders.add('$relativePath/');
      }
    }
  }

  // 添加根 assets 文件夹自身路径
  final rootRelative = p.relative(baseDir.path, from: Directory.current.path);
  folders.add('$rootRelative/');

  return folders.toList();
}

bool _isResolutionFolder(String path) {
  return path.contains(RegExp(r'/[23]\.0x/'));
}

Future<void> addAssetsToPubspec(List<String> folders) async {
  final file = File('pubspec.yaml');
  if (!file.existsSync()) {
    logError('pubspec.yaml not found.');
    return;
  }

  final doc = file.readAsStringSync();
  final editor = YamlEditor(doc);
  final yaml = loadYaml(doc);

  final currentAssets = List<String>.from(
    (yaml['flutter']?['assets'] ?? []).map((e) => e.toString()),
  );

  final toAdd = folders.where((e) => !currentAssets.contains(e)).toList();
  if (toAdd.isEmpty) {
    logError('No new folders to add.');
    return;
  }

  final newAssets = [...currentAssets, ...toAdd]..sort();

  editor.update(['flutter', 'assets'], newAssets);

  await file.writeAsString(editor.toString());
  logSuccess('Added ${toAdd.length} asset folders to pubspec.yaml');
}
