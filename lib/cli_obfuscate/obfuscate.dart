import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../utils/cli_log_until.dart';
import '../utils/cli_project_files.dart';
import 'words_utils.dart';

const appConfigName = 'app_config.json';
const defaultApiDir = 'app/common/api';

const _scriptExtensions = {'.dart', '.kt', '.java'};
const _rootKeys = ['r_code_r', 'r_data_r', 'r_message_r', 'r_success_r'];

final _pathPattern = RegExp(r'''['"](/[^'"\r\n]+)['"]''');
final _propPattern = RegExp('v_[0-9a-zA-Z]+_v');
final _rootPattern = RegExp('r_[0-9a-zA-Z]+_r');
final _placeholderPattern = RegExp(r'\{[^{}/]+\}');
final _skippedLinePattern = RegExp(r'^(//|(import|part)\b)');

/// 混淆流程中可预期的错误（配置缺失、映射未定义等）
class ObfuscateException implements Exception {
  final String message;
  const ObfuscateException(this.message);

  @override
  String toString() => message;
}

/// 生成或补全 lib/app_config.json；已有映射保持不变。
void generateObfuscateConfig({String apiDir = defaultApiDir}) {
  final libPath = _libPath();
  final apiPath = p.join(libPath, apiDir);
  if (!Directory(apiPath).existsSync()) {
    throw ObfuscateException('接口目录不存在: $apiPath');
  }

  final config = _readConfig(libPath) ?? <String, dynamic>{};
  final pathMapping = _mapping(config, 'pathMapping');
  final propMapping = _mapping(config, 'propMapping');
  final rootMapping = _mapping(config, 'rootMapping');

  // 已混淆的路径不能再当作新接口，否则 apply 后再生成配置会二次混淆
  final obfuscatedPaths = pathMapping.values.toSet();
  final usedPaths = {...pathMapping.keys, ...obfuscatedPaths};
  final usedNames = {
    ...propMapping.keys,
    ...propMapping.values,
    ...rootMapping.values,
  };

  String newName() {
    while (true) {
      final name = WordsUtils.words(Random().nextInt(100) < 80 ? 2 : 3);
      if (usedNames.add(name)) return name;
    }
  }

  String newPath(String source) {
    // 保留 {id} 这类占位符，否则运行时无法替换路径参数
    final suffix =
        _placeholderPattern.allMatches(source).map((m) => '/${m[0]}').join();
    while (true) {
      final roll = Random().nextInt(100);
      final count = roll < 10 ? 1 : (roll < 80 ? 2 : 3);
      final path = '/${WordsUtils.wordsJoin(count, '/')}$suffix';
      if (usedPaths.add(path)) return path;
    }
  }

  for (final file in _scriptFiles(libPath)) {
    final isApiFile = p.isWithin(apiPath, file.path) && file.path.endsWith('.dart');
    for (final line in file.readAsLinesSync().where(_isCodeLine)) {
      if (isApiFile) {
        for (final match in _pathPattern.allMatches(line)) {
          if (obfuscatedPaths.contains(match[1])) continue;
          pathMapping.putIfAbsent(match[1]!, () => newPath(match[1]!));
        }
      }
      for (final match in _propPattern.allMatches(line)) {
        propMapping.putIfAbsent(match[0]!, newName);
      }
      for (final match in _rootPattern.allMatches(line)) {
        rootMapping.putIfAbsent(match[0]!, newName);
      }
    }
  }
  for (final key in _rootKeys) {
    if (rootMapping[key]?.isNotEmpty != true) rootMapping[key] = newName();
  }

  final group = config['packageGroup'];
  final output = {
    'packageGroup': group is String && group.isNotEmpty ? group : _defaultGroup(),
    'pathMapping': pathMapping,
    'propMapping': propMapping,
    'rootMapping': rootMapping,
  };
  final file = File(p.join(libPath, appConfigName));
  file.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(output)}\n');
  logSuccess('✅ 已生成 ${file.path}：接口 ${pathMapping.length} 个，'
      '属性 ${propMapping.length} 个，根参数 ${rootMapping.length} 个');
}

