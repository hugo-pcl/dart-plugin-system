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

class IntercomMessage extends Message {
  IntercomMessage({
    required this.to,
    required this.from,
    required this.message,
  }) : super(MessageTag.intercom, [to, from, ...message.pack()]);

  IntercomMessage.from(Message message)
      : to = message.data![0] as PluginReference,
        from = message.data![1] as PluginReference,
        message = Message.unpack(message.data!.sublist(2)),
        super(MessageTag.intercom);
  
  factory IntercomMessage.unpack(List<dynamic> list) {
    if (list.isEmpty) {
      throw ArgumentError('The list cannot be empty.');
    }

    final _ = list.first as String;
    final to = list[1] as PluginReference;
    final from = list[2] as PluginReference;
    final message = Message.unpack(list.sublist(3));

    return IntercomMessage(to: to, from: from, message: message);
  }

  final PluginReference to;
  final PluginReference from;
  final Message message;

  @override
  List pack() {
    return [tag.value, to, from, ...message.pack()];
  }

  @override
  String toString() =>
      'IntercomMessage{to: $to, from: $from, message: $message}';
}
