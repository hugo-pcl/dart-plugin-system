import 'dart:async';
import 'dart:io';
import 'dart:isolate';

const bool isAotCompiled = const bool.fromEnvironment('dart.vm.product');
const bool isJitCompiled = !isAotCompiled;

typedef PluginReference = String;

enum Arch {
  x86,
  x86_64,
  arm,
  arm64,
  unknown,
}

Future<Arch> getArch() async {
  String? cpu;

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
}

class BroadcastReceivePort extends Stream<dynamic> {
  late Stream<dynamic> _receivePort;
  late SendPort _sendPort;

  BroadcastReceivePort.fromReceivePort(ReceivePort receivePort)
      : _receivePort = receivePort.asBroadcastStream(),
        _sendPort = receivePort.sendPort;
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

  SendPort get sendPort => _sendPort;
}

class PluginEvent {
  final String value;

  const PluginEvent(this.value);

  /// First event sent to the plugin.
  /// The plugin should initialize itself and return the receive port.
  static const initial = PluginEvent('initial');

  /// Event sent to the plugin to kill it and free resources by stopping
  /// associated isolate.
  static const kill = PluginEvent('kill');

  @override
  String toString() {
    return value;
  }

  @override
  bool operator ==(Object other) {
    return other is PluginEvent && other.value == value;
  }
}

class Message {
  final PluginEvent event;
  final List<dynamic>? args;

  Message(this.event, [this.args]);

  factory Message.unpack(List<dynamic> data) {
    if (data.isEmpty) {
      throw Exception('Invalid message data');
    }

    if (data.length == 1) {
      return Message(PluginEvent(data[0]));
    }

    return Message(PluginEvent(data[0]), data.sublist(1));
  }

  List<dynamic> pack() {
    return [event.value, ...?args];
  }
}

abstract class PluginLoader {
  /// The broadcast receive port for the main, used to receive events from
  /// the plugin isolate.
  BroadcastReceivePort receivePort = BroadcastReceivePort();

  /// The isolate used to run the plugin.
  Isolate? _isolate;

  /// The send port used to communicate with the plugin.
  SendPort? _sendPort;

  /// The plugin reference.
  String? _pluginReference;

  /// Load the [plugin] with the given [args].
  ///
  /// If [isDebug] is true, the plugin will be loaded in debug mode (JIT).
  Future<void> load(PluginReference plugin,
      {List<String>? args, bool isDebug = isJitCompiled});

  /// Send a [message] to the plugin.
  /// Returns the response from the plugin.
  /// [timeout] is the maximum time to wait for a response.
  Future<T> send<T>(Message message,
      {Duration timeout = const Duration(seconds: 5)});

  /// Check if the plugin is loaded.
  bool get isLoaded => _isolate != null && _pluginReference != null;
}

abstract class PluginManager {
  static Uri pluginsDirectory = Uri.parse('plugins/');
  static String pluginConfigFile = 'plugins';

  static PluginManager _instance = PluginManagerImpl();

  /// List all available plugins in the plugins directory.
  Future<List<PluginReference>> listPlugins();

  /// Load all plugins. Returns a list of loaded plugins.
  Future<List<PluginReference>> loadPlugins({
    Duration timeout = const Duration(seconds: 5),
    bool skipErrors = true,
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
    Duration timeout = const Duration(seconds: 5),
    bool skipErrors = true,
  });

  /// Get the plugin loader for the given plugin.
  PluginLoader getPluginLoader(PluginReference plugin);

  /// Get the plugin manager instance.
  static PluginManager get instance {
    return _instance;
  }
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

  /// Initialize the plugin with the given [sendPort].
  void init(SendPort sendPort) {
    _sendPort = sendPort;
    _eventSubscription = _receivePort.listen((event) {
      try {
        if (event is! List) {
          throw Exception('Invalid event data. Must be a list');
        }

        final parsedMessage = Message.unpack(event);
        _onMessage(parsedMessage);
      } catch (e) {
        print('Error while processing event: $e');
      }
    });

    sendPort.send(_receivePort.sendPort);
  }

  Future<void> _onMessage(Message message) async {
    if (_sendPort != null) {
      final result = await onMessage(message);
      _sendPort!.send(result);
    } else {
      throw Exception('Plugin not initialized');
    }
  }

  /// Handle the [message] received from the main.
  Future<Object?> onMessage(Message message);

  /// Dispose the plugin and free resources.
  void dispose() {
    _eventSubscription?.cancel();
    Isolate.current.kill();
  }
}

class PluginLoaderImpl extends PluginLoader {
  @override
  Future<void> load(
    PluginReference plugin, {
    List<String>? args,
    bool isDebug = isJitCompiled,
  }) async {
    final uri = Uri.parse(PluginManager.pluginsDirectory.toString() +
        plugin +
        (isDebug ? '.dart' : '.aot'));

    final isolate = await Isolate.spawnUri(
      uri,
      args ?? [],
      receivePort.sendPort,
      debugName: plugin,
    );

    // Wait for the isolate to be ready and return the receive port
    final initialMessage = await receivePort.first;

    if (initialMessage is SendPort) {
      _isolate = isolate;
      _pluginReference = plugin;
      _sendPort = initialMessage;
    } else {
      throw Exception('Plugin initialization failed for $plugin');
    }
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

    final subscription = receivePort.listen((event) {
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
          print('Error while sending message to $plugin: $e');
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
  Future<List<PluginReference>> listPlugins() async {
    final directory = Directory.fromUri(PluginManager.pluginsDirectory);

    final plugins = await directory
        .list()
        .where((entity) => entity is File)
        .map((entity) => entity.uri.pathSegments.last.split('.').first)
        .toList();

    return plugins.toSet().toList();
  }

  @override
  Future<List<PluginReference>> loadPlugins({
    Duration timeout = const Duration(seconds: 5),
    bool skipErrors = true,
  }) async {
    final plugins = await listPlugins();

    for (final plugin in plugins) {
      final loader = PluginLoaderImpl();
      await loader.load(plugin);
      _plugins[plugin] = loader;
    }

    await broadcast(
      Message(PluginEvent.initial),
      timeout: timeout,
      skipErrors: skipErrors,
    );

    return plugins;
  }
}
