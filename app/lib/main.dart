import 'package:flutter/material.dart';

void main() {
  runApp(const ReelsmithApp());
}

/// The root of the app. The start screen goes into the slot `start`.
class ReelsmithApp extends StatelessWidget {
  const ReelsmithApp({super.key});

  @override
  Widget build(BuildContext context) {
    // slot: start
    const Widget start = SizedBox.shrink();
    // end slot: start
    return const MaterialApp(home: start);
  }
}
