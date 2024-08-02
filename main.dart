import 'dart:async';
import 'dart:io';

import 'plugin_loader.dart';

Future<void> main() async {
  final plugins = await PluginManager.instance.listPlugins();
  print('Plugins found: $plugins');

  final loadResults = await PluginManager.instance.loadPlugins();
  print('Plugins loaded: ${loadResults.length}');

  final responses =
      await PluginManager.instance.broadcast(Message(PluginEvent.kill));
  print('Responses: $responses');
  exit(0);
}
