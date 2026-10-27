import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/note_repository.dart';
import '../../../domain/models/note_id.dart';
import '../../../domain/models/workspace_change.dart';
import '../../../utils/command.dart';
import '../../core/editor/note_editor.dart';

/// 열려 있는 노트 하나의 편집 상태를 보유한다.
class NoteEditViewModel extends ChangeNotifier {
  NoteEditViewModel({
    required NoteRepository repository,
    required NoteEditorController controller,
    Duration autoSaveDelay = const Duration(milliseconds: 800),
  }) : _repository = repository,
       _controller = controller,
       _autoSaveDelay = autoSaveDelay {
    save = Command0(_save);
    reloadFromDisk = Command0(_reloadFromDisk);
    _controller.addListener(_onTextChanged);
    _changes = _repository.externalChanges.listen(_onExternalChange);
  }

  final NoteRepository _repository;
  final NoteEditorController _controller;
  final Duration _autoSaveDelay;

  late final StreamSubscription<WorkspaceChange> _changes;
  late final Command0 save;
  late final Command0 reloadFromDisk;

  NoteId? _openId;
  String _savedBody = '';
  bool _externalChangePending = false;
  bool _applyingLoadedText = false;
  Timer? _autoSaveTimer;

  NoteEditorController get controller => _controller;
  NoteId? get openId => _openId;
  bool get hasOpenNote => _openId != null;

  /// 디스크에 반영되지 않은 편집이 있는지.
  bool get dirty => _openId != null && _controller.text != _savedBody;

  /// 저장하지 않은 편집이 있는 동안 외부에서 같은 파일이 바뀌었는지.
  bool get externalChangePending => _externalChangePending;

  /// 다른 노트를 연다. 열려 있던 노트에 편집이 남아 있으면 먼저 저장한다.
  Future<void> open(NoteId? id) async {
    _autoSaveTimer?.cancel();
    if (dirty) {
      await _save();
    }

    _openId = id;
    _externalChangePending = false;

    if (id == null) {
      _savedBody = '';
      _applyLoadedText('');
    } else {
      final note = await _repository.read(id);
      _savedBody = note.body;
      _applyLoadedText(note.body);
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    unawaited(_changes.cancel());
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    save.dispose();
    reloadFromDisk.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final id = _openId;
    if (id == null) return;

    _autoSaveTimer?.cancel();
    final note = await _repository.write(id, _controller.text);
    _savedBody = note.body;
    _externalChangePending = false;
    notifyListeners();
  }

  Future<void> _reloadFromDisk() async {
    final id = _openId;
    if (id == null) return;

    final note = await _repository.read(id);
    _savedBody = note.body;
    _applyLoadedText(note.body);
    _externalChangePending = false;
    notifyListeners();
  }

  /// 파일에서 읽어온 본문을 넣는다. 자동 저장을 예약하지 않는다.
  void _applyLoadedText(String body) {
    _applyingLoadedText = true;
    _controller.text = body;
    _applyingLoadedText = false;
  }

  void _onTextChanged() {
    if (_applyingLoadedText || _openId == null) return;

    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(_autoSaveDelay, () => unawaited(save.execute()));
    notifyListeners();
  }

  void _onExternalChange(WorkspaceChange change) {
    if (change.id != _openId) return;

    if (change.kind == WorkspaceChangeKind.removed) {
      unawaited(open(null));
      return;
    }

    if (dirty) {
      _externalChangePending = true;
      notifyListeners();
      return;
    }

    unawaited(reloadFromDisk.execute());
  }
}
