import 'dart:async';
import 'dart:isolate';

import 'package:dart_plugin_system/plugin_common.dart';
import 'package:dart_plugin_system/plugin_manager.dart';
import 'package:dart_plugin_system/plugin_protocol.dart';

/// {@template plugin_loader}
/// The Plugin Loader is responsible for loading a plugin at runtime.
///
/// The Plugin Loader is a Dart library that provides a set of functions to
/// load plugin from a ".tar" file containing AOT snapshots.
/// It also allows the loading of .dart file in debug mode.
/// {@endtemplate}
abstract class PluginLoader {
  /// The broadcast receive port for the main, used to receive events from
  /// the plugin isolate.
  final BroadcastReceivePort _receivePort = BroadcastReceivePort();

  /// The isolate used to run the plugin.
  Isolate? _isolate;

  /// The send port used to communicate with the plugin.
  SendPort? _sendPort;

  /// The plugin reference.
  String? _pluginReference;

  /// Subscription to the receive port.
  StreamSubscription? _pluginSubscription;

  /// {@macro plugin_loader}
  PluginLoader() {
    _pluginSubscription = _receivePort.listen((event) {
      if (event is List) {
        final message = Message.unpack(event);
        if (message.tag == MessageTag.intercom) {
          // Handle intercom message by redirecting it to the plugin
          final intercom = IntercomMessage.from(message);

          // Send the message to the plugin
          PluginManager.instance.getPluginLoader(intercom.to).send(intercom);
        }
      }
    });
  }

  /// Load the [plugin] with the given [args].
  /// [args] are the arguments to pass to the plugin entrypoint.
  /// If [isDebug] is true, the plugin will be loaded in debug mode (JIT).
  Future<PluginReference> load(
    PluginFile plugin, {
    List<String>? args,
    bool isDebug,
  });

  /// Send a [message] to the plugin.
  /// Returns the response from the plugin.
  /// [timeout] is the maximum time to wait for a response.
  Future<T> send<T>(Message message, {Duration timeout});

  /// Check if the plugin is loaded.
  bool get isLoaded => _isolate != null && _pluginReference != null;

  /// Dispose the plugin loader.
  /// This will kill the plugin isolate and close the receive port.
  Future<void> dispose() async {
    _pluginSubscription?.cancel();
    await send(KillMessage());

    _isolate = null;
    _pluginReference = null;
    _sendPort = null;
  }
}

/// {@macro plugin_loader}
class PluginLoaderImpl extends PluginLoader {
  @override
  Future<PluginReference> load(
    PluginFile plugin, {
    List<String>? args,
    bool isDebug = isJitCompiled,
  }) async {
    final completer = Completer<List>();

    final subscription = _receivePort.listen((event) {
      if (event is List) {
        completer.complete(event);
      } else {
        completer.completeError(Exception(
            'Plugin initialization failed for $plugin : Invalid message received : $event'));
      }
    });

    final isolate = await Isolate.spawnUri(
      plugin.uri,
      args ?? [],
      _receivePort.sendPort,
      debugName: plugin.uri.pathSegments.last,
    );

    // Wait for the isolate to be ready and return the receive port
    final initialMessage = await completer.future;
    await subscription.cancel();

    final message = Message.unpack(initialMessage);

    if (message.tag == MessageTag.ready) {
      final ready = ReadyMessage.from(message);

      _isolate = isolate;
      _pluginReference = ready.plugin;
      _sendPort = ready.sendPort;

      return ready.plugin;
    } else if (message.tag == MessageTag.error) {
      final error = ErrorMessage.from(message);
      throw Exception(
          'Plugin initialization failed for $plugin : ${error.error}');
    }

    throw Exception(
        'Plugin initialization failed for $plugin : Unknown message $message');
  }

  @override
  Future<T> send<T>(
    Message message, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (!isLoaded) {
      throw Exception('Plugin not loaded');
    }

    final completer = Completer<T>();

    final subscription = _receivePort.listen((event) {
      if (event is T) {
        completer.complete(event);
      }
    });

    _sendPort!.send(message.pack());

    final timer = Timer(timeout, () {
      completer.completeError(
          Exception('Timeout while waiting for response of $_pluginReference'));
    });

    await completer.future;
    await subscription.cancel();
    timer.cancel();

    return completer.future;
  }
}
