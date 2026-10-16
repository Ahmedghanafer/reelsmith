import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

void main() {
  test('testIdleGivesNoWords', () {
    expect(StartState.idle.words, isNull);
  });

  test('testCopyingGivesTheKeyOfCopying', () {
    expect(StartState.copying.words, Words('start.copying'));
  });

  test('testFailedGivesTheKeyOfNoneReadable', () {
    expect(StartState.failed.words, Words('start.noneReadable'));
  });

  test('testReadyCarriesTheProjectToOpenAndGivesNoWords', () {
    final project = Seed.twoClips.project;

    final carried = switch (StartState.ready(project)) {
      StartStateReady(:final project) => project,
      _ => fail('not ready'),
    };
    expect(carried, project);
    expect(StartState.ready(project).words, isNull);
  });

  test('testAllWordsListsExactlyTheTwoKeys', () {
    expect(StartState.allWords, ['start.copying', 'start.noneReadable']);
  });

  test('testAPickerClosedWithNothingChosenLeavesIdle', () {
    expect(StartState.idle.after(StartStateEvent.pickerClosed(0)), StartState.idle);
  });

  test('testOneOrMoreChosenVideosGiveCopying', () {
    expect(StartState.idle.after(StartStateEvent.pickerClosed(1)), StartState.copying);
    expect(StartState.idle.after(StartStateEvent.pickerClosed(3)), StartState.copying);
  });

  test('testCopyingEndsReadyWithTheFactsAddedToAnEmptyProject', () {
    final facts = [TestClip.blue.info, TestClip.red.info];
    final wanted = reduce(const EditorState(Project()), EditorAction.addClips(facts)).project;

    expect(wanted.clips.length, 2);
    expect(StartState.copying.after(StartStateEvent.copyingEnded(facts)), StartState.ready(wanted));
  });

  test('testAVideoThatCouldNotBeReadIsLeftOutWithoutAMessageOfItsOwn', () {
    // Two were chosen and the facts of one came back.
    final next = StartState.idle
        .after(StartStateEvent.pickerClosed(2))
        .after(StartStateEvent.copyingEnded([TestClip.red.info]));

    final project = switch (next) {
      StartStateReady(:final project) => project,
      _ => fail('not ready'),
    };
    expect(project.clips.map((clip) => clip.media).toList(), [const MediaID('red')]);
    expect(next.words, isNull);
  });

  test('testCopyingEndsFailedWhenNoFactsCouldBeRead', () {
    expect(StartState.copying.after(StartStateEvent.copyingEnded([])), StartState.failed);
  });

  test('testCopyingEndsFailedWhenTheFactsGiveAnEmptyProject', () {
    // Shorter than the shortest clip, so addClips leaves it out.
    final short = TestClip.green.info.copyWith(duration: const Time(ticks: 40));

    expect(StartState.copying.after(StartStateEvent.copyingEnded([short])), StartState.failed);
  });

  test('testAnEventWithNoMeaningInACaseLeavesItUnchanged', () {
    final facts = [TestClip.blue.info];
    final ready = StartState.ready(Seed.twoClips.project);

    expect(StartState.idle.after(StartStateEvent.copyingEnded(facts)), StartState.idle);
    expect(StartState.idle.after(StartStateEvent.failureConfirmed), StartState.idle);
    expect(StartState.copying.after(StartStateEvent.pickerClosed(1)), StartState.copying);
    expect(StartState.copying.after(StartStateEvent.failureConfirmed), StartState.copying);
    expect(StartState.failed.after(StartStateEvent.pickerClosed(1)), StartState.failed);
    expect(StartState.failed.after(StartStateEvent.copyingEnded(facts)), StartState.failed);
    expect(ready.after(StartStateEvent.pickerClosed(1)), ready);
    expect(ready.after(StartStateEvent.copyingEnded(facts)), ready);
    expect(ready.after(StartStateEvent.failureConfirmed), ready);
  });

  test('testConfirmingTheFailedCaseGivesIdle', () {
    expect(StartState.failed.after(StartStateEvent.failureConfirmed), StartState.idle);
  });
}
