import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelsmith/engine/engine_api.g.dart';
import 'package:reelsmith/engine/video_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const eventsChannel = EventChannel('dev.flutter.pigeon.reelsmith.EngineEvents.events', pigeonMethodCodec);
  const showChannel = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.reelsmith.EngineApi.show',
    EngineApi.pigeonChannelCodec,
  );

  tearDown(() {
    messenger.setMockStreamHandler(eventsChannel, null);
    messenger.setMockDecodedMessageHandler(showChannel, null);
  });

  test('the engine gives the events Swift sends at once, in order, on four streams', () async {
    messenger.setMockStreamHandler(
      eventsChannel,
      MockStreamHandler.inline(
        onListen: (arguments, events) {
          events.success(BuildCountEvent(count: 1));
          events.success(PlayheadEvent(ticks: 600));
          events.success(ExportProgressEvent(progress: 0.5));
          events.success(PlayedToEndEvent());
          events.success(BuildCountEvent(count: 2));
        },
      ),
    );
    final VideoEngine engine = PigeonVideoEngine();
    final seen = <String>[];
    engine.playhead.listen((ticks) => seen.add('playhead $ticks'));
    engine.playedToEnd.listen((_) => seen.add('playedToEnd'));
    engine.buildCount.listen((count) => seen.add('buildCount $count'));
    final second = <int>[];
    engine.buildCount.listen(second.add);
    engine.exportProgress.listen((progress) => seen.add('exportProgress $progress'));

    await pumpEventQueue();

    expect(seen, [
      'buildCount 1',
      'playhead 600',
      'exportProgress 0.5',
      'playedToEnd',
      'buildCount 2',
    ]);
    expect(second, [1, 2]);
  });

  test('show passes a null playhead', () async {
    messenger.setMockStreamHandler(eventsChannel, MockStreamHandler.inline(onListen: (arguments, events) {}));
    Object? sent;
    messenger.setMockDecodedMessageHandler<Object?>(showChannel, (message) async {
      sent = message;
      return <Object?>[null];
    });

    await PigeonVideoEngine().show(7, '{}', '/m', null, true);

    expect(sent, [7, '{}', '/m', null, true]);
  });
}
