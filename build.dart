import 'dart:convert';
import 'dart:io';

class Build {
  /// List all dart files in the given path.
  Future<List<FileSystemEntity>> listFiles(String path) async {
    final dir = Directory(path);
    final files = await dir.list().toList();

    return files
        .where((entity) => entity is File)
        .where((entity) => entity.uri.pathSegments.last.endsWith('.dart'))
        .toList();
  }

  /// Compile each passed dart file using the given compiler.
  Future<void> compileFiles(List<FileSystemEntity> files,
      Future<void> compiler(FileSystemEntity file)) async {
    for (final file in files) {
      await compiler(file);
    }
  }

  /// Compile the given dart file to a .exe file.
  Future<void> compileExecutable(FileSystemEntity file) async {
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
  Future<void> compileAot(FileSystemEntity file) async {
    final process = await Process.start('dart', [
      'compile',
      'aot-snapshot',
      file.uri.path,
    ]);

    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      print('Error compiling ${file.uri.path}');
      print(await process.stderr.transform(utf8.decoder).join());
    }
  }

  /// Clean the given directory.
  /// Optionally, you can pass a list of file extensions to filter.
  /// Only files with the given extensions will be deleted.
  Future<void> cleanDirectory(String path, [List<String>? filter]) async {
    final _filter = filter ?? <String>[];

    final dir = Directory(path);

    await for (final entity in dir.list()) {
      if (entity is File) {
        if (_filter
            .contains("." + entity.uri.pathSegments.last.split('.').last)) {
          await entity.delete();
        }
      }
    }
  }
}

Future<void> main(List<String> args) async {
  if (args.isNotEmpty) {
    if (args.first == 'clean') {
      final build = Build();
      await build.cleanDirectory('plugins', ['.exe', '.aot', '.dill', '.jit']);
      await build.cleanDirectory('.', ['.exe', '.aot', '.dill', '.jit']);
      exit(0);
    }
  }

  final build = Build();
  final plugins = await build.listFiles('plugins');
  final app = File('main.dart');

  await build.compileFiles(plugins, build.compileAot);
  await build.compileFiles([app], build.compileExecutable);

  exit(0);
}
