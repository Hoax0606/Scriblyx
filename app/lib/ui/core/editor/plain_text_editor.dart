import 'package:flutter/material.dart';

import 'note_editor.dart';

/// `TextField` 기반 평문 에디터.
class PlainTextEditorController extends NoteEditorController {
  PlainTextEditorController() {
    _controller.addListener(notifyListeners);
  }

  final TextEditingController _controller = TextEditingController();

  TextEditingController get textController => _controller;

  @override
  String get text => _controller.text;

  @override
  set text(String value) {
    if (_controller.text == value) return;
    _controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(notifyListeners);
    _controller.dispose();
    super.dispose();
  }
}

NoteEditorFactory plainTextEditorFactory() => NoteEditorFactory(
  createController: PlainTextEditorController.new,
  buildEditor: _buildPlainTextEditor,
);

Widget _buildPlainTextEditor(
  BuildContext context,
  NoteEditorController controller,
) {
  return TextField(
    controller: (controller as PlainTextEditorController).textController,
    maxLines: null,
    expands: true,
    textAlignVertical: TextAlignVertical.top,
    style: const TextStyle(fontSize: 16, height: 1.6),
    decoration: const InputDecoration(
      border: InputBorder.none,
      contentPadding: EdgeInsets.fromLTRB(24, 16, 24, 24),
      hintText: '여기에 입력하세요',
    ),
  );
}
