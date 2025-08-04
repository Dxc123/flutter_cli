import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'utils/cli_log_until.dart';

/// 只扫描当前项目根目录下的 assets/ 文件夹及其子文件夹
/// 忽略 2.0x、3.0x 等高分辨率文件夹
Future<void> scanAndAddAssetFolders() async {
  final assetsDir = Directory('assets');

  if (!await assetsDir.exists()) {
    logError('⚠️ 目录 "assets/" 不存在，跳过扫描。');
    return;
  }

  final folderSet = <String>{};
  await for (var entity in assetsDir.list(recursive: true, followLinks: false)) {
    if (entity is Directory) {
      final folderName = p.basename(entity.path);
      // 跳过高倍图文件夹，如 2.0x、3.0x 等
      if (_isResolutionFolder(folderName)) continue;
      final relative = p.relative(entity.path, from: Directory.current.path);
      folderSet.add('$relative/');
    }
  }
  // 添加根 assets 文件夹自身
  folderSet.add('assets/');
  final folderList = folderSet.toList()..sort();
  await addAssetsToPubspec(folderList);
}

/// 是否为 2.0x/3.0x/4.0x 等高分辨率文件夹
bool _isResolutionFolder(String folderName) {
  return RegExp(r'^[0-9](\.0)?x$').hasMatch(folderName);
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
  final currentAssets = <String>[...(doc['flutter']?['assets'] ?? const []).map((e) => e.toString())];

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
