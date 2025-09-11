// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fcp_client/fcp_client.dart';
import 'package:flutter/material.dart';

import 'registry.dart';

void main() {
  runApp(const GenUiExampleApp());
}

const String _sampleJsonl = r'''
{"messageType": "StreamHeader", "formatVersion": "1.0.0", "initialState": {"greeting": "Hello", "user": {"name": "World"}}}
{"messageType": "Layout", "nodes": [{"id": "root", "type": "Column", "properties": {"children": ["greeting_text", "button"]}}]}
{"messageType": "Layout", "nodes": [{"id": "greeting_text", "type": "Text", "properties": {"data": "${greeting}, ${user.name}!"}}]}
{"messageType": "Layout", "nodes": [{"id": "button", "type": "ElevatedButton", "properties": {"child": "button_text"}}]}
{"messageType": "Layout", "nodes": [{"id": "button_text", "type": "Text", "properties": {"data": "Click Me"}}]}
{"messageType": "LayoutRoot", "rootId": "root"}
''';

class GenUiExampleApp extends StatelessWidget {
  const GenUiExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GenUI Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const GenUiHomePage(),
    );
  }
}

class GenUiHomePage extends StatefulWidget {
  const GenUiHomePage({super.key});

  @override
  State<GenUiHomePage> createState() => _GenUiHomePageState();
}

class _GenUiHomePageState extends State<GenUiHomePage> {
  late final TextEditingController _textController;
  GspInterpreter? _interpreter;
  final _registry = WidgetCatalogRegistry();

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    registerDefaultWidgets(_registry);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _processInput() {
    final streamController = StreamController<String>();
    setState(() {
      _interpreter = GspInterpreter(
        stream: streamController.stream,
        catalog: _registry.buildCatalog(),
      );
    });

    final lines = _textController.text.split('\n');
    for (final line in lines) {
      if (line.trim().isNotEmpty) {
        streamController.add(line);
      }
    }
    streamController.close();
  }

  void _loadSample() {
    _textController.text = _sampleJsonl;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GenUI Example')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _textController,
              maxLines: 10,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Paste JSONL stream here...',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: _loadSample, child: const Text('Sample')),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _processInput,
                  child: const Text('Process'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _interpreter == null
                    ? const Center(child: Text('Press "Process" to render UI'))
                    : GenUiView(
                        interpreter: _interpreter!,
                        registry: _registry,
                        onEvent: (request) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Event: ${request.event?.eventName} from ${request.event?.sourceNodeId}',
                              ),
                            ),
                          );
                        },
                        onError: (error) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: Colors.red.shade100,
                              content: Text(
                                'Error: ${error.errorType}: ${error.message}',
                                style: TextStyle(color: Colors.red.shade900),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
