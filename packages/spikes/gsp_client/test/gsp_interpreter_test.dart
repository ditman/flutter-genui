// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gsp_client/src/core/gsp_interpreter.dart';
import 'package:gsp_client/src/models/models.dart';
import 'package:gsp_client/src/models/render_error.dart';

void main() {
  group('GspInterpreter', () {
    late WidgetCatalog catalog;

    setUp(() {
      catalog = WidgetCatalog(
        dataTypes: <String, Object?>{},
        items: <String, WidgetDefinition?>{},
      );
    });

    test('handles valid JSONL messages', () async {
      final StreamController<String> controller = StreamController<String>();
      final GspInterpreter interpreter = GspInterpreter(
        stream: controller.stream,
        catalog: catalog,
      );

      const String headerMessage =
          '{"messageType":"StreamHeader","formatVersion":"1.0.0",'
          '"initialState":{"foo":"bar"}}';
      controller.add(headerMessage);

      // Allow the stream to be processed.
      await Future<void>.delayed(Duration.zero);

      expect(interpreter.currentState, <String, String>{'foo': 'bar'});
      expect(interpreter.error, isNull);

      await controller.close();
    });

    test('reports error on invalid JSON', () async {
      final StreamController<String> controller = StreamController<String>();
      final GspInterpreter interpreter = GspInterpreter(
        stream: controller.stream,
        catalog: catalog,
      );

      final Completer<void> completer = Completer<void>();
      interpreter.addListener(() {
        if (interpreter.error != null) {
          completer.complete();
        }
      });

      const String invalidJson =
          '{"messageType":"StreamHeader",}'; // Invalid JSON
      controller.add(invalidJson);

      await completer.future;

      expect(interpreter.error, isA<RenderError>());
      expect(interpreter.error!.errorType, 'JsonParsingError');
      expect(interpreter.error!.message, contains('FormatException'));
      expect(interpreter.error!.sourceNodeId, '@stream');
      expect(interpreter.error!.fullLayout, isNull);
      expect(interpreter.error!.currentState, isEmpty);

      // Should not process further messages
      const String validMessage =
          '{"messageType":"StreamHeader","formatVersion":"1.0.0",'
          '"initialState":{"foo":"bar"}}';
      controller.add(validMessage);
      // The state should not change
      expect(interpreter.currentState, isEmpty);

      await controller.close();
    });
  });
}
