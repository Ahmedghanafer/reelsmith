import 'dart:io';
import 'dart:math';

import 'draft.dart';

/// The folder of drafts: one folder `<folder>/<id>/` a draft, holding draft.json, Media and, once written, cover.jpg.
/// Only the shelf and `OpenDraft` make, read, write or remove anything under `folder`. The one Dart Core file that
/// imports dart:io (https://api.dart.dev/stable/dart-io/dart-io-library.html). A log line of the Swift NSLog is a
/// print, which a Flutter app on iOS sends to the device log.
class DraftShelf {
  /// The drafts folder of rule 59.
  final Directory folder;

  const DraftShelf(this.folder);

  Directory _draftFolder(DraftID id) => Directory('${folder.path}/${id.raw}');

  File _draftFile(DraftID id) => File('${folder.path}/${id.raw}/draft.json');

  /// `<folder>/<id>/Media`.
  Directory mediaFolder(DraftID id) => Directory('${folder.path}/${id.raw}/Media');

  /// `<folder>/<id>/cover.jpg`.
  File coverFile(DraftID id) => File('${folder.path}/${id.raw}/cover.jpg');

  /// A new id, `<folder>/<id>/Media` made with every folder above it, draft.json written.
  /// When either fails the new folder is removed again, so no draft is left.
  OpenDraft create(Draft draft) {
    final open = OpenDraft(shelf: this, id: DraftID(_uuidString()));
    try {
      open.mediaFolder.createSync(recursive: true);
      open.write(draft);
    } catch (error) {
      print('drafts: a new draft was not made: $error');
      try {
        _draftFolder(open.id).deleteSync(recursive: true);
      } catch (_) {}
      throw DraftError.cannotWrite;
    }
    return open;
  }

  /// One summary for each folder in `folder`, from its draft.json, unreadable when that is missing or throws.
  /// Newest changed first, a tie by id, the unreadable last by id. A folder that is not there gives none, and
  /// one that cannot be read gives none and a log line.
  List<DraftSummary> list() {
    if (!_exists(folder.path)) {
      return [];
    }
    final List<String> names;
    try {
      names = folder.listSync(followLinks: false).map((entity) => _name(entity.path)).toList();
    } catch (error) {
      print('drafts: the folder of drafts was not read: $error');
      return [];
    }
    final readable = <DraftSummary>[];
    final unreadable = <DraftSummary>[];
    for (final name in names) {
      final id = DraftID(name);
      if (!FileSystemEntity.isDirectorySync(_draftFolder(id).path)) {
        continue;
      }
      final hasCover = _exists(coverFile(id).path);
      Draft? draft;
      try {
        draft = decodeDraft(_draftFile(id).readAsBytesSync());
      } catch (_) {}
      if (draft != null) {
        readable.add(DraftSummary(id: id, draft: draft, hasCover: hasCover));
      } else {
        unreadable.add(DraftSummary.unreadable(id, hasCover: hasCover));
      }
    }
    readable.sort((first, second) {
      final one = first.changed!.microsecondsSinceEpoch;
      final two = second.changed!.microsecondsSinceEpoch;
      return one != two ? two.compareTo(one) : first.id.raw.compareTo(second.id.raw);
    });
    unreadable.sort((first, second) => first.id.raw.compareTo(second.id.raw));
    return [...readable, ...unreadable];
  }

