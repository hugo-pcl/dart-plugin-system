import 'dart:io';

import 'package:dart_plugin_system/plugin_manager.dart';
import 'package:dart_plugin_system/plugin_protocol.dart';
import 'package:logging/logging.dart';

final logger = Logger('dart_plugin_system');

Future<void> main(List<String> arguments) async {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.loggerName} :: ${record.message}');
  });

  final loadResults = await PluginManager.instance.loadPlugins();
  logger.info('Plugins loaded: ${loadResults.length}');

  final results = await PluginManager.instance.broadcast(KillMessage());

  for (final entry in results.entries) {
    logger.info('Plugin ${entry.key} returned: ${entry.value}');
  }

  exit(0);
}
