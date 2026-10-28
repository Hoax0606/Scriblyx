import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import '../../../data/markdown/note_markdown_codec.dart';
import 'blocks/toggle_component.dart';
import 'editor_reactions.dart';
import 'note_editor.dart';

/// super_editor 를 [NoteEditorController] 계약에 맞춘 구현.
///
/// 본문은 [NoteMarkdownCodec] 을 거쳐 오간다. 편집하지 않은 블록은 불러올 때의
/// 원본 조각이 그대로 다시 쓰인다.
class SuperEditorNoteController extends NoteEditorController {
  SuperEditorNoteController() {
    _build('');
  }

  final NoteMarkdownCodec _codec = NoteMarkdownCodec();

  late MutableDocument _document;
  late MutableDocumentComposer _composer;
  late Editor _editor;

  /// 직렬화 결과를 들고 있다가 문서가 바뀌면 버린다.
  ///
  /// 직렬화는 문서 전체를 훑으므로 입력마다 수행하지 않는다.
  String? _serialized;

  Editor get editor => _editor;

  @override
  String get text => _serialized ??= _codec.encode(_document);

  @override
  set text(String value) {
    if (_serialized == value) return;
    _disposeDocument();
    _build(value);
    _serialized = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposeDocument();
    super.dispose();
  }

  void _build(String markdown) {
    _document = _codec.decode(markdown);
    _composer = MutableDocumentComposer();
    // createDefaultDocumentEditor 는 반응 목록을 받지 않아 직접 만든다.
    _editor = Editor(
      editables: {
        Editor.documentKey: _document,
        Editor.composerKey: _composer,
      },
      requestHandlers: List.from(defaultRequestHandlers),
      reactionPipeline: notionStyleReactions(),
    );
    _document.addListener(_onDocumentChanged);
  }

  void _disposeDocument() {
    _document.removeListener(_onDocumentChanged);
    _editor.dispose();
    _composer.dispose();
    _document.dispose();
  }

  void _onDocumentChanged(DocumentChangeLog changeLog) {
    _serialized = null;
    notifyListeners();
  }
}

NoteEditorFactory superEditorNoteFactory() => NoteEditorFactory(
  createController: SuperEditorNoteController.new,
  buildEditor: _buildSuperEditor,
);

Widget _buildSuperEditor(
  BuildContext context,
  NoteEditorController controller,
) {
  final editor = (controller as SuperEditorNoteController).editor;
  return SuperEditor(
    // 다른 노트를 열면 Editor 인스턴스가 바뀐다. 상태를 새로 만들도록 키를 건다.
    key: ValueKey(editor),
    editor: editor,
    componentBuilders: _componentBuilders(editor),
    customStylePhases: [CollapsedTogglePhase()],
    stylesheet: defaultStylesheet.copyWith(
      documentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
    ),
  );
}

/// 표와 할 일은 super_editor 의 기본 목록에 없다. 빠지면 해당 블록이
/// UnknownComponentBuilder 로 떨어져 빈 상자로 그려진다.
///
/// [TaskComponentBuilder] 는 체크 상태를 바꾸기 위해 [Editor] 를 받는다.
List<ComponentBuilder> _componentBuilders(Editor editor) => [
  ToggleComponentBuilder(editor),
  TaskComponentBuilder(editor),
  const MarkdownTableComponentBuilder(),
  ...defaultComponentBuilders,
];
