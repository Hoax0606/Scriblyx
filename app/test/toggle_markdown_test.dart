import 'package:flutter_test/flutter_test.dart';
import 'package:scriblyx/data/markdown/blocks/toggle_node.dart';
import 'package:scriblyx/data/markdown/note_markdown_codec.dart';
import 'package:super_editor/super_editor.dart';

const _withToggle = '''
앞 문단

<details><summary>접힌 제목</summary>

안쪽 문단입니다.

- 안쪽 목록

</details>

뒤 문단
''';

void main() {
  group('토글 읽기', () {
    late MutableDocument document;

    setUp(() {
      document = NoteMarkdownCodec().decode(_withToggle);
    });

    test('제목이 토글 노드가 된다', () {
      final toggle = document.whereType<ToggleNode>().single;
      expect(toggle.text.toPlainText(), '접힌 제목');
    });

    test('안쪽 내용이 보통 노드로 풀린다', () {
      final toggle = document.whereType<ToggleNode>().single;
      final children = document
          .where((node) => node.toggleParentId == toggle.id)
          .toList();

      expect(children.length, 2);
      expect((children[0] as TextNode).text.toPlainText(), '안쪽 문단입니다.');
      expect(children[1], isA<ListItemNode>());
    });

    test('토글 바깥 노드는 소속 표시가 없다', () {
      final outside = document
          .whereType<TextNode>()
          .where((node) => node.text.toPlainText().contains('문단'))
          .where((node) => node.toggleParentId == null)
          .map((node) => node.text.toPlainText())
          .toList();

      expect(outside, containsAll(['앞 문단', '뒤 문단']));
    });
  });

  group('토글 쓰기', () {
    test('건드리지 않으면 원본이 그대로 나온다', () {
      final codec = NoteMarkdownCodec();
      final document = codec.decode(_withToggle);
      expect(codec.encode(document), _withToggle);
    });

    test('제목을 고치면 details 형태로 다시 쓰인다', () {
      final codec = NoteMarkdownCodec();
      final document = codec.decode(_withToggle);

      final toggle = document.whereType<ToggleNode>().single;
      document.replaceNodeById(
        toggle.id,
        toggle.copyToggleWith(text: AttributedText('바뀐 제목')),
      );

      final output = codec.encode(document);
      expect(output, contains('<details><summary>바뀐 제목</summary>'));
      expect(output, contains('안쪽 문단입니다.'));
      expect(output, contains('- 안쪽 목록'));
      expect(output, contains('</details>'));
      expect(output, contains('앞 문단'));
      expect(output, contains('뒤 문단'));
      expect('</details>'.allMatches(output).length, 1);
    });

    test('안쪽을 고쳐도 토글 구조가 유지된다', () {
      final codec = NoteMarkdownCodec();
      final document = codec.decode(_withToggle);

      final inner = document.firstWhere(
        (node) =>
            node is TextNode &&
            node.text.toPlainText() == '안쪽 문단입니다.',
      );
      document.replaceNodeById(
        inner.id,
        ParagraphNode(
          id: inner.id,
          text: AttributedText('고친 안쪽'),
          metadata: Map.from(inner.metadata),
        ),
      );

      final output = codec.encode(document);
      expect(output, contains('<details><summary>접힌 제목</summary>'));
      expect(output, contains('고친 안쪽'));
      expect(output, isNot(contains('안쪽 문단입니다.')));
      expect(output, contains('</details>'));
    });

    test('소속 표시가 파일로 새어나가지 않는다', () {
      final codec = NoteMarkdownCodec();
      final document = codec.decode(_withToggle);

      final toggle = document.whereType<ToggleNode>().single;
      document.replaceNodeById(
        toggle.id,
        toggle.copyToggleWith(text: AttributedText('바뀐 제목')),
      );

      expect(codec.encode(document), isNot(contains('scriblyx')));
    });
  });
}
