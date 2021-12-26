// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:photo_view/photo_view.dart';

import '_functions_io.dart' if (dart.library.html) '_functions_web.dart';
import 'style_sheet.dart';
import 'widget.dart';

const List<String> _kBlockTags = <String>[
  'p',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'li',
  'blockquote',
  'pre',
  'ol',
  'ul',
  'hr',
  'table',
  'thead',
  'tbody',
  'tr'
];

const List<String> _kListTags = <String>['ul', 'ol'];

bool _isBlockTag(String? tag) => _kBlockTags.contains(tag);

bool _isListTag(String tag) => _kListTags.contains(tag);

class _BlockElement {
  _BlockElement(this.tag);

  final String? tag;
  final List<Widget> children = <Widget>[];

  int nextListIndex = 0;
}

class _TableElement {
  final List<TableRow> rows = <TableRow>[];
}

/// A collection of widgets that should be placed adjacent to (inline with)
/// other inline elements in the same parent block.
///
/// Inline elements can be textual (a/em/strong) represented by [RichText]
/// widgets or images (img) represented by [Image.network] widgets.
///
/// Inline elements can be nested within other inline elements, inheriting their
/// parent's style along with the style of the block they are in.
///
/// When laying out inline widgets, first, any adjacent RichText widgets are
/// merged, then, all inline widgets are enclosed in a parent [Wrap] widget.
class _InlineElement {
  _InlineElement(this.tag, {this.style});

  final String? tag;

  /// Created by merging the style defined for this element's [tag] in the
  /// delegate's [MarkdownStyleSheet] with the style of its parent.
  final TextStyle? style;

  final List<Widget> children = <Widget>[];
}

/// A delegate used by [MarkdownBuilder] to control the widgets it creates.
abstract class MarkdownBuilderDelegate {
  /// Returns a gesture recognizer to use for an `a` element with the given
  /// text, `href` attribute, and title.
  GestureRecognizer createLink(String text, String? href, String title);

  /// Returns formatted text to use to display the given contents of a `pre`
  /// element.
  ///
  /// The `styleSheet` is the value of [MarkdownBuilder.styleSheet].
  TextSpan formatText(MarkdownStyleSheet styleSheet, String code);
}

/// Builds a [Widget] tree from parsed Markdown.
///
/// See also:
///
///  * [Markdown], which is a widget that parses and displays Markdown.
class MarkdownBuilder implements md.NodeVisitor {
  /// Creates an object that builds a [Widget] tree from parsed Markdown.
  MarkdownBuilder({
    required this.delegate,
    required this.selectable,
    required this.styleSheet,
    required this.imageDirectory,
    required this.imageBuilder,
    required this.checkboxBuilder,
    required this.bulletBuilder,
    required this.builders,
    required this.listItemCrossAxisAlignment,
    this.fitContent = false,
    this.onTapText,
  });

  /// A delegate that controls how link and `pre` elements behave.
  final MarkdownBuilderDelegate delegate;

  /// If true, the text is selectable.
  ///
  /// Defaults to false.
  final bool selectable;

  /// Defines which [TextStyle] objects to use for each type of element.
  final MarkdownStyleSheet styleSheet;

  /// The base directory holding images referenced by Img tags with local or network file paths.
  final String? imageDirectory;

  /// Call when build an image widget.
  final MarkdownImageBuilder? imageBuilder;

  /// Call when build a checkbox widget.
  final MarkdownCheckboxBuilder? checkboxBuilder;

  /// Called when building a custom bullet.
  final MarkdownBulletBuilder? bulletBuilder;

  /// Call when build a custom widget.
  final Map<String, MarkdownElementBuilder> builders;

  /// Whether to allow the widget to fit the child content.
  final bool fitContent;

  /// Controls the cross axis alignment for the bullet and list item content
  /// in lists.
  ///
  /// Defaults to [MarkdownListItemCrossAxisAlignment.baseline], which
  /// does not allow for intrinsic height measurements.
  final MarkdownListItemCrossAxisAlignment listItemCrossAxisAlignment;

  /// Default tap handler used when [selectable] is set to true
  final VoidCallback? onTapText;

