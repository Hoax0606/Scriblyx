import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/note_repository.dart';
import '../../../domain/models/note_id.dart';
import '../../../domain/models/note_meta.dart';
import '../../../domain/models/workspace_change.dart';
import '../../../utils/command.dart';

typedef NoteRenameRequest = ({NoteId id, String title});

/// 노트 목록과 선택 상태를 보유한다.
class NoteListViewModel extends ChangeNotifier {
  NoteListViewModel(this._repository) {
    createNote = Command0(_create);
    deleteNote = Command1<NoteId>(_delete);
    renameNote = Command1<NoteRenameRequest>(_rename);
    _changes = _repository.externalChanges.listen(_onExternalChange);
  }

  final NoteRepository _repository;

  late final StreamSubscription<WorkspaceChange> _changes;
  late final Command0 createNote;
  late final Command1<NoteId> deleteNote;
  late final Command1<NoteRenameRequest> renameNote;

  List<NoteMeta> _notes = const [];
  NoteId? _selectedId;
  bool _loading = false;

  List<NoteMeta> get notes => _notes;
  NoteId? get selectedId => _selectedId;
  bool get loading => _loading;

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();

    _notes = await _repository.list();
    if (_selectedId != null && !_notes.any((note) => note.id == _selectedId)) {
      _selectedId = null;
    }

    _loading = false;
    notifyListeners();
  }

  void select(NoteId? id) {
    if (_selectedId == id) return;
    _selectedId = id;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_changes.cancel());
    createNote.dispose();
    deleteNote.dispose();
    renameNote.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final created = await _repository.create();
    await refresh();
    select(created.id);
  }

  Future<void> _delete(NoteId id) async {
    await _repository.delete(id);
    if (_selectedId == id) {
      _selectedId = null;
    }
    await refresh();
  }

  Future<void> _rename(NoteRenameRequest request) async {
    final renamed = await _repository.rename(request.id, request.title);
    if (_selectedId == request.id) {
      _selectedId = renamed.id;
    }
    await refresh();
  }

  void _onExternalChange(WorkspaceChange change) {
    unawaited(refresh());
  }
}
