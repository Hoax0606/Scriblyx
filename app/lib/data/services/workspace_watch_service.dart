import 'dart:async';
import 'dart:io';

import '../../domain/models/note_id.dart';
import '../../domain/models/workspace_change.dart';
import 'workspace_file_service.dart';

/// 워크스페이스 폴더의 마크다운 파일 변경을 감시한다.
///
/// 이 앱이 쓴 변경과 외부 변경을 구분하지 않는다. 구분은 저장소가 담당한다.
class WorkspaceWatchService {
  WorkspaceWatchService(this._files);

  final WorkspaceFileService _files;
  final StreamController<WorkspaceChange> _controller =
      StreamController<WorkspaceChange>.broadcast();

  StreamSubscription<FileSystemEvent>? _subscription;

  Stream<WorkspaceChange> get changes => _controller.stream;

  void start() {
    _subscription ??= Directory(_files.workspace.rootPath)
        .watch(recursive: true)
        .listen(_onEvent);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _controller.close();
  }

  void _onEvent(FileSystemEvent event) {
    if (event is FileSystemMoveEvent) {
      _emit(event.path, WorkspaceChangeKind.removed);
      final destination = event.destination;
      if (destination != null) {
        _emit(destination, WorkspaceChangeKind.added);
      }
      return;
    }

    switch (event.type) {
      case FileSystemEvent.create:
        _emit(event.path, WorkspaceChangeKind.added);
      case FileSystemEvent.modify:
        _emit(event.path, WorkspaceChangeKind.modified);
      case FileSystemEvent.delete:
        _emit(event.path, WorkspaceChangeKind.removed);
    }
  }

  void _emit(String absolutePath, WorkspaceChangeKind kind) {
    if (!_files.isMarkdown(absolutePath)) return;
    _controller.add(
      WorkspaceChange(id: NoteId(_files.toRelative(absolutePath)), kind: kind),
    );
  }
}
