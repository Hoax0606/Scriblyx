import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/editor/note_editor.dart';
import '../../note_edit/view_model/note_edit_viewmodel.dart';
import '../../note_edit/widgets/note_edit_pane.dart';
import '../../note_list/view_model/note_list_viewmodel.dart';
import '../../note_list/widgets/note_list_pane.dart';

/// 목록과 편집기를 좌우로 배치하고, 목록의 선택을 편집기에 연결한다.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.listViewModel,
    required this.editViewModel,
    required this.buildEditor,
  });

  final NoteListViewModel listViewModel;
  final NoteEditViewModel editViewModel;
  final NoteEditorBuilder buildEditor;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _listPaneWidth = 280.0;

  @override
  void initState() {
    super.initState();
    widget.listViewModel.addListener(_onSelectionChanged);
    widget.listViewModel.refresh();
  }

  @override
  void dispose() {
    widget.listViewModel.removeListener(_onSelectionChanged);
    super.dispose();
  }

  void _onSelectionChanged() {
    final selectedId = widget.listViewModel.selectedId;
    if (selectedId == widget.editViewModel.openId) return;
    widget.editViewModel.open(selectedId);
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            widget.editViewModel.save.execute,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Row(
            children: [
              SizedBox(
                width: _listPaneWidth,
                child: NoteListPane(viewModel: widget.listViewModel),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: NoteEditPane(
                  viewModel: widget.editViewModel,
                  buildEditor: widget.buildEditor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