  final List<String> _listIndents = <String>[];
  final List<_BlockElement> _blocks = <_BlockElement>[];
  final List<_TableElement> _tables = <_TableElement>[];
  final List<_InlineElement> _inlines = <_InlineElement>[];
  final List<GestureRecognizer> _linkHandlers = <GestureRecognizer>[];
  String? _currentBlockTag;
  String? _lastTag;
  bool _isInBlockquote = false;

  /// Returns widgets that display the given Markdown nodes.
  ///
  /// The returned widgets are typically used as children in a [ListView].
  List<Widget> build(List<md.Node> nodes) {
    _listIndents.clear();
    _blocks.clear();
    _tables.clear();
    _inlines.clear();
    _linkHandlers.clear();
    _isInBlockquote = false;

    _blocks.add(_BlockElement(null));

    for (final md.Node node in nodes) {
      assert(_blocks.length == 1);
      node.accept(this);
    }

    assert(_tables.isEmpty);
    assert(_inlines.isEmpty);
    assert(!_isInBlockquote);
    return _blocks.single.children;
  }

  @override
  bool visitElementBefore(md.Element element) {
    final String tag = element.tag;
    _currentBlockTag ??= tag;

    if (builders.containsKey(tag)) {
      builders[tag]!.visitElementBefore(element);
    }

    int? start;
    if (_isBlockTag(tag)) {
      _addAnonymousBlockIfNeeded();
      if (_isListTag(tag)) {
        _listIndents.add(tag);
        if (element.attributes['start'] != null)
          start = int.parse(element.attributes['start']!) - 1;
      } else if (tag == 'blockquote') {
        _isInBlockquote = true;
      } else if (tag == 'table') {
        _tables.add(_TableElement());
      } else if (tag == 'tr') {
        final int length = _tables.single.rows.length;
        BoxDecoration? decoration =
            styleSheet.tableCellsDecoration as BoxDecoration?;
        if (length == 0 || length.isOdd) {
          decoration = null;
        }
        _tables.single.rows.add(TableRow(
          decoration: decoration,
          // TODO(stuartmorgan): This should be fixed, not suppressed; enabling
          // this lint warning exposed that the builder is modifying the
          // children of TableRows, even though they are @immutable.
          // ignore: prefer_const_literals_to_create_immutables
          children: <Widget>[],
        ));
      }
      final _BlockElement bElement = _BlockElement(tag);
      if (start != null) {
        bElement.nextListIndex = start;
      }
      _blocks.add(bElement);
    } else {
      if (tag == 'a') {
        final String? text = extractTextFromElement(element);
        // Don't add empty links
        if (text == null) {
          return false;
        }
        final String? destination = element.attributes['href'];
        final String title = element.attributes['title'] ?? '';

        _linkHandlers.add(
          delegate.createLink(text, destination, title),
        );
      }

      _addParentInlineIfNeeded(_blocks.last.tag);

      // The Markdown parser passes empty table data tags for blank
      // table cells. Insert a text node with an empty string in this
      // case for the table cell to get properly created.
      if (element.tag == 'td' &&
          element.children != null &&
          element.children!.isEmpty) {
        element.children!.add(md.Text(''));
      }

      final TextStyle parentStyle = _inlines.last.style!;
      _inlines.add(_InlineElement(
        tag,
        style: parentStyle.merge(styleSheet.styles[tag]),
      ));
    }

    return true;
  }

  /// Returns the text, if any, from [element] and its descendants.
  String? extractTextFromElement(md.Node element) {
    return element is md.Element && (element.children?.isNotEmpty ?? false)
        ? element.children!
            .map((md.Node e) =>
                e is md.Text ? e.text : extractTextFromElement(e))
            .join('')
        : (element is md.Element && (element.attributes.isNotEmpty)
            ? element.attributes['alt']
            : '');
  }

