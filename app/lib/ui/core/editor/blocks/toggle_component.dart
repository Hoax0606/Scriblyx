import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import '../../../../data/markdown/blocks/toggle_node.dart';

/// 토글 제목 줄을 그린다.
///
/// 화살표를 누르면 접히고 펴진다. 제목은 보통 글처럼 편집할 수 있다.
/// 안쪽 노드를 들여쓰고 접혔을 때 빼는 일은 [TogglePhase] 가
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
    final viewModel = widget.viewModel;
    final expanded = viewModel.isExpanded;

    return Directionality(
      textDirection: viewModel.textDirection,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // IconButton 은 자체 포커스 노드를 가져 에디터의 포커스를 가져간다.
          // 그러면 화살표를 누른 뒤 글이 입력되지 않는다.
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => viewModel.setExpanded(!expanded),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(right: 4, top: 2),
                child: Icon(
                  expanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Expanded(
            child: TextComponent(
              key: _textKey,
              text: viewModel.text,
              textDirection: viewModel.textDirection,
              textAlign: viewModel.textAlignment,
              maxLines: viewModel.maxLines,
              overflow: viewModel.overflow,
              textStyleBuilder: viewModel.textStyleBuilder,
              inlineWidgetBuilders: viewModel.inlineWidgetBuilders,
              textSelection: viewModel.selection,
              selectionColor: viewModel.selectionColor,
              highlightWhenEmpty: viewModel.highlightWhenEmpty,
              underlines: viewModel.createUnderlines(),
            ),
          ),
        ],
      ),
    );
  }
}

/// 토글 제목에 쓰는 글자 모양. 기본 문단보다 조금 굵게 둔다.
final toggleStyleRule = StyleRule(
  const BlockSelector('toggle'),
  (document, node) => {
    Styles.padding: const CascadingPadding.only(top: 12),
    Styles.textStyle: const TextStyle(fontWeight: FontWeight.w600),
  },
);

/// 토글 안쪽 노드를 들여쓰고, 접힌 토글의 안쪽은 레이아웃에서 뺀다.
///
/// 높이만 0 으로 만들면 보이지 않는 자리에 커서가 들어가 입력이 사라진 것처럼
/// 보인다. 아예 빼야 그런 일이 없다.
class TogglePhase extends SingleColumnLayoutStylePhase {
  /// 안쪽임을 드러내는 들여쓰기. 토글 화살표 너비와 맞춘다.
  static const childIndent = 24.0;

  @override
  SingleColumnLayoutViewModel style(
    Document document,
    SingleColumnLayoutViewModel viewModel,
  ) {
    final collapsed = <String>{
      for (final node in document)
        if (node is ToggleNode && !node.isExpanded) node.id,
    };

    final visible = <SingleColumnLayoutComponentViewModel>[];
    for (final component in viewModel.componentViewModels) {
      final parentId = document.getNodeById(component.nodeId)?.toggleParentId;
      if (parentId == null) {
        visible.add(component);
        continue;
      }
      if (collapsed.contains(parentId)) continue;

      visible.add(
        component.copy()
          ..padding = component.padding.add(
            const EdgeInsets.only(left: childIndent),
          ),
      );
    }

    return SingleColumnLayoutViewModel(
      padding: viewModel.padding,
      componentViewModels: visible,
    );
  }
}
