import 'package:super_editor/super_editor.dart';

/// 줄 맨 앞에 친 글자로 블록을 바꾸는 규칙들.
///
/// super_editor 기본값 대신 노션 표기를 따른다. 제목은 세 단계까지만 두고,
/// 인용은 `"`, 토글은 `>` 를 쓴다. 기본 규칙과 달리 이미 글이 있는 줄에서도
/// 변환된다.

/// 제목은 세 단계까지만 쓴다. 노션도 그렇다.
const headingMaxLevel = 3;

/// 노션 표기를 적용한 반응 목록.
///
/// 기본 목록에서 제목과 인용 규칙을 빼고 우리 것으로 바꾼다. 목록·할 일·
/// 수평선·링크 감지는 기본 동작이 노션과 같아 그대로 둔다.
List<EditReaction> notionStyleReactions() => [
  for (final reaction in defaultEditorReactions)
    if (reaction is! HeaderConversionReaction &&
        reaction is! BlockquoteConversionReaction)
      reaction,
  const HeadingReaction(),
  const QuoteReaction(),
  const TaskReaction(),
];

/// `#` 부터 `###` 까지로 제목을 만든다.
///
/// 기본 규칙은 패턴 끝을 고정해 빈 줄에서만 동작한다. 여기서는 고정하지 않아
/// 이미 글이 있는 줄 앞에 `# ` 를 쳐도 제목이 된다.
class HeadingReaction extends ParagraphPrefixConversionReaction {
  const HeadingReaction();

  static final _pattern = RegExp('^#{1,$headingMaxLevel}\\s');

  static const _attributions = <int, Attribution>{
    1: header1Attribution,
    2: header2Attribution,
    3: header3Attribution,
  };

  @override
  RegExp get pattern => _pattern;

  @override
  void onPrefixMatched(
    EditContext editContext,
    RequestDispatcher requestDispatcher,
    List<EditEvent> changeList,
    ParagraphNode paragraph,
    String match,
  ) {
    final level = match.length - 1;
    final attribution = _attributions[level];
    if (attribution == null) return;

    requestDispatcher.execute([
      ChangeParagraphBlockTypeRequest(
        nodeId: paragraph.id,
        blockType: attribution,
      ),
      ..._deletePrefix(paragraph, match.length),
    ]);
  }
}

/// `"` 와 공백으로 인용을 만든다. 노션과 같은 표기다.
class QuoteReaction extends ParagraphPrefixConversionReaction {
  const QuoteReaction();

  static final _pattern = RegExp(r'^"\s');

  @override
  RegExp get pattern => _pattern;

  @override
  void onPrefixMatched(
    EditContext editContext,
    RequestDispatcher requestDispatcher,
    List<EditEvent> changeList,
    ParagraphNode paragraph,
    String match,
  ) {
    requestDispatcher.execute([
      ChangeParagraphBlockTypeRequest(
        nodeId: paragraph.id,
        blockType: blockquoteAttribution,
      ),
      ..._deletePrefix(paragraph, match.length),
    ]);
  }
}

/// `[]` 와 공백으로 할 일을 만든다. 노션은 대괄호 사이에 공백을 두지 않는다.
class TaskReaction extends ParagraphPrefixConversionReaction {
  const TaskReaction();

  static final _pattern = RegExp(r'^\[\s?\]\s');

  @override
  RegExp get pattern => _pattern;

  @override
  void onPrefixMatched(
    EditContext editContext,
    RequestDispatcher requestDispatcher,
    List<EditEvent> changeList,
    ParagraphNode paragraph,
    String match,
  ) {
    requestDispatcher.execute([
      ..._deletePrefix(paragraph, match.length),
      ConvertParagraphToTaskRequest(nodeId: paragraph.id),
    ]);
  }
}

/// 변환을 일으킨 접두사를 지우고 커서를 줄 맨 앞에 둔다.
List<EditRequest> _deletePrefix(ParagraphNode paragraph, int length) {
  final prefix = DocumentSelection(
    base: DocumentPosition(
      nodeId: paragraph.id,
      nodePosition: const TextNodePosition(offset: 0),
    ),
    extent: DocumentPosition(
      nodeId: paragraph.id,
      nodePosition: TextNodePosition(offset: length),
    ),
  );

  return [
    ChangeSelectionRequest(
      prefix,
      SelectionChangeType.expandSelection,
      SelectionReason.contentChange,
    ),
    DeleteContentRequest(documentRange: prefix),
    ChangeSelectionRequest(
      DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: paragraph.id,
          nodePosition: const TextNodePosition(offset: 0),
        ),
      ),
      SelectionChangeType.deleteContent,
      SelectionReason.userInteraction,
    ),
  ];
}