  @override
  void visitText(md.Text text) {
    // Don't allow text directly under the root.
    if (_blocks.last.tag == null) {
      return;
    }

    _addParentInlineIfNeeded(_blocks.last.tag);

    // Define trim text function to remove spaces from text elements in
    // accordance with Markdown specifications.
    String trimText(String text) {
      // The leading spaces pattern is used to identify spaces
      // at the beginning of a line of text.
      final RegExp _leadingSpacesPattern = RegExp(r'^ *');

      // The soft line break pattern is used to identify the spaces at the end of a
      // line of text and the leading spaces in the immediately following the line
      // of text. These spaces are removed in accordance with the Markdown
      // specification on soft line breaks when lines of text are joined.
      final RegExp _softLineBreakPattern = RegExp(r' ?\n *');

      // Leading spaces following a hard line break are ignored.
      // https://github.github.com/gfm/#example-657
      if (_lastTag == 'br') {
        text = text.replaceAll(_leadingSpacesPattern, '');
      }

      // Spaces at end of the line and beginning of the next line are removed.
      // https://github.github.com/gfm/#example-670
      return text.replaceAll(_softLineBreakPattern, ' ');
    }

    Widget? child;
    if (_blocks.isNotEmpty && builders.containsKey(_blocks.last.tag)) {
      child = builders[_blocks.last.tag!]!
          .visitText(text, styleSheet.styles[_blocks.last.tag!]);
    } else if (_blocks.last.tag == 'pre') {
      child = Scrollbar(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: styleSheet.codeblockPadding,
          child: _buildRichText(delegate.formatText(styleSheet, text.text)),
        ),
      );
    } else {
      child = _buildRichText(
        TextSpan(
          style: _isInBlockquote
              ? styleSheet.blockquote!.merge(_inlines.last.style)
              : _inlines.last.style,
          text: _isInBlockquote ? text.text : trimText(text.text),
          recognizer: _linkHandlers.isNotEmpty ? _linkHandlers.last : null,
        ),
        textAlign: _textAlignForBlockTag(_currentBlockTag),
      );
    }
    if (child != null) {
      _inlines.last.children.add(child);
    }
  }

  @override
  void visitElementAfter(md.Element element) {
    final String tag = element.tag;

    if (_isBlockTag(tag)) {
      _addAnonymousBlockIfNeeded();

      final _BlockElement current = _blocks.removeLast();
      Widget child;

      if (current.children.isNotEmpty) {
        child = Column(
          crossAxisAlignment: fitContent
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.stretch,
          children: current.children,
        );
      } else {
        child = const SizedBox();
      }

      if (_isListTag(tag)) {
        assert(_listIndents.isNotEmpty);
        _listIndents.removeLast();
      } else if (tag == 'li') {
        if (_listIndents.isNotEmpty) {
          if (element.children!.isEmpty) {
            element.children!.add(md.Text(''));
          }
          Widget bullet;
          final dynamic el = element.children![0];
          if (el is md.Element && el.attributes['type'] == 'checkbox') {
            final bool val = el.attributes['checked'] != 'false';
            bullet = _buildCheckbox(val);
          } else {
            bullet = _buildBullet(_listIndents.last);
          }
          child = Row(
            textBaseline: listItemCrossAxisAlignment ==
                    MarkdownListItemCrossAxisAlignment.start
                ? null
                : TextBaseline.alphabetic,
            crossAxisAlignment: listItemCrossAxisAlignment ==
                    MarkdownListItemCrossAxisAlignment.start
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.baseline,
            children: <Widget>[
              SizedBox(
                width: styleSheet.listIndent! +
                    styleSheet.listBulletPadding!.left +
                    styleSheet.listBulletPadding!.right,
                child: bullet,
              ),
              Expanded(child: child)
            ],
          );
        }
      } else if (tag == 'table') {
        child = Table(
          defaultColumnWidth: styleSheet.tableColumnWidth!,
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          border: styleSheet.tableBorder,
          children: _tables.removeLast().rows,
        );
      } else if (tag == 'blockquote') {
        _isInBlockquote = false;
        child = DecoratedBox(
          decoration: styleSheet.blockquoteDecoration!,
          child: Padding(
            padding: styleSheet.blockquotePadding!,
            child: child,
          ),
        );
      } else if (tag == 'pre') {
        child = DecoratedBox(
          decoration: styleSheet.codeblockDecoration!,
          child: child,
        );
      } else if (tag == 'hr') {
        child = Container(decoration: styleSheet.horizontalRuleDecoration);
      }

      _addBlockChild(child);
    } else {
      final _InlineElement current = _inlines.removeLast();
      final _InlineElement parent = _inlines.last;

      if (builders.containsKey(tag)) {
        final Widget? child =
            builders[tag]!.visitElementAfter(element, styleSheet.styles[tag]);
        if (child != null) {
          current.children[0] = child;
        }
      } else if (tag == 'img') {
        // create an image widget for this image
        current.children.add(BuildImage(
          element.attributes['src']!,
          element.attributes['title'],
          element.attributes['alt'],
          imageBuilder,
          imageDirectory,
          _linkHandlers,
        ));
      } else if (tag == 'br') {
        current.children.add(_buildRichText(const TextSpan(text: '\n')));
      } else if (tag == 'th' || tag == 'td') {
        TextAlign? align;
        final String? style = element.attributes['style'];
        if (style == null) {
          align = tag == 'th' ? styleSheet.tableHeadAlign : TextAlign.left;
        } else {
          final RegExp regExp = RegExp(r'text-align: (left|center|right)');
          final Match match = regExp.matchAsPrefix(style)!;
          switch (match[1]) {
            case 'left':
              align = TextAlign.left;
              break;
            case 'center':
              align = TextAlign.center;
              break;
            case 'right':
              align = TextAlign.right;
              break;
          }
        }
        final Widget child = _buildTableCell(
          _mergeInlineChildren(current.children, align),
          textAlign: align,
        );
        _tables.single.rows.last.children!.add(child);
      } else if (tag == 'a') {
        _linkHandlers.removeLast();
      }

      if (current.children.isNotEmpty) {
        parent.children.addAll(current.children);
      }
    }
    if (_currentBlockTag == tag) {
      _currentBlockTag = null;
    }
    _lastTag = tag;
  }

  Widget _buildCheckbox(bool checked) {
    if (checkboxBuilder != null) {
      return checkboxBuilder!(checked);
    }
    return Padding(
      padding: styleSheet.listBulletPadding!,
      child: Icon(
        checked ? Icons.check_box : Icons.check_box_outline_blank,
        size: styleSheet.checkbox!.fontSize,
        color: styleSheet.checkbox!.color,
      ),
    );
  }

  Widget _buildBullet(String listTag) {
    final int index = _blocks.last.nextListIndex;
    final bool isUnordered = listTag == 'ul';

    if (bulletBuilder != null) {
      return Padding(
        padding: styleSheet.listBulletPadding!,
        child: bulletBuilder!(index,
            isUnordered ? BulletStyle.unorderedList : BulletStyle.orderedList),
      );
    }

    if (isUnordered) {
      return Padding(
        padding: styleSheet.listBulletPadding!,
        child: Text(
          '•',
          textAlign: TextAlign.center,
          style: styleSheet.listBullet,
        ),
      );
    }

    return Padding(
      padding: styleSheet.listBulletPadding!,
      child: Text(
        '${index + 1}.',
        textAlign: TextAlign.right,
        style: styleSheet.listBullet,
      ),
    );
  }

  Widget _buildTableCell(List<Widget?> children, {TextAlign? textAlign}) {
    return TableCell(
      child: Padding(
        padding: styleSheet.tableCellsPadding!,
        child: DefaultTextStyle(
          style: styleSheet.tableBody!,
          textAlign: textAlign,
          child: Wrap(children: children as List<Widget>),
        ),
      ),
    );
  }

  void _addParentInlineIfNeeded(String? tag) {
    if (_inlines.isEmpty) {
      _inlines.add(_InlineElement(
        tag,
        style: styleSheet.styles[tag!],
      ));
    }
  }

  void _addBlockChild(Widget child) {
    final _BlockElement parent = _blocks.last;
    if (parent.children.isNotEmpty) {
      parent.children.add(SizedBox(height: styleSheet.blockSpacing));
    }
    parent.children.add(child);
    parent.nextListIndex += 1;
  }

  void _addAnonymousBlockIfNeeded() {
    if (_inlines.isEmpty) {
      return;
    }

    WrapAlignment blockAlignment = WrapAlignment.start;
    TextAlign textAlign = TextAlign.start;
    if (_isBlockTag(_currentBlockTag)) {
      blockAlignment = _wrapAlignmentForBlockTag(_currentBlockTag);
      textAlign = _textAlignForBlockTag(_currentBlockTag);
    }

    final _InlineElement inline = _inlines.single;
    if (inline.children.isNotEmpty) {
      final List<Widget> mergedInlines = _mergeInlineChildren(
        inline.children,
        textAlign,
      );
      final Wrap wrap = Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: mergedInlines,
        alignment: blockAlignment,
      );
      _addBlockChild(wrap);
      _inlines.clear();
    }
  }

  /// Merges adjacent [TextSpan] children
  List<Widget> _mergeInlineChildren(
    List<Widget> children,
    TextAlign? textAlign,
  ) {
    final List<Widget> mergedTexts = <Widget>[];
    for (final Widget child in children) {
      if (mergedTexts.isNotEmpty &&
          mergedTexts.last is RichText &&
          child is RichText) {
        final RichText previous = mergedTexts.removeLast() as RichText;
        final TextSpan previousTextSpan = previous.text as TextSpan;
        final List<TextSpan> children = previousTextSpan.children != null
            ? List<TextSpan>.from(previousTextSpan.children!)
            : <TextSpan>[previousTextSpan];
        children.add(child.text as TextSpan);
        final TextSpan? mergedSpan = _mergeSimilarTextSpans(children);
        mergedTexts.add(_buildRichText(
          mergedSpan,
          textAlign: textAlign,
        ));
      } else if (mergedTexts.isNotEmpty &&
          mergedTexts.last is SelectableText &&
          child is SelectableText) {
        final SelectableText previous =
            mergedTexts.removeLast() as SelectableText;
        final TextSpan previousTextSpan = previous.textSpan!;
        final List<TextSpan> children = previousTextSpan.children != null
            ? List<TextSpan>.from(previousTextSpan.children!)
            : <TextSpan>[previousTextSpan];
        if (child.textSpan != null) {
          children.add(child.textSpan!);
        }
        final TextSpan? mergedSpan = _mergeSimilarTextSpans(children);
        mergedTexts.add(
          _buildRichText(
            mergedSpan,
            textAlign: textAlign,
          ),
        );
      } else {
        mergedTexts.add(child);
      }
    }
    return mergedTexts;
  }

  TextAlign _textAlignForBlockTag(String? blockTag) {
    final WrapAlignment wrapAlignment = _wrapAlignmentForBlockTag(blockTag);
    switch (wrapAlignment) {
      case WrapAlignment.start:
        return TextAlign.start;
      case WrapAlignment.center:
        return TextAlign.center;
      case WrapAlignment.end:
        return TextAlign.end;
      case WrapAlignment.spaceAround:
        return TextAlign.justify;
      case WrapAlignment.spaceBetween:
        return TextAlign.justify;
      case WrapAlignment.spaceEvenly:
        return TextAlign.justify;
    }
  }

  WrapAlignment _wrapAlignmentForBlockTag(String? blockTag) {
    switch (blockTag) {
      case 'p':
        return styleSheet.textAlign;
      case 'h1':
        return styleSheet.h1Align;
      case 'h2':
        return styleSheet.h2Align;
      case 'h3':
        return styleSheet.h3Align;
      case 'h4':
        return styleSheet.h4Align;
      case 'h5':
        return styleSheet.h5Align;
      case 'h6':
        return styleSheet.h6Align;
      case 'ul':
        return styleSheet.unorderedListAlign;
      case 'ol':
        return styleSheet.orderedListAlign;
      case 'blockquote':
        return styleSheet.blockquoteAlign;
      case 'pre':
        return styleSheet.codeblockAlign;
      case 'hr':
        print('Markdown did not handle hr for alignment');
        break;
      case 'li':
        print('Markdown did not handle li for alignment');
        break;
    }
    return WrapAlignment.start;
  }

  /// Combine text spans with equivalent properties into a single span.
  TextSpan? _mergeSimilarTextSpans(List<TextSpan>? textSpans) {
    if (textSpans == null || textSpans.length < 2) {
      return TextSpan(children: textSpans);
    }

    final List<TextSpan> mergedSpans = <TextSpan>[textSpans.first];

    for (int index = 1; index < textSpans.length; index++) {
      final TextSpan nextChild = textSpans[index];
      if (nextChild.recognizer == mergedSpans.last.recognizer &&
          nextChild.semanticsLabel == mergedSpans.last.semanticsLabel &&
          nextChild.style == mergedSpans.last.style) {
        final TextSpan previous = mergedSpans.removeLast();
        mergedSpans.add(TextSpan(
          text: previous.toPlainText() + nextChild.toPlainText(),
          recognizer: previous.recognizer,
          semanticsLabel: previous.semanticsLabel,
          style: previous.style,
        ));
      } else {
        mergedSpans.add(nextChild);
      }
    }

    // When the mergered spans compress into a single TextSpan return just that
    // TextSpan, otherwise bundle the set of TextSpans under a single parent.
    return mergedSpans.length == 1
        ? mergedSpans.first
        : TextSpan(children: mergedSpans);
  }

  Widget _buildRichText(TextSpan? text, {TextAlign? textAlign}) {
    if (selectable) {
      return SelectableText.rich(
        text!,
        textScaleFactor: styleSheet.textScaleFactor,
        textAlign: textAlign ?? TextAlign.start,
        onTap: onTapText,
      );
    } else {
      if (text?.style == null || text?.text == null) {
        return RichText(
          text: text!,
          textScaleFactor: styleSheet.textScaleFactor!,
          textAlign: textAlign ?? TextAlign.start,
        );
      }
      final coloredTexts = splitColorTags(text!.text!);
      final newTexts = coloredTexts
          .map((coloredText) => TextSpan(
                text: coloredText.text,
                style: text.style
                    ?.copyWith(color: coloredText.color ?? text.style?.color),
                recognizer: text.recognizer,
                mouseCursor: text.mouseCursor,
                onEnter: text.onEnter,
                onExit: text.onExit,
                semanticsLabel: text.semanticsLabel,
              ))
          .toList();

      return RichText(
        text: TextSpan(
          children: newTexts,
          style: text.style,
          recognizer: text.recognizer,
          mouseCursor: text.mouseCursor,
        ),
        textScaleFactor: styleSheet.textScaleFactor!,
        textAlign: textAlign ?? TextAlign.start,
      );
    }
  }
}

