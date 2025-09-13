// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:dart_schema_builder/dart_schema_builder.dart';
import 'package:gsp_client/gsp_client.dart';
import 'package:flutter/material.dart';

/// Creates and registers all the widget builders for the FCP client.
void registerDefaultWidgets(WidgetCatalogRegistry registry) {
  registry.register(
    CatalogItem(
      name: 'Text',
      builder: (context, node, properties, children) {
        return Text(properties['data'] as String? ?? '');
      },
      definition: WidgetDefinition(
        properties: ObjectSchema(
          properties: {
            'data': Schema.string(description: 'The text to display.'),
          },
          required: ['data'],
        ),
      ),
    ),
  );

  registry.register(
    CatalogItem(
      name: 'Column',
      builder: (context, node, properties, children) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.values.firstWhere(
            (e) => e.name == properties['mainAxisAlignment'],
            orElse: () => MainAxisAlignment.start,
          ),
          crossAxisAlignment: CrossAxisAlignment.values.firstWhere(
            (e) => e.name == properties['crossAxisAlignment'],
            orElse: () => CrossAxisAlignment.center,
          ),
          children: children['children'] ?? [],
        );
      },
      definition: WidgetDefinition(
        properties: ObjectSchema(
          properties: {
            'children': Schema.list(
              items: Schema.string(),
              description: 'The list of child widgets.',
            ),
            'mainAxisAlignment': Schema.string(
              description:
                  'How the children should be placed along the main axis.',
              enumValues: MainAxisAlignment.values.map((e) => e.name).toList(),
            ),
            'crossAxisAlignment': Schema.string(
              description:
                  'How the children should be placed along the cross axis.',
              enumValues: CrossAxisAlignment.values.map((e) => e.name).toList(),
            ),
          },
        ),
      ),
    ),
  );

  registry.register(
    CatalogItem(
      name: 'ElevatedButton',
      builder: (context, node, properties, children) {
        return ElevatedButton(
          onPressed: () {
            final onEvent = FcpProvider.of(context)?.onEvent;
            if (onEvent == null) {
              return;
            }
            final event = Event(
              sourceNodeId: node.id,
              eventName: 'onPressed',
              timestamp: DateTime.now(),
            );
            final genUiView = context
                .findAncestorWidgetOfExactType<GenUiView>()!;
            final clientRequest = ClientRequest(
              catalog: genUiView.registry.buildCatalog(),
              event: event,
              layout: genUiView.interpreter.currentLayout,
              state: genUiView.interpreter.currentState,
            );
            onEvent(clientRequest);
          },
          child: children['child']?.first,
        );
      },
      definition: WidgetDefinition(
        properties: ObjectSchema(
          properties: {
            'child': Schema.string(description: 'The child widget to display.'),
          },
        ),
        events: ObjectSchema(
          properties: {'onPressed': Schema.object(properties: {})},
        ),
      ),
    ),
  );
}
