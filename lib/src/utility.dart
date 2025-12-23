// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/cupertino.dart' show BuildContext, CupertinoApp;
import 'package:flutter/services.dart';
import 'package:universal_platform/universal_platform.dart';

import 'dialogs/adaptive_snack_bar/adaptive_snack_bar.dart';

bool? _isCupertinoApp;

/// Determines if the current application is a Cupertino-style app.
///
/// This function checks the widget tree for the presence of a [CupertinoApp]
/// widget. If found, it indicates that the app is using Cupertino (iOS-style)
/// widgets.
///
/// Parameters:
///   * [context]: The [BuildContext] used to search the widget tree.
///
/// Returns: A [bool] value. `true` if a [CupertinoApp] is found in the widget
///   tree, `false` otherwise.
bool isCupertinoApp(BuildContext context) {
  // caching the result to avoid recomputing it on every call; it's not likely
  // to change during the lifetime of the app
  _isCupertinoApp ??=
      context.findAncestorWidgetOfExactType<CupertinoApp>() != null;
  return _isCupertinoApp!;
}

/// Determines if the current platform is a mobile device (Android or iOS).
///
/// This constant uses the [UniversalPlatform] package to check the platform.
///
/// Returns:
///   A [bool] value. `true` if the platform is either Android or iOS,
///   `false` otherwise.
final isMobile = UniversalPlatform.isAndroid || UniversalPlatform.isIOS;

/// Removes Markdown formatting from text.
///
/// This function strips common Markdown syntax including:
/// * Headers (#, ##, ###, etc.)
/// * Bold (**text** or __text__)
/// * Italic (*text* or _text_)
/// * Strikethrough (~~text~~)
/// * Code blocks (```code```)
/// * Inline code (`code`)
/// * Links ([text](url))
/// * Images (![alt](url))
/// * Blockquotes (>)
/// * Horizontal rules (---, ___, ***)
/// * Lists (-, *, +, 1.)
/// * Tables (converts to plain text format)
///
/// Parameters:
///   * [text]: The Markdown-formatted text to clean.
///
/// Returns: The text with all Markdown formatting removed.
String stripMarkdown(String text) {
  String cleaned = text;

  // Convert tables to plain text format
  cleaned = _convertTablesToPlainText(cleaned);

  // Remove code blocks (```)
  cleaned = cleaned.replaceAll(RegExp(r'```[\s\S]*?```'), '');

  // Remove inline code (`)
  cleaned = cleaned.replaceAllMapped(RegExp(r'`([^`]+)`'), (match) => match.group(1)!);

  // Remove images ![alt](url)
  cleaned = cleaned.replaceAllMapped(RegExp(r'!\[([^\]]*)\]\([^\)]+\)'), (match) => match.group(1)!);

  // Remove links [text](url)
  cleaned = cleaned.replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), (match) => match.group(1)!);

  // Remove bold (**text** or __text__)
  cleaned = cleaned.replaceAllMapped(RegExp(r'\*\*([^\*]+?)\*\*'), (match) => match.group(1)!);
  cleaned = cleaned.replaceAllMapped(RegExp(r'__([^_]+?)__'), (match) => match.group(1)!);

  // Remove italic (*text* or _text_)
  cleaned = cleaned.replaceAllMapped(RegExp(r'(?<!\*)\*(?!\*)([^\*]+?)(?<!\*)\*(?!\*)'), (match) => match.group(1)!);
  cleaned = cleaned.replaceAllMapped(RegExp(r'(?<!_)_(?!_)([^_]+?)(?<!_)_(?!_)'), (match) => match.group(1)!);

  // Remove strikethrough (~~text~~)
  cleaned = cleaned.replaceAllMapped(RegExp(r'~~([^~]+?)~~'), (match) => match.group(1)!);

  // Remove headers (# ## ### etc.)
  cleaned = cleaned.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');

  // Remove blockquotes (>)
  cleaned = cleaned.replaceAll(RegExp(r'^>\s+', multiLine: true), '');

  // Remove horizontal rules (---, ___, ***)
  cleaned = cleaned.replaceAll(RegExp(r'^[\-_\*]{3,}$', multiLine: true), '');

  // Remove unordered list markers (-, *, +)
  cleaned = cleaned.replaceAll(RegExp(r'^[\-\*\+]\s+', multiLine: true), '');

  // Remove ordered list markers (1., 2., etc.)
  cleaned = cleaned.replaceAll(RegExp(r'^\d+\.\s+', multiLine: true), '');

  return cleaned.trim();
}

/// Converts Markdown tables to a plain text format.
String _convertTablesToPlainText(String text) {
  final lines = text.split('\n');
  final buffer = StringBuffer();
  bool inTable = false;
  List<String>? headers;

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i].trim();

    // Detect table header row (contains |)
    if (line.startsWith('|') && line.endsWith('|')) {
      if (!inTable) {
        // First row is the header
        inTable = true;
        headers = line
            .split('|')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        continue;
      } else if (i > 0 && lines[i - 1].contains('|') && line.contains('---')) {
        // This is the separator line (|---|---|), skip it
        continue;
      } else {
        // This is a data row
        final cells = line
            .split('|')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

        if (headers != null && cells.length == headers.length) {
          for (int j = 0; j < cells.length; j++) {
            buffer.write('${headers[j]}: ${cells[j]}');
            if (j < cells.length - 1) buffer.write(', ');
          }
          buffer.writeln();
        }
        continue;
      }
    } else {
      // Not a table row
      if (inTable) {
        inTable = false;
        headers = null;
        buffer.writeln(); // Add blank line after table
      }
      buffer.writeln(line);
    }
  }

  return buffer.toString();
}

/// Copies the given text to the clipboard and shows a confirmation message.
///
/// This function removes Markdown formatting from the text before copying it
/// to the clipboard using the [Clipboard] API. After copying, it displays a
/// confirmation message using [AdaptiveSnackBar] if the [context] is still mounted.
///
/// Parameters:
///   * [context]: The [BuildContext] used to show the confirmation message.
///   * [text]: The text to be copied to the clipboard (may contain Markdown).
///
/// Returns: A [Future] that completes when the text has been copied to the
///   clipboard and the confirmation message has been shown.
Future<void> copyToClipboard(BuildContext context, String text) async {
  final cleanedText = stripMarkdown(text);
  await Clipboard.setData(ClipboardData(text: cleanedText));
  if (context.mounted) {
    AdaptiveSnackBar.show(context, 'Message copied to clipboard');
  }
}

/// Inverts the given color.
///
/// This function takes a [Color] object and returns a new [Color] object
/// with the RGB values inverted. The alpha value remains unchanged.
///
/// Parameters:
///   * [color]: The [Color] to be inverted. This parameter must not be null.
///
/// Returns: A new [Color] object with the inverted RGB values.
Color? invertColor(Color? color) =>
    color != null
        ? Color.from(
      alpha: color.a,
      red: 1 - color.r,
      green: 1 - color.g,
      blue: 1 - color.b,
    )
        : null;
