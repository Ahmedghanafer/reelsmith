import 'dart:async';
import 'dart:typed_data';

import 'package:reelsmith/engine/video_engine.dart';

/// The engine of `flutter test`: it records each call by its name in `calls`, answers it with the field of the
/// same name, and gives an event when a test calls `send...`.
class FakeVideoEngine implements VideoEngine {
  final List<String> calls = [];

  String launchAnswer =
      '{"drafts":null,"draftsFolder":"/fake/Drafts","exportFails":false,"playhead":null,"seed":null,'
      '"testDraftsFolder":"/fake/TestDrafts"}';
  String writeSeedMediaAnswer = '/fake/Seeds';
  String readMediaInfoAnswer = '{}';
  int pickAnswer = 0;
  List<String> copyPickedAnswer = [];
  bool pickAudioAnswer = false;
  String importMusicAnswer = '{}';
  String musicFromVideoAnswer = '{}';
  int createPreviewAnswer = 1;
  ExportedVideo exportAnswer = ExportedVideo(file: '/fake/export.mp4');
  SaveOutcome saveToPhotosAnswer = SaveOutcome.saved;
  Map<int, Uint8List> blockFramesAnswer = {};
  String faceNamesAnswer = '';
  bool confirmAnswer = false;

  /// The arguments of each `show`, oldest first.
  final List<({int textureId, String project, String mediaFolder, int? playhead, bool playing})> shows = [];

  /// The file of each `writeCover`, oldest first.
  final List<String> covers = [];

  /// When set, `writeCover` throws it.
  Object? writeCoverError;

  final _playhead = StreamController<int>.broadcast();
  final _playedToEnd = StreamController<void>.broadcast();
  final _buildCount = StreamController<int>.broadcast();
  final _exportProgress = StreamController<double>.broadcast();

  void sendPlayhead(int ticks) => _playhead.add(ticks);
  void sendPlayedToEnd() => _playedToEnd.add(null);
  void sendBuildCount(int count) => _buildCount.add(count);
  void sendExportProgress(double progress) => _exportProgress.add(progress);

  Future<T> _answer<T>(String name, T answer) {
    calls.add(name);
    return Future.value(answer);
  }

  @override
  Future<String> launch() => _answer('launch', launchAnswer);

  @override
  Future<String> writeSeedMedia(String seed) => _answer('writeSeedMedia', writeSeedMediaAnswer);

  @override
  Future<String> readMediaInfo(String id, String fileName, String folder) =>
      _answer('readMediaInfo', readMediaInfoAnswer);

  @override
  Future<int> pick(bool photos, int limit) => _answer('pick', pickAnswer);

  @override
  Future<List<String>> copyPicked(String folder) => _answer('copyPicked', copyPickedAnswer);

  @override
  Future<bool> pickAudio() => _answer('pickAudio', pickAudioAnswer);

  @override
  Future<String> importMusic(String folder) => _answer('importMusic', importMusicAnswer);

  @override
  Future<String> musicFromVideo(String folder) => _answer('musicFromVideo', musicFromVideoAnswer);

  @override
  Future<int> createPreview() => _answer('createPreview', createPreviewAnswer);

  @override
  Future<void> show(int textureId, String project, String mediaFolder, int? playhead, bool playing) {
    shows.add((
      textureId: textureId,
      project: project,
      mediaFolder: mediaFolder,
      playhead: playhead,
      playing: playing,
    ));
    return _answer('show', null);
  }

  @override
  Future<void> disposePreview(int textureId) => _answer('disposePreview', null);

  @override
  Future<ExportedVideo> export(String project, String settings, String mediaFolder, bool fails) =>
      _answer('export', exportAnswer);

  @override
  Future<SaveOutcome> saveToPhotos(String file) => _answer('saveToPhotos', saveToPhotosAnswer);

  @override
  Future<void> writeCover(String project, String mediaFolder, String file) {
    covers.add(file);
    final error = writeCoverError;
    if (error != null) {
      calls.add('writeCover');
      return Future.error(error);
    }
    return _answer('writeCover', null);
  }

  @override
  Future<Map<int, Uint8List>> blockFrames(String media, String mediaFolder) =>
      _answer('blockFrames', blockFramesAnswer);

  @override
  Future<void> keepAwake(bool awake) => _answer('keepAwake', null);

  @override
  Future<String> faceNames() => _answer('faceNames', faceNamesAnswer);

  @override
  Future<bool> confirm(String question, String confirmWords, String cancelWords) =>
      _answer('confirm', confirmAnswer);

  @override
  Stream<int> get playhead => _playhead.stream;

  @override
  Stream<void> get playedToEnd => _playedToEnd.stream;

  @override
  Stream<int> get buildCount => _buildCount.stream;

  @override
  Stream<double> get exportProgress => _exportProgress.stream;
}
