import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelsmith/main.dart';

void main() {
  testWidgets('the root builds', (tester) async {
    await tester.pumpWidget(const ReelsmithApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
