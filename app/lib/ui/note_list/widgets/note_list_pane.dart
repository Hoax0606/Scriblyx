import 'package:flutter/material.dart';

import '../../../domain/models/note_meta.dart';
import '../view_model/note_list_viewmodel.dart';
import 'rename_note_dialog.dart';

/// 노트 목록 화면.
class NoteListPane extends StatefulWidget {
  const NoteListPane({super.key, required this.viewModel});

  final NoteListViewModel viewModel;

  @override
  State<NoteListPane> createState() => _NoteListPaneState();
}

class _NoteListPaneState extends State<NoteListPane> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_onViewModelChanged);
    widget.viewModel.renameNote.addListener(_onRenameResult);
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_onViewModelChanged);
    widget.viewModel.renameNote.removeListener(_onRenameResult);
    super.dispose();
  }

  void _onViewModelChanged() => setState(() {});

  void _onRenameResult() {
    final error = widget.viewModel.renameNote.error;
    if (error == null || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_messageOf(error))),
    );
    widget.viewModel.renameNote.clearError();
  }

  String _messageOf(Object error) =>
      error is Exception ? error.toString() : '작업에 실패했습니다';

  Future<void> _rename(NoteMeta note) async {
    final title = await showRenameNoteDialog(
      context,
      currentTitle: note.title,
    );
    if (title == null || title.trim().isEmpty) return;

    await widget.viewModel.renameNote.execute((id: note.id, title: title));
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;

    return Column(
      children: [
        _Header(
          busy: viewModel.createNote.running,
          onCreate: viewModel.createNote.execute,
        ),
        const Divider(height: 1),
        Expanded(
          child: viewModel.notes.isEmpty
              ? const _EmptyState()
              : ListView.builder(
                  itemCount: viewModel.notes.length,
                  itemBuilder: (context, index) {
                    final note = viewModel.notes[index];
                    return _NoteTile(
                      note: note,
                      selected: note.id == viewModel.selectedId,
                      onTap: () => viewModel.select(note.id),
                      onRename: () => _rename(note),
                      onDelete: () =>
                          viewModel.deleteNote.execute(note.id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.busy, required this.onCreate});

  final bool busy;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Text('노트', style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          IconButton(
            onPressed: busy ? null : onCreate,
            icon: const Icon(Icons.add),
            tooltip: '새 노트',
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          '노트가 없습니다.\n위의 + 를 눌러 만드세요.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({
    required this.note,
    required this.selected,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  final NoteMeta note;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      selected: selected,
      title: Text(note.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        _formatTimestamp(note.modifiedAt),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onTap: onTap,
      trailing: PopupMenuButton<_NoteAction>(
        tooltip: '메뉴',
        onSelected: (action) => switch (action) {
          _NoteAction.rename => onRename(),
          _NoteAction.delete => onDelete(),
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: _NoteAction.rename, child: Text('이름 바꾸기')),
          PopupMenuItem(value: _NoteAction.delete, child: Text('삭제')),
        ],
      ),
    );
  }
}

enum _NoteAction { rename, delete }

String _formatTimestamp(DateTime time) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${time.year}-${two(time.month)}-${two(time.day)} '
      '${two(time.hour)}:${two(time.minute)}';
}
