import 'package:dart_plugin_system/plugin.dart';
import 'package:dart_plugin_system/plugin_common.dart';
import 'package:dart_plugin_system/plugin_protocol.dart';

class Test extends Plugin {
  @override
  PluginReference get reference => 'test';

  @override
  PluginVersion get version => '0.1.0';

  @override
  Future<Message?> onMessage(Message message) async {
    logger.info('Received message: $message');
    return DebugMessage(message: 'Hello from $reference');
  }
}

void main(args, message) => runPlugin(Test(), message, args);
