// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:uzu_flavored_markdown/uzu_flavored_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

void main() => defineTests();

void defineTests() {
  group('ColoredText', () {
    test('generate non tagged', () async {
      expect(ColoredText.generate("TEST_DATA"), equals(null));
    });

    test('generate tagged', () async {
      expect(
        ColoredText.generate("<color=red>test</color>"),
        equals(ColoredText(Colors.red, "test")),
      );
    });
  });

  group('Split Color Tages', () {
    test('generate non tagged', () async {
      expect(
        splitColorTags("aa<color=red>aa</color>a"),
        equals([
          ColoredText(Colors.black, "aa"),
          ColoredText(Colors.red, "aa"),
          ColoredText(Colors.black, "a"),
        ]),
      );
    });

    test('generate invalid non tagged', () async {
      expect(
        splitColorTags("aa<color=rd>aa</color>a"),
        equals([
          ColoredText(Colors.black, "aa"),
          ColoredText(Colors.black, "<color=rd>aa</color>a"),
        ]),
      );
    });
  });
}
