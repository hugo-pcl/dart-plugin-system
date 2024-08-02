import 'dart:async';
import 'dart:isolate';

import 'package:dart_plugin_system/plugin_common.dart';
import 'package:dart_plugin_system/plugin_protocol.dart';
import 'package:logging/logging.dart';

/// Helper function to run a plugin like runApp in Flutter.
T runPlugin<T extends Plugin>(T plugin, SendPort message, List<Object> args) {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print(
        '${record.level.name}: ${record.time}: ${record.loggerName} :: ${record.message}');
  });

  plugin.init(message);
  return plugin;
}

abstract class Plugin {
  /// The broadcast receive port used to receive events from the main.
  /// The plugin should listen to this port to receive events.
  final BroadcastReceivePort _receiveFromMainPort = BroadcastReceivePort();

  /// The broadcast receive port used to receive events from other plugins.
  /// The plugin should listen to this port to receive events.
  final BroadcastReceivePort _receiveFromPluginsPort = BroadcastReceivePort();

  /// Send port used to communicate with the main.
  SendPort? _sendToMainPort;

  /// Send port used to communicate with other plugins.
  final Map<PluginReference, SendPort> _sendToPluginsPort = {};

  /// Subscription to the main receive port.
  /// The plugin should listen to this subscription to receive events.
  /// The subscription should be canceled when the plugin is disposed.
  StreamSubscription? _mainSubscription;

  /// Subscription to the plugins receive port.
  /// The plugin should listen to this subscription to receive events.
  /// The subscription should be canceled when the plugin is disposed.
  StreamSubscription? _pluginsSubscription;

  /// Plugin reference.
  PluginReference get reference;

  /// Plugin version.
  PluginVersion get version;

  /// Logger for the plugin.
  Logger get logger => Logger(reference);

  /// Initialize the plugin with the given [sendPort].
  void init(SendPort sendPort) {
    _sendToMainPort = sendPort;
    _mainSubscription = _receiveFromMainPort.listen((event) {
      logger.finest('>> Received raw from main: $event');

      if (event == null) {
        logger.warning('Received null event from main');
        return;
      }

      if (event is! List) {
        throw Exception(
            'Invalid event data received in $reference from main. Must be a list');
      }

      final parsedMessage = Message.unpack(event);

      if (parsedMessage.tag == MessageTag.kill) {
        _onMessageFromMain(parsedMessage);

        dispose();
        return;
      }

      if (parsedMessage.tag == MessageTag.intercom) {
        // Only ready messages are allowed from other plugins through the main.
        final intercom = IntercomMessage.from(parsedMessage);

        if (intercom.message.tag == MessageTag.ready) {
          final ready = ReadyMessage.from(intercom.message);
          _sendToPluginsPort[intercom.from] = ready.sendPort;

          // Send a ready message back to the plugin directly to establish
          // communication.
          ready.sendPort.send(
            IntercomMessage(
              to: intercom.from,
              from: reference,
              message: ReadyMessage(
                plugin: reference,
                version: version,
                sendPort: _receiveFromPluginsPort.sendPort,
              ),
            ).pack(),
          );
        }
      }

      _onMessageFromMain(parsedMessage);
    });

    _pluginsSubscription = _receiveFromPluginsPort.listen((event) {
      logger.finest('>> Received raw from plugin: $event');

      if (event == null) {
        logger.warning('Received null event from plugin');
        return;
      }

      if (event is! List) {
        throw Exception(
            'Invalid event data received in $reference. Must be a list');
      }

      final parsedMessage = IntercomMessage.unpack(event);
      _onMessageFromPlugins(parsedMessage);
    });

    _sendToMainPort!.send(
      ReadyMessage(
        plugin: reference,
        version: version,
        sendPort: _receiveFromMainPort.sendPort,
      ).pack(),
    );
  }

  Future<void> _onMessageFromMain(Message message) async {
    if (_sendToMainPort != null) {
      final result = await onMessageFromMain(message);

      // Send the result back to the main.
      _sendToMainPort!.send(result?.pack());
    } else {
      throw Exception('Plugin $reference not initialized');
    }
  }

  Future<void> _onMessageFromPlugins(IntercomMessage message) async {
    if (_sendToPluginsPort.containsKey(message.from)) {
      final result = await onMessageFromPlugins(message);

      // Send the result back to the plugin.
      _sendToPluginsPort[message.from]!.send(result?.pack());
    } else {
      if (message.message.tag == MessageTag.ready) {
        // Ready message received from another plugin is assumed to be
        // the acknowledgment of the ready message sent to the plugin.
        final ready = ReadyMessage.from(message.message);
        _sendToPluginsPort[message.from] = ready.sendPort;
      } else {
        throw Exception('Plugin ${message.from} not initialized');
      }
    }
  }

  /// Handle the [message] received from the main.
  Future<Message?> onMessageFromMain(Message message);

  /// Handle the [message] received from other plugins.
  Future<IntercomMessage?> onMessageFromPlugins(IntercomMessage message);

  /// Establish communication with the plugin [to].
  void initiateCommunicationWith(PluginReference to) {
    _sendToMainPort!.send(
      IntercomMessage(
        to: to,
        from: reference,
        message: ReadyMessage(
          plugin: reference,
          version: version,
          sendPort: _receiveFromPluginsPort.sendPort,
        ),
      ).pack(),
    );
  }

  /// Send a message to the plugin [to].
  void sendToPlugin(PluginReference to, Message message) {
    if (_sendToPluginsPort.containsKey(to)) {
      // Communicate with the plugin directly.
      _sendToPluginsPort[to]!.send(
        IntercomMessage(
          to: to,
          from: reference,
          message: message,
        ).pack(),
      );
    } else {
      throw Exception(
          'Communication with $to not established, please initiate communication first');
    }
  }

  /// Dispose the plugin and free resources.
  void dispose() {
    _mainSubscription?.cancel();
    _pluginsSubscription?.cancel();
    Isolate.current.kill();
  }
}