  /// Decodes draft.json and keeps `project.keepingFiles` of the names in `<id>/Media`. Removes from `<id>/Media`
  /// every file that neither that project nor a project of the stored undo history names. Gives the draft with
  /// `history` null when the project lost a clip or its music, or when a project of the history names a file that
  /// is not there. Logs each clip, music and file it takes out, and a history it drops. A Media that is not there
  /// reads as empty, and one that is there but cannot be listed throws unreadable and touches no file. The history
  /// it gives is opened in the editor only through `Editing.withHistory`, which ends its run.
  Draft open(DraftID id) {
    final List<int> data;
    try {
      data = _draftFile(id).readAsBytesSync();
    } catch (_) {
      throw DraftError.unreadable;
    }
    var draft = decodeDraft(data);
    final media = mediaFolder(id);
    final present = <String, FileSystemEntity>{};
    if (_exists(media.path)) {
      try {
        for (final entity in media.listSync(followLinks: false)) {
          present[_name(entity.path)] = entity;
        }
      } catch (error) {
        print('drafts: the media of ${id.raw} was not read, the draft is not opened: $error');
        throw DraftError.unreadable;
      }
    }

    final project = draft.project;
    final kept = project.keepingFiles(present.keys.toSet());
    for (final clip in project.clips) {
      if (!kept.clips.contains(clip)) {
        final file = project.media[clip.media]?.fileName ?? 'no facts';
        print('drafts: clip ${clip.id.raw} taken out of ${id.raw}, its file $file is not there');
      }
    }
    final music = project.music;
    if (music != null && kept.music == null) {
      print('drafts: music taken out of ${id.raw}, its file ${music.file.fileName} is not there');
    }

    final history = draft.history;
    final named = project.fileNames.toSet();
    for (final past in [...?history?.past, ...?history?.future]) {
      named.addAll(past.fileNames);
    }
    for (final name in present.keys.toList()..sort()) {
      if (named.contains(name)) {
        continue;
      }
      try {
        present[name]!.deleteSync(recursive: true);
        print('drafts: file $name removed from ${id.raw}, no project names it');
      } catch (error) {
        print('drafts: file $name of ${id.raw} was not removed: $error');
      }
    }

    final lost = !_sameClips(kept.clips, project.clips) || kept.music != project.music;
    if (history != null && (lost || !present.keys.toSet().containsAll(named))) {
      print('drafts: the undo history of ${id.raw} dropped, it cannot be kept whole');
      draft = draft.copyWith(history: () => null);
    }
    return draft.copyWith(project: kept);
  }

  /// Removes `<folder>/<id>` whole.
  void delete(DraftID id) {
    try {
      _draftFolder(id).deleteSync(recursive: true);
    } catch (error) {
      print('drafts: ${id.raw} was not deleted: $error');
      throw DraftError.cannotWrite;
    }
  }

  /// Removes `folder` whole, for -drafts fresh.
  void removeAll() {
    try {
      folder.deleteSync(recursive: true);
    } catch (error) {
      print('drafts: the folder of drafts was not removed: $error');
      throw DraftError.cannotWrite;
    }
  }

  DraftShelf copyWith({Directory? folder}) => DraftShelf(folder ?? this.folder);

  @override
  bool operator ==(Object other) => other is DraftShelf && other.folder.path == folder.path;

  @override
  int get hashCode => folder.path.hashCode;
}

/// A draft on the shelf that the editor has open.
class OpenDraft {
  final DraftShelf shelf;
  final DraftID id;

  const OpenDraft({required this.shelf, required this.id});

  /// `shelf.mediaFolder(id)`.
  Directory get mediaFolder => shelf.mediaFolder(id);

  /// `shelf.coverFile(id)`.
  File get coverFile => shelf.coverFile(id);

  /// `encodeDraft`, then `<folder>/<id>/draft.json` written whole or not at all, as the atomic option of Swift's
  /// `Data.write`: the bytes go to a temporary name in the same folder, flushed, then renamed over the old file. A
  /// rename in one folder replaces the file in one step (https://api.dart.dev/stable/dart-io/File/renameSync.html),
  /// so a cut write leaves the old draft.json whole. Every failure, a number the codec cannot write among them,
  /// throws cannotWrite and leaves no temporary file.
  void write(Draft draft) {
    final file = shelf._draftFile(id);
    final temporary = File('${shelf._draftFolder(id).path}/.draft.json.${_uuidString()}');
    try {
      temporary.writeAsBytesSync(encodeDraft(draft), flush: true);
      temporary.renameSync(file.path);
    } catch (error) {
      print('drafts: ${id.raw} was not written: $error');
      try {
        if (temporary.existsSync()) {
          temporary.deleteSync();
        }
      } catch (_) {}
      throw DraftError.cannotWrite;
    }
  }

  OpenDraft copyWith({DraftShelf? shelf, DraftID? id}) => OpenDraft(shelf: shelf ?? this.shelf, id: id ?? this.id);

  @override
  bool operator ==(Object other) => other is OpenDraft && other.shelf == shelf && other.id == id;

  @override
  int get hashCode => Object.hash(shelf, id);
}

/// Swift's FileManager.fileExists(atPath:): true for a file, a folder or a link to either.
bool _exists(String path) => FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound;

/// The last part of a path that dart:io listed.
String _name(String path) => path.substring(path.lastIndexOf(Platform.pathSeparator) + 1);

bool _sameClips(List<Object> one, List<Object> two) {
  if (one.length != two.length) {
    return false;
  }
  for (var index = 0; index < one.length; index++) {
    if (one[index] != two[index]) {
      return false;
    }
  }
  return true;
}

/// A random UUID of version 4 in upper case, as Swift's UUID().uuidString.
String _uuidString() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}
