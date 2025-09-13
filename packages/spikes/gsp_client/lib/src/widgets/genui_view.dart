// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:developer';

import 'package:flutter/material.dart';

import '../core/gsp_interpreter.dart';
import '../core/widget_catalog_registry.dart';
import '../models/models.dart';
import '../models/render_error.dart';
import '../models/streaming_models.dart';
import 'fcp_provider.dart';

/// The main entry point for rendering a UI from the GenUI Streaming Protocol.
///
/// This widget takes a [GspInterpreter] and a [WidgetCatalogRegistry] and
/// constructs the corresponding Flutter widget tree. It listens to the
/// interpreter and rebuilds the UI when the state changes.
class GenUiView extends StatefulWidget {
  /// Creates a widget that renders a UI from a GSP stream.
  ///
  /// The [interpreter] processes the stream and the [registry] provides the
  /// widget builders. The [onEvent] callback is invoked when a widget
  /// triggers an event.
  const GenUiView({
    super.key,
    required this.interpreter,
    required this.registry,
    this.onEvent,
    this.onError,
  });

  /// The interpreter that processes the GSP stream.
  final GspInterpreter interpreter;

  /// The registry mapping widget types to builder functions.
  final WidgetCatalogRegistry registry;

  /// A callback function that is invoked when an event is triggered by a
  /// widget.
  final ValueChanged<ClientRequest>? onEvent;

  /// A callback function that is invoked when a rendering error occurs.
  final ValueChanged<RenderError>? onError;

  @override
  State<GenUiView> createState() => _GenUiViewState();
}

class _GenUiViewState extends State<GenUiView> {
  RenderError? _lastReportedError;

  @override
  void initState() {
    super.initState();
    widget.interpreter.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(GenUiView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.interpreter != oldWidget.interpreter) {
      oldWidget.interpreter.removeListener(_rebuild);
      widget.interpreter.addListener(_rebuild);
      _lastReportedError = null;
    }
  }

  @override
  void dispose() {
    widget.interpreter.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    final RenderError? currentError = widget.interpreter.error;
    if (widget.onError != null &&
        currentError != null &&
        currentError != _lastReportedError) {
      _lastReportedError = currentError;
      // Schedule the callback to be called after the build is complete to avoid
      // calling it during a build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onError!(currentError);
        }
      });
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.interpreter.error != null) {
      final RenderError error = widget.interpreter.error!;
      return _ErrorWidget(error.errorType, error.message);
    }
    if (!widget.interpreter.isReadyToRender) {
      return const Center(child: CircularProgressIndicator());
    }
    return FcpProvider(
      onEvent: widget.onEvent,
      onError: widget.onError,
      child: _LayoutEngine(
        interpreter: widget.interpreter,
        registry: widget.registry,
      ),
    );
  }
}

class _LayoutEngine extends StatelessWidget {
  const _LayoutEngine({required this.interpreter, required this.registry});

  final GspInterpreter interpreter;
  final WidgetCatalogRegistry registry;

  @override
  Widget build(BuildContext context) {
    return _buildNode(context, interpreter.currentLayout!.root);
  }

