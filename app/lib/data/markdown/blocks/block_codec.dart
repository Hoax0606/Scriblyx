import 'package:super_editor/super_editor.dart';

import '../markdown_block.dart';

/// 마크다운 한 블록과 문서 노드들 사이를 오가는 규칙.
///
/// 표준 마크다운으로 표현되지 않는 블록(토글, 콜아웃 등)마다 하나씩 만든다.
/// [NoteMarkdownCodec] 은 등록된 규칙들을 차례로 물어보기만 하므로, 블록
/// 종류를 늘려도 고치지 않는다.
abstract class BlockCodec {
  const BlockCodec();

  /// 이 블록을 맡을 수 있으면 노드들을 돌려준다. 아니면 null.
  ///
  /// 돌려준 노드에 블록 소속 표시를 붙이는 일은 호출한 쪽이 한다.
  List<DocumentNode>? decode(MarkdownBlock block);

  /// 한 블록에서 나온 노드 묶음을 맡을 수 있는지. 묶음의 첫 노드로 판단한다.
  bool canEncode(DocumentNode first);

  /// 노드 묶음을 마크다운으로 되돌린다. 뒤따르는 빈 줄까지 포함한다.
  String encode(List<DocumentNode> nodes);
}
