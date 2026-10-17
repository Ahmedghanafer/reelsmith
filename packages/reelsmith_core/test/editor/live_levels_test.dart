import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

/// A level changed while the video plays: the six levels leave isPlaying as it was, every other sound action that
/// changes the state pauses, and `sameTracks` tells a change of levels from a change of the tracks.
void main() {
  const red = ClipID(2);
  final music = EditorState(Seed.musicWide.project);
  final wide = EditorState(Seed.twoClipsWide.project);

  EditorState playing(EditorState state) => state.copyWith(isPlaying: true);

  Time ticks(int value) => Time(ticks: value);

  final levels = <SoundAction>[
    SoundAction.setClipVolume(0.5),
    SoundAction.muteClips(true),
    SoundAction.setVolumeOfClip(const ClipID(2), 0.5),
    SoundAction.setMusicVolume(0.25),
    SoundAction.setFadeIn(const Time(ticks: 600)),
    SoundAction.setFadeOut(const Time(ticks: 600)),
  ];

  /// The project with the clip at the index changed.
  Project withClip(Project project, int index, Clip Function(Clip) change) {
    final clips = List.of(project.clips);
    clips[index] = change(clips[index]);
    return project.copyWith(clips: clips);
  }

  test('testEachLevelThatChangesTheStateWhilePlayingLeavesItPlaying', () {
    for (var index = 0; index < levels.length; index++) {
      final next = reduce(playing(music), EditorAction.sound(levels[index]));
      expect(next.project, isNot(music.project), reason: 'level ${index + 1} changed nothing');
      expect(next.isPlaying, isTrue, reason: 'level ${index + 1}');
    }
  });

  test('testEachLevelThatChangesTheStateWhilePausedLeavesItPaused', () {
    for (var index = 0; index < levels.length; index++) {
      final next = reduce(music, EditorAction.sound(levels[index]));
      expect(next.project, isNot(music.project), reason: 'level ${index + 1} changed nothing');
      expect(next.isPlaying, isFalse, reason: 'level ${index + 1}');
    }
  });

  test('testSetMusicRemoveMusicAndSetMusicStartThatChangeTheStateStillPause', () {
    final actions = <(EditorState, SoundAction)>[
      (playing(wide), SoundAction.setMusic(TestTone.long.file)),
      (playing(music), SoundAction.setMusic(TestTone.short.file)),
      (playing(music), SoundAction.removeMusic),
      (playing(music), SoundAction.setMusicStart(ticks(600))),
    ];
    for (var index = 0; index < actions.length; index++) {
      final (state, action) = actions[index];
      final next = reduce(state, EditorAction.sound(action));
      expect(next.project, isNot(state.project), reason: 'action ${index + 1} changed nothing');
      expect(next.isPlaying, isFalse, reason: 'action ${index + 1}');
    }
  });

  test('testEverySoundActionThatChangesNothingReturnsTheStateUnchanged', () {
    final onMusic = <SoundAction>[
      SoundAction.setClipVolume(1),
      SoundAction.setClipVolume(double.nan),
      SoundAction.muteClips(false),
      SoundAction.setVolumeOfClip(red, 1),
      SoundAction.setVolumeOfClip(const ClipID(9), 0.5),
      SoundAction.setVolumeOfClip(red, double.nan),
      SoundAction.setMusic(TestTone.long.file),
      SoundAction.setMusicVolume(1),
      SoundAction.setMusicVolume(double.infinity),
      SoundAction.setMusicStart(Time.zero),
      SoundAction.setFadeIn(Time.zero),
      SoundAction.setFadeOut(Time.zero),
    ];
    for (var index = 0; index < onMusic.length; index++) {
      expect(
        reduce(playing(music), EditorAction.sound(onMusic[index])),
        playing(music),
        reason: 'on music, action ${index + 1}',
      );
    }
    final onWide = <SoundAction>[
      SoundAction.removeMusic,
      SoundAction.setMusicVolume(0.5),
      SoundAction.setMusicStart(ticks(600)),
      SoundAction.setFadeIn(ticks(600)),
      SoundAction.setFadeOut(ticks(600)),
    ];
    for (var index = 0; index < onWide.length; index++) {
      expect(
        reduce(playing(wide), EditorAction.sound(onWide[index])),
        playing(wide),
        reason: 'on wide, action ${index + 1}',
      );
    }
  });

  // sameTracks

  test('testSameTracksHoldsWhenOnlyTheLevelsDiffer', () {
    final base = Seed.musicWide.project;
    final changes = <(String, Project)>[];
    var project = base.copyWith(clipVolume: 0.5);
    changes.add(('the volume of the clips', project));
    project = base.copyWith(clipsMuted: true);
    changes.add(('the mute', project));
    project = withClip(base, 1, (clip) => clip.copyWith(volume: 0.5));
    changes.add(('the volume of red', project));
    project = base.copyWith(music: () => base.music?.copyWith(volume: 0.25));
    changes.add(('the volume of the music', project));
    project = base.copyWith(music: () => base.music?.copyWith(fadeIn: ticks(600)));
    changes.add(('the fade in', project));
    project = base.copyWith(music: () => base.music?.copyWith(fadeOut: ticks(600)));
    changes.add(('the fade out', project));
    project = withClip(project.copyWith(clipVolume: 0.5, clipsMuted: true), 0, (clip) => clip.copyWith(volume: 0));
    project = project.copyWith(music: () => project.music?.copyWith(volume: 0, fadeIn: ticks(300)));
    changes.add(('every level at once', project));

    for (final (what, changed) in changes) {
      expect(base.sameTracks(changed), isTrue, reason: what);
      expect(changed.sameTracks(base), isTrue, reason: what);
      expect(base.sameFootage(changed), isFalse, reason: what);
    }
  });

  test('testSameTracksFailsForAClipMovedCutOrTrimmedAnotherMediaCanvasMusicFileOrStart', () {
    final base = Seed.musicWide.project;
    final changes = <(String, Project)>[];
    var project = base.copyWith(clips: base.clips.reversed.toList());
    changes.add(('red moved before blue', project));
    final blue = base.clips[0];
    final cut = List.of(base.clips);
    cut[0] = blue.copyWith(duration: ticks(900));
    cut.insert(1, Clip(id: ClipID(base.nextClipID), media: blue.media, sourceStart: ticks(900), duration: ticks(900)));
    project = base.copyWith(clips: cut, nextClipID: base.nextClipID + 1);
    changes.add(('blue cut in two', project));
    project = withClip(base, 1, (clip) => clip.copyWith(duration: ticks(1800)));
    changes.add(('red trimmed at its end', project));
    project = withClip(base, 1, (clip) => clip.copyWith(sourceStart: ticks(600), duration: ticks(1800)));
    changes.add(('red trimmed at its start', project));
    final media = Map.of(base.media);
    final info = media[blue.media];
    if (info != null) {
      media[blue.media] = info.copyWith(width: 640);
    }
    project = base.copyWith(media: media);
    changes.add(('another media', project));
    project = base.copyWith(canvas: Canvas.portrait);
    changes.add(('another canvas', project));
    project = base.copyWith(music: () => Music.file(TestTone.short.file));
    changes.add(('another music file', project));
    project = base.copyWith(music: () => null);
    changes.add(('no music', project));
    project = base.copyWith(music: () => base.music?.copyWith(start: ticks(600)));
    changes.add(('another start of the music', project));

    for (final (what, changed) in changes) {
      expect(base.sameTracks(changed), isFalse, reason: what);
      expect(changed.sameTracks(base), isFalse, reason: what);
    }
  });
}
