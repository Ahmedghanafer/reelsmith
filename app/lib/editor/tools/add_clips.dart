import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:reelsmith_core/reelsmith_core.dart' as core;

import '../editor_store.dart';

/// The button `editor.addClips` in the tools row, as `AddClips.swift`. It calls `pick` for videos and photos in the
/// order she chooses, then `copyPicked` into the media folder of the store, and sends the facts to the project in
/// one `addClips`, at its end. A picker closed with nothing chosen, a copy that gives nothing, or one that ends
/// after the editor closed, sends no action. The button is disabled while a copy runs, and on no other state.
///
/// https://api.flutter.dev/flutter/widgets/State/setState.html
/// https://api.flutter.dev/flutter/widgets/State/mounted.html
class AddClips extends StatefulWidget {
  const AddClips({super.key, required this.store, required this.button});

  final EditorStore store;

  /// The button of the tools row, given the tap or null for disabled.
  final Widget Function(VoidCallback? tap) button;

  @override
  State<AddClips> createState() => _AddClipsState();
}

class _AddClipsState extends State<AddClips> {
  bool _copying = false;

  /// True while the picker is up, so a second tap shows no second picker.
  bool _picking = false;

  @override
  Widget build(BuildContext context) => widget.button(_copying ? null : _add);

  Future<void> _add() async {
    final store = widget.store;
    if (_picking) {
      return;
    }
    _picking = true;
    int chosen;
    try {
      chosen = await store.engine.pick(true, 0);
    } catch (error) {
      print('editor: the picker was not shown: $error');
      return;
    } finally {
      _picking = false;
    }
    if (chosen == 0) {
      return;
    }
    _setCopying(true);
    List<String> facts;
    try {
      facts = await store.engine.copyPicked(store.mediaFolder.path);
    } catch (error) {
      print('editor: the picked items were not copied: $error');
      facts = const [];
    }
    final media = facts.map(_mediaInfo).nonNulls.toList();
    // An editor closed during the copy writes no more: the draft may be open in another store by now.
    if (media.isNotEmpty && store.isOpen) {
      store.send(core.EditorAction.addClips(media));
    }
    _setCopying(false);
  }

  void _setCopying(bool copying) {
    if (mounted) {
      setState(() => _copying = copying);
    }
  }
}

/// A media fact as `copyPicked` gives it: the JSON the Swift encoder writes of `MediaInfo`, kind video when it is
/// missing. A fact that cannot be read is logged and left out.
core.MediaInfo? _mediaInfo(String text) {
  try {
    final json = jsonDecode(text) as Map<String, Object?>;
    final kind = json['kind'] as String?;
    return core.MediaInfo(
      id: core.MediaID((json['id']! as Map<String, Object?>)['raw']! as String),
      fileName: json['fileName']! as String,
      width: (json['width']! as num).toInt(),
      height: (json['height']! as num).toInt(),
      duration: core.Time(ticks: ((json['duration']! as Map<String, Object?>)['ticks']! as num).toInt()),
      quarterTurns: (json['quarterTurns']! as num).toInt(),
      hasSound: json['hasSound']! as bool,
      kind: kind == null ? core.MediaKind.video : core.MediaKind.values.firstWhere((value) => value.rawValue == kind),
    );
  } catch (error) {
    print('editor: a media fact was not read: $error');
    return null;
  }
}
