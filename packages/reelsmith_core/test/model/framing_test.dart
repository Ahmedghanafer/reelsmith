import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

// Holds the framing of a clip in the model and the edits, on the seed `two-clips`: a portrait canvas of 1080 by 1920,
// blue (1920 by 1080, clip 1) then red (1080 by 1920, clip 2).
//
// Stay in Swift, since they read the plan through segments: testThePlanOfTwoClipsAtTheStandardFramingIsTheFitOfToday,
// testFillCoversTheCanvasWithBlue, testFitAtZoomTwoDoublesBlueAroundTheCentre, testAnOffsetPastTheEdgeIsStoredHeld,
// testABlurredBackdropFillsTheCanvasOnlyWhereThePictureLeavesBars and testThePlanAt4KHasEveryRectangleTwiceAsLarge.
// Ported with the draft codec:
// testAVersionOneTextWhoseClipsLackFramingDecodesToTheStandardFraming and
// testADraftOfTwoClipsWithBlueFilledBlurredAndZoomedRoundTrips.
void main() {
  const blue = ClipID(1);
  const red = ClipID(2);

  /// The project with the framing of the clip at the index replaced.
  Project framed(Project project, int index, Framing framing) {
    final clips = List.of(project.clips);
    clips[index] = clips[index].copyWith(framing: framing);
    return project.copyWith(clips: clips);
  }

  /// `two-clips` with blue framed as given, not playing.
  EditorState seeded({Framing blue = Framing.standard}) => EditorState(framed(Seed.twoClips.project, 0, blue));

  EditorState playing(EditorState state) => state.copyWith(isPlaying: true);

  EditorState frame(EditorState state, FrameAction action) => reduce(state, EditorAction.frame(action));

  test('testEachFrameActionChangesOnlyTheNamedClipPausesAndIsOneUndoStep', () {
    final start = playing(seeded());
    final actions = <(FrameAction, Framing)>[
      (FrameAction.setFit(blue, Fit.fill), const Framing(fit: Fit.fill)),
      (FrameAction.setBackdrop(blue, Backdrop.blurred), const Framing(backdrop: Backdrop.blurred)),
      (FrameAction.setZoom(blue, 2.5), const Framing(zoom: 2.5)),
      (FrameAction.setOffset(blue, 0, 0.25), const Framing(y: 0.25)),
    ];
    for (final (action, framing) in actions) {
      final after = frame(start, action);

      expect(after.project.clips[0].framing, framing, reason: '$action');
      expect(after.project.clips[1], start.project.clips[1], reason: '$action');
      expect(after.isPlaying, isFalse, reason: '$action');

      final edited = Editing(start).after(EditorAction.frame(action));
      expect(edited.history.past.length, 1, reason: '$action');
      expect(edited.state.project, after.project, reason: '$action');
      expect(edited.undone().state.project, start.project, reason: '$action');
    }
  });

  test('testSetZoomHoldsItsValueAndTheOffsetAgain', () {
    expect(
      frame(seeded(blue: const Framing(zoom: 2)), FrameAction.setZoom(blue, 0.5)).project.clips[0].framing.zoom,
      1,
    );
    expect(frame(seeded(), FrameAction.setZoom(blue, 9)).project.clips[0].framing.zoom, 4);

    final moved = frame(seeded(blue: const Framing(zoom: 2)), FrameAction.setOffset(blue, 0.5, 0));
    expect(moved.project.clips[0].framing.x, closeTo(0.5, 0.0001));

    final back = frame(moved, FrameAction.setZoom(blue, 1));
    expect(back.project.clips[0].framing.zoom, 1);
    expect(back.project.clips[0].framing.x, 0);
  });

  test('testNothingChangesForAnUnknownIdOrAValueThatIsNotFinite', () {
    final start = playing(seeded(blue: const Framing(zoom: 2)));
    const unknown = ClipID(9);
    final refused = <FrameAction>[
      FrameAction.setFit(unknown, Fit.fill),
      FrameAction.setBackdrop(unknown, Backdrop.blurred),
      FrameAction.setZoom(unknown, 2),
      FrameAction.setOffset(unknown, 0.1, 0.1),
      FrameAction.applyToAll(unknown),
      FrameAction.setZoom(blue, double.nan),
      FrameAction.setZoom(blue, double.infinity),
      FrameAction.setOffset(blue, double.nan, 0.1),
      FrameAction.setOffset(blue, 0.1, double.negativeInfinity),
    ];
    for (var index = 0; index < refused.length; index++) {
      expect(frame(start, refused[index]), start, reason: 'action $index');
    }
  });

  test('testApplyToAllGivesEveryClipTheFitAndBackdropAndKeepsTheirZoomAndOffset', () {
    var start = seeded(blue: const Framing(fit: Fit.fill, backdrop: Backdrop.blurred));
    start = start.copyWith(project: framed(start.project, 1, const Framing(zoom: 2, x: 0.3, y: -0.2)));

    final edited = Editing(start).after(EditorAction.frame(FrameAction.applyToAll(blue)));
    final after = edited.state;

    expect(after.project.clips[0].framing, const Framing(fit: Fit.fill, backdrop: Backdrop.blurred));
    expect(
      after.project.clips[1].framing,
      const Framing(fit: Fit.fill, backdrop: Backdrop.blurred, zoom: 2, x: 0.3, y: -0.2),
    );
    expect(edited.history.past.length, 1);
    expect(edited.undone().state.project, start.project);
  });

  test('testApplyToAllHoldsTheOffsetOfEachClipAgain', () {
    var start = seeded(blue: const Framing(fit: Fit.fill, x: 0.3));
    start = start.copyWith(project: framed(start.project, 1, const Framing(backdrop: Backdrop.blurred)));

    final after = frame(start, FrameAction.applyToAll(red));

    expect(after.project.clips[0].framing, const Framing(backdrop: Backdrop.blurred));
    expect(after.project.clips[1].framing, const Framing(backdrop: Backdrop.blurred));
  });

  test('testASplitGivesBothHalvesTheFramingAndTheOtherEditsKeepIt', () {
    const framing = Framing(fit: Fit.fill, zoom: 1.5);
    final state = seeded(blue: framing).copyWith(playhead: const Time(ticks: 600), selection: () => blue);

    final split = reduce(state, EditorAction.split);
    expect(split.project.clips.map((clip) => clip.framing).toList(), [framing, framing, Framing.standard]);

    final moved = reduce(state, EditorAction.moveClip(blue, 2));
    expect(moved.project.clips.map((clip) => clip.id).toList(), [red, blue]);
    expect(moved.project.clips[1].framing, framing);

    expect(reduce(state, EditorAction.cutBefore).project.clips[0].framing, framing);
    expect(reduce(state, EditorAction.cutAfter).project.clips[0].framing, framing);
    expect(reduce(state, EditorAction.cutBefore).project.clips[0].duration, isNot(state.project.clips[0].duration));
    expect(reduce(state, EditorAction.cutAfter).project.clips[0].duration, isNot(state.project.clips[0].duration));

    final added = reduce(state, EditorAction.addClips([TestClip.green.info]));
    expect(added.project.clips.length, 3);
    expect(added.project.clips[2].framing, Framing.standard);
  });

  test('testFramedByHandIsTheSelectedClipUnderThePlayheadWithNoTextSelected', () {
    final state = seeded().copyWith(selection: () => blue, playhead: const Time(ticks: 600));
    expect(state.framedByHand, blue);

    final text = state.copyWith(selectedText: () => const TextID(1));
    expect(text.framedByHand, isNull);

    final none = state.copyWith(selection: () => null);
    expect(none.framedByHand, isNull);

    final other = state.copyWith(playhead: const Time(ticks: 2400));
    expect(other.framedByHand, isNull);
  });

  test('testFrameInfoReadsTheFramingOfTheSelectedClip', () {
    var state = seeded();
    expect(state.frameInfo, 'none');

    state = reduce(state, EditorAction.select(blue));
    expect(state.frameInfo, 'fit black 100 0,0');

    state = frame(state, FrameAction.setFit(blue, Fit.fill));
    state = frame(state, FrameAction.setBackdrop(blue, Backdrop.blurred));
    state = frame(state, FrameAction.setZoom(blue, 1.5));
    state = frame(state, FrameAction.setOffset(blue, 0.1, -0.05));
    final framing = state.project.clips[0].framing;
    expect(framing.x, closeTo(0.1, 0.0001));
    expect(framing.y, closeTo(-0.05, 0.0001));
    expect(state.frameInfo, 'fill blur 150 100,-50');
  });

  test('testSameFootageHoldsBetweenProjectsThatDifferOnlyInAFraming', () {
    final plain = Seed.twoClips.project;
    final framedProject = framed(
      plain,
      1,
      const Framing(fit: Fit.fill, backdrop: Backdrop.blurred, zoom: 3, x: 0.1, y: 0.2),
    );

    expect(plain, isNot(framedProject));
    expect(plain.sameFootage(framedProject), isTrue);
    expect(framedProject.sameFootage(plain), isTrue);
  });
}
