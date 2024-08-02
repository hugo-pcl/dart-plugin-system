import 'dart:convert';
import 'dart:io';

import 'package:dart_plugin_system/plugin_common.dart';
import 'package:hashlib/hashlib.dart';

class Builder {
  /// List all dart files in the given path.
  Future<List<File>> listFiles(String path) async {
    final dir = Directory(path);
    final files = await dir.list().toList();

    return files
        .whereType<File>()
        .where((entity) => entity.uri.pathSegments.last.endsWith('.dart'))
        .toList();
  }

  /// Compile each passed dart file using the given compiler.
  Future<void> compileFiles(
      List<File> files, Future<void> Function(File file) compiler) async {
    for (final file in files) {
      await compiler(file);
    }
  }

  /// Compile the given dart file to a .exe file.
  Future<void> compileExecutable(File file) async {
    final process = await Process.start('dart', [
      'compile',
      'exe',
      file.uri.path,
    ]);

    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      print('Error compiling ${file.uri.path}');
      print(await process.stderr.transform(utf8.decoder).join());
    }
  }

  /// Compile the given dart file to a .aot file.
  Future<void> compileAot(File file) async {
    final platform = Platform.operatingSystem.toLowerCase();
    final arch = await Arch.get().then((arch) => arch.name.toLowerCase());

    final output =
        '${file.uri.resolve('.').path}${file.uri.pathSegments.last.split('.').first}-$platform-$arch';

    final outputAot = '$output.aot';
    final outputChecksum = '$output.checksum';

    final process = await Process.start('dart', [
      'compile',
      'aot-snapshot',
      '-o',
      outputAot,
      file.uri.path,
    ]);

    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      print('Error compiling ${file.uri.path}');
      print(await process.stderr.transform(utf8.decoder).join());
    }

    // Post-process the .aot file
    final aotFile = File(outputAot);
    final checksumFile = File(outputChecksum);

    // Create checksum file
    final checksum = await sha3_256.file(aotFile);
    await checksumFile.writeAsString(checksum.toString());
  }

  /// Clean the given directory.
  /// Optionally, you can pass a list of file extensions to filter.
  /// Only files with the given extensions will be deleted.
  Future<void> cleanDirectory(String path, [List<String>? filter]) async {
    final filter0 = filter ?? <String>[];

    final dir = Directory(path);

    await for (final entity in dir.list()) {
      if (entity is File) {
        if (filter0
            .contains(".${entity.uri.pathSegments.last.split('.').last}")) {
          await entity.delete();
        }
      }
    }
  }
}

Future<void> main(List<String> args) async {
  if (args.contains('clean')) {
    final build = Builder();
    await build.cleanDirectory(
        'example/plugins', ['.exe', '.aot', '.dill', '.jit', '.checksum']);
    await build.cleanDirectory(
        'example', ['.exe', '.aot', '.dill', '.jit', '.checksum']);
    await build
        .cleanDirectory('.', ['.exe', '.aot', '.dill', '.jit', '.checksum']);
    print('Cleaned');
  }

  if (args.contains('build')) {
    final build = Builder();
    final plugins = await build.listFiles('example/plugins');
    final app = File('example/dart_plugin_system.dart');

    await build.compileFiles(plugins, build.compileAot);
    await build.compileFiles([app], build.compileExecutable);
    print('Built');
  }

  if (args.isEmpty) {
    print('Usage: dart run builder.dart [clean|build]');
  }

  exit(0);
}
