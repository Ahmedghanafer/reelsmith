import '../model/media.dart';
import '../model/sound.dart';
import '../model/time.dart';

/// The values of a tone file. The file itself is written by the Swift writers.
class TestTone {
  final String name;
  final Time duration;

  /// The pitch of the first half of the file.
  final int firstHertz;

  /// The pitch of the second half.
  final int secondHertz;

  /// Of full scale.
  final double peak;
  final int sampleRate;

  /// 1 or 2. With 2 both carry the same samples.
  final int channels;

  const TestTone({
    required this.name,
    required this.duration,
    required this.firstHertz,
    required this.secondHertz,
    required this.peak,
    required this.sampleRate,
    required this.channels,
  });

  /// The id is MediaID(name), the file name is name + ".mov", the title is the name.
  MusicFile get file => MusicFile(id: MediaID(name), fileName: '$name.mov', title: name, duration: duration);

  static const TestTone long = TestTone(
    name: 'long-tone',
    duration: Time(ticks: 6000),
    firstHertz: 880,
    secondHertz: 1320,
    peak: 0.25,
    sampleRate: 44100,
    channels: 1,
  );

  static const TestTone short = TestTone(
    name: 'short-tone',
    duration: Time(ticks: 1200),
    firstHertz: 660,
    secondHertz: 660,
    peak: 0.25,
    sampleRate: 44100,
    channels: 1,
  );

  static const List<TestTone> all = [long, short];

  TestTone copyWith({
    String? name,
    Time? duration,
    int? firstHertz,
    int? secondHertz,
    double? peak,
    int? sampleRate,
    int? channels,
  }) => TestTone(
    name: name ?? this.name,
    duration: duration ?? this.duration,
    firstHertz: firstHertz ?? this.firstHertz,
    secondHertz: secondHertz ?? this.secondHertz,
    peak: peak ?? this.peak,
    sampleRate: sampleRate ?? this.sampleRate,
    channels: channels ?? this.channels,
  );

  @override
  bool operator ==(Object other) =>
      other is TestTone &&
      other.name == name &&
      other.duration == duration &&
      other.firstHertz == firstHertz &&
      other.secondHertz == secondHertz &&
      other.peak == peak &&
      other.sampleRate == sampleRate &&
      other.channels == channels;

  @override
  int get hashCode => Object.hash(name, duration, firstHertz, secondHertz, peak, sampleRate, channels);
}
