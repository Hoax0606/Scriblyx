import 'note_id.dart';

/// 본문 전체를 가진 노트.
class Note {
  const Note({
    required this.id,
    required this.body,
    required this.modifiedAt,
  });

  final NoteId id;
  final String body;
  final DateTime modifiedAt;
}
