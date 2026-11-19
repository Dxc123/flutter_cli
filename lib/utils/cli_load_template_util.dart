import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;

import 'cli_confirm.dart';
import 'cli_log_until.dart';

/// 加载模板内容，失败返回 null
typedef TemplateLoader = Future<String?> Function(String templatePath, String baseUrl);

/// 按 {目标文件: 模板路径} 生成文件。
///
/// 已存在的文件需经 [confirm] 同意才覆盖，拒绝则不写入任何文件；
/// 先获取全部模板再写入，任一模板获取失败也不写入，避免留下不完整的目录。
/// 没有出错（包括用户取消）时返回 true。
Future<bool> writeTemplates(
  Map<String, String> files,
  String baseUrl, {
  String Function(String content)? transform,
  Confirm confirm = askUser,
  TemplateLoader loader = loadTemplateFromGithub,
}) async {
  final notFiles = files.keys
      .where((f) => !const [FileSystemEntityType.file, FileSystemEntityType.notFound]
          .contains(FileSystemEntity.typeSync(f)))
      .toList();
  if (notFiles.isNotEmpty) {
    for (final f in notFiles) {
      logError('❌ 目标路径已存在且不是文件: $f');
    }
    logError('未写入任何文件');
    return false;
  }

  final existing = files.keys.where((f) => File(f).existsSync()).toList();
  if (existing.isNotEmpty) {
    logWarning('以下 ${existing.length} 个文件已存在:');
    for (final f in existing) {
      logWarning('  - $f');
    }
    if (!confirm('是否覆盖这些文件？')) {
      logWarning('❎ 已取消，未修改任何文件。');
      return true;
    }
  }

  final contents = <String, String>{};
  for (final MapEntry(key: target, value: template) in files.entries) {
    final content = await loader(template, baseUrl);
    if (content == null) {
      logError('❌ 获取模板失败: $template，未写入任何文件');
      return false;
    }
    contents[target] = transform == null ? content : transform(content);
  }

  var written = 0;
  for (final MapEntry(key: target, value: content) in contents.entries) {
    try {
      final file = File(target);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(content);
    } on FileSystemException catch (e) {
      logError('❌ 写入失败: $target → ${e.message} ${e.osError ?? ''}');
      logError('已写入 $written/${contents.length} 个文件，请检查后重试');
      return false;
    }
    written++;
    logSuccess('✅ Created file: $target');
  }
  return true;
}

/// 从 GitHub 加载模板文件
Future<String?> loadTemplateFromGithub(
  String templatePath,
  String githubBaseUrl, {
  int retries = 3,
}) async {
  /// 缓存目录
  ///Users/daixingchuang/.pub-cache/global_packages/cli/.template_cache
  final cacheDir = Directory(path.join(_getGlobalPackagesPath(), '.template_cache'));
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
Future<void> clearTemplateCache({Confirm confirm = askUser}) async {
  final cacheDir = Directory(path.join(_getGlobalPackagesPath(), '.template_cache'));

  if (!await cacheDir.exists()) {
    print('📭 No cache to clear.');
    return;
  }

  if (!confirm('Are you sure you want to delete ${cacheDir.path}?')) {
    print('❎ Cancelled.');
    return;
  }

  await cacheDir.delete(recursive: true);
  print('🧹 Cleared template cache.');
}

//获取 mac 本地 .pub-cache/global_packages/cli目录
String _getGlobalPackagesPath() {
  return path.join(_getPubCachePath(), 'global_packages/cli');
}
String _getPubCachePath() {
  final env = Platform.environment;
  final home = env['HOME'] ?? env['USERPROFILE']; // macOS/Linux 或 Windows
  if (home == null) throw Exception('无法确定主目录');

  final pubCache = env['PUB_CACHE'] ?? path.join(home, '.pub-cache');
  return pubCache;
}
