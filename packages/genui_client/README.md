# `genui_client`

The `genui_client` package is a Flutter package that enables the creation of applications with dynamically generated user interfaces. It is responsible for defining the set of available UI components (the "catalog"), communicating with a `genui_server` backend, and rendering the UI definitions received from it in real-time.

## Features

-   **Dynamic UI Generation**: Render UIs from definitions sent by a `genui_server`.
-   **Component Catalog**: Define a catalog of Flutter widgets that the AI can use to build interfaces.
-   **High-Level Facade**: Use the `UiAgent` to easily manage sessions, conversation state, and UI updates.
-   **Pre-built Chat Widgets**: Quickly build chat-based UIs with the `GenUiChat` widget.
-   **State Management**: Automatically handles the state of dynamic UI surfaces.

## Getting Started

### Installation

Add `genui_client` to your `pubspec.yaml` file:

```yaml
dependencies:
  genui_client: <latest_version>
```

Then, run `flutter pub get`.

### Basic Usage

Here is a minimal example of how to use `GenUiChat` to create a simple chat application.

```dart
import 'package:flutter/material.dart';
import 'package:genui_client/genui_client.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final UiAgent _agent;

  @override
  void initState() {
    super.initState();
    // The UiAgent is the main entry point for the client.
    _agent = UiAgent();
    // Start a session with the server when the app starts.
    _agent.startSession();
  }

  @override
  void dispose() {
    _agent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('GenUI Chat'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GenUiChat(
            agent: _agent,
            onEvent: (event) {
              // Handle UI events from generated widgets
              print('UI Event: ${event.toMap()}');
            },
          ),
        ),
      ),
    );
  }
}
```

## Core Concepts

### `UiAgent`

The `UiAgent` is a high-level facade and the primary entry point for the package. It simplifies interaction with the various components by orchestrating the `GenUiManager` (state management) and `GenUIClient` (network communication).

-   `agent.startSession()`: Initializes a session with the server, sending the widget catalog.
-   `agent.sendRequest(UserMessage message)`: Sends a user message to the server to generate a UI response.
-   `agent.conversation`: A `ValueListenable` that holds the current conversation history.
-   `agent.builder`: Provides the `SurfaceBuilder` interface needed by `GenUiSurface` widgets.

### `Catalog`

The `Catalog` is the cornerstone of the client's capabilities. It defines every widget that the application knows how to render. The catalog is serialized to a JSON schema and sent to the server during `startSession()`, informing the AI about the available UI components.

The package provides a `coreCatalog` with common widgets like `Column`, `Text`, `ElevatedButton`, etc. You can create your own catalog or extend the core one.

### `GenUiChat`

A complete, pre-built chat widget that integrates with a `UiAgent`. It provides a user interface for sending messages and displaying the conversation history, including any UI surfaces rendered by the AI.

### `GenUiSurface`

A Flutter widget that renders a dynamic UI based on a definition from the server. It listens to the `GenUiManager` (via the `SurfaceBuilder` interface provided by the `UiAgent`) and recursively builds the Flutter widget tree. You typically don't need to use this directly unless you are building a custom UI that is not based on `GenUiChat`.