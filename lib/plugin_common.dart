import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:dart_plugin_system/plugin_protocol.dart';

/// Indicates whether the current application is compiled in AOT mode.
const bool isAotCompiled = bool.fromEnvironment('dart.vm.product');

/// Indicates whether the current application is compiled in JIT mode.
/// JIT mode is the default mode when running the application with `dart run`.
const bool isJitCompiled = !isAotCompiled;

/// A reference to a plugin.
typedef PluginReference = String;

/// A plugin file.
typedef PluginFile = File;

/// Version of a plugin.
typedef PluginVersion = String;

/// {@template plugin_common.broadcast_receive_port}
/// A broadcast receive port that can be listened to multiple times.
/// {@endtemplate}
class BroadcastReceivePort extends Stream<dynamic> {
  late Stream<dynamic> _receivePort;
  late SendPort _sendPort;

  /// {@macro plugin_common.broadcast_receive_port}
  BroadcastReceivePort.fromReceivePort(ReceivePort receivePort)
      : _receivePort = receivePort.asBroadcastStream(),
        _sendPort = receivePort.sendPort;

  /// {@macro plugin_common.broadcast_receive_port}
  BroadcastReceivePort() {
    final receivePort = ReceivePort();
    _receivePort = receivePort.asBroadcastStream();
    _sendPort = receivePort.sendPort;
  }

  @override
  StreamSubscription<dynamic> listen(void Function(dynamic event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return _receivePort.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  /// The [SendPort] of this [BroadcastReceivePort].
  SendPort get sendPort => _sendPort;

  @override
  String toString() => 'BroadcastReceivePort';
}

/// {@template plugin_common.message_tag}
/// A message tag.
/// This class is used to tag messages sent between plugins.
/// {@endtemplate}
class MessageTag {
  /// The value of this tag.
  final String value;

  /// {@macro plugin_common.message_tag}
  const MessageTag(this.value);

  static const MessageTag empty = MessageTag('');
  static const MessageTag debug = MessageTag('debug');
  static const MessageTag initial = MessageTag('initial');
  static const MessageTag ready = MessageTag('ready');
  static const MessageTag error = MessageTag('error');
  static const MessageTag kill = MessageTag('kill');

  @override
  String toString() => 'MessageTag{value: $value}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageTag &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// {@template plugin_common.message}
/// A message that can be sent between plugins.
/// {@endtemplate}
class Message {
  /// The tag of this message.
  final MessageTag tag;

  /// The data of this message.
  final List<dynamic>? data;

  /// {@macro plugin_common.message}
  const Message(this.tag, [this.data]);

  /// Unpacks a message from a list.
  /// The first element is the tag, the rest are the data.
  factory Message.unpack(List<dynamic> list) {
    if (list.isEmpty) {
      throw ArgumentError('The list cannot be empty.');
    }

    final tag = list.first;
    final data = list.length > 1 ? list.sublist(1) : null;

    try {
      return switch (tag) {
        MessageTag.initial => InitialMessage(),
        MessageTag.ready => ReadyMessage(
            plugin: data![0] as PluginReference,
            version: data[1] as PluginVersion,
            sendPort: data[2] as SendPort),
        MessageTag.error => ErrorMessage(error: data![0] as String),
        MessageTag.kill => KillMessage(),
        MessageTag.empty => EmptyMessage(),
        _ => Message(MessageTag(tag), data),
      };
    } on Exception catch (e) {
      throw ArgumentError('Invalid message: $e');
    }
  }

  /// Packs this message into a list.
  /// The first element is the tag, the rest are the data.
  List<dynamic> pack() => [tag.value, ...?data];

  /// Returns the data at the given index.
  /// Throws a [StateError] if the data is null.
  /// Throws a [RangeError] if the index is out of range.
  /// This ignores the tag.
  dynamic operator [](int index) {
    if (data == null) {
      throw StateError('The data is null.');
    }

    if (index >= data!.length) {
      throw RangeError.index(index, data, 'index', 'Index out of range');
    }

    return data![index];
  }

  @override
  String toString() => 'Message{tag: $tag, data: $data}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Message &&
          runtimeType == other.runtimeType &&
          tag == other.tag &&
          data == other.data;

  @override
  int get hashCode => tag.hashCode ^ data.hashCode;
}

enum Arch {
  x86,
  x86_64,
  arm,
  arm64,
  unknown;

  static Future<Arch> get() async {
    String? cpu;

    try {
      if (Platform.isWindows) {
        cpu = Platform.environment['PROCESSOR_ARCHITECTURE'];
      } else {
        var info = await Process.run('uname', ['-m']);
        cpu = info.stdout.toString().replaceAll('\n', '');
      }

      return switch (cpu.toString().toLowerCase()) {
        'x86_64' || 'x64' || 'amd64' => Arch.x86_64,
        'x86' || 'i386' || 'x32' || '386' || 'amd32' => Arch.x86,
        'arm64' || 'aarch64' || 'a64' => Arch.arm64,
        'arm' || 'arm32' || 'a32' => Arch.arm,
        _ => Arch.unknown,
      };
    } catch (e) {
      return Arch.unknown;
    }
  }
}