const Map<String, Color> colorMap = <String, Color>{
  'red': Colors.red,
  'blue': Colors.blue,
  'yellow': Colors.yellow,
  'black': Colors.black,
  'transparent': Colors.transparent,
  'white': Colors.white,
  'amber': Colors.amber,
  'blueGrey': Colors.blueGrey,
  'brown': Colors.brown,
  'cyan': Colors.cyan,
  'deepOrange': Colors.deepOrange,
  'deepPurple': Colors.deepPurple,
  'green': Colors.green,
  'grey': Colors.grey,
  'indigo': Colors.indigo,
  'lightBlue': Colors.lightBlue,
  'lightGreen': Colors.lightGreen,
  'lime': Colors.lime,
  'orange': Colors.orange,
  'pink': Colors.pink,
  'purple': Colors.purple,
  'teal': Colors.teal,
};

class ColoredText {
  Color? color;
  String text;
  ColoredText(
    this.color,
    this.text,
  );

  @override
  bool operator ==(other) =>
      other is ColoredText && other.color == color && other.text == text;
  @override
  int get hashCode => hashValues(color, text);

  @override
  String toString() {
    return "color: $color, text: $text";
  }

  // 生成に失敗したらnullを返す。
  static ColoredText deligate(String text) {
    return ColoredText(
      null,
      text,
    );
  }

