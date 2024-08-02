import 'package:dart_plugin_system/plugin.dart';
import 'package:dart_plugin_system/plugin_common.dart';
import 'package:dart_plugin_system/plugin_protocol.dart';

class Another extends Plugin {
  @override
  PluginReference get reference => 'another';

  @override
  PluginVersion get version => '0.1.0';
  
  @override
  Future<Message?> onMessageFromMain(Message message) async {
    logger.info('Received message: $message from main');

    if (message.tag == MessageTag.initial) {
      logger.info('Plugin $reference initialized');
      initiateCommunicationWith('test');
      return null;
    }

    if (message.tag == MessageTag.empty) {
      sendToPlugin('test', DebugMessage(message: '$reference received empty message'));
    }
    
    return null;
  }
  
  @override
  Future<IntercomMessage?> onMessageFromPlugins(IntercomMessage message) async {
    logger.info('Received message: $message from ${message.from}');

    if (message.message.tag == MessageTag.debug) {
      return null;
    }
    
    return IntercomMessage(
      from: reference,
      to: message.from,
      message: DebugMessage(message: 'Hey from $reference'),
    );
  }
}

void main(args, message) => runPlugin(Another(), message, args);
