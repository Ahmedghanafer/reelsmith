import '../model/text.dart';
import '../model/time.dart';

/// The Swift enum TextAction, one subclass per case.
sealed class TextAction {
  const TextAction();

  /// A new text: empty string, whole, the centre of the canvas, rotation 0, TextStyle.standard.
  /// It is selected. Nothing on an empty project.
  static const TextAction add = TextActionAdd();

  /// Nothing for an unknown id. Leaves isPlaying alone.
  const factory TextAction.select(TextID id) = TextActionSelect;

  /// Stored as given.
  const factory TextAction.setString(TextID id, String string) = TextActionSetString;

  /// The size and the line spacing are held between their limits.
  const factory TextAction.setStyle(TextID id, TextStyle style) = TextActionSetStyle;

  /// The new centre in canvas pixels, held inside the canvas, the edge is inside.
  const factory TextAction.move(TextID id, double x, double y) = TextActionMove;

  /// Degrees clockwise, brought above minus 180 and at most 180, and to 0 when at most 3 from it.
  const factory TextAction.turn(TextID id, double angle) = TextActionTurn;

  /// A positive amount makes the text shorter. Rounded toward zero to whole frames. Sent once, on release.
  const factory TextAction.trimStart(TextID id, Time amount) = TextActionTrimStart;

  /// A positive amount makes the text shorter. Rounded toward zero to whole frames. Sent once, on release.
  const factory TextAction.trimEnd(TextID id, Time amount) = TextActionTrimEnd;
}

final class TextActionAdd extends TextAction {
  const TextActionAdd();

  @override
  bool operator ==(Object other) => other is TextActionAdd;

  @override
  int get hashCode => (TextActionAdd).hashCode;
}

final class TextActionSelect extends TextAction {
  final TextID id;

  const TextActionSelect(this.id);

  TextActionSelect copyWith({TextID? id}) => TextActionSelect(id ?? this.id);

  @override
  bool operator ==(Object other) => other is TextActionSelect && other.id == id;

  @override
  int get hashCode => Object.hash(TextActionSelect, id);
}

final class TextActionSetString extends TextAction {
  final TextID id;
  final String string;

  const TextActionSetString(this.id, this.string);

  TextActionSetString copyWith({TextID? id, String? string}) =>
      TextActionSetString(id ?? this.id, string ?? this.string);

  @override
  bool operator ==(Object other) => other is TextActionSetString && other.id == id && other.string == string;

  @override
  int get hashCode => Object.hash(TextActionSetString, id, string);
}

final class TextActionSetStyle extends TextAction {
  final TextID id;
  final TextStyle style;

  const TextActionSetStyle(this.id, this.style);

  TextActionSetStyle copyWith({TextID? id, TextStyle? style}) => TextActionSetStyle(id ?? this.id, style ?? this.style);

  @override
  bool operator ==(Object other) => other is TextActionSetStyle && other.id == id && other.style == style;

  @override
  int get hashCode => Object.hash(TextActionSetStyle, id, style);
}

final class TextActionMove extends TextAction {
  final TextID id;
  final double x;
  final double y;

  const TextActionMove(this.id, this.x, this.y);

  TextActionMove copyWith({TextID? id, double? x, double? y}) => TextActionMove(id ?? this.id, x ?? this.x, y ?? this.y);

  @override
  bool operator ==(Object other) => other is TextActionMove && other.id == id && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(TextActionMove, id, x, y);
}

final class TextActionTurn extends TextAction {
  final TextID id;
  final double angle;

  const TextActionTurn(this.id, this.angle);

  TextActionTurn copyWith({TextID? id, double? angle}) => TextActionTurn(id ?? this.id, angle ?? this.angle);

  @override
  bool operator ==(Object other) => other is TextActionTurn && other.id == id && other.angle == angle;

  @override
  int get hashCode => Object.hash(TextActionTurn, id, angle);
}

final class TextActionTrimStart extends TextAction {
  final TextID id;
  final Time amount;

  const TextActionTrimStart(this.id, this.amount);

  TextActionTrimStart copyWith({TextID? id, Time? amount}) => TextActionTrimStart(id ?? this.id, amount ?? this.amount);

  @override
  bool operator ==(Object other) => other is TextActionTrimStart && other.id == id && other.amount == amount;

  @override
  int get hashCode => Object.hash(TextActionTrimStart, id, amount);
}

final class TextActionTrimEnd extends TextAction {
  final TextID id;
  final Time amount;

  const TextActionTrimEnd(this.id, this.amount);

  TextActionTrimEnd copyWith({TextID? id, Time? amount}) => TextActionTrimEnd(id ?? this.id, amount ?? this.amount);

  @override
  bool operator ==(Object other) => other is TextActionTrimEnd && other.id == id && other.amount == amount;

  @override
  int get hashCode => Object.hash(TextActionTrimEnd, id, amount);
}