  // 生成に失敗したらnullを返す。
  static ColoredText? generate(String taggedString) {
    RegExp exp = RegExp(r'^<color=(\w+)>([\s\S]+)</color>$');
    final match = exp.firstMatch(taggedString);
    if (match == null) {
      return null;
    }
    final colorStr = match.group(1);
    final body = match.group(2);

    if (colorStr == null || body == null) {
      return null;
    }
    final color = colorMap[colorStr];
    if (color == null) {
      return null;
    }
    return ColoredText(color, body);
  }
}

class PhotoViewPage extends StatelessWidget {
  PhotoViewPage({this.imageProvider});

  final ImageProvider<Object>? imageProvider;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBarを入れないと、アプリの表示するときにバグる。
      // おそらく、Navigator関連
      appBar: AppBar(
        toolbarHeight: 0,
      ),
      body: Stack(
        children: [
          PhotoView(
            imageProvider: imageProvider,
          ),
          Container(
            padding: EdgeInsets.all(8),
            width: 48,
            decoration: ShapeDecoration(
              color: Colors.white.withOpacity(0.6),
              shape: CircleBorder(),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: () => {Navigator.of(context).pop()},
              icon: Icon(
                Icons.close,
                size: 24,
                color: Colors.black87,
              ),
            ),
          )
        ],
      ),
    );
  }
}

