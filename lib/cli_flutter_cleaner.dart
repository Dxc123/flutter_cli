import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'utils/cli_log_until.dart';

/// 并发数限制（可根据机器性能调整）
const int maxConcurrent = 3;

/// 清理当前目录下所有 Flutter 项目
///
/// 全部成功（或没有项目）时返回 true。
Future<bool> flutterClean() async {
  logInfo('Scanning current directory for Flutter projects...');

  final currentDir = Directory.current;

  final projects = await findFlutterProjects(currentDir);

  if (projects.isEmpty) {
    logWarning('No Flutter projects found.');
    return true;
  }

  logInfo('\nFound ${projects.length} Flutter project(s). Starting cleaning...\n');

  final failed = await _cleanProjectsConcurrently(projects, maxConcurrent);

  if (failed.isNotEmpty) {
    logError('\n${failed.length}/${projects.length} project(s) failed:');
    failed.forEach(logError);
    return false;
  }
  logSuccess('\nAll Flutter projects cleaned successfully!');
  return true;
}

/// 异步扫描 Flutter 项目（排除部分目录）
Future<List<Directory>> findFlutterProjects(Directory root) async {
  final ignoreDirs = {'.git', 'build', '.dart_tool', '.idea', '.vscode'};
  final projects = <Directory>[];

  Future<void> search(Directory dir) async {
    try {
      final entities = await dir.list(followLinks: false).toList();
      if (_isFlutterProject(dir)) {
        projects.add(dir);
        return;// 已识别为Flutter项目，无需继续深入
      }

      for (var entity in entities) {
        if (entity is Directory) {
          final name = p.basename(entity.path);
          if (!ignoreDirs.contains(name)) {
            await search(entity);
          }
        }
      }
    } catch (e) {
      logWarning('Skipped directory ${dir.path} due to error: $e');
    }
  }

  await search(root);
  return projects;
}

// 判断是否为 Flutter 项目(采用正则判断，执行速度更快)
bool _isFlutterProject(Directory dir) {
  final pubspecFile = File('${dir.path}/pubspec.yaml');
  if (!pubspecFile.existsSync()) return false;

  try {
    final content = pubspecFile.readAsStringSync();
    // 粗略判断 pubspec.yaml 是否包含 flutter 依赖
    return RegExp(r'^\s*(dev_)?dependencies:\s*[\s\S]*?flutter\s*:', multiLine: true).hasMatch(content);
  } catch (_) {
    return false;
  }
}


/// 控制并发数的清理执行器，返回失败的项目路径
Future<List<String>> _cleanProjectsConcurrently(List<Directory> projects, int concurrentLimit) async {
  final queue = Queue<Directory>.from(projects);
  final failed = <String>[];

  await Future.wait([
    for (int i = 0; i < concurrentLimit; i++) _cleanWorker(queue, i + 1, failed),
  ]);

  return failed;
}

Future<void> _cleanWorker(Queue<Directory> queue, int workerId, List<String> failed) async {
  while (queue.isNotEmpty) {
    final project = queue.removeFirst();
    try {
      logInfo('[Worker $workerId] Cleaning ${project.path}');
      await _cleanProjectAsync(project);
    } catch (e) {
      logError('[Worker $workerId] Failed to clean ${project.path}: $e');
      failed.add(project.path);
    }
  }
}

/// 清理单个项目：先执行 flutter clean，再删除残留目录，避免同时操作同一目录
Future<void> _cleanProjectAsync(Directory dir) async {
  await _runFlutterCleanAsync(dir);
  await _deleteFolder('${dir.path}/.dart_tool', 'Cache');
  await _deleteFolder('${dir.path}/build', 'Build');
  logSuccess('✅ Project ${dir.path} cleaned.');
}

/// 运行 flutter clean 命令，失败时抛出异常
Future<void> _runFlutterCleanAsync(Directory dir) async {
  final result = await Process.run(
    'flutter',
    ['clean'],
    workingDirectory: dir.path,
  );

  if (result.exitCode != 0) {
    throw 'flutter clean failed: ${result.stderr}';
  }
  logSuccess('flutter clean completed for ${dir.path}.');
}

/// 删除指定目录（如 build 或 .dart_tool）
Future<void> _deleteFolder(String path, String label) async {
  final dir = Directory(path);
  if (await dir.exists()) {
    await dir.delete(recursive: true);
    logSuccess('$label folder deleted: $path');
  } else {
    logInfo('$label folder already removed: $path');
  }
}