  Widget _buildNode(
    BuildContext context,
    String nodeId, [
    Set<String> visited = const <String>{},
  ]) {
    final ValueChanged<RenderError>? onError = FcpProvider.of(context)?.onError;
    if (visited.contains(nodeId)) {
      const String title = 'Layout Cycle Detected';
      const String message =
          'The widget is part of a circular dependency. This usually happens '
          'when a widget is set as its own ancestor (e.g., a `Column`\'s '
          '`children` property refers to the `Column` itself, or one of its '
          'parents).\n\n'
          'To fix this, review the `children` properties of the widgets in the '
          'layout and ensure that a widget\'s ID does not appear in the '
          '`children` list of itself or any of its descendants.';
      onError?.call(
        RenderError(
          errorType: title,
          message: message,
          sourceNodeId: nodeId,
          fullLayout: interpreter.currentLayout!,
          currentState: interpreter.currentState,
        ),
      );
      return const _ErrorWidget(title, message);
    }
    final Set<String> currentPath = <String>{...visited, nodeId};

    final LayoutNode node = interpreter.currentLayout!.nodes.firstWhere(
      (LayoutNode n) => n.id == nodeId,
    );

    if (node.type == 'ListViewBuilder') {
      return _buildListView(context, node, currentPath);
    }

    final CatalogWidgetBuilder? builder = registry.getBuilder(node.type);
    if (builder == null) {
      final String availableTypes = registry.getRegisteredWidgetTypes().join(
        ', ',
      );
      const String title = 'Unknown Widget Type';
      final String message =
          'The layout specified a widget of type "${node.type}", but no '
          'corresponding widget builder was found in the client\'s catalog.\n\n'
          'Please use one of the following registered widget types: '
          '$availableTypes. Check for typos in the \'type\' property.';
      onError?.call(
        RenderError(
          errorType: title,
          message: message,
          sourceNodeId: node.id,
          fullLayout: interpreter.currentLayout!,
          currentState: interpreter.currentState,
        ),
      );
      return _ErrorWidget(title, message);
    }

    final Map<String, Object?> resolvedProperties = _resolveProperties(
      node,
      null,
    );

    final Map<String, List<Widget>> builtChildren = <String, List<Widget>>{};
    for (final MapEntry<String, Object?> entry in resolvedProperties.entries) {
      final String key = entry.key;
      final Object? value = entry.value;

      if (value is String &&
          interpreter.currentLayout!.nodes.any(
            (LayoutNode n) => n.id == value,
          )) {
        builtChildren[key] = <Widget>[_buildNode(context, value, currentPath)];
      } else if (value is List) {
        final List<Widget> childWidgets = <Widget>[];
        for (final Object? item in value) {
          if (item is String &&
              interpreter.currentLayout!.nodes.any(
                (LayoutNode n) => n.id == item,
              )) {
            childWidgets.add(_buildNode(context, item, currentPath));
          }
        }
        if (childWidgets.isNotEmpty) {
          builtChildren[key] = childWidgets;
        }
      }
    }

    return builder(context, node, resolvedProperties, builtChildren);
  }

  Widget _buildListView(
    BuildContext context,
    LayoutNode node,
    Set<String> visited,
  ) {
    final ValueChanged<RenderError>? onError = FcpProvider.of(context)?.onError;
    final Map<String, Object?> resolvedProperties = _resolveProperties(
      node,
      null,
    );
    final List<dynamic> data =
        resolvedProperties['data'] as List<dynamic>? ?? <dynamic>[];
    final LayoutNode? itemTemplate = node.itemTemplate;

    if (itemTemplate == null) {
      const String title = 'Missing `itemTemplate`';
      final String message =
          'The `ListViewBuilder` with ID "${node.id}" must have an '
          '`itemTemplate` property.\n\n'
          'To fix this, add an `itemTemplate` property to the '
          '`ListViewBuilder` node. The value should be a complete LayoutNode '
          'object that defines the template for each item in the list.';
      onError?.call(
        RenderError(
          errorType: title,
          message: message,
          sourceNodeId: node.id,
          fullLayout: interpreter.currentLayout!,
          currentState: interpreter.currentState,
        ),
      );
      return _ErrorWidget(title, message);
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: data.length,
      itemBuilder: (BuildContext context, int index) {
        final Map<String, Object?> itemData =
            data[index] as Map<String, Object?>;
        return _buildListItem(context, itemTemplate, itemData, visited);
      },
    );
  }

