import 'package:flutter/widgets.dart';

/// 에디터 구현이 제공해야 하는 본문 접근 수단.
///
/// 본문이 바뀌면 리스너에게 알린다.
abstract class NoteEditorController extends ChangeNotifier {
  String get text;

  set text(String value);
}

/// 주어진 컨트롤러를 편집하는 위젯을 만든다.
typedef NoteEditorBuilder =
    Widget Function(BuildContext context, NoteEditorController controller);

/// 에디터 구현 한 벌. 컨트롤러와 위젯은 같은 구현끼리 짝을 이룬다.
class NoteEditorFactory {
  const NoteEditorFactory({
    required this.createController,
    required this.buildEditor,
  });

  final NoteEditorController Function() createController;
  final NoteEditorBuilder buildEditor;
}
