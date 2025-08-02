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
    logError('❌ pubspec.yaml not found.');
    return;
  }

  final content = file.readAsStringSync();
  final doc = loadYaml(content);
  final editor = YamlEditor(content);

  // 获取当前已存在的 asset 路径
  final currentAssets = <String>[
    ...(doc['flutter']?['assets'] ?? const []).map((e) => e.toString())
  ];

  final toAdd = folders.where((e) => !currentAssets.contains(e)).toList();
  if (toAdd.isEmpty) {
    logSuccess('✅ 没有新的 assets 目录需要添加');
    return;
  }

  final allAssets = [...currentAssets, ...toAdd]..sort();

  try {
    // 若 flutter: 不存在，先创建
    if (doc['flutter'] == null) {
      editor.update(['flutter'], {'assets': allAssets});
    } else {
      editor.update(['flutter', 'assets'], allAssets);
    }

    await file.writeAsString(editor.toString());
    logSuccess('✅ 已添加 ${toAdd.length} 个 assets 目录到 pubspec.yaml');
  } catch (e) {
    logError('❌ 更新 pubspec.yaml 出错: $e');
  }
}
