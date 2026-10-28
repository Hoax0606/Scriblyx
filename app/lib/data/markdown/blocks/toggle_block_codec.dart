import 'package:super_editor/super_editor.dart';

import '../markdown_block.dart';
import '../node_serializers.dart';
import 'block_codec.dart';
import 'toggle_node.dart';

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
class ToggleBlockCodec extends BlockCodec {
  const ToggleBlockCodec();

  static final _openPattern = RegExp(
    r'^\s*<details[^>]*>\s*<summary[^>]*>(.*?)</summary>\s*$',
    caseSensitive: false,
    dotAll: true,
  );

  static final _closePattern = RegExp(
    r'^\s*</details>\s*$',
    caseSensitive: false,
  );

  @override
  List<DocumentNode>? decode(MarkdownBlock block) {
    if (block.kind != MarkdownBlockKind.html) return null;

    final lines = block.content.split('\n');
    final opening = _openPattern.firstMatch(lines.first);
    if (opening == null) return null;

    var end = lines.length - 1;
    while (end > 0 && !_closePattern.hasMatch(lines[end])) {
      end--;
    }
    if (end == 0) return null;

    final toggle = ToggleNode(
      id: Editor.createNodeId(),
      text: AttributedText(opening.group(1)?.trim() ?? ''),
    );

    final inner = lines.sublist(1, end).join('\n').trim();
    if (inner.isEmpty) return [toggle];

    return [
      toggle,
      ...deserializeMarkdownToDocument(inner).map(
        (node) => node.copyWithAddedMetadata({toggleParentKey: toggle.id}),
      ),
    ];
  }

  @override
  bool canEncode(DocumentNode first) => first is ToggleNode;

  @override
  String encode(List<DocumentNode> nodes) {
    final toggle = nodes.first as ToggleNode;
    final children = nodes.skip(1).toList();

    final buffer = StringBuffer()
      ..writeln('<details><summary>${toggle.text.toPlainText()}</summary>')
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

  /// 토글 소속 표시는 화면용이라 파일에 나가면 안 된다.
  DocumentNode _withoutToggleParent(DocumentNode node) {
    final metadata = Map<String, dynamic>.from(node.metadata)
      ..remove(toggleParentKey);
    return node.copyAndReplaceMetadata(metadata);
  }
}
