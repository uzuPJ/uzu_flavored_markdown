// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html'; // ignore: avoid_web_libraries_in_flutter
import 'dart:io' as io;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart' show CupertinoTheme;
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

import 'style_sheet.dart';
import 'widget.dart';

/// Type for a function that creates image widgets.
typedef ImageBuilder = ImageProvider Function(Uri uri, String? imageDirectory);

/// A default image builder handling http/https, resource, data, and file URLs.
// ignore: prefer_function_declarations_over_variables
final ImageBuilder kDefaultImageBuilder = (
  Uri uri,
  String? imageDirectory,
) {
  if (uri.scheme == 'http' || uri.scheme == 'https') {
    return CachedNetworkImageProvider(uri.toString());
  } else if (uri.scheme == 'data') {
    return _handleDataSchemeUri(uri);
  } else if (uri.scheme == 'resource') {
    return AssetImage(uri.path);
  } else {
    final Uri fileUri = imageDirectory != null
        ? Uri.parse(imageDirectory + uri.toString())
        : uri;
    if (fileUri.scheme == 'http' || fileUri.scheme == 'https') {
      return CachedNetworkImageProvider(fileUri.toString());
    } else {
      return FileImage(io.File.fromUri(fileUri));
    }
  }
};

/// A default style sheet generator.
final MarkdownStyleSheet Function(BuildContext, MarkdownStyleSheetBaseTheme?)
// ignore: prefer_function_declarations_over_variables
    kFallbackStyle = (
  BuildContext context,
  MarkdownStyleSheetBaseTheme? baseTheme,
) {
  MarkdownStyleSheet result;
  switch (baseTheme) {
    case MarkdownStyleSheetBaseTheme.platform:
      final String userAgent = window.navigator.userAgent;
      result = userAgent.contains('Mac OS X')
          ? MarkdownStyleSheet.fromCupertinoTheme(CupertinoTheme.of(context))
          : MarkdownStyleSheet.fromTheme(Theme.of(context));
      break;
    case MarkdownStyleSheetBaseTheme.cupertino:
      result =
          MarkdownStyleSheet.fromCupertinoTheme(CupertinoTheme.of(context));
      break;
    case MarkdownStyleSheetBaseTheme.material:
    default:
      result = MarkdownStyleSheet.fromTheme(Theme.of(context));
  }

  return result.copyWith(
    textScaleFactor: MediaQuery.textScaleFactorOf(context),
  );
};

ImageProvider _handleDataSchemeUri(Uri uri) {
  final String mimeType = uri.data!.mimeType;
  if (mimeType.startsWith('image/')) {
    return MemoryImage(
      uri.data!.contentAsBytes(),
    );
  }
  return AssetImage('lib/assets/blank.png');
}
