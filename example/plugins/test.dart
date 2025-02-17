import 'package:dart_plugin_system/plugin.dart';
import 'package:dart_plugin_system/plugin_common.dart';
import 'package:dart_plugin_system/plugin_protocol.dart';

class Test extends Plugin {
  @override
  PluginReference get reference => 'test';

  @override
  PluginVersion get version => '0.1.0';

  @override
  Future<Message?> onMessageFromMain(Message message) async {
    logger.info('Received message: $message from main');

    if (message.tag == MessageTag.kill) {
      return DebugMessage(message: 'Bye from $reference');
    }

    return null;
  }

  @override
  Future<IntercomMessage?> onMessageFromPlugins(IntercomMessage message) async {
    logger.info('Received message: $message from ${message.from}');

    return IntercomMessage(
      from: reference,
      to: message.from,
      message: DebugMessage(message: 'Hey from $reference'),
    );
  }
}

void main(args, message) => runPlugin(Test(), message, args);
