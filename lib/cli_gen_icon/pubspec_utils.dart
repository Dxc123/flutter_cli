import 'dart:io';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:yaml/yaml.dart';


// ignore: avoid_classes_with_only_static_members
class PubspecUtils {
  static final _pubspecFile = File('pubspec.yaml');

  static Pubspec get pubSpec => Pubspec.parse(pubspecString);

  static String get pubspecString => _pubspecFile.readAsStringSync();

  static get pubspecJson => loadYaml(pubspecString);

  /// separtor
  static final _mapSep = _PubValue<String>(() {
    var yaml = pubspecJson;

    if (yaml.containsKey('get_cli')) {
      if ((yaml['get_cli'] as Map).containsKey('separator')) {
        return (yaml['get_cli']['separator'] as String?) ?? '';
      }
    }

    return '';
  });

  static String? get separatorFileType => _mapSep.value;

  static final _mapName = _PubValue<String>(() => pubSpec.name.trim());

  static String? get projectName => _mapName.value;

  static final _extraFolder = _PubValue<bool?>(
    () {
      try {
        var yaml = pubspecJson;
        if (yaml.containsKey('get_cli')) {
          if ((yaml['get_cli'] as Map).containsKey('sub_folder')) {
            return (yaml['get_cli']['sub_folder'] as bool?);
          }
        }
      } on Exception catch (_) {}
      // retorno nulo está sendo tratado
      // ignore: avoid_returning_null
      return null;
    },
  );

  static bool? get extraFolder => _extraFolder.value;



  static bool containsPackage(String package, [bool isDev = false]) {
    var dependencies = isDev ? pubSpec.devDependencies : pubSpec.dependencies;
    return dependencies.containsKey(package.trim());
  }


  /// make sure it is a get_server project
  /// 确保它是一个 get_server 项目
  static bool get isServerProject {
    return containsPackage('get_server');
  }

  static String get getPackageImport => !isServerProject ? "import 'package:get/get.dart';" : "import 'package:get_server/get_server.dart';";

  // static v.Version? getPackageVersion(String package) {
  //   if (containsPackage(package)) {
  //     pubSpec.dependencies.containsKey(pa)
  //     var version = pubSpec.allDependencies[package]!;
  //     try {
  //       final json = version.toJson();
  //       if (json is String) {
  //         return v.Version.parse(json);
  //       }
  //       return null;
  //     } on FormatException catch (_) {
  //       return null;
  //     } on Exception catch (_) {
  //       rethrow;
  //     }
  //   } else {
  //     throw CliException(
  //         LocaleKeys.info_package_not_installed.trArgs([package]));
  //   }
  // }

  // static void _savePub(Pubspec pub) {
  //   var value = CliYamlToString().toYamlString(pub.toJson());
  //   _pubspecFile.writeAsStringSync(value);
  // }
}

/// avoids multiple reads in one file
class _PubValue<T> {
  final T Function() _setValue;
  bool _isChecked = false;
  T? _value;

  /// takes the value of the file,
  /// if not already called it will call the first time
  T? get value {
    if (!_isChecked) {
      _isChecked = true;
      _value = _setValue.call();
    }
    return _value;
  }

  _PubValue(this._setValue);
}
