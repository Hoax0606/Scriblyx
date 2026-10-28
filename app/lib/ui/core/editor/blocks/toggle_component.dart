import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import '../../../../data/markdown/blocks/toggle_node.dart';

/// 토글 제목 줄을 그린다.
///
/// 화살표를 누르면 접히고 펴진다. 제목은 보통 글처럼 편집할 수 있다.
/// 접혀 있을 때 자식 노드를 레이아웃에서 빼는 일은 [CollapsedTogglePhase] 가
/// 맡는다.
class ToggleComponentBuilder implements ComponentBuilder {
  const ToggleComponentBuilder(this._editor);

  final Editor _editor;

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(
    Document document,
    DocumentNode node,
  ) {
    if (node is! ToggleNode) return null;

    return ToggleComponentViewModel(
      nodeId: node.id,
      createdAt: node.metadata[NodeMetadata.createdAt],
      padding: EdgeInsets.zero,
      isExpanded: node.isExpanded,
      setExpanded: (expanded) => _setExpanded(node.id, expanded),
      text: node.text,
      textStyleBuilder: noStyleBuilder,
      selectionColor: const Color(0x00000000),
    );
  }

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel is! ToggleComponentViewModel) return null;
    return ToggleComponent(
      key: componentContext.componentKey,
      viewModel: componentViewModel,
    );
  }

  void _setExpanded(String nodeId, bool expanded) {
    final document = _editor.context.document;
    final node = document.getNodeById(nodeId);
    if (node is! ToggleNode) return;

    _editor.execute([
      ReplaceNodeRequest(
        existingNodeId: nodeId,
        newNode: node.copyToggleWith(isExpanded: expanded),
      ),
    ]);
  }
}

class ToggleComponentViewModel extends SingleColumnLayoutComponentViewModel
    with TextComponentViewModel {
  ToggleComponentViewModel({
    required super.nodeId,
    super.createdAt,
    super.maxWidth,
    required super.padding,
    super.opacity = 1.0,
    required this.isExpanded,
    required this.setExpanded,
    required this.text,
    required this.textStyleBuilder,
    this.inlineWidgetBuilders = const [],
    this.textDirection = TextDirection.ltr,
    this.textAlignment = TextAlign.left,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.selection,
    required this.selectionColor,
    this.highlightWhenEmpty = false,
    TextRange? composingRegion,
    bool showComposingRegionUnderline = false,
  }) {
    this.composingRegion = composingRegion;
    this.showComposingRegionUnderline = showComposingRegionUnderline;
  }

  final bool isExpanded;
  final void Function(bool expanded) setExpanded;

  @override
  AttributedText text;

  @override
  AttributionStyleBuilder textStyleBuilder;

  @override
  List<InlineWidgetBuilder> inlineWidgetBuilders;

  @override
  TextDirection textDirection;

  @override
  TextAlign textAlignment;

  @override
  int? maxLines;

  @override
  TextOverflow overflow;

  @override
  TextSelection? selection;

  @override
  Color selectionColor;

  @override
  bool highlightWhenEmpty;

  @override
  ToggleComponentViewModel copy() => ToggleComponentViewModel(
    nodeId: nodeId,
    createdAt: createdAt,
    maxWidth: maxWidth,
    padding: padding,
    opacity: opacity,
    isExpanded: isExpanded,
    setExpanded: setExpanded,
    text: text,
    textStyleBuilder: textStyleBuilder,
    inlineWidgetBuilders: inlineWidgetBuilders,
    textDirection: textDirection,
    textAlignment: textAlignment,
    maxLines: maxLines,
    overflow: overflow,
    selection: selection,
    selectionColor: selectionColor,
    highlightWhenEmpty: highlightWhenEmpty,
    composingRegion: composingRegion,
    showComposingRegionUnderline: showComposingRegionUnderline,
  );
}

class ToggleComponent extends StatefulWidget {
  const ToggleComponent({super.key, required this.viewModel});

  final ToggleComponentViewModel viewModel;

  @override
  State<ToggleComponent> createState() => _ToggleComponentState();
}

class _ToggleComponentState extends State<ToggleComponent>
    with ProxyDocumentComponent<ToggleComponent>, ProxyTextComposable {
  final GlobalKey _textKey = GlobalKey();

  @override
  GlobalKey<State<StatefulWidget>> get childDocumentComponentKey => _textKey;

  @override
  TextComposable get childTextComposable =>
      childDocumentComponentKey.currentState as TextComposable;

  @override
  Widget build(BuildContext context) {
    final expanded = widget.viewModel.isExpanded;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          child: IconButton(
            onPressed: () => widget.viewModel.setExpanded(!expanded),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            iconSize: 18,
            icon: Icon(
              expanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
            ),
            tooltip: expanded ? '접기' : '펴기',
          ),
        ),
        Expanded(
          child: TextComponent(
            key: _textKey,
            text: widget.viewModel.text,
            textStyleBuilder: widget.viewModel.textStyleBuilder,
            textSelection: widget.viewModel.selection,
            selectionColor: widget.viewModel.selectionColor,
            highlightWhenEmpty: widget.viewModel.highlightWhenEmpty,
          ),
        ),
      ],
    );
  }
}

/// 접힌 토글에 속한 노드를 레이아웃에서 뺀다.
///
/// 높이만 0 으로 만들면 보이지 않는 자리에 커서가 들어가 입력이 사라진 것처럼
/// 보인다. 아예 빼야 그런 일이 없다.
class CollapsedTogglePhase extends SingleColumnLayoutStylePhase {
  @override
  SingleColumnLayoutViewModel style(
    Document document,
    SingleColumnLayoutViewModel viewModel,
  ) {
    final collapsed = <String>{
      for (final node in document)
        if (node is ToggleNode && !node.isExpanded) node.id,
    };
    if (collapsed.isEmpty) return viewModel;

    return SingleColumnLayoutViewModel(
      padding: viewModel.padding,
      componentViewModels: [
        for (final component in viewModel.componentViewModels)
          if (!_isHidden(document, component.nodeId, collapsed)) component,
      ],
    );
  }

  bool _isHidden(
    Document document,
    String nodeId,
    Set<String> collapsedToggleIds,
  ) {
    final parentId = document.getNodeById(nodeId)?.toggleParentId;
    return parentId != null && collapsedToggleIds.contains(parentId);
  }
}
