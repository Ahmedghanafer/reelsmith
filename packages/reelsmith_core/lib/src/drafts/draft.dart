import '../model/project.dart';

extension ProjectFileNames on Project {
  /// The file name of every media a clip uses, and of the music, each once, sorted.
  List<String> get fileNames {
    final names = <String>{};
    for (final clip in clips) {
      final info = media[clip.media];
      if (info != null) {
        names.add(info.fileName);
      }
    }
    final music = this.music;
    if (music != null) {
      names.add(music.file.fileName);
    }
    return names.toList()..sort();
  }
}
