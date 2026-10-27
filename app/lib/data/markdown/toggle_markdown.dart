import 'package:super_editor/super_editor.dart';

import 'blocks/toggle_node.dart';
import 'node_serializers.dart';

/// `<details>` 블록과 토글 노드 사이를 오간다.
///
/// 저장 형태:
/// ```
/// <details><summary>제목</summary>
///
/// 안쪽 내용
///
/// </details>
/// ```
/// 안쪽 내용 위아래의 빈 줄은 마크다운이 해석되게 하려고 둔다. 빈 줄이 없으면
/// 대부분의 렌더러가 안쪽을 그냥 글자로 다룬다.

final _openPattern = RegExp(
  r'^\s*<details[^>]*>\s*<summary[^>]*>(.*?)</summary>\s*$',
  caseSensitive: false,
  dotAll: true,
);

final _closePattern = RegExp(r'^\s*</details>\s*$', caseSensitive: false);

bool isToggleBlock(String markdown) =>
    _openPattern.hasMatch(markdown.split('\n').first);

/// `<details>` 블록을 토글 제목 노드와 자식 노드들로 바꾼다.
///
/// 형태가 맞지 않으면 null 을 돌려준다. 그러면 호출한 쪽이 평범한 HTML
/// 블록으로 다룬다.
List<DocumentNode>? decodeToggle(
  String markdown,
  DocumentNode Function(DocumentNode node) tag,
) {
  final lines = markdown.split('\n');
  final opening = _openPattern.firstMatch(lines.first);
  if (opening == null) return null;

  var end = lines.length - 1;
  while (end > 0 && !_closePattern.hasMatch(lines[end])) {
    end--;
  }
  if (end == 0) return null;

  final title = opening.group(1)?.trim() ?? '';
  final inner = lines.sublist(1, end).join('\n').trim();

  final toggle = ToggleNode(
    id: Editor.createNodeId(),
    text: AttributedText(title),
  );

  final children = inner.isEmpty
      ? <DocumentNode>[]
      : deserializeMarkdownToDocument(inner)
            .map(
              (node) =>
                  node.copyWithAddedMetadata({toggleParentKey: toggle.id}),
            )
            .toList();

  return [tag(toggle), ...children.map(tag)];
}

/// 토글 제목 노드와 자식 노드들을 `<details>` 블록으로 되돌린다.
String encodeToggle(ToggleNode toggle, List<DocumentNode> children) {
  final title = toggle.text.toPlainText();
  final buffer = StringBuffer()
    ..writeln('<details><summary>$title</summary>')
    ..writeln();

  if (children.isNotEmpty) {
    final inner = serializeDocumentToMarkdown(
      MutableDocument(nodes: children.map(_withoutToggleParent).toList()),
      customNodeSerializers: scriblyxNodeSerializers,
    );
    buffer.writeln(inner.trimRight());
    buffer.writeln();
  }

  buffer.writeln('</details>');
  buffer.writeln();
  return buffer.toString();
}

/// 직렬화할 때 토글 소속 표시는 파일에 나갈 내용이 아니므로 뗀다.
DocumentNode _withoutToggleParent(DocumentNode node) {
  final metadata = Map<String, dynamic>.from(node.metadata)
    ..remove(toggleParentKey);
  return node.copyAndReplaceMetadata(metadata);
}
