// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import '../../styles/llm_chat_view_style.dart';
import '../action_button.dart';
import '../adaptive_progress_indicator.dart';
import 'input_state.dart';

/// A button widget that adapts its appearance and behavior based on the current
/// input state.
@immutable
class InputButton extends StatelessWidget {
  /// Creates an [InputButton].
  ///
  /// All parameters are required:
  /// - [inputState]: The current state of the input.
  /// - [chatStyle]: The style configuration for the chat interface.
  /// - [onSubmitPrompt]: Callback function when submitting a prompt.
  /// - [onCancelPrompt]: Callback function when cancelling a prompt.
  /// - [onStartRecording]: Callback function when starting audio recording.
  /// - [onStopRecording]: Callback function when stopping audio recording.
  const InputButton({
    required this.inputState,
    required this.chatStyle,
    required this.onSubmitPrompt,
    required this.onCancelPrompt,
    required this.onStartRecording,
    required this.onStopRecording,
    super.key,
  });

  /// The current state of the input.
  final InputState? inputState;

  /// The style configuration for the chat interface.
  final LlmChatViewStyle chatStyle;

  /// Callback function when submitting a prompt.
  final void Function() onSubmitPrompt;

  /// Callback function when cancelling a prompt.
  final void Function() onCancelPrompt;

  /// Callback function when starting audio recording.
  final void Function() onStartRecording;

  /// Callback function when stopping audio recording.
  final void Function() onStopRecording;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        if (inputState == null) {
          return ActionButton(style: chatStyle.disabledButtonStyle!, onPressed: () {});
        } else {
          switch (inputState!) {
            case InputState.canSubmitPrompt:
              return ActionButton(style: chatStyle.submitButtonStyle!, onPressed: onSubmitPrompt);

            case InputState.canCancelPrompt:
              return ActionButton(style: chatStyle.stopButtonStyle!, onPressed: onCancelPrompt);
            case InputState.canStt:
              return ActionButton(style: chatStyle.recordButtonStyle!, onPressed: onStartRecording);
            case InputState.isRecording:
              return ActionButton(style: chatStyle.stopButtonStyle!, onPressed: onStopRecording);
            case InputState.canCancelStt:
              return AdaptiveCircularProgressIndicator(color: chatStyle.progressIndicatorColor!);
            case InputState.disabled:
              return ActionButton(style: chatStyle.disabledButtonStyle!, onPressed: () {});
          }
        }
      },
    );
  }
}
