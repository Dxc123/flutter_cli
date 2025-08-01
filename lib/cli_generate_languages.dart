import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;

/// 默认 Excel 文件路径（如果未传参）
const defaultExcelPath = 'lib/assets/languages.xlsx';

/// 输出目录
const outputDir = 'lib/generated_languages';

/// 读取Excel表格翻译内容生成对应的语言文件
Future<void> generatedLanguages() async {
  final inputExcel = _findExcelFileWithNamePart('languages', 'lib/assets');
  if (inputExcel == null) {
    print('❌ Excel 文件不存在: $inputExcel');
    print('请将确保目标文件路径为: lib/assets/languages.xlsx');
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

  final headers = sheet.rows.first.map((e) => e?.value.toString() ?? '').toList();
  final langCodes = headers.where((h) => h != 'key').toList();

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
    final filename = 'language_${lang.toLowerCase()}.dart';
    final className = 'language${lang[0].toUpperCase()}${lang.substring(1)}';
    final buffer = StringBuffer()
      ..writeln('// ignore_for_file: prefer_single_quotes')
      ..writeln('final Map<String, String> $className = {');

    translations[lang]!.forEach((key, value) {
      buffer.writeln("  '$key': '${_escape(value)}',");
    });

    buffer.writeln('};');

    File(p.join(outputDir, filename)).writeAsStringSync(buffer.toString());
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

String _escape(String input) {
  return input.replaceAll("'", "\\'").replaceAll('\n', '\\n');
}
