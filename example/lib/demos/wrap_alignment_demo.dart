// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../shared/dropdown_menu.dart';
import '../shared/markdown_demo_widget.dart';
import '../shared/markdown_extensions.dart';

// ignore_for_file: public_member_api_docs

const String _notes = '''
# Wrap Alignment Demo
---
The Wrap Alignment Demo shows the effect of defining a wrap alignment for
various Markdown elements. Wrap alignments for the block elements text
paragraphs, headers, ordered and unordered lists, blockquotes, and code blocks
are set in the **MarkdownStyleSheet**. This demo shows the effect of setting
this parameter universally on these block elements for illustration purposes,
but they are independent settings.

This demo also shows the effect of setting the **MarkdownStyleSheet** block
spacing parameter. The Markdown widget lays out block elements in a column using
**SizedBox** widgets to separate widgets with formatted output. The block
spacing parameter sets the height of the **SizedBox**.
''';

class WrapAlignmentDemo extends StatefulWidget implements MarkdownDemoWidget {
  const WrapAlignmentDemo({Key? key}) : super(key: key);

  static const String _title = 'Wrap Alignment Demo';

  @override
  String get title => WrapAlignmentDemo._title;

  @override
  String get description => 'Shows the effect the wrap alignment and block '
      'spacing parameters have on various Markdown tagged elements.';

  @override
  Future<String> get data =>
      rootBundle.loadString('assets/markdown_test_page.md');

  @override
  Future<String> get notes => Future<String>.value(_notes);

  @override
  _WrapAlignmentDemoState createState() => _WrapAlignmentDemoState();
}

class _WrapAlignmentDemoState extends State<WrapAlignmentDemo> {
  double _blockSpacing = 8.0;

  WrapAlignment _wrapAlignment = WrapAlignment.start;

  final Map<String, WrapAlignment> _wrapAlignmentMenuItems =
      Map<String, WrapAlignment>.fromIterables(
    WrapAlignment.values.map((WrapAlignment e) => e.displayTitle),
    WrapAlignment.values,
  );

  static const List<double> _spacing = <double>[4.0, 8.0, 16.0, 24.0, 32.0];
  final Map<String, double> _blockSpacingMenuItems =
      Map<String, double>.fromIterables(
    _spacing.map((double e) => e.toString()),
    _spacing,
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: widget.data,
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return Column(
            children: <Widget>[
              DropdownMenu<WrapAlignment>(
                items: _wrapAlignmentMenuItems,
                label: 'Wrap Alignment:',
                initialValue: _wrapAlignment,
                onChanged: (WrapAlignment? value) {
                  if (value != _wrapAlignment) {
                    setState(() {
                      _wrapAlignment = value!;
                    });
                  }
                },
              ),
              DropdownMenu<double>(
                items: _blockSpacingMenuItems,
                label: 'Block Spacing:',
                initialValue: _blockSpacing,
                onChanged: (double? value) {
                  if (value != _blockSpacing) {
                    setState(() {
                      _blockSpacing = value!;
                    });
                  }
                },
              ),
              Expanded(
                child: Markdown(
                  key: Key(_wrapAlignment.toString()),
                  data: snapshot.data!,
                  imageDirectory: 'https://raw.githubusercontent.com',
                  styleSheet:
                      MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                    blockSpacing: _blockSpacing,
                    textAlign: _wrapAlignment,
                    h1Align: _wrapAlignment,
                    h2Align: _wrapAlignment,
                    h3Align: _wrapAlignment,
                    h4Align: _wrapAlignment,
                    h5Align: _wrapAlignment,
                    h6Align: _wrapAlignment,
                    unorderedListAlign: _wrapAlignment,
                    orderedListAlign: _wrapAlignment,
                    blockquoteAlign: _wrapAlignment,
                    codeblockAlign: _wrapAlignment,
                  ),
                ),
              ),
            ],
          );
        } else {
          return const CircularProgressIndicator();
        }
      },
    );
  }
}
