# Flutter Markdown

[![pub package](https://img.shields.io/pub/v/uzu_flavored_markdown.svg)](https://pub.dartlang.org/packages/flutter_markdown)
[![Build Status](https://github.com/flutter/uzu_flavored_markdown/workflows/test/badge.svg)](https://github.com/flutter/uzu_flavored_markdown/actions?workflow=test)

A markdown renderer for Flutter. It supports the
[original format](https://daringfireball.net/projects/markdown/), but no inline HTML.

## Overview

The [`uzu_flavored_markdown`](https://pub.dev/packages/uzu_flavored_markdown) package
renders Uzu flavored Markdown, a lightweight markup language, into a Flutter widget
containing a rich text representation.

`uzu_flavored_markdown` is built on top of the Dart
[`markdown`](https://pub.dev/packages/markdown) package, which parses
the Markdown into an abstract syntax tree (AST). The nodes of the AST are an
HTML representation of the Markdown data.

This package was forked from flutter_markdown.

## Uzu Flavored Markdown

色をつけたりできます。

## 使い方

```
UzuMd(body)
```
