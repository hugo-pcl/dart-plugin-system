import 'dart:isolate';

import 'package:dart_plugin_system/plugin_common.dart';

class InitialMessage extends Message {
  const InitialMessage() : super(MessageTag.initial);

  @override
  String toString() => 'InitialMessage';
}

class ReadyMessage extends Message {
  ReadyMessage({
    required this.plugin,
    required this.version,
    required this.sendPort,
  }) : super(MessageTag.ready, [plugin, version, sendPort]);

  ReadyMessage.from(Message message)
      : plugin = message.data![0] as PluginReference,
        version = message.data![1] as PluginVersion,
        sendPort = message.data![2] as SendPort,
        super(MessageTag.ready);

  final PluginReference plugin;
  final PluginVersion version;
  final SendPort sendPort;

  @override
  String toString() => 'ReadyMessage{plugin: $plugin, version: $version}';
}

class ErrorMessage extends Message {
  ErrorMessage({
    required this.error,
  }) : super(MessageTag.error, [error]);

  ErrorMessage.from(Message message)
      : error = message.data![0] as String,
        super(MessageTag.error);

  final String error;

  @override
  String toString() => 'ErrorMessage{error: $error}';
}

class KillMessage extends Message {
  const KillMessage() : super(MessageTag.kill);

  @override
  String toString() => 'KillMessage';
}

class EmptyMessage extends Message {
  const EmptyMessage() : super(MessageTag.empty);

  @override
  String toString() => 'EmptyMessage';
}

class DebugMessage extends Message {
  DebugMessage({
    required this.message,
  }) : super(MessageTag.debug, [message]);

  DebugMessage.from(Message message)
      : message = message.data![0] as String,
        super(MessageTag.debug);

  final String message;

  @override
  String toString() => 'DebugMessage{message: $message}';
}
