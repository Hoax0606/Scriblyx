import 'package:flutter/material.dart';

/// 노트 이름을 입력받는다. 취소하면 null을 돌려준다.
Future<String?> showRenameNoteDialog(
  BuildContext context, {
  required String currentTitle,
}) {
  final controller = TextEditingController(text: currentTitle);

  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('이름 바꾸기'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: '노트 이름'),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('변경'),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}
