import 'package:dashability/src/cli/install_mcp.dart';
import 'package:dashability/src/cli/interactive_menu.dart';
import 'package:dashability/src/cli/server_runner.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.isNotEmpty && arguments.first == 'install-mcp') {
    await installMcp(arguments.sublist(1));
    return;
  }

  if (arguments.isEmpty) {
    await showInteractiveMenu();
    return;
  }

  await runWithArgs(arguments);
}
