# Dart Plugin System - Architecture

The Dart Plugin System is a system that allows Dart developers to create 
plugins that can be used in Dart applications at runtime.
Since the Dart VM is packaged in "exe" compiled files, the plugins are just
"snapshots" compiled files that are loaded at runtime in Isolate instances.

| Type | Debug | Release |
|-------|-------|---------|
| Main application | JIT | EXE |
| Plugin | Dart File | .tar containing AOT snapshots |

In release mode, the main application is compiled to an "exe" file, and the plugins are compiled to a ".tar" file containing AOT snapshots for each supported platform.

The Dart Plugin System is composed of the following components:
- Plugin Loader
- Plugin Manager
- Plugin
- Development Tools

## Plugin Loader

The Plugin Loader is responsible for loading a plugin at runtime.

The Plugin Loader is a Dart library that provides a set of functions to load plugin from a ".tar" file containing AOT snapshots. It also allows the loading of .dart file in debug mode.

The Plugin Loader is responsible for:
- Loading the plugin from the ".tar" file
- Loading the plugin from the ".dart" file in debug mode
- Managing the plugin isolate instance
  - Send messages to the plugin
  - Receive messages from the plugin

> The Plugin Loader is responsible of only one plugin at a time.

## Plugin Manager

The Plugin Manager is responsible for managing the plugins.

The Plugin Manager is a Dart library that provides a set of functions to manage the plugins. It allows the main application to load, unload, and communicate with the plugins.

The Plugin Manager is responsible for:
- Managing plugin list
- Loading the plugins
- Communicating with the plugins

> The Plugin Manager is responsible of multiple plugins at a time. It can load multiple plugins and communicate with them. It is singleton.

## Plugin

The Plugin is an abstract class that defines the interface of a plugin.

Each plugin must implement the Plugin interface. The Plugin interface defines the following methods:
- `main`: The entry point of the plugin
- `init`: Initialize the plugin
- `dispose`: Dispose the plugin
- `onMessage`: Handle a message from the main application

## Development Tools

The Development Tools are a set of tools that help developers to create and debug plugins.
