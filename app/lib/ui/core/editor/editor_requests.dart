import 'package:super_editor/super_editor.dart';

import '../../../data/markdown/blocks/toggle_node.dart';

/// super_editor 기본 요청 핸들러에 우리 블록용 처리를 더한다.
///
/// 핸들러는 앞에 둔 것부터 물어보므로 우리 것을 먼저 둔다.
List<EditRequestHandler> scriblyxRequestHandlers() => [
  _toggleNewlineHandler,
  _toggleChildNewlineHandler,
  ...defaultRequestHandlers,
];

/// 토글 제목에서 Enter 를 쳤을 때의 동작.
///
/// 기본 핸들러는 노드 종류별로 등록되어 있고 [ToggleNode] 용이 없다. 그래서
/// 토글 제목에서 Enter 를 치면 아무 일도 일어나지 않는다.
EditCommand? _toggleNewlineHandler(Editor editor, EditRequest request) {
  if (request is! InsertNewlineAtCaretRequest) return null;

  final selection = editor.composer.selection;
  if (selection == null) return null;

  final node = editor.document.getNodeById(selection.base.nodeId);
  if (node is! ToggleNode) return null;

  return InsertNewlineInToggleCommand(request.newNodeId);
}

/// 토글 안쪽 문단에서 Enter 를 쳤을 때의 동작.
///
/// 기본 처리기는 새 문단을 만들 때 소속 표시를 물려주지 않아, 안쪽에서 줄을
/// 바꾸면 토글 밖으로 빠져나갔다.
EditCommand? _toggleChildNewlineHandler(Editor editor, EditRequest request) {
  if (request is! InsertNewlineAtCaretRequest) return null;

  final selection = editor.composer.selection;
  if (selection == null) return null;

  final node = editor.document.getNodeById(selection.base.nodeId);
  if (node is! ParagraphNode) return null;

  final parentId = node.toggleParentId;
  if (parentId == null) return null;

  return InsertNewlineInToggleChildCommand(request.newNodeId, parentId);
}

class InsertNewlineInToggleChildCommand extends BaseInsertNewlineAtCaretCommand {
  const InsertNewlineInToggleChildCommand(this.newNodeId, this.toggleId);

  final String newNodeId;
  final String toggleId;

  @override
  void doInsertNewline(
    EditContext context,
    CommandExecutor executor,
    DocumentPosition caretPosition,
    NodePosition caretNodePosition,
  ) {
    final node = context.document.getNodeById(caretPosition.nodeId);
    if (caretNodePosition is! TextNodePosition || node is! ParagraphNode) {
      return;
    }

    if (node.text.isEmpty) {
      // 빈 줄에서 Enter 를 치면 토글에서 빠져나간다. 그래야 나올 방법이 있다.
      final metadata = Map<String, dynamic>.from(node.metadata)
        ..remove(toggleParentKey);
      executor.executeCommand(
        ReplaceNodeCommand(
          existingNodeId: node.id,
          newNode: ParagraphNode(
            id: node.id,
            text: AttributedText(''),
            metadata: metadata,
          ),
        ),
      );
      return;
    }

    final offset = caretNodePosition.offset;
    final carried = node.text.copyText(offset);
    final remaining = node.text.removeRegion(
      startOffset: offset,
      endOffset: node.text.length,
    );

    executor
      ..executeCommand(
        ReplaceNodeCommand(
          existingNodeId: node.id,
          newNode: node.copyParagraphWith(text: remaining),
        ),
      )
      ..executeCommand(
        InsertNodeAfterNodeCommand(
          existingNodeId: node.id,
          newNode: ParagraphNode(
            id: newNodeId,
            text: carried,
            metadata: {toggleParentKey: toggleId},
          ),
        ),
      )
      ..executeCommand(
        ChangeSelectionCommand(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: newNodeId,
              nodePosition: const TextNodePosition(offset: 0),
            ),
          ),
          SelectionChangeType.insertContent,
          SelectionReason.userInteraction,
        ),
      );
  }
}

class InsertNewlineInToggleCommand extends BaseInsertNewlineAtCaretCommand {
  const InsertNewlineInToggleCommand(this.newNodeId);

  final String newNodeId;

  @override
  void doInsertNewline(
    EditContext context,
    CommandExecutor executor,
    DocumentPosition caretPosition,
    NodePosition caretNodePosition,
  ) {
    final node = context.document.getNodeById(caretPosition.nodeId);
    if (caretNodePosition is! TextNodePosition || node is! ToggleNode) return;

    if (node.text.isEmpty) {
      // 제목이 빈 토글에서 Enter 를 치면 토글을 그만둔다.
      executor.executeCommand(
        ReplaceNodeCommand(
          existingNodeId: node.id,
          newNode: ParagraphNode(id: node.id, text: AttributedText('')),
        ),
      );
      return;
    }

    // 제목 뒤쪽 글자는 새로 만드는 안쪽 블록으로 옮긴다.
    final offset = caretNodePosition.offset;
    final carried = node.text.copyText(offset);
    final remaining = node.text.removeRegion(
      startOffset: offset,
      endOffset: node.text.length,
    );

    executor
      ..executeCommand(
        ReplaceNodeCommand(
          existingNodeId: node.id,
          newNode: node.copyToggleWith(text: remaining, isExpanded: true),
        ),
      )
      ..executeCommand(
        InsertNodeAfterNodeCommand(
          existingNodeId: node.id,
          newNode: ParagraphNode(
            id: newNodeId,
            text: carried,
            metadata: {toggleParentKey: node.id},
          ),
        ),
      )
      ..executeCommand(
        ChangeSelectionCommand(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: newNodeId,
              nodePosition: const TextNodePosition(offset: 0),
            ),
          ),
          SelectionChangeType.insertContent,
          SelectionReason.userInteraction,
        ),
      );
  }
}
