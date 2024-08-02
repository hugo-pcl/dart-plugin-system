import 'dart:async';
import 'dart:isolate';

import 'package:dart_plugin_system/plugin_common.dart';
import 'package:dart_plugin_system/plugin_protocol.dart';
import 'package:logging/logging.dart';

/// Helper function to run a plugin like runApp in Flutter.
T runPlugin<T extends Plugin>(T plugin, SendPort message, List<Object> args) {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.loggerName} :: ${record.message}');
  });

  plugin.init(message);
  return plugin;
}

abstract class Plugin {
  /// The broadcast receive port used to receive events from the main.
  /// The plugin should listen to this port to receive events.
  final BroadcastReceivePort _receivePort = BroadcastReceivePort();

  /// Send port used to communicate with the main.
  SendPort? _sendPort;

  /// Subscription to the receive port.
  /// The plugin should listen to this subscription to receive events.
  /// The subscription should be canceled when the plugin is disposed.
  StreamSubscription? _eventSubscription;

  /// Plugin reference.
  PluginReference get reference;

  /// Plugin version.
  PluginVersion get version;

  /// Logger for the plugin.
  Logger get logger => Logger(reference);

  /// Initialize the plugin with the given [sendPort].
  void init(SendPort sendPort) {
    _sendPort = sendPort;
    _eventSubscription = _receivePort.listen((event) {
      if (event is! List) {
        throw Exception('Invalid event data. Must be a list');
      }

      final parsedMessage = Message.unpack(event);
      _onMessage(parsedMessage);
    });

    sendPort.send(
      ReadyMessage(
        plugin: reference,
        version: version,
        sendPort: _receivePort.sendPort,
      ).pack(),
    );
  }

  Future<void> _onMessage(Message message) async {
    if (_sendPort != null) {
      final result = await onMessage(message);
      _sendPort!.send(result?.pack());
    } else {
      throw Exception('Plugin $reference not initialized');
    }
  }

  /// Handle the [message] received from the main.
  Future<Message?> onMessage(Message message);

  /// Dispose the plugin and free resources.
  void dispose() {
    _eventSubscription?.cancel();
    Isolate.current.kill();
  }
}
