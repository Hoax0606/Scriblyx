import 'package:flutter_test/flutter_test.dart';
import 'package:scriblyx/data/markdown/note_markdown_codec.dart';
import 'package:super_editor/super_editor.dart';

const _hard = '''
---
title: 왕복 테스트
tags: [프로젝트, 긴급]
---

# 제목 1

보통 문단입니다. **굵게**, *기울임*, ~~취소선~~, `인라인 코드`.

## 제목 2

- 목록 항목
- 두 번째
  - 중첩 1단계
    - 중첩 2단계

> 인용문입니다.
> 두 줄짜리.

---

```dart
void main() {
  print('# 이건 제목이 아니다');
}
```

| 왼쪽 | 가운데 | 오른쪽 |
|:-----|:------:|-------:|
| 가   | 나     | 다     |

<details><summary>접힌 제목</summary>

내용입니다.

</details>

\\~물결표\\~ 와 \\*별표\\* 와 \\# 샵

[[다른 노트]] 와 [[노트|별칭]] 형식.

마지막 줄.
''';

void main() {
  group('편집하지 않으면 원본이 그대로 나온다', () {
    for (final entry in <String, String>{
      '빈 문서': '',
      '한 문단': '안녕하세요\n',
      '제목과 본문': '# 제목\n\n본문입니다.\n',
      '어려운 지문': _hard,
    }.entries) {
      test(entry.key, () {
        final codec = NoteMarkdownCodec();
        final document = codec.decode(entry.value);
        expect(codec.encode(document), entry.value);
      });
    }
  });

  group('손실되던 요소가 보존된다', () {
    late NoteMarkdownCodec codec;
    late MutableDocument document;
    late String output;

    setUp(() {
      codec = NoteMarkdownCodec();
      document = codec.decode(_hard);
      output = codec.encode(document);
    });

    test('코드 블록의 언어 태그', () {
      expect(output, contains('```dart'));
    });

    test('표의 정렬 표시', () {
      expect(output, contains('|:-----|:------:|-------:|'));
    });

    test('이스케이프한 백슬래시', () {
      expect(output, contains(r'\~물결표\~'));
      expect(output, contains(r'\# 샵'));
    });

    test('HTML 블록', () {
      expect(output, contains('<details><summary>접힌 제목</summary>'));
      expect(output, contains('</details>'));
    });

    test('frontmatter', () {
      expect(output, contains('title: 왕복 테스트'));
      expect(output, contains('tags: [프로젝트, 긴급]'));
    });

    test('중첩 목록의 들여쓰기', () {
      expect(output, contains('    - 중첩 2단계'));
    });

    test('위키 링크', () {
      expect(output, contains('[[다른 노트]]'));
      expect(output, contains('[[노트|별칭]]'));
    });
  });

  group('고친 부분만 다시 쓰인다', () {
    test('한 문단을 고쳐도 다른 블록은 바이트가 그대로다', () {
      final codec = NoteMarkdownCodec();
      final document = codec.decode(_hard);

      final target = document.firstWhere(
        (node) => node is TextNode && node.text.toPlainText().contains('마지막 줄'),
      );
      document.replaceNodeById(
        target.id,
        ParagraphNode(id: target.id, text: AttributedText('고친 마지막 줄')),
      );

      final output = codec.encode(document);

      expect(output, contains('고친 마지막 줄'));
      expect(output, isNot(contains('마지막 줄.')));
      // 건드리지 않은 블록들은 그대로다.
      expect(output, contains('```dart'));
      expect(output, contains('|:-----|:------:|-------:|'));
      expect(output, contains(r'\~물결표\~'));
      expect(output, contains('<details><summary>접힌 제목</summary>'));
    });

    test('frontmatter 가 중복되지 않는다', () {
      final codec = NoteMarkdownCodec();
      final document = codec.decode(_hard);

      final target = document.firstWhere(
        (node) => node is TextNode && node.text.toPlainText().contains('마지막 줄'),
      );
      document.replaceNodeById(
        target.id,
        ParagraphNode(id: target.id, text: AttributedText('고침')),
      );

      final output = codec.encode(document);
      expect('title: 왕복 테스트'.allMatches(output).length, 1);
      expect('---'.allMatches(output).length, '---'.allMatches(_hard).length);
    });

    test('한 블록에서 나온 노드 중 하나만 고쳐도 중복되지 않는다', () {
      const source = '''
> 인용 첫 줄
> 인용 둘째 줄

뒤 문단
''';
      final codec = NoteMarkdownCodec();
      final document = codec.decode(source);

      final quote = document.firstWhere(
        (node) => node is TextNode && node.text.toPlainText().contains('인용 첫 줄'),
      );
      document.replaceNodeById(
        quote.id,
        ParagraphNode(id: quote.id, text: AttributedText('고친 인용')),
      );

      final output = codec.encode(document);
      expect('인용 첫 줄'.allMatches(output).length, 0);
      expect('고친 인용'.allMatches(output).length, 1);
      expect('뒤 문단'.allMatches(output).length, 1);
    });

    test('블록을 지우면 그 블록만 사라진다', () {
      final codec = NoteMarkdownCodec();
      final document = codec.decode('# 제목\n\n본문 하나\n\n본문 둘\n');

      final target = document.firstWhere(
        (node) => node is TextNode && node.text.toPlainText() == '본문 하나',
      );
      document.deleteNode(target.id);

      final output = codec.encode(document);
      expect(output, contains('# 제목'));
      expect(output, contains('본문 둘'));
      expect(output, isNot(contains('본문 하나')));
    });
  });
}
