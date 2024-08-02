import 'dart:io';

import 'package:dart_plugin_system/plugin_manager.dart';
import 'package:dart_plugin_system/plugin_protocol.dart';
import 'package:logging/logging.dart';

final logger = Logger('dart_plugin_system');

Future<void> main(List<String> arguments) async {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print(
        '${record.level.name}: ${record.time}: ${record.loggerName} :: ${record.message}');
  });

  final loadResults = await PluginManager.instance.loadPlugins();
  logger.info('Plugins loaded: ${loadResults.length}');

  await PluginManager.instance
      .broadcast(DebugMessage(message: 'Hello from main'));

  await Future.delayed(Duration(seconds: 1));

  await PluginManager.instance.broadcast(EmptyMessage());

  await Future.delayed(Duration(seconds: 1));

  await PluginManager.instance.dispose();

  exit(0);
}
