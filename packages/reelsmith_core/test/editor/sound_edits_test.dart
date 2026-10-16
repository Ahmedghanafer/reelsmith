import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

import '../model/sound_model_test.dart' show musicFile;

// testMuteKeepsTheVolumeAndThePlanReadsZero and testALongFadeIsStoredAsSentAndCutOnlyInThePlan call renderPlan
// and stay in Swift.

void main() {
  const one = TextID(1);
  const blue = ClipID(1);
  final wide = EditorState(Seed.twoClipsWide.project);
  final music = EditorState(Seed.musicWide.project);
  final textWide = EditorState(Seed.textWide.project);

  void assertValid(EditorState state, String step) {
    final project = state.project;
    expect(project.clipVolume, greaterThanOrEqualTo(0), reason: '$step: the volume of the clips');
    expect(project.clipVolume, lessThanOrEqualTo(1), reason: '$step: the volume of the clips');
    final music = project.music;
    if (music != null) {
      expect(music.volume, greaterThanOrEqualTo(0), reason: '$step: the volume of the music');
      expect(music.volume, lessThanOrEqualTo(1), reason: '$step: the volume of the music');
      expect(music.start.ticks.remainder(Time.frame.ticks), 0, reason: '$step: the start of the music');
      expect(music.start >= Time.zero, isTrue, reason: '$step: the start of the music');
      expect(music.start <= music.largestStart, isTrue, reason: '$step: the start of the music');
      for (final fade in [music.fadeIn, music.fadeOut]) {
        expect(fade.ticks.remainder(Time.frame.ticks), 0, reason: '$step: a fade');
        expect(fade >= Time.zero, isTrue, reason: '$step: a fade');
        expect(fade <= SoundGeometry.maximumFade, isTrue, reason: '$step: a fade');
      }
      expect(music.file.duration > Time.zero, isTrue, reason: '$step: the length of the file');
    }
    final set = [state.selection != null, state.selectedText != null, state.showsSound].where((value) => value);
    expect(set.length, lessThanOrEqualTo(1), reason: '$step: more than one of a clip, a text and the sound panel');
    if (project.clips.isEmpty) {
      expect(state.showsSound, isFalse, reason: '$step: the sound panel on an empty project');
    }
  }

  /// Sends the actions one by one. The state must be valid after each.
  EditorState send(EditorState state, List<EditorAction> actions) {
    var next = state;
    for (var index = 0; index < actions.length; index++) {
      next = reduce(next, actions[index]);
      assertValid(next, 'after action ${index + 1}');
    }
    return next;
  }

  EditorState sendSound(EditorState state, List<SoundAction> actions) =>
      send(state, actions.map(EditorAction.sound).toList());

  EditorState playing(EditorState state) => state.copyWith(isPlaying: true);

  Time ticks(int value) => Time(ticks: value);

  /// The music seed with every value of sound away from the one it starts with, playing.
  EditorState changed() => playing(
    sendSound(music, [
      SoundAction.setClipVolume(0.5),
      SoundAction.muteClips(true),
      SoundAction.setMusicStart(ticks(600)),
      SoundAction.setMusicVolume(0.25),
      SoundAction.setFadeIn(ticks(300)),
      SoundAction.setFadeOut(ticks(300)),
    ]),
  );

  /// The three values of sound.
  List<Object?> sound(EditorState state) => [state.project.clipVolume, state.project.clipsMuted, state.project.music];

  String field(int number, EditorState state) {
    final fields = state.soundInfo.split(' ').where((field) => field.isNotEmpty).toList();
    return number <= fields.length ? fields[number - 1] : 'missing';
  }

  // Open

  test('testOpenShowsThePanelAndLeavesPlayingAlone', () {
    final stopped = sendSound(wide, [SoundAction.open]);
    expect(stopped.showsSound, isTrue);
    expect(stopped.isPlaying, isFalse);

    final moving = sendSound(playing(wide), [SoundAction.open]);
    expect(moving.showsSound, isTrue);
    expect(moving.isPlaying, isTrue);
  });

  test('testOpenClearsTheSelectedClip', () {
    final selected = send(wide, [EditorAction.select(blue)]);
    expect(selected.selection, blue);

    final next = sendSound(selected, [SoundAction.open]);

    expect(next.selection, isNull);
    expect(next.showsSound, isTrue);
  });

  test('testOpenClearsTheSelectedTextAndKeepsIt', () {
    final selected = textWide.copyWith(selectedText: () => one);

    final next = sendSound(selected, [SoundAction.open]);

    expect(next.selectedText, isNull);
    expect(next.project.text(one), isNotNull);
    expect(next.showsSound, isTrue);
  });

  test('testOpenAfterAddRemovesTheBlankText', () {
    final added = send(wide, [EditorAction.text(TextAction.add)]);
    expect(added.project.texts.length, 1);

    final next = sendSound(added, [SoundAction.open]);

    expect(next.project.texts, isEmpty);
    expect(next.selectedText, isNull);
    expect(next.showsSound, isTrue);
  });

  test('testOpenOnAnEmptyProjectChangesNothing', () {
    final empty = EditorState(Seed.empty.project);

    expect(sendSound(empty, [SoundAction.open]), empty);
    expect(sendSound(playing(empty), [SoundAction.open]), playing(empty));
  });

  // The one of three

  test('testSelectingAClipClosesThePanel', () {
    final next = send(music, [EditorAction.sound(SoundAction.open), EditorAction.select(blue)]);

    expect(next.showsSound, isFalse);
    expect(next.selection, blue);
  });

  test('testSelectingATextClosesThePanel', () {
    final next = send(textWide, [EditorAction.sound(SoundAction.open), EditorAction.text(TextAction.select(one))]);

    expect(next.showsSound, isFalse);
    expect(next.selectedText, one);
  });

  test('testAddingATextClosesThePanel', () {
    final next = send(music, [EditorAction.sound(SoundAction.open), EditorAction.text(TextAction.add)]);

    expect(next.showsSound, isFalse);
    expect(next.selectedText, isNotNull);
    expect(next.selectedText, next.project.texts.isEmpty ? null : next.project.texts.last.id);
  });

  test('testClearSelectionLeavesNothingSet', () {
    final next = send(music, [EditorAction.sound(SoundAction.open), EditorAction.clearSelection]);

    expect(next.showsSound, isFalse);
    expect(next.selection, isNull);
    expect(next.selectedText, isNull);
  });

  test('testThePlayheadAndPlayingLeaveThePanelAsItWas', () {
    final names = ['movePlayhead', 'play', 'pause'];
    for (final start in [music, sendSound(music, [SoundAction.open])]) {
      final actions = [EditorAction.movePlayhead(ticks(600)), EditorAction.play, EditorAction.pause];
      for (var index = 0; index < actions.length; index++) {
        expect(send(start, [actions[index]]).showsSound, start.showsSound, reason: names[index]);
      }
    }
  });

  test('testEverySoundActionButOpenLeavesThePanelAsItWas', () {
    final actions = <SoundAction>[
      SoundAction.setClipVolume(0.5),
      SoundAction.muteClips(true),
      SoundAction.setMusic(TestTone.short.file),
      SoundAction.removeMusic,
      SoundAction.setMusicVolume(0.5),
      SoundAction.setMusicStart(ticks(600)),
      SoundAction.setFadeIn(ticks(300)),
      SoundAction.setFadeOut(ticks(300)),
    ];
    for (final start in [music, sendSound(music, [SoundAction.open])]) {
      for (var index = 0; index < actions.length; index++) {
        final next = sendSound(start, [actions[index]]);
        expect(next.project, isNot(start.project), reason: 'action ${index + 1} changed nothing');
        expect(next.showsSound, start.showsSound, reason: 'action ${index + 1}');
      }
    }
  });

  test('testDeletingEveryClipWithThePanelOpenLeavesItClosed', () {
    var next = sendSound(music, [SoundAction.open]);
    while (next.project.clips.isNotEmpty) {
      next = send(next, [EditorAction.select(next.project.clips.first.id), EditorAction.deleteSelected]);
    }

    expect(next.project.clips, isEmpty);
    expect(next.showsSound, isFalse);
  });

  test('testAnyActionOnAnEmptyProjectClosesThePanel', () {
    // Only a state made by hand has the panel open on an empty project.
    final start = EditorState(Seed.musicWide.project.copyWith(clips: [])).copyWith(showsSound: true);

    expect(send(start, [EditorAction.pause]).showsSound, isFalse);
  });

  // The volume of the clips

  test('testSetClipVolumeStoresTheVolumeAndPlaysOn', () {
    final next = sendSound(playing(music), [SoundAction.setClipVolume(0.5)]);

    expect(next.project.clipVolume, 0.5);
    expect(next.isPlaying, isTrue);
  });

  test('testSetClipVolumeIsHeldBetweenZeroAndOne', () {
    final half = sendSound(music, [SoundAction.setClipVolume(0.5)]);

    expect(sendSound(half, [SoundAction.setClipVolume(1.7)]).project.clipVolume, 1);
    expect(sendSound(half, [SoundAction.setClipVolume(-0.3)]).project.clipVolume, 0);
  });

  test('testSetClipVolumeWithItsOwnValueChangesNothing', () {
    expect(sendSound(playing(music), [SoundAction.setClipVolume(1)]), playing(music));
    expect(sendSound(playing(music), [SoundAction.setClipVolume(1.7)]), playing(music));
    expect(sendSound(changed(), [SoundAction.setClipVolume(0.5)]), changed());
  });

  test('testSetClipVolumeThatIsNotFiniteChangesNothing', () {
    for (final volume in [double.nan, double.infinity, double.negativeInfinity]) {
      expect(sendSound(changed(), [SoundAction.setClipVolume(volume)]), changed(), reason: '$volume');
    }
  });

  test('testSetClipVolumeWorksWithThePanelClosedAndLeavesItAlone', () {
    final closed = sendSound(music, [SoundAction.setClipVolume(0.5)]);
    expect(closed.project.clipVolume, 0.5);
    expect(closed.showsSound, isFalse);

    final open = sendSound(music, [SoundAction.open, SoundAction.setClipVolume(0.5)]);
    expect(open.project.clipVolume, 0.5);
    expect(open.showsSound, isTrue);
  });

  // The mute

  test('testMuteWithItsOwnValueChangesNothing', () {
    expect(sendSound(playing(music), [SoundAction.muteClips(false)]), playing(music));
    expect(sendSound(changed(), [SoundAction.muteClips(true)]), changed());
  });

  // Set and remove the music

  test('testSetMusicStoresANewMusicAndPauses', () {
    final next = sendSound(playing(wide), [SoundAction.setMusic(TestTone.long.file)]);

    expect(next.project.music, Music.file(TestTone.long.file));
    expect(next.isPlaying, isFalse);
  });

  test('testSetMusicReplacesTheMusicWhole', () {
    final set = sendSound(music, [
      SoundAction.setMusicStart(ticks(600)),
      SoundAction.setMusicVolume(0.5),
      SoundAction.setFadeIn(ticks(300)),
    ]);
    expect(
      set.project.music,
      Music(file: TestTone.long.file, start: ticks(600), volume: 0.5, fadeIn: ticks(300), fadeOut: Time.zero),
    );

    final next = sendSound(set, [SoundAction.setMusic(TestTone.short.file)]);

    expect(
      next.project.music,
      Music(file: TestTone.short.file, start: Time.zero, volume: 1, fadeIn: Time.zero, fadeOut: Time.zero),
    );
  });

  test('testSetMusicWithAFileOfNoLengthChangesNothing', () {
    expect(sendSound(playing(wide), [SoundAction.setMusic(musicFile(0))]), playing(wide));
    expect(sendSound(changed(), [SoundAction.setMusic(musicFile(0))]), changed());
  });

  test('testSetMusicWithTheMusicItAlreadyHasChangesNothing', () {
    expect(sendSound(playing(music), [SoundAction.setMusic(TestTone.long.file)]), playing(music));
  });

  test('testRemoveMusicKeepsTheSoundOfTheClips', () {
    final removed = sendSound(playing(music), [SoundAction.removeMusic]);
    expect(removed.project.music, isNull);
    expect(removed.soundInfo, '100 . none');
    expect(removed.isPlaying, isFalse);

    final next = sendSound(changed(), [SoundAction.removeMusic]);
    expect(next.project.music, isNull);
    expect(next.project.clipVolume, 0.5);
    expect(next.project.clipsMuted, isTrue);
  });

  // The volume of the music

  test('testSetMusicVolumeStoresTheVolumeHeldBetweenZeroAndOne', () {
    final quarter = sendSound(playing(music), [SoundAction.setMusicVolume(0.25)]);
    expect(quarter.project.music?.volume, 0.25);
    expect(quarter.isPlaying, isTrue);

    expect(sendSound(quarter, [SoundAction.setMusicVolume(2)]).project.music?.volume, 1);
    expect(sendSound(quarter, [SoundAction.setMusicVolume(-1)]).project.music?.volume, 0);
  });

  // The start of the music

  int? startAfter(int value, [EditorState? state]) =>
      sendSound(state ?? music, [SoundAction.setMusicStart(ticks(value))]).project.music?.start.ticks;

  test('testSetMusicStartIsHeldAndRoundedTowardZeroToAWholeFrame', () {
    final atSix = sendSound(music, [SoundAction.setMusicStart(ticks(600))]);

    expect(startAfter(600), 600);
    expect(startAfter(619), 600);
    expect(startAfter(-50, atSix), 0);
    expect(startAfter(9000), 5400);
  });

  test('testTheLargestStartLeavesSixHundredTicksHeard', () {
    final next = sendSound(playing(music), [SoundAction.setMusicStart(ticks(9000))]);

    expect(next.project.music?.start, ticks(5400));
    expect(next.project.heardMusic, ticks(600));
    expect(next.isPlaying, isFalse);
  });

  test('testTheLargestStartOfTheShortToneIs600', () {
    final short = sendSound(wide, [SoundAction.setMusic(TestTone.short.file)]);

    expect(startAfter(9000, short), 600);
    expect(startAfter(400, short), 400);
  });

  test('testAFileOf500TicksKeepsItsStartAtZero', () {
    final small = sendSound(wide, [SoundAction.setMusic(musicFile(500))]);

    for (final value in [20, 600, 9000, -50]) {
      expect(startAfter(value, small), 0, reason: '$value');
      expect(
        sendSound(playing(small), [SoundAction.setMusicStart(ticks(value))]),
        playing(small),
        reason: '$value',
      );
    }
  });

  test('testAStartOf3000ReadsInTheLabelAndTheInfo', () {
    final next = sendSound(music, [SoundAction.setMusicStart(ticks(3000))]);

    expect(next.musicLabel, '00:05-00:10 / 00:10');
    expect(field(3, next), '3000+3000');
  });

  // The fades

  int? fadeInAfter(int value, [EditorState? state]) =>
      sendSound(state ?? music, [SoundAction.setFadeIn(ticks(value))]).project.music?.fadeIn.ticks;

  int? fadeOutAfter(int value, [EditorState? state]) =>
      sendSound(state ?? music, [SoundAction.setFadeOut(ticks(value))]).project.music?.fadeOut.ticks;

  test('testSetFadeInIsHeldAndRoundedTowardZeroToAWholeFrame', () {
    final set = sendSound(music, [SoundAction.setFadeIn(ticks(300))]);

    expect(fadeInAfter(300), 300);
    expect(fadeInAfter(310), 300);
    expect(fadeInAfter(-5, set), 0);
    expect(fadeInAfter(9000), 3000);
  });

  test('testSetFadeOutIsHeldAndRoundedTowardZeroToAWholeFrame', () {
    final set = sendSound(music, [SoundAction.setFadeOut(ticks(300))]);

    expect(fadeOutAfter(300), 300);
    expect(fadeOutAfter(310), 300);
    expect(fadeOutAfter(-5, set), 0);
    expect(fadeOutAfter(9000), 3000);
  });

  test('testEachFadeChangesOnlyItself', () {
    final next = sendSound(music, [SoundAction.setFadeIn(ticks(300)), SoundAction.setFadeOut(ticks(600))]);

    expect(next.project.music?.fadeIn, ticks(300));
    expect(next.project.music?.fadeOut, ticks(600));
  });

  // An action that changes nothing

  test('testEveryActionOnTheMusicWithNoMusicChangesNothing', () {
    final actions = <SoundAction>[
      SoundAction.removeMusic,
      SoundAction.setMusicVolume(0.5),
      SoundAction.setMusicStart(ticks(600)),
      SoundAction.setFadeIn(ticks(300)),
      SoundAction.setFadeOut(ticks(300)),
    ];
    for (var index = 0; index < actions.length; index++) {
      expect(sendSound(playing(wide), [actions[index]]), playing(wide), reason: 'action ${index + 1}');
    }
  });

  test('testEveryActionOnTheMusicWithTheValueItHasChangesNothing', () {
    final actions = <SoundAction>[
      SoundAction.setMusicVolume(0.25),
      SoundAction.setMusicStart(ticks(600)),
      SoundAction.setFadeIn(ticks(300)),
      SoundAction.setFadeOut(ticks(300)),
      SoundAction.setMusicStart(ticks(610)),
      SoundAction.setFadeIn(ticks(319)),
      SoundAction.setFadeOut(ticks(301)),
    ];
    for (var index = 0; index < actions.length; index++) {
      expect(sendSound(changed(), [actions[index]]), changed(), reason: 'action ${index + 1}');
    }
    final full = <SoundAction>[
      SoundAction.setMusicVolume(1),
      SoundAction.setMusicVolume(2),
      SoundAction.setMusicStart(Time.zero),
      SoundAction.setFadeIn(Time.zero),
      SoundAction.setFadeOut(Time.zero),
    ];
    for (var index = 0; index < full.length; index++) {
      expect(sendSound(playing(music), [full[index]]), playing(music), reason: 'full action ${index + 1}');
    }
  });

  test('testAMusicVolumeThatIsNotFiniteChangesNothing', () {
    for (final volume in [double.nan, double.infinity, double.negativeInfinity]) {
      expect(sendSound(changed(), [SoundAction.setMusicVolume(volume)]), changed(), reason: '$volume');
    }
  });

  test('testEveryActionOnTheMusicThatChangesItPausesButALevel', () {
    final actions = <SoundAction>[
      SoundAction.removeMusic,
      SoundAction.setMusicVolume(0.5),
      SoundAction.setMusicStart(ticks(1200)),
      SoundAction.setFadeIn(ticks(600)),
      SoundAction.setFadeOut(ticks(600)),
    ];
    final pausing = <SoundAction>[SoundAction.removeMusic, SoundAction.setMusicStart(ticks(1200))];
    for (var index = 0; index < actions.length; index++) {
      final next = sendSound(changed(), [actions[index]]);
      expect(next.project, isNot(changed().project), reason: 'action ${index + 1} changed nothing');
      expect(next.isPlaying, !pausing.contains(actions[index]), reason: 'action ${index + 1}');
    }
  });

  // Clip and text actions

  test('testNoClipActionAndNoTextActionChangesSound', () {
    var next = changed();
    final before = sound(next);
    var count = 0;
    void step(EditorAction action) {
      count += 1;
      next = send(next, [action]);
      expect(sound(next), before, reason: 'step $count');
    }

    step(EditorAction.addClips([TestClip.green.info]));
    expect(next.project.clips.length, 3);
    step(EditorAction.movePlayhead(ticks(600)));
    step(EditorAction.split);
    expect(next.project.clips.length, 4);
    step(EditorAction.trimStart(blue, ticks(60)));
    step(EditorAction.trimEnd(blue, ticks(60)));
    expect(next.project.clips.isEmpty ? null : next.project.clips.first.duration, ticks(480));
    step(EditorAction.text(TextAction.add));
    final text = next.selectedText ?? one;
    step(EditorAction.text(TextAction.setString(text, 'Sound')));
    step(EditorAction.text(TextAction.move(text, 100, 100)));
    expect(next.project.text(text)?.x, 100);
    while (next.project.clips.isNotEmpty) {
      step(EditorAction.select(next.project.clips.first.id));
      step(EditorAction.deleteSelected);
    }

    expect(next.project.clips, isEmpty);
    expect(next.project.heardMusic, isNull);
    expect(field(3, next), 'hidden');

    step(EditorAction.addClips([TestClip.blue.info]));
    expect(next.project.heardMusic, ticks(1800));
  });

  // Delete

  test('testDeleteWithThePanelOpenAndNothingSelectedChangesNothing', () {
    final open = sendSound(music, [SoundAction.open]);

    expect(open.canDelete, isFalse);
    expect(send(open, [EditorAction.deleteSelected]), open);
    expect(send(playing(open), [EditorAction.deleteSelected]), playing(open));
  });
}
