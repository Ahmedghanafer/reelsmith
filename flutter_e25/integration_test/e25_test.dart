import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_e25/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final clock = Stopwatch()..start();

  void say(String line) => debugPrint('E25 TEST ${clock.elapsedMilliseconds} ms: $line');

  /// Pumps until the condition holds, with a limit. Returns the wait in milliseconds.
  Future<int> waitFor(WidgetTester tester, String what, bool Function() done, Duration limit) async {
    final watch = Stopwatch()..start();
    while (!done()) {
      if (watch.elapsed > limit) {
        fail('$what did not happen within ${limit.inSeconds} s');
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    }
    say('$what after ${watch.elapsedMilliseconds} ms');
    return watch.elapsedMilliseconds;
  }

  Future<void> shot(String name) async {
    try {
      final bytes = await binding.takeScreenshot(name).timeout(const Duration(seconds: 20));
      // The simulator shares the host's disk, so the run's own folder is written straight.
      const out = String.fromEnvironment('E25_OUT');
      final folder = Directory(out.isEmpty ? '${Directory.systemTemp.path}/e25shots' : out)..createSync(recursive: true);
      File('${folder.path}/$name.png').writeAsBytesSync(bytes);
      say('screenshot $name ${bytes.length} bytes in ${folder.path}');
    } catch (e) {
      say('screenshot $name failed: $e');
    }
  }

  testWidgets('a Flutter screen drives the Engine: preview, play, export', (tester) async {
    await tester.pumpWidget(const E25App());
    await waitFor(tester, 'texture id and first frame', () => e25.textureId != null && e25.frames >= 1,
        const Duration(seconds: 90));
    say('texture ${e25.textureId} frames ${e25.frames} rgb ${e25.rgb} prepare ${e25.prepareMs.round()} ms');
    await shot('1-first-frame');

    final before = e25.time;
    await tester.tap(find.byKey(const ValueKey('e25.play')));
    await waitFor(tester, 'time past 1 s', () => e25.time > before + 1, const Duration(seconds: 30));
    say('time ${e25.time} frames ${e25.frames} rgb ${e25.rgb}');
    await shot('2-playing');

    await tester.tap(find.byKey(const ValueKey('e25.export')));
    await waitFor(tester, 'export done', () => e25.exported.startsWith('export done') || e25.exported.startsWith('export failed'),
        const Duration(seconds: 180));
    say(e25.exported);
    await shot('3-exported');
    expect(e25.exported, startsWith('export done'));
    const out = String.fromEnvironment('E25_OUT');
    if (out.isNotEmpty) {
      File(e25.exportPath).copySync('$out/e25-export.mp4');
      say('export copied to $out/e25-export.mp4');
    }

    // E27, measured and printed, never failing the test.
    await engine.invokeMethod('pause');
    final slider = find.byKey(const ValueKey('e25.slider'));
    for (var step = 0; step < 10; step++) {
      await tester.drag(slider, const Offset(-20, 0));
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await tester.pump();
    }
    await waitFor(tester, 'seeks settled', () => e25.seekMs.isNotEmpty, const Duration(seconds: 10));
    say('seek ms per step ${e25.seekMs.map((m) => m.toStringAsFixed(1)).join(' ')}');

    await tester.tap(find.byKey(const ValueKey('e25.refresh')));
    await waitFor(tester, 'refresh', () => e25.refreshed.isNotEmpty, const Duration(seconds: 20));
    say(e25.refreshed);
    await shot('4-refreshed');

    await tester.tap(find.byKey(const ValueKey('e25.swap')));
    await waitFor(tester, 'swap', () => e25.swapped.isNotEmpty, const Duration(seconds: 30));
    say(e25.swapped);
    await shot('5-swapped');
  });
}
