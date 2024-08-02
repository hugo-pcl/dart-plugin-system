# Dart Plugin System

Check Architecture on [architecture.md](architecture.md)

## Build

`dart run tools/builder.dart clean` - Clean the build directories
`dart run tools/builder.dart build` - Build the plugin system in AOT mode

## Run

`dart run example/dart_plugin_system.dart` - Run the plugin system in JIT mode
`./example/dart_plugin_system.exe` - Run the plugin system in AOT mode (need to build first)
