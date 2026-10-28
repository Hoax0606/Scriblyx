import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scriblyx/data/markdown/blocks/toggle_node.dart';
import 'package:scriblyx/data/markdown/note_markdown_codec.dart';
import 'package:scriblyx/ui/core/editor/blocks/toggle_component.dart';
import 'package:scriblyx/ui/core/editor/editor_requests.dart';
import 'package:super_editor/super_editor.dart';

const _markdown = '''
앞 문단

<details><summary>접힌 제목</summary>

안쪽 문단입니다.

</details>

뒤 문단
''';

void main() {
  late MutableDocument document;
  late MutableDocumentComposer composer;
  late Editor editor;

  setUp(() {
    document = NoteMarkdownCodec().decode(_markdown);
    composer = MutableDocumentComposer();
    editor = Editor(
      editables: {
        Editor.documentKey: document,
        Editor.composerKey: composer,
      },
      requestHandlers: scriblyxRequestHandlers(),
    );
  });

  tearDown(() {
    editor.dispose();
    composer.dispose();
    document.dispose();
  });

  Widget wrap(Editor editor) => MaterialApp(
    home: Scaffold(
      body: SuperEditor(
        editor: editor,
        componentBuilders: [
          ToggleComponentBuilder(editor),
          ...defaultComponentBuilders,
        ],
        customStylePhases: [TogglePhase()],
      ),
    ),
  );

  /// super_editor 는 글을 자체 렌더링으로 그려 find.text 로 잡히지 않는다.
  /// 문단 수는 그려진 TextComponent 개수로 센다.
  int paragraphCount(WidgetTester tester) =>
      tester.widgetList(find.byType(TextComponent)).length;

  testWidgets('토글 제목 위젯이 그려진다', (tester) async {
    await tester.pumpWidget(wrap(editor));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(ToggleComponent), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
  });

  testWidgets('화살표가 실제로 자리를 차지한다', (tester) async {
    await tester.pumpWidget(wrap(editor));
    await tester.pump();

    final icon = find.byIcon(Icons.keyboard_arrow_down);
    final size = tester.getSize(icon);
    final rect = tester.getRect(icon);

    // 크기가 0 이면 글리프가 그려질 자리가 없다.
    expect(size.width, greaterThan(0));
    expect(size.height, greaterThan(0));
    // 화면 밖으로 밀려나지 않았는지.
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.top, greaterThanOrEqualTo(0));
  });

  testWidgets('펼쳐져 있으면 안쪽까지 그려진다', (tester) async {
    await tester.pumpWidget(wrap(editor));
    await tester.pump();

    // 앞 문단, 토글 제목, 안쪽 문단, 뒤 문단
    expect(paragraphCount(tester), 4);
  });

  testWidgets('접으면 안쪽이 레이아웃에서 빠진다', (tester) async {
    await tester.pumpWidget(wrap(editor));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.keyboard_arrow_right), findsOneWidget);
    // 안쪽 문단이 빠져 셋만 남는다.
    expect(paragraphCount(tester), 3);
  });

  group('토글 제목에서 Enter', () {
    /// 토글 제목 끝에 커서를 두고 Enter 를 누른 것과 같은 요청을 보낸다.
    void pressEnterAtEndOfTitle() {
      final toggle = document.whereType<ToggleNode>().single;
      editor.execute([
        ChangeSelectionRequest(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: toggle.id,
              nodePosition: TextNodePosition(offset: toggle.text.length),
            ),
          ),
          SelectionChangeType.placeCaret,
          SelectionReason.userInteraction,
        ),
        InsertNewlineAtCaretRequest(),
      ]);
    }

    test('토글 안쪽에 새 블록이 생긴다', () {
      final before = document.nodeCount;
      pressEnterAtEndOfTitle();

      expect(document.nodeCount, before + 1);

      final toggle = document.whereType<ToggleNode>().single;
      final index = document.getNodeIndexById(toggle.id);
      final created = document.getNodeAt(index + 1)!;

      expect(created.toggleParentId, toggle.id);
      expect((created as TextNode).text.toPlainText(), isEmpty);
    });

    test('토글은 그대로 남는다', () {
      pressEnterAtEndOfTitle();
      final toggle = document.whereType<ToggleNode>().single;
      expect(toggle.text.toPlainText(), '접힌 제목');
    });

    test('제목이 비어 있으면 토글을 그만둔다', () {
      final toggle = document.whereType<ToggleNode>().single;
      document.replaceNodeById(
        toggle.id,
        toggle.copyToggleWith(text: AttributedText('')),
      );

      editor.execute([
        ChangeSelectionRequest(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: toggle.id,
              nodePosition: const TextNodePosition(offset: 0),
            ),
          ),
          SelectionChangeType.placeCaret,
          SelectionReason.userInteraction,
        ),
        InsertNewlineAtCaretRequest(),
      ]);

      expect(document.whereType<ToggleNode>(), isEmpty);
      expect(document.getNodeById(toggle.id), isA<ParagraphNode>());
    });
  });

  test('문서에 토글 노드가 하나 있다', () {
    expect(document.whereType<ToggleNode>().length, 1);
    expect(
      document.whereType<ToggleNode>().single.text.toPlainText(),
      '접힌 제목',
    );
  });
}
