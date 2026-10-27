import 'package:super_editor/super_editor.dart';

import 'blocks/toggle_node.dart';
import 'markdown_block.dart';
import 'markdown_block_splitter.dart';
import 'node_serializers.dart';
import 'toggle_markdown.dart';

/// 같은 블록에서 나온 노드들을 묶는 식별자.
const _blockKey = 'scriblyxBlock';

/// 마크다운과 super_editor 문서 사이를 오간다.
///
/// 불러올 때 각 블록의 원본 조각을 기억해둔다. 저장할 때 그 블록에서 나온
/// 노드가 모두 그대로면 원본 조각을 다시 쓴다. 그래서 편집하지 않은 부분은
/// 바이트가 바뀌지 않는다.
class NoteMarkdownCodec {
  /// 불러온 시점의 노드. [DocumentNode] 는 불변이라 편집하면 새 인스턴스로
  /// 교체되므로, 참조를 들고 있으면 그대로 비교 기준이 된다.
  final Map<String, DocumentNode> _loaded = {};

  /// 블록 식별자별 원본 조각.
  final Map<String, String> _blockSource = {};

  /// 블록 식별자별로 불러올 때 만들어진 노드 수.
  ///
  /// 일부가 지워졌는데 원본 조각을 다시 쓰면 지운 내용이 되살아난다.
  final Map<String, int> _blockNodeCount = {};

  /// 본문보다 앞서는 frontmatter. 마크다운이 아니라 속성이므로 파싱하지 않고
  /// 원본 그대로 보관한다.
  String? _frontmatter;

  String? get frontmatter => _frontmatter;

  MutableDocument decode(String markdown) {
    _loaded.clear();
    _blockSource.clear();
    _blockNodeCount.clear();
    _frontmatter = null;

    final nodes = <DocumentNode>[];
    var blockIndex = 0;

    for (final block in splitMarkdownBlocks(markdown)) {
      if (block.kind == MarkdownBlockKind.frontmatter && _frontmatter == null) {
        _frontmatter = block.source;
        continue;
      }
      if (block.kind == MarkdownBlockKind.blank) {
        // 블록마다 뒤따르는 빈 줄을 이미 품고 있으므로 따로 둘 필요가 없다.
        if (nodes.isEmpty && _frontmatter != null) {
          _frontmatter = '${_frontmatter!}${block.source}';
        }
        continue;
      }

      final blockId = 'b${blockIndex++}';
      _blockSource[blockId] = block.source;

      final produced = _decodeBlock(block, blockId).toList();
      _blockNodeCount[blockId] = produced.length;
      for (final node in produced) {
        nodes.add(node);
        _loaded[node.id] = node;
      }
    }

    if (nodes.isEmpty) {
      nodes.add(
        ParagraphNode(id: Editor.createNodeId(), text: AttributedText('')),
      );
    }
    return MutableDocument(nodes: nodes);
  }

  String encode(Document document) {
    final buffer = StringBuffer();
    if (_frontmatter != null) {
      buffer.write(_frontmatter);
    }

    for (final group in _groupByBlock(document)) {
      if (_canReuseSource(group)) {
        buffer.write(_blockSource[group.blockId]);
      } else {
        buffer.write(_encodeNodes(group.nodes));
      }
    }
    return buffer.toString();
  }

  /// 문서 순서대로 훑으면서 같은 블록에서 나온 연속된 노드를 묶는다.
  List<_NodeGroup> _groupByBlock(Document document) {
    final groups = <_NodeGroup>[];
    for (final node in document) {
      final blockId = node.getMetadataValue(_blockKey) as String?;
      final last = groups.isEmpty ? null : groups.last;
      if (blockId != null && last != null && last.blockId == blockId) {
        last.nodes.add(node);
      } else {
        groups.add(_NodeGroup(blockId, [node]));
      }
    }
    return groups;
  }

  /// 블록에서 나온 노드가 하나도 빠지지 않고 전부 그대로일 때만 원본을 쓴다.
  bool _canReuseSource(_NodeGroup group) {
    final blockId = group.blockId;
    if (blockId == null) return false;
    if (_blockNodeCount[blockId] != group.nodes.length) return false;
    return group.nodes.every(_isUnchanged);
  }

  bool _isUnchanged(DocumentNode node) {
    final loaded = _loaded[node.id];
    return loaded != null && loaded.hasEquivalentContent(node);
  }

  Iterable<DocumentNode> _decodeBlock(MarkdownBlock block, String blockId) {
    DocumentNode tag(DocumentNode node) =>
        node.copyWithAddedMetadata({_blockKey: blockId});

    if (block.kind == MarkdownBlockKind.html &&
        isToggleBlock(block.content)) {
      final toggle = decodeToggle(block.content, tag);
      if (toggle != null) return toggle;
    }

    return deserializeMarkdownToDocument(block.content).map(tag);
  }

  String _encodeNodes(List<DocumentNode> nodes) {
    final first = nodes.first;
    if (first is ToggleNode) {
      return encodeToggle(first, nodes.skip(1).toList());
    }

    final text = serializeDocumentToMarkdown(
      MutableDocument(nodes: nodes),
      customNodeSerializers: scriblyxNodeSerializers,
    );
    if (text.isEmpty) return '';
    return text.endsWith('\n') ? '$text\n' : '$text\n\n';
  }
}

class _NodeGroup {
  _NodeGroup(this.blockId, this.nodes);

  final String? blockId;
  final List<DocumentNode> nodes;
}
