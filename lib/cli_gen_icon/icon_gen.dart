import 'config_reader.dart';
import 'icon_font_class_parser.dart';
import 'icon_font_gen_config.dart';


/*解压字体图标生成
##  yaml文件配置，命令cli generate icons
#flutter_icons:
#  src_zip: 'assets/download.zip' # 下载的字体图标压缩包资源路径
#  assets_dir: 'assets/icon_font/'  # ttf文件解压的文件夹
#  dist_file: 'lib/app/data/utils/icon_until.dart' # 生成的代码文件路径
 */
class IconGen {
  const IconGen();

  Future<void> gen() async {
    final IconFontClassParser parser = IconFontClassParser();
    var configResult = await ConfigReader().readIconConfig();
    print("configResult.first = ${configResult.$1}");
    print("configResult.last = ${configResult.$2}");
    IconFontGenConfig? config = configResult.$1;
    if (config == null) {
      print(configResult.$2);
      return;
    }
    parser.gen(config);
    print('生成代码成功！${config.distFilePath}');
  }
}
