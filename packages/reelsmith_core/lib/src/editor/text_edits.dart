// The text actions and the blank rule.

import 'dart:math';

import '../model/project.dart';
import '../model/text.dart';
import '../model/time.dart';
import 'editor_state.dart';
import 'text_action.dart';
import 'text_geometry.dart';

/// What reduce calls for the case text. An action that names an unknown text returns the state unchanged,
/// and so does one with a size, a line spacing, a place or an angle that is not a finite number.
EditorState reduceText(EditorState state, TextAction action) {
  final texts = List.of(state.project.texts);
  switch (action) {
    case TextActionAdd():
      if (!state.canAddText) {
        return state;
      }
      final id = TextID(state.project.nextTextID);
      final canvas = state.project.canvas;
      texts.add(
        TextItem(
          id: id,
          string: '',
          span: TextSpan.whole,
          x: canvas.width / 2,
          y: canvas.height / 2,
          rotation: 0,
          style: TextStyle.standard,
        ),
      );
      return state.copyWith(
        project: state.project.copyWith(texts: texts, nextTextID: state.project.nextTextID + 1),
        selectedText: () => id,
        selection: () => null,
        isPlaying: false,
      );
    case TextActionSelect(:final id):
      if (state.project.text(id) == null) {
        return state;
      }
      return state.copyWith(selectedText: () => id, selection: () => null);
    case TextActionSetString(:final id, :final string):
      final index = _place(id, state);
      if (index == null) {
        return state;
      }
      texts[index] = texts[index].copyWith(string: string);
    case TextActionSetStyle(:final id, :final style):
      final index = _place(id, state);
      if (index == null || !style.size.isFinite || !style.lineSpacing.isFinite) {
        return state;
      }
      texts[index] = texts[index].copyWith(
        style: style.copyWith(
          size: min(max(style.size, TextGeometry.minimumSize), TextGeometry.maximumSize),
          lineSpacing: min(max(style.lineSpacing, 0.0), 2.0),
        ),
      );
    case TextActionMove(:final id, :final x, :final y):
      final index = _place(id, state);
      if (index == null || !x.isFinite || !y.isFinite) {
        return state;
      }
      final canvas = state.project.canvas;
      texts[index] = texts[index].copyWith(
        x: min(max(x, 0.0), canvas.width.toDouble()),
        y: min(max(y, 0.0), canvas.height.toDouble()),
      );
    case TextActionTurn(:final id, :final angle):
      final index = _place(id, state);
      if (index == null || !angle.isFinite) {
        return state;
      }
      var held = angle.remainder(360);
      if (held > 180) {
        held -= 360;
      } else if (held <= -180) {
        held += 360;
      }
      if (held >= -3 && held <= 3) {
        held = 0;
      }
      texts[index] = texts[index].copyWith(rotation: held);
    case TextActionTrimStart(:final id, :final amount):
      final index = _place(id, state);
      final seen = state.project.range(id);
      if (index == null || seen == null) {
        return state;
      }
      // A seen range shorter than the minimum gives a limit below zero, so the start moves back.
      final change = _heldFrames(amount, Time.zero - seen.start, seen.duration - TextGeometry.minimumText);
      texts[index] = texts[index].copyWith(
        span: _span(seen.start + change, seen.start + seen.duration, state.project),
      );
    case TextActionTrimEnd(:final id, :final amount):
      final index = _place(id, state);
      final seen = state.project.range(id);
      if (index == null || seen == null || !(seen.duration >= TextGeometry.minimumText)) {
        return state;
      }
      final end = seen.start + seen.duration;
      final change = _heldFrames(amount, end - state.project.duration, seen.duration - TextGeometry.minimumText);
      texts[index] = texts[index].copyWith(span: _span(seen.start, end - change, state.project));
  }
  return state.copyWith(project: state.project.copyWith(texts: texts), isPlaying: false);
}

/// The Swift settleTexts(from:to:). The blank rule: a blank text exists only while it is selected. Called by reduce
/// on every path.
EditorState settleTexts(EditorState before, EditorState after) {
  // The text that was selected goes when it is blank and no longer selected. So does a text that is not
  // selected and was given a blank string.
  final texts = after.project.texts.where((text) => !(text.isBlank && text.id != after.selectedText)).toList();
  return after.copyWith(project: after.project.copyWith(texts: texts));
}

int? _place(TextID text, EditorState state) {
  final index = state.project.texts.indexWhere((candidate) => candidate.id == text);
  return index < 0 ? null : index;
}

/// The amount held between the two limits, then rounded toward zero to whole frames.
Time _heldFrames(Time amount, Time low, Time high) {
  final held = _min(_max(amount, low), high);
  return Time(ticks: held.ticks ~/ Time.frame.ticks * Time.frame.ticks);
}

/// Whole when the two ends are zero and the project length, a range otherwise.
TextSpan _span(Time start, Time end, Project project) {
  if (start == Time.zero && end == project.duration) {
    return TextSpan.whole;
  }
  return TextSpan.range(TextRange(start: start, duration: end - start));
}

/// Swift's min: the second when it is less than the first, else the first.
Time _min(Time a, Time b) => b < a ? b : a;

/// Swift's max: the second when it is at least the first, else the first.
Time _max(Time a, Time b) => b >= a ? b : a;
