import 'dart:typed_data';

import 'engine_api.g.dart';

export 'engine_api.g.dart' show ExportedVideo, SaveOutcome;

/// The one door from the screens and the store to the Swift Engine. Each call is the call of the same name in
/// `app/pigeons/engine.dart`, which says what it takes and gives. Tests use `FakeVideoEngine`.
abstract class VideoEngine {
  Future<String> launch();
  Future<String> writeSeedMedia(String seed);
  Future<String> readMediaInfo(String id, String fileName, String folder);
  Future<int> pick(bool photos, int limit);
  Future<List<String>> copyPicked(String folder);
  Future<bool> pickAudio();
  Future<String> importMusic(String folder);
  Future<String> musicFromVideo(String folder);
  Future<int> createPreview();
  Future<void> show(int textureId, String project, String mediaFolder, int? playhead, bool playing);
  Future<void> disposePreview(int textureId);
  Future<ExportedVideo> export(String project, String settings, String mediaFolder, bool fails);
  Future<SaveOutcome> saveToPhotos(String file);
  Future<void> writeCover(String project, String mediaFolder, String file);
  Future<Map<int, Uint8List>> blockFrames(String media, String mediaFolder);
  Future<void> keepAwake(bool awake);
  Future<String> faceNames();
  Future<bool> confirm(String question, String confirmWords, String cancelWords);

  /// The time of the playing preview in ticks, at most 30 a second.
  Stream<int> get playhead;

  /// The preview played to its end.
  Stream<void> get playedToEnd;

  /// The count of the items the preview began to build.
  Stream<int> get buildCount;

  /// The part of the export done, from 0 to 1.
  Stream<double> get exportProgress;
}

/// The engine of the app: every call goes through the generated Pigeon class, every event comes on its one
/// event channel.
class PigeonVideoEngine implements VideoEngine {
  final EngineApi _api = EngineApi();
  final Stream<EngineEvent> _events = events();

  @override
  Future<String> launch() => _api.launch();

  @override
  Future<String> writeSeedMedia(String seed) => _api.writeSeedMedia(seed);

  @override
  Future<String> readMediaInfo(String id, String fileName, String folder) =>
      _api.readMediaInfo(id, fileName, folder);

  @override
  Future<int> pick(bool photos, int limit) => _api.pick(photos, limit);

  @override
  Future<List<String>> copyPicked(String folder) => _api.copyPicked(folder);

  @override
  Future<bool> pickAudio() => _api.pickAudio();

  @override
  Future<String> importMusic(String folder) => _api.importMusic(folder);

  @override
  Future<String> musicFromVideo(String folder) => _api.musicFromVideo(folder);

  @override
  Future<int> createPreview() => _api.createPreview();

  @override
  Future<void> show(int textureId, String project, String mediaFolder, int? playhead, bool playing) =>
      _api.show(textureId, project, mediaFolder, playhead, playing);

  @override
  Future<void> disposePreview(int textureId) => _api.disposePreview(textureId);

  @override
  Future<ExportedVideo> export(String project, String settings, String mediaFolder, bool fails) =>
      _api.export(project, settings, mediaFolder, fails);

  @override
  Future<SaveOutcome> saveToPhotos(String file) => _api.saveToPhotos(file);

  @override
  Future<void> writeCover(String project, String mediaFolder, String file) =>
      _api.writeCover(project, mediaFolder, file);

  @override
  Future<Map<int, Uint8List>> blockFrames(String media, String mediaFolder) =>
      _api.blockFrames(media, mediaFolder);

  @override
  Future<void> keepAwake(bool awake) => _api.keepAwake(awake);

  @override
  Future<String> faceNames() => _api.faceNames();

  @override
  Future<bool> confirm(String question, String confirmWords, String cancelWords) =>
      _api.confirm(question, confirmWords, cancelWords);

  @override
  Stream<int> get playhead => _events.where((event) => event is PlayheadEvent).map((event) => (event as PlayheadEvent).ticks);

  @override
  Stream<void> get playedToEnd => _events.where((event) => event is PlayedToEndEvent).map((_) {});

  @override
  Stream<int> get buildCount => _events.where((event) => event is BuildCountEvent).map((event) => (event as BuildCountEvent).count);

  @override
  Stream<double> get exportProgress => 
      _events.where((event) => event is ExportProgressEvent).map((event) => (event as ExportProgressEvent).progress);
}
