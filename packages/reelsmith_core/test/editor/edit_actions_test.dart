import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

void main() {
  const blue = ClipID(1);
  const red = ClipID(2);
  const green = ClipID(3);
  final empty = EditorState(Seed.empty.project);
  final threeClips = EditorState(Seed.threeClips.project);

  EditorState seedAt(int playhead) => threeClips.copyWith(playhead: Time(ticks: playhead));

  EditorState playing(EditorState state) => state.copyWith(isPlaying: true);

  List<int> lengths(EditorState state) => state.project.clips.map((clip) => clip.duration.ticks).toList();

  List<int> ids(EditorState state) => state.project.clips.map((clip) => clip.id.raw).toList();

  Clip? clip(ClipID id, EditorState state) {
    for (final candidate in state.project.clips) {
      if (candidate.id == id) {
        return candidate;
      }
    }
    return null;
  }

  MediaInfo withDuration(MediaInfo info, int ticks) => info.copyWith(duration: Time(ticks: ticks));

  void assertValid(EditorState state, String step) {
    for (final clip in state.project.clips) {
      final source = state.project.media[clip.media]?.duration ?? const Time(ticks: -1);
      expect(clip.sourceStart >= Time.zero, isTrue, reason: step);
      expect(clip.sourceStart + clip.duration <= source, isTrue, reason: step);
      expect(clip.duration.ticks.remainder(Time.frame.ticks), 0, reason: step);
      expect(clip.duration >= TimelineGeometry.minimumClip, isTrue, reason: step);
    }
    expect(state.playhead.ticks.remainder(Time.frame.ticks), 0, reason: step);
    expect(state.playhead >= Time.zero, isTrue, reason: step);
    expect(state.playhead <= state.project.duration, isTrue, reason: step);
    final selection = state.selection;
    if (selection != null) {
      expect(state.project.positionOfClip(selection), isNotNull, reason: step);
    }
  }

  test('testEveryActionReturnsAValidStateFromAValidState', () {
    final actions = <EditorAction>[
      EditorAction.addClips([TestClip.turned.info, TestClip.fast.info]),
      EditorAction.movePlayhead(const Time(ticks: 600)),
      EditorAction.split,
      EditorAction.select(const ClipID(2)),
      EditorAction.trimEnd(const ClipID(2), const Time(ticks: 5000)),
      EditorAction.trimEnd(const ClipID(2), const Time(ticks: -619)),
      EditorAction.trimStart(const ClipID(2), const Time(ticks: 619)),
      EditorAction.trimStart(const ClipID(2), const Time(ticks: -5000)),
      EditorAction.play,
      EditorAction.movePlayhead(const Time(ticks: 99999)),
      EditorAction.trimStart(const ClipID(5), const Time(ticks: 5000)),
      EditorAction.pause,
      EditorAction.deleteSelected,
      EditorAction.select(const ClipID(5)),
      EditorAction.deleteSelected,
      EditorAction.clearSelection,
      EditorAction.split,
    ];
    var state = threeClips;
    assertValid(state, 'seed');
    for (var index = 0; index < actions.length; index++) {
      state = reduce(state, actions[index]);
      assertValid(state, 'after action $index');
    }
  });

  test('testTheFiveEditsLeaveIsPlayingFalse', () {
    final playing = seedAt(600).copyWith(selection: () => red, isPlaying: true);

    expect(reduce(playing, EditorAction.addClips([TestClip.turned.info])).isPlaying, isFalse);
    expect(reduce(playing, EditorAction.split).isPlaying, isFalse);
    expect(reduce(playing, EditorAction.trimStart(red, const Time(ticks: 600))).isPlaying, isFalse);
    expect(reduce(playing, EditorAction.trimEnd(red, const Time(ticks: 600))).isPlaying, isFalse);
    expect(reduce(playing, EditorAction.deleteSelected).isPlaying, isFalse);
  });

  test('testAnEditThatIsDoneButChangesNothingStillPauses', () {
    final state = playing(threeClips);

    expect(reduce(state, EditorAction.addClips([])).isPlaying, isFalse);
    expect(reduce(state, EditorAction.trimStart(red, const Time(ticks: 19))).isPlaying, isFalse);
  });

  test('testAddClipsWithOtherFactsForAMediaInUseKeepsTheStateValid', () {
    final shorter = withDuration(TestClip.red.info, 1200);

    final next = reduce(threeClips, EditorAction.addClips([shorter]));

    assertValid(next, 'red again with a shorter length');
    expect(ids(next), [1, 2, 3, 4]);
    expect(lengths(next), [1800, 2400, 1200, 2400]);
    expect(next.project.media[TestClip.red.info.id], TestClip.red.info);
  });

  test('testAddClipsTakesAMediaOfExactlyTheShortestLength', () {
    final info = TestClip.turned.info.copyWith(duration: TimelineGeometry.minimumClip);

    expect(lengths(reduce(empty, EditorAction.addClips([info]))), [60]);
  });

  test('testAddClipsStoresTheGivenFactsOfAMediaNoClipUsesAnyMore', () {
    var state = reduce(empty, EditorAction.addClips([TestClip.red.info]));
    state = state.copyWith(selection: () => const ClipID(1));
    state = reduce(state, EditorAction.deleteSelected);
    final shorter = withDuration(TestClip.red.info, 1200);

    final next = reduce(state, EditorAction.addClips([shorter]));

    expect(lengths(next), [1200]);
    expect(next.project.media[shorter.id], shorter);
  });

  test('testAddClipsOnTheEmptySeedPutsBlueThenRedAtTheEnd', () {
    final next = reduce(empty, EditorAction.addClips([TestClip.blue.info, TestClip.red.info]));

    expect(next.project.duration, const Time(ticks: 4200));
    expect(ids(next), [1, 2]);
    expect(next.project.clips.map((clip) => clip.media).toList(), [TestClip.blue.info.id, TestClip.red.info.id]);
    expect(next.project.clips.map((clip) => clip.sourceStart).toList(), [Time.zero, Time.zero]);
    expect(next.project.media[TestClip.blue.info.id], TestClip.blue.info);
    expect(next.project.media[TestClip.red.info.id], TestClip.red.info);
    expect(next.project.nextClipID, 3);
    expect(next.playhead, Time.zero);
    expect(next.selection, isNull);
  });

  test('testAddClipsGoesToTheEndWithLengthsRoundedDownAndLeavesOutAMediaThatIsTooShort', () {
    final long = withDuration(TestClip.turned.info, 1219);
    final short = withDuration(TestClip.fast.info, 59);

    final next = reduce(threeClips, EditorAction.addClips([short, long]));

    expect(ids(next), [1, 2, 3, 4]);
    expect(lengths(next), [1800, 2400, 1200, 1200]);
    expect(next.project.clips.last.media, long.id);
    expect(next.project.media[long.id], long);
    expect(next.project.nextClipID, 5);
  });

  test('testSplitCutsTheClipUnderThePlayheadInTwo', () {
    final state = seedAt(600).copyWith(selection: () => blue);

    final next = reduce(state, EditorAction.split);

    expect(lengths(next), [600, 1200, 2400, 1200]);
    expect(ids(next), [1, 4, 2, 3]);
    expect(next.project.clips[1].media, next.project.clips[0].media);
    expect(next.project.clips[0].sourceStart, Time.zero);
    expect(next.project.clips[1].sourceStart, const Time(ticks: 600));
    expect(next.project.duration, const Time(ticks: 5400));
    expect(next.selection, blue);
    expect(next.playhead, const Time(ticks: 600));
    expect(reduce(seedAt(600), EditorAction.split).selection, isNull);
  });

  test('testTheTwoPartsOfASplitTouchInsideTheSourceOfATrimmedClip', () {
    var state = reduce(threeClips, EditorAction.trimStart(blue, const Time(ticks: 600)));
    state = state.copyWith(playhead: const Time(ticks: 400));

    final next = reduce(state, EditorAction.split);

    expect(next.project.clips[0].sourceStart, const Time(ticks: 600));
    expect(next.project.clips[0].duration, const Time(ticks: 400));
    expect(next.project.clips[1].sourceStart, const Time(ticks: 1000));
    expect(next.project.clips[1].duration, const Time(ticks: 800));
  });

  test('testCanSplitNeedsTheShortestClipOnBothSidesOfThePlayhead', () {
    expect(seedAt(600).canSplit, isTrue);
    expect(seedAt(60).canSplit, isTrue);
    expect(seedAt(40).canSplit, isFalse);
    expect(seedAt(1740).canSplit, isTrue);
    expect(seedAt(1760).canSplit, isFalse);
    expect(seedAt(1860).canSplit, isTrue);
  });

  test('testCanSplitIsFalseOnAJoinAtTheEndAndOnAnEmptyProject', () {
    expect(seedAt(1800).canSplit, isFalse);
    expect(seedAt(5400).canSplit, isFalse);
    expect(empty.canSplit, isFalse);
  });

  test('testSplitThatCannotBeDoneReturnsTheStateUnchanged', () {
    expect(reduce(playing(seedAt(1800)), EditorAction.split), playing(seedAt(1800)));
    expect(reduce(playing(seedAt(40)), EditorAction.split), playing(seedAt(40)));
    expect(reduce(playing(seedAt(5400)), EditorAction.split), playing(seedAt(5400)));
    expect(reduce(empty, EditorAction.split), empty);
  });

  test('testTrimEndMovesTheLastFrameAndTheLaterClipsFollow', () {
    final next = reduce(threeClips, EditorAction.trimEnd(red, const Time(ticks: 600)));

    expect(clip(red, next)?.duration, const Time(ticks: 1800));
    expect(clip(red, next)?.sourceStart, Time.zero);
    expect(next.project.duration, const Time(ticks: 4800));
    expect(next.project.start(green), const Time(ticks: 3600));
  });

  test('testTrimStartMovesTheFirstFrameAndTheLaterClipsFollow', () {
    final next = reduce(threeClips, EditorAction.trimStart(red, const Time(ticks: 600)));

    expect(clip(red, next)?.sourceStart, const Time(ticks: 600));
    expect(clip(red, next)?.duration, const Time(ticks: 1800));
    expect(next.project.start(red), const Time(ticks: 1800));
    expect(next.project.start(green), const Time(ticks: 3600));
  });

  test('testANegativeAmountMakesTheClipLonger', () {
    final shortEnd = reduce(threeClips, EditorAction.trimEnd(red, const Time(ticks: 1200)));
    final shortStart = reduce(threeClips, EditorAction.trimStart(red, const Time(ticks: 1200)));

    final longerEnd = reduce(shortEnd, EditorAction.trimEnd(red, const Time(ticks: -600)));
    final longerStart = reduce(shortStart, EditorAction.trimStart(red, const Time(ticks: -600)));

    expect(clip(red, longerEnd)?.duration, const Time(ticks: 1800));
    expect(clip(red, longerStart)?.duration, const Time(ticks: 1800));
    expect(clip(red, longerStart)?.sourceStart, const Time(ticks: 600));
  });

  test('testATrimAmountIsRoundedTowardZeroToWholeFrames', () {
    final shortEnd = reduce(threeClips, EditorAction.trimEnd(red, const Time(ticks: 1200)));
    final shortStart = reduce(threeClips, EditorAction.trimStart(red, const Time(ticks: 1200)));

    expect(
      clip(red, reduce(threeClips, EditorAction.trimEnd(red, const Time(ticks: 619))))?.duration,
      const Time(ticks: 1800),
    );
    expect(
      clip(red, reduce(threeClips, EditorAction.trimStart(red, const Time(ticks: 619))))?.duration,
      const Time(ticks: 1800),
    );
    expect(
      clip(red, reduce(shortEnd, EditorAction.trimEnd(red, const Time(ticks: -619))))?.duration,
      const Time(ticks: 1800),
    );
    expect(
      clip(red, reduce(shortStart, EditorAction.trimStart(red, const Time(ticks: -619))))?.duration,
      const Time(ticks: 1800),
    );
  });

  test('testATrimOfAClipWhoseMediaHasNoFactsReturnsTheStateUnchanged', () {
    var state = playing(threeClips);
    final media = Map.of(state.project.media)..remove(TestClip.red.info.id);
    state = state.copyWith(project: state.project.copyWith(media: media));

    expect(reduce(state, EditorAction.trimStart(red, const Time(ticks: 600))), state);
    expect(reduce(state, EditorAction.trimEnd(red, const Time(ticks: 600))), state);
  });

  test('testATrimOfAClipThatIsNotInTheProjectReturnsTheStateUnchanged', () {
    final state = playing(threeClips);

    expect(reduce(state, EditorAction.trimStart(const ClipID(99), const Time(ticks: 600))), state);
    expect(reduce(state, EditorAction.trimEnd(const ClipID(99), const Time(ticks: 600))), state);
  });

  test('testATrimOfAClipWhoseSourceIsNotWholeFramesKeepsItsLengthInWholeFrames', () {
    final info = withDuration(TestClip.turned.info, 1219);
    final added = reduce(empty, EditorAction.addClips([info]));

    final shorter = reduce(added, EditorAction.trimEnd(const ClipID(1), const Time(ticks: 600)));
    final longer = reduce(shorter, EditorAction.trimEnd(const ClipID(1), const Time(ticks: -5000)));

    expect(lengths(shorter), [600]);
    expect(lengths(longer), [1200]);
    assertValid(longer, 'grown back to the end of a source of 1219 ticks');
  });

  test('testATrimStopsAtItsLimit', () {
    final endShort = reduce(threeClips, EditorAction.trimEnd(red, const Time(ticks: 5000)));
    final startShort = reduce(threeClips, EditorAction.trimStart(red, const Time(ticks: 5000)));
    final endLong = reduce(threeClips, EditorAction.trimEnd(red, const Time(ticks: -600)));
    final startLong = reduce(threeClips, EditorAction.trimStart(red, const Time(ticks: -600)));

    expect(clip(red, endShort)?.duration, const Time(ticks: 60));
    expect(clip(red, startShort)?.duration, const Time(ticks: 60));
    expect(clip(red, startShort)?.sourceStart, const Time(ticks: 2340));
    expect(clip(red, endLong)?.duration, const Time(ticks: 2400));
    expect(clip(red, startLong), clip(red, threeClips));
  });

  test('testAfterATrimTheSelectionIsUnchangedAndThePlayheadStaysOrMovesToTheEnd', () {
    final early = seedAt(600).copyWith(selection: () => green);
    final late = seedAt(5400).copyWith(selection: () => green);

    final earlyNext = reduce(early, EditorAction.trimEnd(red, const Time(ticks: 600)));
    final lateNext = reduce(late, EditorAction.trimEnd(red, const Time(ticks: 600)));
    final lateStart = reduce(late, EditorAction.trimStart(red, const Time(ticks: 600)));

    expect(earlyNext.selection, green);
    expect(earlyNext.playhead, const Time(ticks: 600));
    expect(lateNext.selection, green);
    expect(lateNext.playhead, const Time(ticks: 4800));
    expect(lateStart.selection, green);
    expect(lateStart.playhead, const Time(ticks: 4800));
  });

  test('testDeleteSelectedRemovesTheClipAndClearsTheSelection', () {
    final state = seedAt(600).copyWith(selection: () => green);

    final next = reduce(state, EditorAction.deleteSelected);

    expect(next.project.duration, const Time(ticks: 4200));
    expect(ids(next), [1, 2]);
    expect(next.selection, isNull);
    expect(next.playhead, const Time(ticks: 600));
  });

  test('testAfterADeleteTheLaterClipsCloseTheGapAndThePlayheadMovesToTheEnd', () {
    final state = seedAt(5400).copyWith(selection: () => blue);

    final next = reduce(state, EditorAction.deleteSelected);

    expect(ids(next), [2, 3]);
    expect(next.project.start(red), Time.zero);
    expect(next.project.start(green), const Time(ticks: 2400));
    expect(next.playhead, const Time(ticks: 3600));
  });

  test('testDeletingTheOnlyClipLeavesAnEmptyProjectWithThePlayheadAtZero', () {
    var state = reduce(empty, EditorAction.addClips([TestClip.blue.info]));
    state = state.copyWith(selection: () => blue, playhead: const Time(ticks: 600));

    final next = reduce(state, EditorAction.deleteSelected);

    expect(next.project.clips.isEmpty, isTrue);
    expect(next.playhead, Time.zero);
    expect(next.selection, isNull);
  });

  test('testDeleteWithNothingSelectedReturnsTheStateUnchanged', () {
    expect(reduce(playing(seedAt(600)), EditorAction.deleteSelected), playing(seedAt(600)));
  });

  test('testAfterADeleteThePlayheadKeepsItsTimeAndTheMediaFactsStay', () {
    final state = seedAt(3000).copyWith(selection: () => blue);

    final next = reduce(state, EditorAction.deleteSelected);

    expect(next.playhead, const Time(ticks: 3000));
    expect(next.project.media[TestClip.blue.info.id], TestClip.blue.info);
  });

  test('testCanDeleteIsTrueExactlyWhenAClipIsSelected', () {
    final selected = threeClips.copyWith(selection: () => red);

    expect(selected.canDelete, isTrue);
    expect(threeClips.canDelete, isFalse);
    expect(empty.canDelete, isFalse);
  });
}
