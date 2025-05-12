This is a demo project to show how to create CLI using Dart.

dart cli工具，生成 getx 项目目录结构，需配合 Git 模版使用


安装到本地：(需要Flutter环境)

dart pub global activate -sgit https://github.com/Dxc123/flutter_cli.git

列出本地所有的cli 工具
dart pub global list

本地移除：dart pub global deactivate flutter_cli

生成page命令：
cli create page:zt_home

生成common目录命令：
cli create common


清理本地模板缓存命令：
cli --clear或者cli -c

清理当前目录下所有Flutter项目命令：
cli --clean或者cli -l


打印命令帮助信息：
cli --help / cli -h
打印 CLI 工具版本：
cli --version / cli -v

