// The one API between the Flutter app and the Swift Engine. Run from `app/` with
// `dart run pigeon --input pigeons/engine.dart`, which writes the two generated files.
// https://pub.dev/packages/pigeon
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/engine/engine_api.g.dart',
    swiftOut: 'ios/Runner/Engine/EngineApi.g.swift',
    dartPackageName: 'reelsmith',
  ),
)
/// A written export: the file in the temporary folder, and the facts read from it.
class ExportedVideo {
  ExportedVideo({required this.file, this.facts});

  String file;

  /// `VideoFacts.infoText` of the file, null when it cannot be read.
  String? facts;
}

/// How a save to Photos ended.
enum SaveOutcome {
  saved,

  /// The photo library does not allow adding.
  notAllowed,
  failed,
}

/// A project crosses as the `project` member of the draft JSON of version 1, the export settings, a media fact
/// and a music file as their JSON. A folder or a file is a path. A time is in ticks of 1/600 second.
/// A call that is not built yet throws `EngineError.notBuilt`, which reaches Dart as a `PlatformException`
/// with the code `notBuilt`. A refusal of the Engine reaches Dart the same way, its code the Swift description of the error, as `protectedFile`.
@HostApi()
abstract class EngineApi {
  /// The JSON of the launch values of a debug build (`seed`, `playhead`, `exportFails`, `drafts`) and the two
  /// folders of the drafts, `draftsFolder` and `testDraftsFolder`, in one object. A release build has no
  /// launch values.
  String launch();

  /// Writes the test clips, tones and photos of the seed of that name into `<caches>/Seeds/`, keeping a file
  /// that is there, and gives that folder. A file that cannot be written is logged and left missing.
  @async
  String writeSeedMedia(String seed);

  /// The JSON of the media fact of `<folder>/<fileName>`.
  @async
  String readMediaInfo(String id, String fileName, String folder);

  /// Shows the system photo picker, for videos and also photos when `photos` is true, with at most `limit`
  /// items (0 for no limit, in the order she chose), and gives the count chosen. The items are kept for
  /// `copyPicked` and `musicFromVideo`.
  @async
  int pick(bool photos, int limit);

  /// Copies the items of the last `pick` into the folder and gives the JSON of their media facts, in the order
  /// she chose. An item that cannot be copied or read is left out.
  @async
  List<String> copyPicked(String folder);

  /// Shows the system file browser for one audio file. True when one was chosen: it is kept for `importMusic`.
  @async
  bool pickAudio();

  /// Copies the audio file of the last `pickAudio` into the folder and gives the JSON of its music file.
  @async
  String importMusic(String folder);

  /// Takes the sound of the video of the last `pick` into the folder and gives the JSON of its music file.
  @async
  String musicFromVideo(String folder);

  /// Makes the preview's texture and gives its id.
  int createPreview();

  /// Hands the preview the project, its media folder, a playhead only when Dart moved it, and playing.
  void show(
    int textureId,
    String project,
    String mediaFolder,
    int? playhead,
    bool playing,
  );

  void disposePreview(int textureId);

  /// Exports the project at the settings to a file in the temporary folder, sending `ExportProgressEvent`.
  /// With `fails` the file lies in a folder that is not there.
  @async
  ExportedVideo export(
    String project,
    String settings,
    String mediaFolder,
    bool fails,
  );

  /// Adds the file to Photos with the right to add only, then removes the file.
  @async
  SaveOutcome saveToPhotos(String file);

  /// Writes the cover of the project to the file.
  @async
  void writeCover(String project, String mediaFolder, String file);

  /// The PNG bytes of the frames of a media for the blocks of the strip, by their time.
  @async
  Map<int, Uint8List> blockFrames(String media, String mediaFolder);

  /// The screen stays awake while true.
  void keepAwake(bool awake);

  /// The PostScript names of the faces made for naskh and naskh bold, one space between them.
  String faceNames();

  /// Shows the question as a system alert with a destructive button and a cancel button. True when she
  /// confirmed.
  @async
  bool confirm(String question, String confirmWords, String cancelWords);
}

/// What the Engine sends to Dart.
sealed class EngineEvent {}

/// The time of the playing preview, at most 30 a second.
class PlayheadEvent extends EngineEvent {
  PlayheadEvent({required this.ticks});

  int ticks;
}

/// The preview played to its end.
class PlayedToEndEvent extends EngineEvent {
  PlayedToEndEvent();
}

/// The count of the items the preview began to build.
class BuildCountEvent extends EngineEvent {
  BuildCountEvent({required this.count});

  int count;
}

/// The part of the export done, from 0 to 1.
class ExportProgressEvent extends EngineEvent {
  ExportProgressEvent({required this.progress});

  double progress;
}

@EventChannelApi()
abstract class EngineEvents {
  EngineEvent events();
}
