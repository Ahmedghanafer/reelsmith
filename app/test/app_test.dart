import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelsmith/main.dart';

import 'support/fake_video_engine.dart';

void main() {
  testWidgets('the root builds', (tester) async {
    await tester.pumpWidget(ReelsmithApp(engine: FakeVideoEngine()));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
