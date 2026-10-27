import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import 'note_editor.dart';

/// super_editor 를 [NoteEditorController] 계약에 맞춘 구현.
///
/// 본문은 super_editor 의 마크다운 직렬화를 거쳐 오간다. 이 직렬화는 일부
/// 마크다운 요소를 보존하지 못하므로, 편집하지 않은 블록을 원본 그대로 두는
/// 처리는 아직 들어 있지 않다.
class SuperEditorNoteController extends NoteEditorController {
  SuperEditorNoteController() {
    _build('');
  }

  late MutableDocument _document;
  late MutableDocumentComposer _composer;
  late Editor _editor;

  /// 직렬화 결과를 들고 있다가 문서가 바뀌면 버린다.
  ///
  /// 직렬화는 문서 전체를 훑으므로 입력마다 수행하지 않는다.
  String? _serialized;

  Editor get editor => _editor;

  @override
  String get text => _serialized ??= serializeDocumentToMarkdown(_document);

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
    _document = markdown.isEmpty
        ? MutableDocument(
            nodes: [
              ParagraphNode(
                id: Editor.createNodeId(),
                text: AttributedText(''),
              ),
            ],
          )
        : deserializeMarkdownToDocument(markdown);

    _composer = MutableDocumentComposer();
    _editor = createDefaultDocumentEditor(
      document: _document,
      composer: _composer,
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
    stylesheet: defaultStylesheet.copyWith(
      documentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
    ),
  );
}
