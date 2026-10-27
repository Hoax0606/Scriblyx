import 'note_id.dart';

enum WorkspaceChangeKind { added, modified, removed }

/// 워크스페이스 폴더에서 감지된 노트 파일 변경.
class WorkspaceChange {
  const WorkspaceChange({required this.id, required this.kind});

  final NoteId id;
  final WorkspaceChangeKind kind;
}