/// 按 lib/app_config.json 替换接口地址和模型属性。
///
/// 先计算全部结果再写入，存在未定义的映射时不会改动任何文件。
/// 返回需要修改的文件数。
int applyObfuscation({bool dryRun = false}) {
  final libPath = _libPath();
  final config = _readConfig(libPath);
  if (config == null) {
    throw const ObfuscateException('未找到 $appConfigName，请先运行 cli obfuscate config');
  }
  final pathMapping = _mapping(config, 'pathMapping');
  final propMapping = _mapping(config, 'propMapping');
  final rootMapping = _mapping(config, 'rootMapping');

  final missing = <String>{};
  final changes = <File, String>{};

  for (final file in _scriptFiles(libPath)) {
    final source = file.readAsStringSync();
    final updated = source.split('\n').map((line) {
      if (!_isCodeLine(line)) return line;
      return line
          .replaceAllMapped(_pathPattern, (m) {
            final target = pathMapping[m[1]!];
            return target == null ? m[0]! : m[0]!.replaceFirst(m[1]!, target);
          })
          .replaceAllMapped(_propPattern, (m) => _lookup(m[0]!, propMapping, missing))
          .replaceAllMapped(_rootPattern, (m) => _lookup(m[0]!, rootMapping, missing));
    }).join('\n');
    if (updated != source) changes[file] = updated;
  }

  if (missing.isNotEmpty) {
    throw ObfuscateException(
        '以下属性没有映射，未修改任何文件，请先运行 cli obfuscate config:\n${missing.join('\n')}');
  }

  changes.forEach((file, content) {
    if (dryRun) {
      logInfo('将修改: ${file.path}');
    } else {
      file.writeAsStringSync(content);
      logInfo('✏️ 已修改: ${file.path}');
    }
  });
  logSuccess(dryRun ? '✅ 预览完成，将修改 ${changes.length} 个文件' : '✅ 混淆完成，共修改 ${changes.length} 个文件');
  return changes.length;
}

String _lookup(String key, Map<String, String> mapping, Set<String> missing) {
  final value = mapping[key];
  if (value == null) missing.add(key);
  return value ?? key;
}

bool _isCodeLine(String line) => !_skippedLinePattern.hasMatch(line.trim());

String _projectRoot() {
  final root = findProjectRoot(Directory.current);
  if (!File(p.join(root.path, 'pubspec.yaml')).existsSync()) {
    throw const ObfuscateException('未找到 pubspec.yaml，请在 Flutter 项目中运行');
  }
  return root.path;
}

String _libPath() {
  final libPath = p.join(_projectRoot(), 'lib');
  if (!Directory(libPath).existsSync()) {
    throw ObfuscateException('lib 目录不存在: $libPath');
  }
  return libPath;
}

String _defaultGroup() {
  final yaml = loadYaml(File(p.join(_projectRoot(), 'pubspec.yaml')).readAsStringSync());
  final name = yaml is Map ? yaml['name']?.toString() ?? '' : '';
  return name.isEmpty ? '' : name[0].toUpperCase() + name.substring(1);
}

List<File> _scriptFiles(String libPath) {
  return Directory(libPath)
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((f) => _scriptExtensions.contains(p.extension(f.path).toLowerCase()))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

Map<String, dynamic>? _readConfig(String libPath) {
  final file = File(p.join(libPath, appConfigName));
  if (!file.existsSync()) return null;
  final content = file.readAsStringSync();
  if (content.trim().isEmpty) return null;
  try {
    return jsonDecode(content) as Map<String, dynamic>;
  } on Object catch (e) {
    throw ObfuscateException('$appConfigName 格式错误，未修改任何文件: $e');
  }
}

Map<String, String> _mapping(Map<String, dynamic> config, String key) {
  final value = config[key];
  if (value == null) return {};
  if (value is! Map) throw ObfuscateException('$appConfigName 中的 $key 必须是对象');
  return value.map((k, v) => MapEntry(k.toString(), v.toString()));
}
