import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

/// The volume of a clip goes from 0 to 2, on `two-clips-wide`.
void main() {
  const red = ClipID(2);
  final wide = EditorState(Seed.twoClipsWide.project);

  double? volumeOfRed(double volume) {
    final clips = reduce(wide, EditorAction.sound(SoundAction.setVolumeOfClip(red, volume))).project.clips;
    final found = clips.where((clip) => clip.id == red);
    return found.isEmpty ? null : found.first.volume;
  }

  test('testSetVolumeOfClipHoldsTwoAndAHalfAtTwoAndMinusOneAtZeroAndKeepsOneAndAHalf', () {
    expect(volumeOfRed(2.5), 2);
    expect(volumeOfRed(-1), 0);
    expect(volumeOfRed(1.5), 1.5);
  });

  test('testClipInfoOfAClipAtTwoEndsWithTwoHundredV', () {
    final state = reduce(wide, EditorAction.sound(SoundAction.setVolumeOfClip(red, 2)));
    expect(state.project.clipInfo(red), 'red 0+2400 200 v');
  });
}
