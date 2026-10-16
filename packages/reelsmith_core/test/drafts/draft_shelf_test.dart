import 'dart:io';
import 'dart:math';

import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

// Holds the shelf of drafts in a folder: create, list, open with its repair, write, delete and removeAll.
// Each test works in a new folder under the temporary folder, removed at its end.
void main() {
  /// 2026-10-14 00:00:00 in UTC.
  final midnight = DateTime.fromMillisecondsSinceEpoch(1791936000 * 1000, isUtc: true);

  /// A UUID string, as Swift's UUID().uuidString gives it.
  String uuid() {
    final random = Random.secure();
    final hex = List.generate(32, (_) => random.nextInt(16).toRadixString(16).toUpperCase()).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// A shelf on a folder that is not there yet, inside a new folder that is removed at the end of the test.
  DraftShelf makeShelf() {
    final root = Directory.systemTemp.createTempSync('draft-shelf-');
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
    return DraftShelf(Directory('${root.path}/Drafts'));
  }

  DateTime at(int hour) => midnight.add(Duration(hours: hour));

  Draft draft(Seed seed, {int hour = 10}) =>
      Draft(project: seed.project, exportSettings: ExportSettings.startChoice, changed: at(hour));

  Directory folderOf(DraftID id, DraftShelf shelf) => Directory('${shelf.folder.path}/${id.raw}');

  /// A media file: a few bytes under the name the project gives.
  void put(List<String> names, Directory folder) {
    for (final name in names) {
      File('${folder.path}/$name').writeAsBytesSync([1, 2, 3]);
    }
  }

  List<String> names(Directory folder) => [
    for (final entity in folder.listSync())
      entity.path.substring(entity.path.lastIndexOf(Platform.pathSeparator) + 1),
  ]..sort();

  /// A folder in the shelf with a draft.json that holds the text given, or none for null.
  DraftID odd(String? text, DraftShelf shelf) {
    final id = DraftID(uuid());
    final place = folderOf(id, shelf);
    place.createSync(recursive: true);
    if (text != null) {
      File('${place.path}/draft.json').writeAsStringSync(text);
    }
    return id;
  }

  /// two-clips-wide with red deleted through the editing, so the history holds that delete.
  Editing deletedRed() {
    final project = Seed.twoClipsWide.project;
    final red = project.clips.firstWhere((clip) => clip.media == TestClip.red.info.id).id;
    final edited = Editing(EditorState(project)).after(EditorAction.select(red)).after(EditorAction.deleteSelected);
    expect(edited.state.project.fileNames, ['blue.mov']);
    expect(edited.history.past.any((past) => past.fileNames.contains('red.mov')), isTrue);
    return edited;
  }

  test('testCreateMakesTheFoldersAndOpenGivesTheDraft', () {
    final shelf = makeShelf();
    expect(shelf.folder.existsSync(), isFalse);
    final made = draft(Seed.twoClipsWide);

    final open = shelf.create(made);
    put(['blue.mov', 'red.mov'], open.mediaFolder);

    expect(open.mediaFolder.path, '${shelf.folder.path}/${open.id.raw}/Media');
    expect(open.coverFile.path, '${shelf.folder.path}/${open.id.raw}/cover.jpg');
    expect(open.mediaFolder.existsSync(), isTrue);
    expect(FileSystemEntity.isDirectorySync(open.mediaFolder.path), isTrue);
    expect(shelf.open(open.id), made);
    expect(shelf.create(made).id, isNot(open.id));
  });

  test('testAFolderThatIsNotThereListsNone', () {
    final shelf = makeShelf();
    expect(shelf.list(), isEmpty);
  });

  test('testTheListIsNewestFirstThenTheUnreadableByID', () {
    final shelf = makeShelf();
    final ten = shelf.create(draft(Seed.twoClipsWide, hour: 10));
    final twelve = shelf.create(draft(Seed.textWide, hour: 12));
    final eleven = shelf.create(draft(Seed.musicWide, hour: 11));
    put(['cover.jpg'], folderOf(eleven.id, shelf));
    final unreadable = [odd(null, shelf), odd('broken', shelf)]..sort((one, two) => one.raw.compareTo(two.raw));

    final list = shelf.list();

    expect(list.map((summary) => summary.id).toList(), [twelve.id, eleven.id, ten.id, ...unreadable]);
    expect(list.map((summary) => summary.changed).toList(), [at(12), at(11), at(10), null, null]);
    expect(list.map((summary) => summary.hasCover).toList(), [false, true, false, false, false]);
    expect(list[0], DraftSummary(id: twelve.id, draft: draft(Seed.textWide, hour: 12), hasCover: false));
    expect(list[3], DraftSummary.unreadable(unreadable[0], hasCover: false));
    expect(list[4], DraftSummary.unreadable(unreadable[1], hasCover: false));
  });

  test('testOpenTakesOutTheClipsAndTheMusicWhoseFilesAreMissing', () {
    final shelf = makeShelf();
    final open = shelf.create(draft(Seed.musicWide));
    put(['blue.mov'], open.mediaFolder);

    final project = shelf.open(open.id).project;

    expect(project.clips.map((clip) => clip.media).toList(), [TestClip.blue.info.id]);
    expect(project.clips, [Seed.musicWide.project.clips[0]]);
    expect(project.music, isNull);
    expect(names(open.mediaFolder), ['blue.mov']);
  });

  test('testOpenRemovesAFileTheProjectDoesNotName', () {
    final shelf = makeShelf();
    final made = draft(Seed.musicWide);
    final open = shelf.create(made);
    put(['blue.mov', 'red.mov', 'long-tone.mov', 'old.mov'], open.mediaFolder);

    expect(shelf.open(open.id), made);
    expect(names(open.mediaFolder), ['blue.mov', 'long-tone.mov', 'red.mov']);
  });

  test('testAnUnreadableDraftDoesNotOpenAndLosesNoFile', () {
    final shelf = makeShelf();
    for (final text in [null, 'broken']) {
      final id = odd(text, shelf);
      final media = shelf.mediaFolder(id);
      media.createSync(recursive: true);
      put(['blue.mov', 'old.mov'], media);
      final before = names(folderOf(id, shelf));

      expect(() => shelf.open(id), throwsA(DraftError.unreadable));
      expect(names(folderOf(id, shelf)), before);
      expect(names(media), ['blue.mov', 'old.mov']);
    }
  });

  test('testAMediaFolderThatCannotBeListedDoesNotOpenAndLosesNoFile', () {
    final shelf = makeShelf();
    final open = shelf.create(draft(Seed.musicWide));
    open.mediaFolder.deleteSync(recursive: true);
    File(open.mediaFolder.path).writeAsBytesSync([4, 5, 6]);
    final json = File('${folderOf(open.id, shelf).path}/draft.json');
    final before = json.readAsBytesSync();

    expect(() => shelf.open(open.id), throwsA(DraftError.unreadable));
    expect(json.readAsBytesSync(), before);
    expect(File(open.mediaFolder.path).readAsBytesSync(), [4, 5, 6]);
    expect(names(folderOf(open.id, shelf)), ['Media', 'draft.json']);
  });

  test('testTheSecondOfTwoWritesStaysAndNothingElseChanges', () {
    final shelf = makeShelf();
    final open = shelf.create(draft(Seed.twoClipsWide));
    final file = File('${open.mediaFolder.path}/blue.mov');
    file.writeAsBytesSync([7, 8, 9]);
    put(['red.mov'], open.mediaFolder);
    final first = draft(Seed.textWide, hour: 11);
    final second = draft(Seed.musicWide, hour: 12);

    open.write(first);
    open.write(second);

    final json = File('${folderOf(open.id, shelf).path}/draft.json');
    expect(decodeDraft(json.readAsBytesSync()), second);
    expect(names(folderOf(open.id, shelf)), ['Media', 'draft.json']);
    expect(names(open.mediaFolder), ['blue.mov', 'red.mov']);
    expect(file.readAsBytesSync(), [7, 8, 9]);
    expect(File('${open.mediaFolder.path}/red.mov').readAsBytesSync(), [1, 2, 3]);
  });

  /// Not a Swift test: it holds that a write is whole or not at all, and that a draft not made leaves no folder.
  test('aFailedWriteLeavesTheOldDraftWholeAndAFailedCreateNoFolder', () {
    final shelf = makeShelf();
    final made = draft(Seed.twoClipsWide);
    final open = shelf.create(made);
    final json = File('${folderOf(open.id, shelf).path}/draft.json');
    final before = json.readAsBytesSync();
    final broken = made.copyWith(project: made.project.copyWith(clipVolume: double.nan));

    expect(() => open.write(broken), throwsA(DraftError.cannotWrite));
    expect(json.readAsBytesSync(), before);
    expect(names(folderOf(open.id, shelf)), ['Media', 'draft.json']);

    expect(() => shelf.create(broken), throwsA(DraftError.cannotWrite));
    expect(names(shelf.folder), [open.id.raw]);
  });

  test('testDeleteRemovesOneDraftAndRemoveAllTheShelf', () {
    final shelf = makeShelf();
    final gone = shelf.create(draft(Seed.twoClipsWide, hour: 10));
    final kept = shelf.create(draft(Seed.textWide, hour: 11));
    put(['blue.mov'], gone.mediaFolder);
    put(['cover.jpg'], folderOf(gone.id, shelf));

    shelf.delete(gone.id);

    expect(folderOf(gone.id, shelf).existsSync(), isFalse);
    expect(shelf.list().map((summary) => summary.id).toList(), [kept.id]);
    expect(() => shelf.delete(gone.id), throwsA(DraftError.cannotWrite));

    shelf.removeAll();

    expect(shelf.folder.existsSync(), isFalse);
    expect(shelf.list(), isEmpty);
  });

  test('testOpenKeepsTheFilesAndTheHistoryOfAnUndo', () {
    final shelf = makeShelf();
    final edited = deletedRed();
    final made = Draft(
      project: edited.state.project,
      exportSettings: ExportSettings.startChoice,
      changed: at(10),
      history: edited.history,
    );
    final open = shelf.create(made);
    put(['blue.mov', 'red.mov'], open.mediaFolder);

    final opened = shelf.open(open.id);

    expect(opened.history, edited.history);
    expect(opened.project, made.project.keepingFiles({'blue.mov', 'red.mov'}));
    expect(opened.project.clips, made.project.clips);
    expect(names(open.mediaFolder), ['blue.mov', 'red.mov']);
  });

  test('testOpenDropsAHistoryThatNamesAMissingFile', () {
    final shelf = makeShelf();
    final edited = deletedRed();
    final open = shelf.create(
      Draft(
        project: edited.state.project,
        exportSettings: ExportSettings.startChoice,
        changed: at(10),
        history: edited.history,
      ),
    );
    put(['blue.mov'], open.mediaFolder);

    final opened = shelf.open(open.id);

    expect(opened.history, isNull);
    expect(opened.project, edited.state.project.keepingFiles({'blue.mov'}));
    expect(opened.project.clips, edited.state.project.clips);
    expect(names(open.mediaFolder), ['blue.mov']);
  });

  /// E15: the bytes of draft.json and the milliseconds of 100 writes, printed with no assertion.
  test('testE15PrintsTheBytesAndTheTimeOfAWrite', () {
    final shelf = makeShelf();
    for (final seed in [Seed.textWide, Seed.musicWide]) {
      final made = draft(seed);
      final open = shelf.create(made);
      final bytes = encodeDraft(made).length;
      final watch = Stopwatch()..start();
      for (var index = 0; index < 100; index++) {
        open.write(made);
      }
      print('E15 ${seed.rawValue}: $bytes bytes, 100 writes in ${watch.elapsedMilliseconds} ms');
    }
  });
}