  Widget _buildListItem(
    BuildContext context,
    LayoutNode templateNode,
    Map<String, Object?> itemData,
    Set<String> visited,
  ) {
    final ValueChanged<RenderError>? onError = FcpProvider.of(context)?.onError;
    final CatalogWidgetBuilder? builder = registry.getBuilder(
      templateNode.type,
    );
    if (builder == null) {
      final String availableTypes = registry.getRegisteredWidgetTypes().join(
        ', ',
      );
      const String title = 'Unknown Widget Type in `itemTemplate`';
      final String message =
          'The `itemTemplate` for the `ListViewBuilder` specified a widget of '
          'type "${templateNode.type}", but no corresponding widget builder '
          'was found in the client\'s catalog.\n\n'
          'Please use one of the following registered widget types for the '
          'item template: $availableTypes. Check for typos in the \'type\' '
          'property of the itemTemplate.';
      onError?.call(
        RenderError(
          errorType: title,
          message: message,
          sourceNodeId: templateNode.id,
          fullLayout: interpreter.currentLayout!,
          currentState: interpreter.currentState,
        ),
      );
      return _ErrorWidget(title, message);
    }

    final Map<String, Object?> resolvedProperties = _resolveProperties(
      templateNode,
      itemData,
    );

    final Map<String, List<Widget>> builtChildren = <String, List<Widget>>{};
    for (final MapEntry<String, Object?> entry in resolvedProperties.entries) {
      final String key = entry.key;
      final Object? value = entry.value;

      if (value is String &&
          interpreter.currentLayout!.nodes.any(
            (LayoutNode n) => n.id == value,
          )) {
        builtChildren[key] = <Widget>[_buildNode(context, value, visited)];
      } else if (value is List) {
        final List<Widget> childWidgets = <Widget>[];
        for (final Object? item in value) {
          if (item is String &&
              interpreter.currentLayout!.nodes.any(
                (LayoutNode n) => n.id == item,
              )) {
            childWidgets.add(_buildNode(context, item, visited));
          }
        }
        if (childWidgets.isNotEmpty) {
          builtChildren[key] = childWidgets;
        }
      }
    }

    return builder(context, templateNode, resolvedProperties, builtChildren);
  }

  Map<String, Object?> _resolveProperties(
    LayoutNode node,
    Map<String, Object?>? scopedData,
  ) {
    final Map<String, Object?> resolvedProperties = Map<String, Object?>.from(
      node.properties ?? <String, Object?>{},
    );

    final RegExp interpolationRegex = RegExp(r'\$\{([^}]+)\}');

    resolvedProperties.updateAll((String key, Object? value) {
      if (value is String) {
        return value.replaceAllMapped(interpolationRegex, (Match match) {
          final String path = match.group(1)!;
          Object? resolvedValue;
          if (path.startsWith('item.') && scopedData != null) {
            resolvedValue = _getValueFromMap(path.substring(5), scopedData);
          } else {
            resolvedValue = _getValueFromMap(path, interpreter.currentState);
          }
          return resolvedValue?.toString() ?? '';
        });
      }
      if (value is Map<String, Object?> && value.containsKey(r'$bind')) {
        final Binding binding = Binding.fromMap(value);
        Object? resolvedValue;
        if (binding.path.startsWith('item.') && scopedData != null) {
          resolvedValue = _getValueFromMap(
            binding.path.substring(5),
            scopedData,
          );
        } else {
          resolvedValue = _getValueFromMap(
            binding.path,
            interpreter.currentState,
          );
        }
        if (resolvedValue != null) {
          return _applyTransformation(resolvedValue, binding);
        }
        return null;
      }
      return value;
    });

    return resolvedProperties;
  }

  Object? _getValueFromMap(String path, Map<String, Object?>? map) {
    if (map == null) return null;
    final List<String> parts = path.split('.');
    Object? currentValue = map;
    for (final String part in parts) {
      if (currentValue is Map<String, Object?>) {
        currentValue = currentValue[part];
      } else {
        return null;
      }
    }
    return currentValue;
  }

  Object? _applyTransformation(Object? value, Binding binding) {
    if (binding.format != null) {
      return binding.format!.replaceAll('{}', value?.toString() ?? '');
    }

    if (binding.condition != null) {
      final Condition condition = binding.condition!;
      if (value == true) {
        return condition.ifValue;
      } else {
        return condition.elseValue;
      }
    }

    if (binding.map != null) {
      final MapTransformer map = binding.map!;
      final String? key = value?.toString();
      return map.mapping[key] ?? map.fallback;
    }

    return value;
  }
}

class _ErrorWidget extends StatelessWidget {
  const _ErrorWidget(this.title, this.message);
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final String fullMessage = '$title: $message';
    log('Error: $fullMessage');
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'GenUI Error: $title',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: Colors.red.shade900),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(color: Colors.red.shade900),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
