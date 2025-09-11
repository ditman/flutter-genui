// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'models.dart';

/// A structured error object that provides detailed context about a layout
/// rendering failure.
class RenderError {
  /// Creates a new [RenderError].
  RenderError({
    required this.errorType,
    required this.message,
    required this.sourceNodeId,
    required this.fullLayout,
    required this.currentState,
  });

  /// The type of error that occurred (e.g., 'UnknownWidgetType').
  final String errorType;

  /// A detailed, human-readable message describing the error and providing
  /// suggestions for how to fix it.
  final String message;

  /// The ID of the layout node that caused the error.
  final String sourceNodeId;

  /// The complete layout that was being processed when the error occurred.
  final Layout fullLayout;

  /// The state of the UI at the time of the error.
  final Map<String, Object?> currentState;
}
