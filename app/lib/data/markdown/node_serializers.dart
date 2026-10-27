import 'package:super_editor/super_editor.dart';

/// 파일에 쓸 때 쓰는 직렬화기들.
///
/// super_editor 기본 직렬화기보다 먼저 적용된다.
const scriblyxNodeSerializers = <DocumentNodeMarkdownSerializer>[
  _ListItemSerializer(),
];

/// 목록 항목을 널리 쓰이는 형태로 쓴다.
///
/// super_editor 기본 직렬화기는 글머리 기호로 `*` 를 쓰고 0단계 항목에도
/// 들여쓰기 두 칸을 넣는다. 그래서 `- 항목` 이 `  * 항목` 으로 바뀐다.
/// 여기서는 `-` 를 쓰고 단계만큼만 들여쓴다.
class _ListItemSerializer
    extends NodeTypedDocumentNodeMarkdownSerializer<ListItemNode> {
  const _ListItemSerializer();

  @override
  String doSerialization(
    Document document,
    ListItemNode node, {
    NodeSelection? selection,
  }) {
    if (selection != null && selection is! TextNodeSelection) return '';

    final textSelection = selection as TextNodeSelection?;
    if (textSelection != null && textSelection.isCollapsed) return '';

    final text = textSelection != null
        ? node.text.copyText(textSelection.start, textSelection.end)
        : node.text;

    final indent = '  ' * node.indent;
    final marker = node.type == ListItemType.unordered ? '-' : '1.';

    final buffer = StringBuffer()
      ..write('$indent$marker ${text.toMarkdown()}');

    // 목록이 끝나는 자리에는 빈 줄을 둔다. 다음 블록과 붙으면 같은 목록으로
    // 읽힌다.
    final index = document.getNodeIndexById(node.id);
    final below = index < document.nodeCount - 1
        ? document.getNodeAt(index + 1)
        : null;
    if (below != null && (below is! ListItemNode || below.type != node.type)) {
      buffer.writeln('');
    }

    return buffer.toString();
  }
}