class BuildImage extends StatefulWidget {
  BuildImage(this.src, this.title, this.alt, this.imageBuilder,
      this.imageDirectory, this.linkHandlers);
  final String src;
  final String? title;
  final String? alt;
  final imageBuilder;
  final imageDirectory;
  final linkHandlers;

  @override
  _BuildImageState createState() => _BuildImageState();
}

class _BuildImageState extends State<BuildImage> {
  @override
  Widget build(BuildContext context) {
    final List<String> parts = widget.src.split('#');
    if (parts.isEmpty) {
      return const SizedBox();
    }

    final String path = parts.first;
    double? width;
    double? height;
    if (parts.length == 2) {
      final List<String> dimensions = parts.last.split('x');
      if (dimensions.length == 2) {
        width = double.parse(dimensions[0]);
        height = double.parse(dimensions[1]);
      }
    }

    final Uri uri = Uri.parse(path);
    Widget child;
    if (widget.imageBuilder != null) {
      child = InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (BuildContext context) {
                return PhotoViewPage(
                  imageProvider: kDefaultImageBuilder(
                    uri,
                    widget.imageDirectory,
                  ),
                );
              },
            ),
          );
        },
        child: Container(
          width: width ?? 400,
          height: height ?? ((width ?? 400) * 0.8),
          child: Image(
            image: widget.imageBuilder!(
              uri,
              widget.imageDirectory,
              widget.alt,
            ),
          ),
        ),
      );
    } else {
      child = InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (BuildContext context) {
                return PhotoViewPage(
                  imageProvider: kDefaultImageBuilder(
                    uri,
                    widget.imageDirectory,
                  ),
                );
              },
            ),
          );
        },
        child: Container(
          width: width ?? 400,
          height: height ?? ((width ?? 400) * 0.8),
          child: Image(
            image: kDefaultImageBuilder(
              uri,
              widget.imageDirectory,
            ),
          ),
        ),
      );
    }
    if (widget.linkHandlers.isNotEmpty) {
      final TapGestureRecognizer recognizer =
          widget.linkHandlers.last as TapGestureRecognizer;
      return GestureDetector(child: child, onTap: recognizer.onTap);
    } else {
      return child;
    }
  }
}

