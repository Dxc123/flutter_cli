import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;

/// 输出目录
const outputDir = 'lib/generated_languages';

/// 读取Excel表格翻译内容生成对应的语言文件
Future<void> generatedLanguages() async {
  final inputExcel = _findExcelFileWithNamePart('languages', 'assets');
  if (inputExcel == null) {
    print('❌ Excel 文件不存在');
    print('请确保目标文件路径为: assets/languages.xlsx');
    exit(1);
  }

  final inputFile = File(inputExcel);
  print('📥 正在读取 Excel 文件: $inputExcel');

  final bytes = inputFile.readAsBytesSync();
  final excel = Excel.decodeBytes(bytes);

  final sheet = excel.tables[excel.tables.keys.first];
  if (sheet == null) {
    print('❌ 没有找到有效的 sheet');
    exit(1);
  }

  final headers = sheet.rows.first.map((e) => e?.value?.toString().trim() ?? '').toList();
  final langCodes = headers.where((h) => h.isNotEmpty && h != 'key').toList();

  print('📦 找到语言列: $langCodes');

  final Map<String, Map<String, String>> translations = {
    for (var lang in langCodes) lang: {},
  };

  for (var row in sheet.rows.skip(1)) {
    final key = row[0]?.value?.toString();
    if (key == null || key.trim().isEmpty) continue;

    for (int i = 1; i < row.length && i < headers.length; i++) {
      final lang = headers[i];
      final value = row[i]?.value?.toString() ?? '';
      translations[lang]?[key] = value;
    }
  }

  final outDir = Directory(outputDir);
  if (!outDir.existsSync()) outDir.createSync(recursive: true);

  for (var lang in translations.keys) {
    final filename = languageFileName(lang);
    final content = renderLanguageFile(lang, translations[lang]!);

    File(p.join(outputDir, filename)).writeAsStringSync(content);
    print('✅ 生成: $filename');
  }

  print('🎉 所有语言文件生成完成！');
}

/// 在指定目录查找包含指定名称的 Excel 文件
String? _findExcelFileWithNamePart(String namePart, String dirPath) {
  final dir = Directory(dirPath);
  if (!dir.existsSync()) return null;

  final files = dir.listSync().whereType<File>().where((f) => f.path.toLowerCase().endsWith('.xlsx') && p.basename(f.path).toLowerCase().contains(namePart.toLowerCase())).toList();

  return files.isNotEmpty ? files.first.path : null;
}

/// 语言列名中不能用于标识符的字符（如 zh-CN 的 -）统一替换为下划线
String _languageId(String lang) => lang.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');

String languageFileName(String lang) => 'language_${_languageId(lang).toLowerCase()}.dart';

/// 生成单个语言文件的内容
String renderLanguageFile(String lang, Map<String, String> entries) {
  final id = _languageId(lang);
  final variableName = 'language${id[0].toUpperCase()}${id.substring(1)}';
  final buffer = StringBuffer()
    ..writeln('// ignore_for_file: prefer_single_quotes')
    ..writeln('final Map<String, String> $variableName = {');
  entries.forEach((key, value) {
    buffer.writeln("  '${_escape(key)}': '${_escape(value)}',");
  });
  buffer.writeln('};');
  return buffer.toString();
}

String _escape(String input) {
  return input
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$')
      .replaceAll('\r', r'\r')
      .replaceAll('\n', r'\n');
}
