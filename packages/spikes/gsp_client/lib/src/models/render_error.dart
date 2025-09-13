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
    this.fullLayout,
    required this.currentState,
  });

  /// Creates a new [RenderError] from a map.
  RenderError.fromMap(Map<String, Object?> json)
    : errorType = json['errorType'] as String,
      message = json['message'] as String,
      sourceNodeId = json['sourceNodeId'] as String,
      fullLayout = json['fullLayout'] != null
          ? Layout.fromMap(json['fullLayout'] as Map<String, Object?>)
          : null,
      currentState = json['currentState'] as Map<String, Object?>;

  /// The type of error that occurred (e.g., 'UnknownWidgetType').
  final String errorType;

  /// A detailed, human-readable message describing the error and providing
  /// suggestions for how to fix it.
  final String message;

  /// The ID of the layout node that caused the error.
  final String sourceNodeId;

  /// The complete layout that was being processed when the error occurred.
  final Layout? fullLayout;

  /// The state of the UI at the time of the error.
  final Map<String, Object?> currentState;

  /// Converts this object to a JSON-encodable map.
  Map<String, Object?> toJson() => <String, Object?>{
    'errorType': errorType,
    'message': message,
    'sourceNodeId': sourceNodeId,
    if (fullLayout != null) 'fullLayout': fullLayout!.toJson(),
    'currentState': currentState,
  };
}
