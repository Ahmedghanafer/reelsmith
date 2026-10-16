import 'dart:convert';

import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

// Holds the kind of a media, the volume of a clip, the length of a photo clip and `clipInfo`, from the seed
// `photo-wide`.
//
// Stay in Swift, since they read the plan: testThePlanOfPhotoWideHasAStillSegmentInTheMiddle and
// testAClipAtAVolumeGivesItsSegmentThatVolumeAndTheClipsKeepTheirs.
void main() {
  /// A draft of `two-clips-wide` at 1080p and 30, as a draft of version 1 was written: no clip has `volume` and
  /// no media fact has `kind`.
  const versionOne =
      '{"changed":813704709,"exportSettings":{"rate":{"thirty":{}},"size":{"hd1080":{}}},"project":{"canvas":{"landscape":{}},"clipVolume":1,"clips":[{"duration":{"ticks":1800},"id":{"raw":1},"media":{"raw":"blue"},"sourceStart":{"ticks":0}},{"duration":{"ticks":2400},"id":{"raw":2},"media":{"raw":"red"},"sourceStart":{"ticks":0}}],"clipsMuted":false,"media":[{"raw":"red"},{"duration":{"ticks":2400},"fileName":"red.mov","hasSound":true,"height":1920,"id":{"raw":"red"},"quarterTurns":0,"width":1080},{"raw":"blue"},{"duration":{"ticks":1800},"fileName":"blue.mov","hasSound":true,"height":1080,"id":{"raw":"blue"},"quarterTurns":0,"width":1920}],"nextClipID":3,"nextTextID":1,"texts":[]},"version":1}';

  EditorState sendSound(EditorState state, SoundAction action) => reduce(state, EditorAction.sound(action));

  EditorState playing(Project project) => EditorState(project).copyWith(isPlaying: true);

  /// The project with the volume of the clip at each index replaced.
  Project withVolumes(Project project, Map<int, double> volumes) {
    final clips = List.of(project.clips);
    volumes.forEach((index, volume) => clips[index] = clips[index].copyWith(volume: volume));
    return project.copyWith(clips: clips);
  }

  /// The project with every clip at that volume.
  Project allAt(Project project, double volume) =>
      withVolumes(project, {for (var index = 0; index < project.clips.length; index++) index: volume});

  test('testAVersionOneTextDecodesWithEachClipAtOneAndEachMediaAVideo', () {
    final draft = decodeDraft(utf8.encode(versionOne));

    expect(draft.version, 1);
    expect(draft.project, Seed.twoClipsWide.project);
    expect(draft.project.clips.map((clip) => clip.volume).toList(), [1, 1]);
    expect(draft.project.media.length, 2);
    for (final info in draft.project.media.values) {
      expect(info.kind, MediaKind.video, reason: info.id.raw);
    }
  });

  test('testADraftOfPhotoWideWithAClipAtAVolumeRoundTripsAtVersionOne', () {
    final project = withVolumes(Seed.photoWide.project, {1: 0.35});
    final draft = Draft(
      project: project,
      exportSettings: ExportSettings.startChoice,
      changed: DateTime.fromMillisecondsSinceEpoch(1792011909 * 1000, isUtc: true),
    );

    final back = decodeDraft(encodeDraft(draft));

    expect(back, draft);
    expect(back.project.clips[1].volume, 0.35);
    expect(back.project.media[const MediaID('magenta')]?.kind, MediaKind.photo);
    expect(back.version, 1);
    expect(Draft.currentVersion, 1);
  });

  test('testTheTwoLengthsOfAPhoto', () {
    expect(MediaInfo.photoLength, const Time(ticks: 1800));
    expect(MediaInfo.photoLongest, const Time(ticks: 108000));
  });

  test('testAPhotoIsAddedForThreeSecondsAndTrimmedWithinThreeMinutes', () {
    final added = reduce(
      const EditorState(Project(canvas: Canvas.landscape)),
      EditorAction.addClips([TestPhoto.magenta.info]),
    );
    final clip = added.project.clips.first;

    expect(added.project.clips.length, 1);
    expect(clip.sourceStart, Time.zero);
    expect(clip.duration, const Time(ticks: 1800));

    final longer = reduce(added, EditorAction.trimEnd(clip.id, const Time(ticks: -600)));
    expect(longer.project.clips[0].duration, const Time(ticks: 2400));

    final longest = reduce(added, EditorAction.trimEnd(clip.id, const Time(ticks: -200000)));
    expect(longest.project.clips[0].duration, const Time(ticks: 108000));

    final earlier = reduce(added, EditorAction.trimStart(clip.id, const Time(ticks: -600)));
    expect(earlier.project, added.project);
  });

  test('testATestClipIsStillAddedWhole', () {
    final added = reduce(const EditorState(Project()), EditorAction.addClips([TestClip.red.info]));

    expect(added.project.clips.map((clip) => clip.duration).toList(), [const Time(ticks: 2400)]);
    expect(added.project.clips.map((clip) => clip.sourceStart).toList(), [Time.zero]);
  });

  test('testASplitGivesBothHalvesTheVolumeOfTheClip', () {
    final project = withVolumes(Seed.twoClipsWide.project, {0: 0.4});
    final state = EditorState(project).copyWith(playhead: const Time(ticks: 600));

    final split = reduce(state, EditorAction.split);

    expect(split.project.clips.length, 3);
    expect(split.project.clips.map((clip) => clip.volume).toList(), [0.4, 0.4, 1]);
  });

  test('testADeleteKeepsTheVolumeOfTheClipsLeft', () {
    final project = withVolumes(Seed.threeClips.project, {0: 0.4, 2: 0.7});
    final state = EditorState(project).copyWith(selection: () => const ClipID(2));

    final deleted = reduce(state, EditorAction.deleteSelected);

    expect(deleted.project.clips.map((clip) => clip.id).toList(), [const ClipID(1), const ClipID(3)]);
    expect(deleted.project.clips.map((clip) => clip.volume).toList(), [0.4, 0.7]);
  });

  test('testTheVolumeOfAClipIsHeldBetweenZeroAndTwoAndPlaysOn', () {
    final state = playing(allAt(Seed.photoWide.project, 0.5));

    final above = sendSound(state, const SoundAction.setVolumeOfClip(ClipID(1), 2.5));
    expect(above.project.clips.map((clip) => clip.volume).toList(), [2, 0.5, 0.5]);
    expect(above.isPlaying, isTrue);

    final below = sendSound(state, const SoundAction.setVolumeOfClip(ClipID(1), -1));
    expect(below.project.clips.map((clip) => clip.volume).toList(), [0, 0.5, 0.5]);
    expect(below.isPlaying, isTrue);

    final quarter = sendSound(state, const SoundAction.setVolumeOfClip(ClipID(2), 0.25));
    expect(quarter.project.clips.map((clip) => clip.volume).toList(), [0.5, 0.25, 0.5]);
    expect(quarter.isPlaying, isTrue);
    expect(quarter.project.clipVolume, 1);
  });

  test('testAVolumeOfAClipThatChangesNothingReturnsTheStateUnchanged', () {
    final state = playing(withVolumes(Seed.photoWide.project, {0: 0.5}));

    expect(sendSound(state, const SoundAction.setVolumeOfClip(ClipID(9), 0.25)), state);
    expect(sendSound(state, const SoundAction.setVolumeOfClip(ClipID(1), 0.5)), state);
    expect(sendSound(state, const SoundAction.setVolumeOfClip(ClipID(1), double.nan)), state);
    expect(sendSound(state, const SoundAction.setVolumeOfClip(ClipID(1), double.infinity)), state);
    expect(sendSound(state, const SoundAction.setVolumeOfClip(ClipID(1), double.negativeInfinity)), state);
  });

  test('testNoOtherActionChangesTheVolumeOfAClip', () {
    final project = allAt(Seed.photoWide.project, 0.4).copyWith(music: () => Music.file(TestTone.long.file));
    final start = EditorState(
      project,
    ).copyWith(playhead: const Time(ticks: 600), selection: () => const ClipID(1));
    final added = reduce(start, const EditorAction.text(TextAction.add));
    const text = TextID(1);
    final actions = <EditorAction>[
      EditorAction.addClips([TestClip.green.info]),
      EditorAction.split,
      const EditorAction.trimStart(ClipID(1), Time(ticks: 300)),
      const EditorAction.trimEnd(ClipID(3), Time(ticks: 300)),
      EditorAction.deleteSelected,
      const EditorAction.select(ClipID(2)),
      EditorAction.clearSelection,
      const EditorAction.movePlayhead(Time(ticks: 900)),
      EditorAction.play,
      EditorAction.pause,
      const EditorAction.text(TextAction.add),
      const EditorAction.text(TextAction.select(text)),
      const EditorAction.text(TextAction.setString(text, 'Peace')),
      const EditorAction.text(TextAction.setStyle(text, TextStyle.standard)),
      const EditorAction.text(TextAction.move(text, 100, 100)),
      const EditorAction.text(TextAction.turn(text, 45)),
      const EditorAction.text(TextAction.trimStart(text, Time(ticks: 60))),
      const EditorAction.text(TextAction.trimEnd(text, Time(ticks: 60))),
      const EditorAction.sound(SoundAction.open),
      const EditorAction.sound(SoundAction.setClipVolume(0.2)),
      const EditorAction.sound(SoundAction.muteClips(true)),
      EditorAction.sound(SoundAction.setMusic(TestTone.short.file)),
      const EditorAction.sound(SoundAction.setMusicVolume(0.3)),
      const EditorAction.sound(SoundAction.setMusicStart(Time(ticks: 600))),
      const EditorAction.sound(SoundAction.setFadeIn(Time(ticks: 300))),
      const EditorAction.sound(SoundAction.setFadeOut(Time(ticks: 300))),
      const EditorAction.sound(SoundAction.removeMusic),
    ];

    for (final action in actions) {
      for (final before in [start, added]) {
        final after = reduce(before, action);
        for (final clip in after.project.clips) {
          if (before.project.positionOfClip(clip.id) != null) {
            expect(clip.volume, 0.4, reason: '$action on clip ${clip.id.raw}');
          }
        }
      }
    }
  });

  test('testTheInfoOfEachClipOfPhotoWide', () {
    final project = Seed.photoWide.project;

    expect(project.clipInfo(const ClipID(1)), 'blue 0+1800 100 v');
    expect(project.clipInfo(const ClipID(2)), 'magenta 0+1800 100 p');
    expect(project.clipInfo(const ClipID(3)), 'red 0+2400 100 v');
    expect(project.clipInfo(const ClipID(9)), isNull);

    final quieter = reduce(
      EditorState(project),
      const EditorAction.sound(SoundAction.setVolumeOfClip(ClipID(1), 0.355)),
    );
    expect(quieter.project.clipInfo(const ClipID(1)), 'blue 0+1800 36 v');
  });
}
