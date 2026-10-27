import 'dart:async';

import 'package:path/path.dart' as p;

import '../../domain/models/note.dart';
import '../../domain/models/note_id.dart';
import '../../domain/models/note_meta.dart';
import '../../domain/models/workspace.dart';
import '../../domain/models/workspace_change.dart';
import '../services/workspace_file_service.dart';
import '../services/workspace_watch_service.dart';
import 'note_repository.dart';

/// 워크스페이스 폴더의 `.md` 파일을 노트로 다루는 저장소.
///
/// 노트의 제목은 확장자를 뺀 파일명이다.
class FileNoteRepository implements NoteRepository {
  FileNoteRepository({
    required WorkspaceFileService files,
    required WorkspaceWatchService watcher,
  }) : _files = files,
       _watcher = watcher {
    _watcher.start();
    _watchSubscription = _watcher.changes.listen(_onWatchEvent);
  }

  final WorkspaceFileService _files;
  final WorkspaceWatchService _watcher;

  final StreamController<WorkspaceChange> _external =
      StreamController<WorkspaceChange>.broadcast();

  /// 이 저장소가 마지막으로 쓴 시점의 파일 수정 시각.
  ///
  /// 감시 이벤트가 자신의 쓰기 때문인지 가리는 데 쓴다. 파일을 열지 않고
  /// 비교해야 하는데, Windows에서 열린 핸들이 있으면 이름 변경이 거부된다.
  final Map<String, DateTime> _writtenAt = {};

  /// 이 저장소가 지금 건드리고 있는 경로.
  ///
  /// 감시 이벤트는 쓰기가 끝나기 전에 도착할 수 있어 [_writtenAt] 만으로는
  /// 자신의 쓰기를 가려낼 수 없다. 작업 시작 시점부터 막는다.
  final Set<String> _writing = {};

  late final StreamSubscription<WorkspaceChange> _watchSubscription;

  bool _disposed = false;

  static const _newNoteBaseName = '새 노트';
  static final _invalidFileNameChars = RegExp(r'[\\/:*?"<>|]');

  /// 쓰기가 끝난 뒤에도 감시 이벤트가 조금 늦게 도착한다. 그동안 더 막는다.
  static const _selfWriteGrace = Duration(milliseconds: 150);

  @override
  Stream<WorkspaceChange> get externalChanges => _external.stream;

  @override
  Future<List<NoteMeta>> list() async {
    final files = await _files.listMarkdownFiles();
    return files.map(_toMeta).toList()
      ..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
  }

  @override
  Future<Note> read(NoteId id) async {
    final body = await _files.read(id.relativePath);
    return Note(
      id: id,
      body: body,
      modifiedAt: await _files.modifiedAt(id.relativePath),
    );
  }

  @override
  Future<Note> write(NoteId id, String body) async {
    final modifiedAt = await _guardSelfWrite(id.relativePath, () async {
      final at = await _files.write(id.relativePath, body);
      _writtenAt[id.relativePath] = at;
      return at;
    });
    return Note(id: id, body: body, modifiedAt: modifiedAt);
  }

  @override
  Future<NoteMeta> create() async {
    final relativePath = await _availableNewNotePath();
    final modifiedAt = await _guardSelfWrite(relativePath, () async {
      final at = await _files.write(relativePath, '');
      _writtenAt[relativePath] = at;
      return at;
    });
    return NoteMeta(
      id: NoteId(relativePath),
      title: _titleOf(relativePath),
      modifiedAt: modifiedAt,
    );
  }

  @override
  Future<NoteMeta> rename(NoteId id, String title) async {
    final targetPath = p.join(
      p.dirname(id.relativePath),
      '${_sanitizeFileName(title)}${WorkspaceFileService.markdownExtension}',
    );

    if (targetPath == id.relativePath) {
      return NoteMeta(
        id: id,
        title: _titleOf(id.relativePath),
        modifiedAt: await _files.modifiedAt(id.relativePath),
      );
    }

    if (await _files.exists(targetPath)) {
      throw NoteNameTakenException(title);
    }

    final modifiedAt = await _guardSelfWrite(id.relativePath, () async {
      return _guardSelfWrite(
        targetPath,
        () => _files.move(id.relativePath, targetPath),
      );
    });
    _writtenAt.remove(id.relativePath);
    _writtenAt[targetPath] = modifiedAt;

    return NoteMeta(
      id: NoteId(targetPath),
      title: _titleOf(targetPath),
      modifiedAt: modifiedAt,
    );
  }

  @override
  Future<void> delete(NoteId id) async {
    await _guardSelfWrite(
      id.relativePath,
      () => _files.delete(id.relativePath),
    );
    _writtenAt.remove(id.relativePath);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _watchSubscription.cancel();
    await _watcher.dispose();
    await _external.close();
  }

  NoteMeta _toMeta(WorkspaceFile file) => NoteMeta(
    id: NoteId(file.relativePath),
    title: _titleOf(file.relativePath),
    modifiedAt: file.modifiedAt,
  );

  String _titleOf(String relativePath) =>
      p.basenameWithoutExtension(relativePath);

  String _sanitizeFileName(String title) {
    final cleaned = title.replaceAll(_invalidFileNameChars, ' ').trim();
    return cleaned.isEmpty ? _newNoteBaseName : cleaned;
  }

  Future<String> _availableNewNotePath() async {
    for (var index = 1; ; index++) {
      final name = index == 1 ? _newNoteBaseName : '$_newNoteBaseName $index';
      final path = p.join(
        Workspace.personalFolderName,
        '$name${WorkspaceFileService.markdownExtension}',
      );
      if (!await _files.exists(path)) return path;
    }
  }

  /// [path] 를 건드리는 동안과 그 직후의 감시 이벤트를 자신의 것으로 간주한다.
  Future<T> _guardSelfWrite<T>(String path, Future<T> Function() action) async {
    _writing.add(path);
    try {
      return await action();
    } finally {
      Timer(_selfWriteGrace, () => _writing.remove(path));
    }
  }

  Future<void> _onWatchEvent(WorkspaceChange change) async {
    if (_disposed) return;
    final path = change.id.relativePath;
    if (_writing.contains(path)) return;

    if (change.kind == WorkspaceChangeKind.removed) {
      _writtenAt.remove(path);
      _emitExternal(change);
      return;
    }

    final writtenAt = _writtenAt[path];
    if (writtenAt != null) {
      final current = await _currentModifiedAt(path);
      if (current == null) return;
      if (current == writtenAt) return;
      _writtenAt.remove(path);
    }

    _emitExternal(change);
  }

  Future<DateTime?> _currentModifiedAt(String relativePath) async {
    try {
      if (!await _files.exists(relativePath)) return null;
      return await _files.modifiedAt(relativePath);
    } on Exception {
      return null;
    }
  }

  void _emitExternal(WorkspaceChange change) {
    if (_disposed || _external.isClosed) return;
    _external.add(change);
  }
}