List<ColoredText> splitColorTags(String text) {
  final startTagIndexes =
      RegExp(r"<color=(\w+)>").allMatches(text).map((tag) => tag.start);
  final endTagIndexes =
      RegExp(r"</color>").allMatches(text).map((tag) => tag.end);
  final tagMatches = <List<int>>[];

  for (int startIndex in startTagIndexes) {
    final lastIndex = tagMatches.lastOrNull?.lastOrNull;
    if (lastIndex != null && startIndex < lastIndex) {
      continue;
    }
    final endIndex = endTagIndexes.firstWhereOrNull((i) => i > startIndex);
    if (endIndex == null) {
      continue;
    }
    tagMatches.add([startIndex, endIndex]);
  }

  final coloredTextStart = tagMatches.map((e) => e.first);
  final normalTextStart = tagMatches.map((e) => e.last + 1).toList();
  if (coloredTextStart.firstOrNull != 0) {
    normalTextStart.insert(0, 0);
  }
  if (normalTextStart.lastOrNull != null &&
      normalTextStart.last > text.length) {
    normalTextStart.removeLast();
  }

  int pointer = 0;
  final coloredTexts = <ColoredText>[];

  tagMatches.forEach((tagMatch) {
    if (pointer < tagMatch.first) {
      coloredTexts
          .add(ColoredText.deligate(text.substring(pointer, tagMatch.first)));
      pointer = tagMatch.first;
    }
    final coloredText =
        ColoredText.generate(text.substring(pointer, tagMatch.last));
    if (coloredText != null) {
      coloredTexts.add(coloredText);
      pointer = tagMatch.last;
    }
  });

  if (pointer != text.length) {
    coloredTexts
        .add(ColoredText.deligate(text.substring(pointer, text.length)));
  }

  return coloredTexts;
}
