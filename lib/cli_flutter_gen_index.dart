import 'dart:io';

import 'utils/cli_log_until.dart';

void generateIndex() {
  final directory = Directory.current; // 获取当前目录
  logInfo('Scanning directory: ${directory.path}');

  final dartFiles = getDartFiles(directory);
  final totalFiles = dartFiles.length;

  if (totalFiles == 0) {
    logError('No .dart files found.');
  } else {
    generateIndexFile(dartFiles);
    logSuccess('✅ index.dart generated successfully with $totalFiles files.');
  }
}

List<File> getDartFiles(Directory directory) {
  return directory
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .where((file) => !file.path.endsWith('index.dart')) // 排除 index.dart
      .toList();
}

void generateIndexFile(List<File> dartFiles) {
  final indexFile = File('${Directory.current.path}/index.dart');
  final buffer = StringBuffer();

  buffer.writeln('// Auto-generated index file');
  buffer.writeln('// Exporting ${dartFiles.length} files');
  buffer.writeln('');

  for (var file in dartFiles) {
    final relativePath = file.path.replaceFirst('${Directory.current.path}/', '');
    buffer.writeln("export '$relativePath';");
  }

  indexFile.writeAsStringSync(buffer.toString());
}
