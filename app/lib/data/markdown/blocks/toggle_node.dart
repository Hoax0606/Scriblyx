import 'package:super_editor/super_editor.dart';

const toggleAttribution = NamedAttribution('toggle');

/// 자식 노드가 이 토글에 속한다는 표시. 값은 토글 노드의 id 다.
const toggleParentKey = 'scriblyxToggleParent';

/// 접었다 펼 수 있는 블록의 제목 줄.
///
/// 안쪽 내용은 이 노드가 품지 않는다. 문서에서 바로 뒤에 오는 평범한 노드들이
/// [toggleParentKey] 메타데이터로 이 노드를 가리킨다. 그래서 안쪽에서도
/// 보통 블록처럼 편집할 수 있다.
///
/// 파일에는 `<details><summary>제목</summary>` 과 `</details>` 사이로 저장된다.
class ToggleNode extends TextNode {
  ToggleNode({
    required super.id,
    required super.text,
    super.metadata,
    this.isExpanded = true,
  }) {
    initAddToMetadata({NodeMetadata.blockType: toggleAttribution});
  }

  /// 펼쳐져 있는지. 접혀 있으면 자식 노드를 그리지 않는다.
  ///
  /// 이 값은 화면 상태일 뿐이라 파일에 저장하지 않는다.
  final bool isExpanded;

  @override
  bool hasEquivalentContent(DocumentNode other) =>
      other is ToggleNode && super.hasEquivalentContent(other);

  ToggleNode copyToggleWith({
    String? id,
    AttributedText? text,
    Map<String, dynamic>? metadata,
    bool? isExpanded,
  }) => ToggleNode(
    id: id ?? this.id,
    text: text ?? this.text,
    metadata: metadata ?? this.metadata,
    isExpanded: isExpanded ?? this.isExpanded,
  );

  @override
  ToggleNode copyTextNodeWith({
    String? id,
    AttributedText? text,
    Map<String, dynamic>? metadata,
  }) => copyToggleWith(id: id, text: text, metadata: metadata);

  @override
  ToggleNode copyAndReplaceMetadata(Map<String, dynamic> newMetadata) =>
      copyToggleWith(metadata: newMetadata);

  @override
  ToggleNode copyWithAddedMetadata(Map<String, dynamic> newProperties) =>
      copyToggleWith(metadata: {...metadata, ...newProperties});

  @override
  ToggleNode copy() => copyToggleWith(metadata: Map.from(metadata));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ToggleNode &&
          super == other &&
          isExpanded == other.isExpanded;

  @override
  int get hashCode => super.hashCode ^ isExpanded.hashCode;
}

extension ToggleMembership on DocumentNode {
  /// 이 노드가 속한 토글의 id. 토글 밖이면 null.
  String? get toggleParentId => getMetadataValue(toggleParentKey) as String?;
}
