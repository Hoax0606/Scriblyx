import 'package:flutter/material.dart';

import '../../core/editor/note_editor.dart';
import '../view_model/note_edit_viewmodel.dart';

/// 노트 편집 화면.
class NoteEditPane extends StatefulWidget {
  const NoteEditPane({
    super.key,
    required this.viewModel,
    required this.buildEditor,
  });

  final NoteEditViewModel viewModel;
  final NoteEditorBuilder buildEditor;

  @override
  State<NoteEditPane> createState() => _NoteEditPaneState();
}

class _NoteEditPaneState extends State<NoteEditPane> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_onViewModelChanged);
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_onViewModelChanged);
    super.dispose();
  }

  void _onViewModelChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;

    if (!viewModel.hasOpenNote) {
      return const _NoNoteOpen();
    }

    return Column(
      children: [
        if (viewModel.externalChangePending)
          _ExternalChangeBar(
            onReload: viewModel.reloadFromDisk.execute,
            onKeepMine: viewModel.save.execute,
          ),
        Expanded(
          child: widget.buildEditor(context, viewModel.controller),
        ),
        const Divider(height: 1),
        _StatusBar(
          saving: viewModel.save.running,
          dirty: viewModel.dirty,
        ),
      ],
    );
  }
}

class _NoNoteOpen extends StatelessWidget {
  const _NoNoteOpen();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '왼쪽에서 노트를 선택하세요',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

/// 저장하지 않은 편집이 있는 동안 파일이 외부에서 바뀌었을 때 표시된다.
class _ExternalChangeBar extends StatelessWidget {
  const _ExternalChangeBar({
    required this.onReload,
    required this.onKeepMine,
  });

  final VoidCallback onReload;
  final VoidCallback onKeepMine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Icon(Icons.warning_amber, size: 20, color: scheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '이 파일이 앱 밖에서 변경되었습니다. 저장하지 않은 편집이 있습니다.',
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
            TextButton(onPressed: onReload, child: const Text('디스크 내용으로')),
            TextButton(onPressed: onKeepMine, child: const Text('내 편집 저장')),
          ],
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.saving, required this.dirty});

  final bool saving;
  final bool dirty;

  @override
  Widget build(BuildContext context) {
    final label = saving
        ? '저장 중'
        : dirty
        ? '저장되지 않음'
        : '저장됨';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
