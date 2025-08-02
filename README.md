This is a demo project to show how to create CLI using Dart.

dart cli工具


从git仓库安装到本地：(需要Flutter环境)

dart pub global activate -sgit https://github.com/Dxc123/flutter_cli.git

列出本地所有的cli 工具
dart pub global list

本地移除：dart pub global deactivate cli


生成page命令(生成 getx 项目目录结构，配合 Git 模版使用)：
cli create page:zt_home

生成common目录命令：
cli create common


清理本地模板缓存命令：
cli --clear或者cli -c

清理当前目录下所有Flutter项目命令：
cli --clean或者cli -l

导出当前目录下所有dart头文件生成index.dart命令：
cli --generate或者cli -g

批量修改当前目录下所有图片的 MD5 值命令:
cli --md5或者cli -m

批量修改asset目录下图片格式:png->webp命令:
cli --webp或者cli -w

删除未使用资源功能
cli --delete或者cli -d

读取Excel表格翻译内容生成对应的语言文件
cli --excel或者cli -e

自动扫描 assets文件夹以及其子文件夹并写入 pubspec.yaml
cli --assets或者cli -a


cli generate icons

打印命令帮助信息：
cli --help / cli -h
打印 CLI 工具版本：
cli --version / cli -v

