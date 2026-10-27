/// 마크다운 문서를 이루는 최상위 블록 하나.
///
/// [source] 는 뒤따르는 빈 줄까지 포함한 원본 조각이다. 한 문서에서 얻은
/// 블록들의 [source] 를 순서대로 이어붙이면 원본과 바이트 단위로 같다.
class MarkdownBlock {
  const MarkdownBlock({required this.source, required this.kind});

  final String source;
  final MarkdownBlockKind kind;

  /// 빈 줄을 뺀 내용. 블록 종류를 판별하거나 파서에 넘길 때 쓴다.
  String get content => source.trimRight();

  bool get isBlank => content.isEmpty;
}

enum MarkdownBlockKind {
  frontmatter,
  heading,
  fencedCode,
  indentedCode,
  blockquote,
  list,
  table,
  thematicBreak,
  html,
  paragraph,
  blank,
}
