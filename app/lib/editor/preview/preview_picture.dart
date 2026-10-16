import 'package:flutter/widgets.dart';

/// The picture of the preview: the texture the Swift player draws the compositor's frames into, on black,
/// left to right whatever the language. It fills the space it is given, which the pane gives the shape of
/// the canvas. `editor.picture` carries `builds`, the count of the items the player began to build, as its
/// value when it is given (a seeded start).
///
/// https://api.flutter.dev/flutter/widgets/Texture-class.html
/// https://api.flutter.dev/flutter/widgets/Semantics-class.html
class PreviewPicture extends StatelessWidget {
  const PreviewPicture({super.key, required this.textureId, this.builds});

  /// The id `createPreview` gave, null until it has come.
  final int? textureId;
  final int? builds;

  @override
  Widget build(BuildContext context) {
    final id = textureId;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Semantics(
        identifier: 'editor.picture',
        container: true,
        value: builds?.toString(),
        child: ColoredBox(
          color: const Color(0xFF000000),
          child: id == null ? const SizedBox.expand() : Texture(textureId: id),
        ),
      ),
    );
  }
}
