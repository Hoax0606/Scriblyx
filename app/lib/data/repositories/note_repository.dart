import '../../domain/models/note.dart';
import '../../domain/models/note_id.dart';
import '../../domain/models/note_meta.dart';
import '../../domain/models/workspace_change.dart';

/// 같은 이름의 노트가 이미 있어 이름을 바꿀 수 없을 때 던져진다.
class NoteNameTakenException implements Exception {
  const NoteNameTakenException(this.title);

  final String title;

  @override
  String toString() => '같은 이름의 노트가 이미 있습니다: $title';
}

/// 노트의 진실의 원천.
abstract class NoteRepository {
  Future<List<NoteMeta>> list();

  Future<Note> read(NoteId id);

  /// 본문을 저장하고 저장된 상태의 노트를 돌려준다.
  Future<Note> write(NoteId id, String body);

  /// 빈 노트를 만들고 그 메타데이터를 돌려준다.
  Future<NoteMeta> create();

  /// 노트의 이름을 바꾼다. 이름이 곧 파일명이므로 식별자가 함께 바뀐다.
  ///
  /// 대상 이름이 이미 쓰이고 있으면 [NoteNameTakenException]을 던진다.
  Future<NoteMeta> rename(NoteId id, String title);

  Future<void> delete(NoteId id);

  /// 이 저장소를 거치지 않은 변경만 흘린다.
  Stream<WorkspaceChange> get externalChanges;

  Future<void> dispose();
}
