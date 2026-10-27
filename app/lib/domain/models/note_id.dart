/// 워크스페이스 루트를 기준으로 한 노트 파일의 상대 경로.
class NoteId {
  const NoteId(this.relativePath);

  final String relativePath;

  @override
  bool operator ==(Object other) =>
      other is NoteId && other.relativePath == relativePath;

  @override
  int get hashCode => relativePath.hashCode;

  @override
  String toString() => relativePath;
}
