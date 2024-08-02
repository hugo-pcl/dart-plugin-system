import 'dart:io';

import 'package:dart_plugin_system/plugin_common.dart';
import 'package:dart_plugin_system/plugin_loader.dart';
import 'package:dart_plugin_system/plugin_protocol.dart';
import 'package:logging/logging.dart';

/// {@template plugin_manager}
/// The Plugin Manager is responsible for managing the plugins.
///
/// The Plugin Manager is a Dart library that provides a set of functions
/// to manage the plugins. It allows the main application to load, unload,
/// and communicate with the plugins.
/// {@endtemplate}
abstract class PluginManager {
  /// The directory where the plugins are stored.
  static Uri pluginsDirectory = Platform.script.resolve('plugins/');

  static final PluginManager _instance = PluginManagerImpl();

  /// Logger for the plugin manager.
  Logger get logger => Logger('PluginManager');

  /// List all available plugins in the plugins directory.
  Future<List<PluginFile>> listPlugins({bool isDebug});

  /// Load all plugins. Returns a list of loaded plugins.
  /// [timeout] is the maximum time to wait for a plugin to load.
  /// [skipErrors] determines if errors should be skipped.
  Future<List<PluginReference>> loadPlugins({
    Duration timeout,
    bool skipErrors,
  });

  /// Send a message to all loaded plugins.
  /// Returns a map of plugin references to their responses.
  /// [timeout] is the maximum time to wait for a response.
  /// [skipErrors] determines if errors should be skipped.
  /// If [skipErrors] is true, the error will be logged and the plugin will be
  /// skipped.
  /// If [skipErrors] is false, the error will be thrown.
  Future<Map<PluginReference, T>> broadcast<T>(
    Message message, {
    Duration timeout,
    bool skipErrors,
  });

  /// Get the plugin loader for the given plugin.
  PluginLoader getPluginLoader(PluginReference plugin);

  /// Get the plugin manager instance.
  ///
  /// {@macro plugin_manager}
  static PluginManager get instance {
    return _instance;
  }
}

/// {@macro plugin_manager}
class PluginManagerImpl extends PluginManager {
  final Map<PluginReference, PluginLoader> _plugins = {};

  @override
  Future<Map<PluginReference, T>> broadcast<T>(
    Message message, {
    Duration timeout = const Duration(seconds: 5),
    bool skipErrors = true,
  }) async {
    final responses = <PluginReference, T>{};

    for (final plugin in _plugins.keys) {
      try {
        final loader = _plugins[plugin]!;
        final response = await loader.send<T>(message, timeout: timeout);
        responses[plugin] = response;
      } catch (e) {
        if (skipErrors) {
          logger.warning(
            'Error while sending message to $plugin, but skipping it ($e)',
          );
        } else {
          rethrow;
        }
      }
    }

    return responses;
  }

  @override
  PluginLoader getPluginLoader(PluginReference plugin) {
    final loader = _plugins[plugin];
    if (loader == null) {
      throw Exception('Plugin $plugin not found');
    }

    return loader;
  }

  @override
  Future<List<PluginFile>> listPlugins({
    bool isDebug = isJitCompiled,
  }) async {
    final directory = Directory.fromUri(PluginManager.pluginsDirectory);

    final plugins =
        await directory.list().where((entity) => entity is File).toList();

    return plugins.whereType<File>().where((file) {
      return isDebug ? file.path.endsWith('.dart') : file.path.endsWith('.aot');
    }).toList();
  }

  @override
  Future<List<PluginReference>> loadPlugins({
    Duration timeout = const Duration(seconds: 5),
    bool skipErrors = true,
  }) async {
    final plugins = await listPlugins();

    for (final plugin in plugins) {
      final loader = PluginLoaderImpl();
      final reference = await loader.load(plugin);

      if (_plugins.containsKey(reference)) {
        throw Exception('Plugin $reference already loaded or conflicted');
      }

      _plugins[reference] = loader;
    }

    await broadcast(
      const InitialMessage(),
      timeout: timeout,
      skipErrors: skipErrors,
    );

    return _plugins.keys.toList();
  }
}
