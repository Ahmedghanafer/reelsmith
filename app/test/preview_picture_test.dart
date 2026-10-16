import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelsmith/editor/preview/preview_picture.dart';

void main() {
  testWidgets('editor.picture carries the count of builds as its value', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(width: 90, height: 160, child: PreviewPicture(textureId: 1, builds: 3)),
        ),
      ),
    );
    final node = tester.getSemantics(find.bySemanticsIdentifier('editor.picture'));
    expect(node.value, '3');
    semantics.dispose();
  });
}
