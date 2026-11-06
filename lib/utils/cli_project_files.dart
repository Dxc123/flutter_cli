import 'dart:io';

import 'package:path/path.dart' as p;

/// 任意层级都不处理的目录
const _ignoredDirs = {
  'build', '.dart_tool', '.git', '.idea', '.vscode', '.fvm', '.symlinks',
  'Pods', 'node_modules',
};

/// 项目根目录下的平台工程目录，其图片由原生工程按文件名引用，不能批量改动
const _platformDirs = {'android', 'ios', 'macos', 'windows', 'linux', 'web'};

/// 从 [start] 向上查找 pubspec.yaml 所在目录，找不到时返回 [start]
Directory findProjectRoot(Directory start) {
  var dir = start.absolute;
  while (true) {
    if (File(p.join(dir.path, 'pubspec.yaml')).existsSync()) return dir;
    if (dir.parent.path == dir.path) return start.absolute;
    dir = dir.parent;
  }
}

/// 递归收集 [dir] 下满足 [test] 的文件，跳过构建产物和平台工程目录
List<File> collectProjectFiles(Directory dir, bool Function(String path) test) {
  final root = findProjectRoot(dir);
  final files = <File>[];
  void walk(Directory current) {
    for (final entity in current.listSync(followLinks: false)) {
      if (entity is Directory) {
        final name = p.basename(entity.path);
        final topLevel = p.split(p.relative(entity.path, from: root.path)).first;
        if (!_ignoredDirs.contains(name) && !_platformDirs.contains(topLevel)) {
          walk(entity);
        }
      } else if (entity is File && test(entity.path)) {
        files.add(entity);
      }
    }
  }

  walk(dir.absolute);
  return files;
}
