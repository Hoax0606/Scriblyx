import 'note_id.dart';

/// 목록 표시에 필요한 정보. 본문을 포함하지 않는다.
class NoteMeta {
  const NoteMeta({
    required this.id,
    required this.title,
    required this.modifiedAt,
  });

  final NoteId id;
  final String title;
  final DateTime modifiedAt;
}
