import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
/// 从 GitHub 加载模板文件
Future<String?> loadTemplateFromGithub(
  String templatePath,
  String githubBaseUrl, {
  int retries = 3,
}) async {
  /// 缓存目录
  final cacheDir = Directory(path.join(Directory.current.path, '.template_cache'));
  final localPath = path.join(cacheDir.path, templatePath);
  final localFile = File(localPath);

  // 本地缓存存在，优先读取
  if (await localFile.exists()) {
    print('📦 Loaded from cache: $templatePath');
    return await localFile.readAsString();
  }

  // 不存在则尝试从 GitHub 下载
  final url = '$githubBaseUrl/$templatePath';
  for (int attempt = 1; attempt <= retries; attempt++) {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        print('🌐 Downloaded: $templatePath');

        // 写入本地缓存
        await localFile.create(recursive: true);
        await localFile.writeAsString(response.body);

        return response.body;
      } else {
        print('⚠️ HTTP ${response.statusCode} for $templatePath');
      }
    } catch (e) {
      print('❌ Error loading $templatePath (attempt $attempt): $e');
    }
    if (attempt < retries) {
      await Future.delayed(Duration(seconds: 2));
    }
  }

  return null;
}

/// 清理本地模板缓存
Future<void> clearTemplateCache() async {
  final cacheDir = Directory(path.join(Directory.current.path, '.template_cache'));

  if (!await cacheDir.exists()) {
    print('📭 No cache to clear.');
    return;
  }

  stdout.write('⚠️ Are you sure you want to delete ${cacheDir.path}? (y/N): ');
  final response = stdin.readLineSync()?.toLowerCase().trim();
  if (response != 'y') {
    print('❎ Cancelled.');
    return;
  }

  await cacheDir.delete(recursive: true);
  print('🧹 Cleared template cache.');
}
