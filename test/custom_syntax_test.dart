// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'utils.dart';

void main() => defineTests();

void defineTests() {
  group('Custom Syntax', () {
    testWidgets(
      'Subscript',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          boilerplate(
            Markdown(
              data: 'H_2O',
              extensionSet: md.ExtensionSet.none,
              inlineSyntaxes: <md.InlineSyntax>[SubscriptSyntax()],
              builders: <String, MarkdownElementBuilder>{
                'sub': SubscriptBuilder(),
              },
            ),
          ),
        );

        final Iterable<Widget> widgets = tester.allWidgets;
        expectTextStrings(widgets, <String>['H₂O']);
      },
    );

    testWidgets(
      'link for wikistyle',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          boilerplate(
            Markdown(
              data: 'This is a [[wiki link]]',
              extensionSet: md.ExtensionSet.none,
              inlineSyntaxes: <md.InlineSyntax>[WikilinkSyntax()],
              builders: <String, MarkdownElementBuilder>{
                'wikilink': WikilinkBuilder(),
              },
            ),
          ),
        );

        final RichText textWidget = tester.widget(find.byType(RichText));
        final TextSpan span =
            (textWidget.text as TextSpan).children![1] as TextSpan;

        expect(span.children, null);
        expect(span.recognizer.runtimeType, equals(TapGestureRecognizer));
      },
    );
  });
}

class SubscriptSyntax extends md.InlineSyntax {
  SubscriptSyntax() : super(_pattern);

  static const String _pattern = r'_([0-9]+)';

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('sub', match[1]!));
    return true;
  }
}

class SubscriptBuilder extends MarkdownElementBuilder {
  static const List<String> _subscripts = <String>[
    '₀',
    '₁',
    '₂',
    '₃',
    '₄',
    '₅',
    '₆',
    '₇',
    '₈',
    '₉'
  ];

  @override
  Widget visitElementAfter(md.Element element, _) {
    // We don't currently have a way to control the vertical alignment of text spans.
    // See https://github.com/flutter/flutter/issues/10906#issuecomment-385723664
    final String textContent = element.textContent;
    String text = '';
    for (int i = 0; i < textContent.length; i++) {
      text += _subscripts[int.parse(textContent[i])];
    }
    return RichText(text: TextSpan(text: text));
  }
}

class WikilinkSyntax extends md.InlineSyntax {
  WikilinkSyntax() : super(_pattern);

  static const String _pattern = r'\[\[(.*?)\]\]';

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final md.Element el = md.Element.withTag('wikilink');
    el.attributes['href'] = match[1]!.replaceAll(' ', '_');
    el.children!.add(md.Element.text('span', match[1]!));

    parser.addNode(el);
    return true;
  }
}

class WikilinkBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfter(md.Element element, _) {
    return RichText(
      text: TextSpan(
          text: element.textContent,
          recognizer: TapGestureRecognizer()..onTap = () {}),
    );
  }
}
