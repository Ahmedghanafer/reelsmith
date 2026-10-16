class Time implements Comparable<Time> {
  /// 600 ticks are one second.
  final int ticks;

  const Time({required this.ticks});

  /// Exact for 24, 25, 30 and 60 frames a second.
  Time.frames({required int frames, required int perSecond}) : ticks = frames * 600 ~/ perSecond;

  static const Time zero = Time(ticks: 0);

  /// 20 ticks, one frame at 30 a second.
  static const Time frame = Time(ticks: 20);

  Time get roundedDownToFrame => Time(ticks: ticks - ticks.remainder(Time.frame.ticks));

  /// "mm:ss", rounded down.
  String get clockText {
    final seconds = ticks ~/ 600;
    final minutes = seconds ~/ 60;
    final rest = seconds.remainder(60);
    return '${minutes < 10 ? '0' : ''}$minutes:${rest < 10 ? '0' : ''}$rest';
  }

  Time operator +(Time b) => Time(ticks: ticks + b.ticks);

  Time operator -(Time b) => Time(ticks: ticks - b.ticks);

  bool operator <(Time b) => ticks < b.ticks;

  bool operator <=(Time b) => ticks <= b.ticks;

  bool operator >(Time b) => ticks > b.ticks;

  bool operator >=(Time b) => ticks >= b.ticks;

  @override
  int compareTo(Time other) => ticks.compareTo(other.ticks);

  Time copyWith({int? ticks}) => Time(ticks: ticks ?? this.ticks);

  @override
  bool operator ==(Object other) => other is Time && other.ticks == ticks;

  @override
  int get hashCode => ticks.hashCode;
}
