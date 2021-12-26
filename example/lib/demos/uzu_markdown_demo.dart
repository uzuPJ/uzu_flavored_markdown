import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../shared/markdown_demo_widget.dart';
import 'package:uzu_flavored_markdown/uzu_flavored_markdown.dart';

class UzuMarkdownDemo extends StatelessWidget implements MarkdownDemoWidget {
  const UzuMarkdownDemo({Key? key}) : super(key: key);

  @override
  String get title => 'UzuMD';

  @override
  String get description => 'Shows the effect the wrap alignment and block '
      'spacing parameters have on various Markdown tagged elements.';

  @override
  Future<String> get data =>
      rootBundle.loadString('assets/markdown_test_page.md');

  @override
  Future<String> get notes => Future<String>.value('_notes');

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: rootBundle.loadString('assets/markdown_test_page.md'),
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const CircularProgressIndicator();
        }
        return SingleChildScrollView(child: UzuMd(body: snapshot.data ?? ''));
      },
    );
  }
}
