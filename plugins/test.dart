import 'dart:io';

import '../plugin_loader.dart';

class Test extends Plugin {
  @override
  Future<Object?> onMessage(Message message) async {
    switch (message.event) {
      case PluginEvent.initial:
        final platform = Platform.operatingSystem;
        final arch = await getArch();
        print('Test plugin initialized on $platform ${arch.name} (JIT enabled: $isJitCompiled)');
      case PluginEvent.kill:
        print('Killing plugin Test');
        dispose();
    }

    return null;
  }
}

void main(args, message) {
  Test().init(message);
}
