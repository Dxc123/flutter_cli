import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'package:crypto/crypto.dart';

import 'utils/cli_log_until.dart';


/// 修改图片的 MD5
Future<void> imagesModifyMD5() async {
  final directoryPath = Directory.current.path;
  final directory = Directory(directoryPath);

  if (!directory.existsSync()) {
    logError('Error: Directory "$directoryPath" does not exist.');
    exit(1);
  }

  logInfo('Starting to modify MD5 for all images in directory: $directoryPath');

  final imageFiles = directory.listSync(recursive: true).whereType<File>().where((file) => _isImageFile(file.path)).toList();

  if (imageFiles.isEmpty) {
    logWarning('No image files found in the directory or its subdirectories.');
    return;
  }

  logInfo('Found ${imageFiles.length} image files.');

  // 限制并发 Isolate 数量
  const maxConcurrentIsolates = 4;
  await _processFilesWithIsolatePool(imageFiles, maxConcurrentIsolates);

  logSuccess('\nCompleted modifying MD5 for ${imageFiles.length} images.');
}

/// 检查文件是否为图片文件
bool _isImageFile(String path) {
  final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff', '.webp'];
  return imageExtensions.any((ext) => path.toLowerCase().endsWith(ext));
}

/// 使用 Isolate 池处理文件
Future<void> _processFilesWithIsolatePool(List<File> files, int maxConcurrentIsolates) async {
  final pool = IsolatePool(maxConcurrentIsolates);
  final progress = StreamController<int>();
  int processedCount = 0;

  // 监听进度更新
  progress.stream.listen((count) {
    processedCount += count;
    _showProgress(processedCount, files.length);
  });

  // 向池中提交任务
  for (final file in files) {
    pool.submitTask(() async {
      await _processFileInIsolate(file, progress);
    });
  }

  // 等待所有任务完成
  await pool.close();
  await progress.close();
}

/// 使用 Isolate 处理单个文件
Future<void> _processFileInIsolate(File file, StreamController<int> progress) async {
  final receivePort = ReceivePort();
  final isolate = await Isolate.spawn(_isolateProcessFile, [file.path, receivePort.sendPort]);

  await for (var message in receivePort) {
    if (message == 'done') {
      progress.add(1);
      receivePort.close();
      isolate.kill();
      break;
    }
  }
}

/// Isolate 的处理逻辑
void _isolateProcessFile(List args) async {
  final filePath = args[0] as String;
  final sendPort = args[1] as SendPort;

  try {
    final file = File(filePath);
    final originalMD5 = await _calculateMD5(file);

    final content = await file.readAsBytes();

    // 生成随机字节数据
    final random = Random();
    final randomBytes = List<int>.generate(8, (_) => random.nextInt(256));

    // 添加随机字节数据到文件末尾
    final modifiedContent = BytesBuilder()
      ..add(content)
      ..add(randomBytes);

    // 写回文件
    await file.writeAsBytes(modifiedContent.toBytes());

    final modifiedMD5 = await _calculateMD5(file);

    logInfo('\n[Image Processed]');
    logInfo('File: $filePath');
    logInfo('MD5 Before: $originalMD5');
    logInfo('MD5 After: $modifiedMD5');
  } catch (e) {
    logError('Failed to process file: $filePath. Error: $e');
  }

  sendPort.send('done');
}

/// 计算文件的 MD5 值
Future<String> _calculateMD5(File file) async {
  final bytes = await file.readAsBytes();
  final digest = md5.convert(bytes);
  return digest.toString();
}

/// 显示进度条
void _showProgress(int current, int total) {
  final percentage = (current / total * 100).toStringAsFixed(1);
  stdout.write('\rProgress: $current/$total ($percentage%)');
}

/// Isolate 池类
class IsolatePool {
  final int maxConcurrentIsolates;
  final Queue<Function()> _taskQueue = Queue();
  final List<Future<void>> _runningTasks = [];

  IsolatePool(this.maxConcurrentIsolates);

  /// 提交任务
  void submitTask(Future<void> Function() task) {
    _taskQueue.add(task);
    _tryStartNextTask();
  }

  /// 尝试启动下一个任务
  void _tryStartNextTask() {
    if (_taskQueue.isNotEmpty && _runningTasks.length < maxConcurrentIsolates) {
      final task = _taskQueue.removeFirst();
      final taskFuture = task();
      _runningTasks.add(taskFuture);

      taskFuture.whenComplete(() {
        _runningTasks.remove(taskFuture);
        _tryStartNextTask();
      });
    }
  }

  /// 关闭池（等待所有任务完成）
  Future<void> close() async {
    while (_runningTasks.isNotEmpty || _taskQueue.isNotEmpty) {
      await Future.delayed(Duration(milliseconds: 100));
    }
  }
}
