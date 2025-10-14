// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:delayed_display/delayed_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For clipboard
import 'package:flutter/widgets.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';

import '../../styles/llm_chat_view_style.dart';
import '../../utility.dart';

/// A widget that displays hovering buttons for editing, copying, and feedback.
///
/// This widget is a [StatefulWidget] that shows buttons for editing, copying,
/// liking, and disliking when the user hovers over the child widget. The buttons
/// are displayed at the bottom right of the child widget. Feedback buttons are
/// only shown for LLM messages (!isUserMessage).
class HoveringButtons extends StatefulWidget {
  /// Creates a [HoveringButtons] widget.
  ///
  /// The [onEdit] callback is invoked when the edit button is pressed. The
  /// [child] widget is the content over which the buttons will hover.
  HoveringButtons({
    required this.chatStyle,
    required this.isUserMessage,
    required this.child,
    this.clipboardText,
    this.onEdit,
    this.onFeedback, // Added for feedback callback
    this.messageId, // Added for message ID in feedback
    this.messageText,
    super.key,
  });

  /// The style information for the chat.
  final LlmChatViewStyle chatStyle;

  /// Whether the message is a user message.
  final bool isUserMessage;

  /// The text to be copied to the clipboard.
  final String? clipboardText;

  /// The child widget over which the buttons will hover.
  final Widget child;

  /// The callback to be invoked when the edit button is pressed.
  final VoidCallback? onEdit;

  /// The callback invoked when user provides feedback on the message.
  /// Only used for !isUserMessage.
  final Future<void> Function(String? messageText, int messageId, bool like, String? comment)? onFeedback;

  /// The ID of the message for feedback.
  final int? messageId;

  final String? messageText;


  final _hovering = ValueNotifier(true);

  @override
  State<HoveringButtons> createState() => _HoveringButtonsState();
}

class _HoveringButtonsState extends State<HoveringButtons> {
  bool hasLiked = false; // Track if liked
  bool hasDisliked = false; // Track if disliked
  bool showCommentInput = false; // Track if comment input is shown
  late final TextEditingController _commentController; // Controller for comment input

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  static const _iconSize = 16;

  @override
  Widget build(BuildContext context) {
    final inputStyle = ChatInputStyle.resolve(widget.chatStyle.chatInputStyle);
    final hoverButtonPadding = widget.isUserMessage ? _iconSize + 20.0 : _iconSize + 40.0;
    final extraPaddingForComment = showCommentInput ? 60.0 : 0.0; // Extra padding for wide comment input
    final totalBottomPadding = hoverButtonPadding + extraPaddingForComment;

    final paddedChild = Padding(
      padding: EdgeInsets.only(bottom: totalBottomPadding),
      child: widget.child,
    );

    return widget.clipboardText == null
        ? paddedChild
        : Stack(
      children: [
        paddedChild,
        // Hovering buttons row (always includes feedback if applicable)
        ListenableBuilder(
          listenable: widget._hovering,
          builder: (context, child) => widget._hovering.value
              ? Positioned(
            bottom: 0,
            right: widget.isUserMessage ? 0 : null,
            left: widget.isUserMessage ? null : 32,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main buttons row (edit, copy, feedback)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 8,
                  children: [
                    // if (widget.onEdit != null)
                    //   GestureDetector(
                    //     onTap: widget.onEdit,
                    //     child: Icon(
                    //       widget.chatStyle.editButtonStyle!.icon,
                    //       size: _iconSize.toDouble(),
                    //       color: invertColor(
                    //         widget.chatStyle.editButtonStyle!.iconColor,
                    //       ),
                    //     ),
                    //   ),
                    if (widget.clipboardText != null)
                      GestureDetector(
                        onTap: () => unawaited(
                          copyToClipboard(
                            context,
                            widget.clipboardText!,
                          ),
                        ),
                        child: Icon(
                          widget.chatStyle.copyButtonStyle!.icon,
                          size: 22,
                          color: invertColor(
                            widget.chatStyle.copyButtonStyle!.iconColor,
                          ),
                        ),
                      ),
                    if (!widget.isUserMessage && widget.onFeedback != null && widget.messageId != null)
                      _buildFeedbackButtons(),
                  ],
                ),
                // Wide comment input (only if shown)
                if (showCommentInput)
                  DelayedDisplay(
                    slidingBeginOffset: Offset.zero,
                    fadingDuration: const Duration(milliseconds: 350),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width - 64, // Almost full screen width, minus margins
                        child: DecoratedBox(
                          decoration: inputStyle.decoration!,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _commentController,
                                    decoration: InputDecoration(
                                      hintText: 'Help us improve...',
                                      hintStyle: inputStyle.hintStyle,
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                    style: inputStyle.textStyle,
                                    maxLines: 1,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.send, size: 20),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () async {
                                    final commentText = _commentController.text.trim();
                                    await widget.onFeedback!(
                                      widget.messageText,
                                      widget.messageId!,
                                      false,
                                      commentText.isEmpty ? null : commentText,
                                    );
                                    if (mounted) {
                                      setState(() {
                                        hasDisliked = true;
                                        showCommentInput = false;
                                        _commentController.clear();
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          )
              : const SizedBox(),
        ),
      ],
    );
  }

  /// Builds the feedback buttons (like/dislike) in the same row as copy.
  Widget _buildFeedbackButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Like button (gray initially, black if selected)
        GestureDetector(
          onTap: () async {
            if (mounted) {
              setState(() {
                showCommentInput = false;
                hasLiked = true;
                hasDisliked = false; // Toggle off dislike if liked
              });
            }
            await widget.onFeedback!(widget.messageText, widget.messageId!, true, null);
          },
          child: Container(
            padding: const EdgeInsets.all(4),
            child: Icon(
              Icons.thumb_up,
              size: _iconSize.toDouble(),
              color: hasLiked ? Colors.black : Colors.grey[600],
            ),
          ),
        ),
        const SizedBox(width: 8), // Space between like and dislike
        // Dislike button (gray initially, black if selected)
        GestureDetector(
          onTap: () async {
            if (mounted) {
              setState(() {
                showCommentInput = true;
                hasLiked = false;
                hasDisliked = true;
              });
            }
            await widget.onFeedback!(widget.messageText, widget.messageId!, false, null);
          },
          child: Container(
            padding: const EdgeInsets.all(4),
            child: Icon(
              Icons.thumb_down,
              size: _iconSize.toDouble(),
              color: hasDisliked ? Colors.black : Colors.grey[600],
            ),
          ),
        ),
      ],
    );
  }
}