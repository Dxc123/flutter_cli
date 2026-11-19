import 'dart:io';
import 'dart:math';

import 'package:cli/utils/cli_confirm.dart';
import 'package:cli/utils/cli_log_until.dart';
import 'package:cli/utils/cli_project_files.dart';
import 'package:image/image.dart';
import 'package:path/path.dart' as p;

/// 3x 目录名 → 对应的 2x 目录名
const _x2DirNames = {'3.0x': '2.0x', '3x': '2x'};
const _extensions = {'.png', '.jpg', '.jpeg'};

/// 一张 3x 图及其 1x、2x 输出路径
class ScaledTargets {
  final File source;
  final String x1Path;
  final String x2Path;

  const ScaledTargets(this.source, this.x1Path, this.x2Path);
}

/// 按 Flutter 分辨率目录约定计算输出路径：
/// `dir/3.0x/a.png` → `dir/a.png`（1x）和 `dir/2.0x/a.png`（2x）。
///
/// 只处理直接位于 3.0x/3x 目录下的图片，其他位置返回 null，
/// 保证输出路径不会与原图重合。
ScaledTargets? scaledTargetsFor(File source) {
  final variantDir = p.dirname(source.path);
  final x2DirName = _x2DirNames[p.basename(variantDir)];
  if (x2DirName == null) return null;
  final baseDir = p.dirname(variantDir);
  final name = p.basename(source.path);
  return ScaledTargets(
    source,
    p.join(baseDir, name),
    p.join(baseDir, x2DirName, name),
  );
}

/// 找出输出路径与其他图片的输出或某张原图重合的目标，
/// 例如同一目录下同时存在 `3.0x/a.png` 和 `3x/a.png`（1x 都是 `a.png`）。
Set<ScaledTargets> findConflictingTargets(List<ScaledTargets> targets) {
  final owners = <String, List<ScaledTargets>>{};
  for (final t in targets) {
    for (final path in [t.x1Path, t.x2Path]) {
      (owners[p.normalize(path)] ??= []).add(t);
    }
  }
  final sources = {for (final t in targets) p.normalize(t.source.path)};
  return {
    for (final MapEntry(key: path, value: users) in owners.entries)
      if (users.length > 1 || sources.contains(path)) ...users,
  };
}

bool _isSourceImage(String path) =>
    _extensions.contains(p.extension(path).toLowerCase()) &&
    _x2DirNames.containsKey(p.basename(p.dirname(path)));

/// 根据 3.0x/3x 图片生成 1x、2x 图片；已存在的输出需经 [confirm] 同意才覆盖。
///
/// 全部成功时返回 true。
Future<bool> generateX1_2xPic({Confirm confirm = askUser}) async {
  final baseDir = Directory.current;

  logInfo('🔍 正在扫描 ${baseDir.path} 下的 3.0x/3x 图片...');

  final found = collectProjectFiles(baseDir, _isSourceImage)
      .map(scaledTargetsFor)
      .whereType<ScaledTargets>()
      .toList()
    ..sort((a, b) => a.source.path.compareTo(b.source.path));

  if (found.isEmpty) {
    logWarning('⚠️ 未找到任何 3.0x/3x 图片。');
    return true;
  }

  final conflicts = findConflictingTargets(found);
  for (final t in conflicts) {
    logError('❌ 输出路径与其他图片冲突，已跳过: ${t.source.path}');
  }
  if (conflicts.isNotEmpty) {
    logError('同一目录请只保留 3.0x 或 3x 其中一种目录名。');
  }
  final targets = found.where((t) => !conflicts.contains(t)).toList();

  final existing = [
    for (final t in targets)
      for (final path in [t.x1Path, t.x2Path])
        if (File(path).existsSync()) path,
  ];
  var overwrite = false;
  if (existing.isNotEmpty) {
    logWarning('以下 ${existing.length} 个 1x/2x 图片已存在:');
    for (final path in existing) {
      logWarning('  - $path');
    }
    overwrite = confirm('是否覆盖这些图片？选 N 只生成缺失的图片');
  }

  logInfo('✅ 共找到 ${targets.length} 张图片，开始处理...\n');

  var failed = 0;
  for (final target in targets) {
    try {
      await _processImage(target, overwrite: overwrite);
    } catch (e) {
      logError('❌ 处理失败: ${target.source.path} => $e');
      failed++;
    }
  }

  failed += conflicts.length;
  if (failed > 0) {
    logError('\n$failed/${found.length} 张图片处理失败或被跳过。');
    return false;
  }
  logInfo('\n🎉 所有图片处理完成。');
  return true;
}

Future<void> _processImage(ScaledTargets target, {required bool overwrite}) async {
  final outputs = {target.x1Path: 1 / 3, target.x2Path: 2 / 3}
    ..removeWhere((path, _) => !overwrite && File(path).existsSync());
  final sourcePath = target.source.path;
  if (outputs.isEmpty) {
    logInfo('⏭️ 已存在，跳过: $sourcePath');
    return;
  }

  final image = decodeImage(await target.source.readAsBytes());
  if (image == null) throw '无法解析图片：$sourcePath';

  for (final MapEntry(key: path, value: scale) in outputs.entries) {
    final resized = copyResize(image, width: max(1, (image.width * scale).round()));
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(encodeImage(resized, sourcePath));
  }

  logSuccess('✅ $sourcePath => ${outputs.keys.join(' , ')}');
}

List<int> encodeImage(Image image, String path) {
  switch (p.extension(path).toLowerCase()) {
    case '.png':
      return encodePng(image);
    case '.jpg':
    case '.jpeg':
      return encodeJpg(image);
  }
  throw '不支持的图片格式: $path';
}
