class Words {
  /// A word key written screen.thing, for example "export.saved".
  final String key;

  /// Put into the text at %1$@, %2$@ and so on. Numbers are handed over as text with the digits 0 to 9.
  final List<String> arguments;

  const Words(this.key, [this.arguments = const []]);

  Words copyWith({String? key, List<String>? arguments}) =>
      Words(key ?? this.key, arguments ?? this.arguments);

  @override
  bool operator ==(Object other) {
    if (other is! Words || other.key != key || other.arguments.length != arguments.length) {
      return false;
    }
    for (var index = 0; index < arguments.length; index++) {
      if (other.arguments[index] != arguments[index]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(key, Object.hashAll(arguments));

  @override
  String toString() => 'Words($key, $arguments)';
}
