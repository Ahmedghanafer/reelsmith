import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

// Stay in Swift, since they read renderPlan or RenderPlan: testThePlanCarriesTheCanvasOfTheProject,
// testAPlanWrittenWithNoCanvasIsPortrait, testAWidePictureOfAnySizeFillsTheLandscapeCanvas,
// testAnUprightPictureStandsInTheMiddleOfTheLandscapeCanvas, testASquarePictureStandsInTheMiddleOfTheLandscapeCanvas
// and testTheSideThatLimitsTheFitIsExactlyTheSideOfTheLandscapeCanvas. The checks of a placement, of a plan and of
// LaunchOptions in the tests below stay in Swift too.
void main() {
  test('testTheTwoCanvasesAreLandscapeThenPortraitWithTheirSizes', () {
    expect(Canvas.allCases, [Canvas.landscape, Canvas.portrait]);
    expect(Canvas.landscape.width, 1920);
    expect(Canvas.landscape.height, 1080);
    expect(Canvas.portrait.width, 1080);
    expect(Canvas.portrait.height, 1920);
    expect(Canvas.startChoice, Canvas.landscape);
  });

  test('testEachCanvasGivesItsWordKeyAndAllWordsListsTheTwo', () {
    expect(Canvas.landscape.words, Words('start.landscape'));
    expect(Canvas.portrait.words, Words('start.portrait'));
    expect(Canvas.allWords, ['start.landscape', 'start.portrait']);
  });

  test('testAProjectIsPortraitUnlessItIsGivenTheLandscapeCanvas', () {
    const upright = Project();
    expect(upright.canvas, Canvas.portrait);
    expect(upright.clips, <Clip>[]);
    expect(upright.nextClipID, 1);

    const wide = Project(canvas: Canvas.landscape);
    expect(wide.canvas, Canvas.landscape);
    expect(wide.clips, <Clip>[]);
    expect(wide.nextClipID, 1);

    expect(Project.framesPerSecond, 30);
  });

  test('testTheTurnedClipIsPlacedAsAnUprightPictureWithItsTurn', () {
    expect(TestClip.turned.storedWidth, 1920);
    expect(TestClip.turned.storedHeight, 1080);
  });

  test('testTheWideSeedIsFoundByItsName', () {
    expect(Seed.fromRawValue('two-clips-wide'), Seed.twoClipsWide);
  });

  test('testTheWideSeedIsBlueThenRedOnTheLandscapeCanvas', () {
    const seed = Seed.twoClipsWide;
    expect(seed.testClips, [TestClip.blue, TestClip.red]);
    expect(seed.canvas, Canvas.landscape);

    final project = seed.project;
    expect(project.clips.map((clip) => clip.id).toList(), [const ClipID(1), const ClipID(2)]);
    expect(project.nextClipID, 3);
    expect(project.duration, const Time(ticks: 4200));
    expect(project.canvas, Canvas.landscape);
  });

  test('testTheOtherThreeSeedsAreOnThePortraitCanvas', () {
    for (final seed in [Seed.empty, Seed.twoClips, Seed.threeClips]) {
      expect(seed.canvas, Canvas.portrait, reason: seed.rawValue);
      expect(seed.project.canvas, Canvas.portrait, reason: seed.rawValue);
    }
  });

  test('testEveryEditKeepsTheCanvas', () {
    var state = EditorState(Seed.twoClipsWide.project);
    expect(state.project.canvas, Canvas.landscape);

    state = reduce(state, EditorAction.addClips([TestClip.green.info]));
    expect(state.project.clips.length, 3);
    expect(state.project.canvas, Canvas.landscape, reason: 'after addClips');

    state = reduce(state, EditorAction.movePlayhead(const Time(ticks: 600)));
    state = reduce(state, EditorAction.split);
    expect(state.project.clips.length, 4);
    expect(state.project.canvas, Canvas.landscape, reason: 'after split');

    state = reduce(state, EditorAction.trimStart(const ClipID(2), const Time(ticks: 600)));
    expect(state.project.duration, const Time(ticks: 4800));
    expect(state.project.canvas, Canvas.landscape, reason: 'after trimStart');

    state = reduce(state, EditorAction.trimEnd(const ClipID(2), const Time(ticks: 600)));
    expect(state.project.duration, const Time(ticks: 4200));
    expect(state.project.canvas, Canvas.landscape, reason: 'after trimEnd');

    for (final clip in state.project.clips) {
      state = reduce(state, EditorAction.select(clip.id));
      state = reduce(state, EditorAction.deleteSelected);
      expect(state.project.canvas, Canvas.landscape, reason: 'after deleteSelected');
    }
    expect(state.project.clips, <Clip>[]);
    expect(state.project.canvas, Canvas.landscape);
  });
}
