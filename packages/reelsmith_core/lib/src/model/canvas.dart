import 'words.dart';

/// The shape of a project. The picture of every clip is fitted whole inside it.
enum Canvas {
  /// 16:9. `allCases` is landscape then portrait, the order on the start screen.
  landscape,

  /// 9:16.
  portrait;

  static const List<Canvas> allCases = [landscape, portrait];

  /// Pixels.
  int get width => switch (this) {
    Canvas.landscape => 1920,
    Canvas.portrait => 1080,
  };

  /// Pixels.
  int get height => switch (this) {
    Canvas.landscape => 1080,
    Canvas.portrait => 1920,
  };

  Words get words => switch (this) {
    Canvas.landscape => Words('start.landscape'),
    Canvas.portrait => Words('start.portrait'),
  };

  static const List<String> allWords = ['start.landscape', 'start.portrait'];

  /// The shape the start screen has chosen before she taps.
  static const Canvas startChoice = Canvas.landscape;
}
