import 'dart:io';

/// 向用户确认一项操作，返回是否继续。
typedef Confirm = bool Function(String message);

/// 需要确认但读不到输入（stdin 已关闭，如 CI 或 `< /dev/null`）。
///
/// 与用户主动取消区分开：取消是正常结束，这里应以非 0 退出码报错，
/// 避免脚本里什么都没做却显示成功。
class ConfirmationRequired implements Exception {
  final String message;
  const ConfirmationRequired(this.message);

  @override
  String toString() => '需要确认「$message」，但没有可读取的输入。非交互环境请加 -y';
}

/// 在终端询问 (y/N)；读不到输入时抛出 [ConfirmationRequired]。
bool askUser(String message) {
  stdout.write('⚠️ $message (y/N): ');
  final answer = stdin.readLineSync();
  if (answer == null) {
    stdout.writeln();
    throw ConfirmationRequired(message);
  }
  return answer.trim().toLowerCase() == 'y';
}

/// 不询问，直接同意（对应命令行 --yes）。
bool alwaysYes(String message) => true;

/// 根据 --yes 选择确认方式。
Confirm confirmer({required bool yes}) => yes ? alwaysYes : askUser;
