import 'dart:async';
import 'dart:io';

import 'utils/cli_log_until.dart';
//清理当前目录下所有Flutter项目以便释放更多磁盘空间
Future<void> flutterClean() async {
  logInfo('Scanning current directory for Flutter projects...');

  final currentDir = Directory.current;

  // 获取所有 Flutter 项目
  final flutterProjects = await _findFlutterProjects(currentDir);

  if (flutterProjects.isEmpty) {
    logWarning('No Flutter projects found in the current directory.');
    return;
  }

  logInfo('\nFound ${flutterProjects.length} Flutter project(s). Starting cleaning...');

  // 并发清理所有项目
  await Future.wait(flutterProjects.map((project) => _cleanProjectAsync(project)));

  logSuccess('\nAll Flutter projects cleaned successfully!');
}

/// 异步扫描目录中的所有 Flutter 项目
Future<List<Directory>> _findFlutterProjects(Directory dir) async {
  final projects = <Directory>[];

  await for (var entity in dir.list(recursive: true, followLinks: false)) {
    if (entity is Directory && _isFlutterProject(entity)) {
      projects.add(entity);
    }
  }

  return projects;
}

/// 检查是否为 Flutter 项目
bool _isFlutterProject(Directory dir) {
  final pubspecFile = File('${dir.path}/pubspec.yaml');
  return pubspecFile.existsSync();
}

/// 异步清理 Flutter 项目
Future<void> _cleanProjectAsync(Directory dir) async {
  logInfo('\nCleaning project: ${dir.path}');

  // 并发执行清理任务
  await Future.wait([
    _runFlutterCleanAsync(dir),
    _deleteCacheAsync(dir),
    _deleteBuildAsync(dir),
  ]);

  logSuccess('Project ${dir.path} cleaned successfully.');
}

/// 异步执行 flutter clean
Future<void> _runFlutterCleanAsync(Directory dir) async {
  logInfo('Running flutter clean in ${dir.path}...');
  final flutterCommand = 'flutter';
  final processResult = await Process.run(
    flutterCommand,
    ['clean'],
    workingDirectory: dir.path,
  );

  if (processResult.exitCode == 0) {
    logSuccess('flutter clean completed for ${dir.path}.');
  } else {
    logError('Failed to run flutter clean for ${dir.path}. Error: ${processResult.stderr}');
  }
}

/// 异步删除缓存文件夹
Future<void> _deleteCacheAsync(Directory dir) async {
  final cacheDir = Directory('${dir.path}/.dart_tool');
  if (await cacheDir.exists()) {
    logInfo('Deleting cache folder: ${cacheDir.path}');
    await cacheDir.delete(recursive: true);
    logSuccess('Cache folder deleted.');
  } else {
    logWarning('Cache folder not found: ${cacheDir.path}');
  }
}

/// 异步删除构建文件夹
Future<void> _deleteBuildAsync(Directory dir) async {
  final buildDir = Directory('${dir.path}/build');
  if (await buildDir.exists()) {
    logInfo('Deleting build folder: ${buildDir.path}');
    await buildDir.delete(recursive: true);
    logSuccess('Build folder deleted.');
  } else {
    logWarning('Build folder not found: ${buildDir.path}');
  }
}

