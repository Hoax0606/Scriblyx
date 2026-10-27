import 'package:flutter_test/flutter_test.dart';
import 'package:scriblyx/data/markdown/markdown_block.dart';
import 'package:scriblyx/data/markdown/markdown_block_splitter.dart';

/// 어려운 요소를 모아둔 지문. 왕복이 깨지기 쉬운 것들을 넣었다.
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
- [ ] 체크 안 됨
- [x] 체크 됨

1. 번호 목록
2. 두 번째
   1. 중첩 번호

> 인용문입니다.
> 두 줄짜리.

---

```dart
void main() {
  // 코드 안의 **마크다운** 은 그대로 남아야 한다
  print('# 이건 제목이 아니다');
}
```

    들여쓰기 코드 블록
    두 번째 줄

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
  group('이어붙이면 원본과 같다', () {
    for (final entry in <String, String>{
      '빈 문서': '',
      '한 줄': '안녕하세요',
      '줄바꿈 없이 끝남': '마지막에 줄바꿈이 없다',
      '빈 줄만': '\n\n\n',
      '앞뒤 빈 줄': '\n\n내용\n\n\n',
      '어려운 지문': _hard,
      'CRLF': '첫 줄\r\n\r\n# 제목\r\n본문\r\n',
    }.entries) {
      test(entry.key, () {
        final blocks = splitMarkdownBlocks(entry.value);
        final joined = blocks.map((b) => b.source).join();
        expect(joined, entry.value);
      });
    }
  });

  group('블록 경계', () {
    List<MarkdownBlock> nonBlank(String markdown) => splitMarkdownBlocks(
      markdown,
    ).where((b) => b.kind != MarkdownBlockKind.blank).toList();

    test('frontmatter 를 한 블록으로 묶는다', () {
      final blocks = nonBlank(_hard);
      expect(blocks.first.kind, MarkdownBlockKind.frontmatter);
      expect(blocks.first.content, contains('title: 왕복 테스트'));
      expect(blocks.first.content, contains('tags:'));
    });

    test('코드 블록 안의 제목 표시를 블록으로 보지 않는다', () {
      final code = nonBlank(
        _hard,
      ).firstWhere((b) => b.kind == MarkdownBlockKind.fencedCode);
      expect(code.content, startsWith('```dart'));
      expect(code.content, contains("print('# 이건 제목이 아니다');"));
      expect(code.content, endsWith('```'));
    });

    test('제목은 한 줄짜리 블록이다', () {
      final blocks = nonBlank('# 제목\n본문입니다\n');
      expect(blocks[0].kind, MarkdownBlockKind.heading);
      expect(blocks[0].content, '# 제목');
      expect(blocks[1].kind, MarkdownBlockKind.paragraph);
    });

    test('중첩 목록은 한 블록으로 묶인다', () {
      final list = nonBlank(
        '- 하나\n- 둘\n  - 중첩\n    - 더 중첩\n',
      ).single;
      expect(list.kind, MarkdownBlockKind.list);
      expect(list.content, contains('더 중첩'));
    });

    test('표를 한 블록으로 묶는다', () {
      final table = nonBlank(
        _hard,
      ).firstWhere((b) => b.kind == MarkdownBlockKind.table);
      expect(table.content, contains('|:-----|:------:|-------:|'));
      expect(table.content, contains('| 가'));
    });

    test('HTML 블록을 한 덩어리로 묶는다', () {
      final html = nonBlank(
        '<details><summary>제목</summary>\n내용\n</details>\n',
      ).single;
      expect(html.kind, MarkdownBlockKind.html);
      expect(html.content, contains('</details>'));
    });

    test('details 는 안에 빈 줄이 있어도 닫는 태그까지 한 덩어리다', () {
      final blocks = nonBlank('''
<details><summary>접힌 제목</summary>

안쪽 문단입니다.

- 안쪽 목록

</details>

바깥 문단
''');
      expect(blocks[0].kind, MarkdownBlockKind.html);
      expect(blocks[0].content, contains('안쪽 문단입니다.'));
      expect(blocks[0].content, contains('- 안쪽 목록'));
      expect(blocks[0].content, endsWith('</details>'));
      expect(blocks[1].content, '바깥 문단');
    });

    test('pre 도 안의 빈 줄을 품는다', () {
      final blocks = nonBlank('<pre>\n한 줄\n\n두 줄\n</pre>\n\n다음\n');
      expect(blocks[0].content, contains('두 줄'));
      expect(blocks[1].content, '다음');
    });

    test('닫히지 않은 details 는 문서 끝까지 본다', () {
      final blocks = nonBlank('<details><summary>제목</summary>\n\n내용\n');
      expect(blocks.length, 1);
      expect(blocks.single.content, contains('내용'));
    });

    test('일반 HTML 태그는 빈 줄에서 끊긴다', () {
      final blocks = nonBlank('<div>\n안쪽\n</div>\n\n바깥\n');
      expect(blocks[0].kind, MarkdownBlockKind.html);
      expect(blocks[1].content, '바깥');
    });

    test('수평선과 frontmatter 구분선을 혼동하지 않는다', () {
      final blocks = nonBlank('본문\n\n---\n\n다음 본문\n');
      expect(blocks[1].kind, MarkdownBlockKind.thematicBreak);
    });

    test('인용문을 한 블록으로 묶는다', () {
      final quote = nonBlank('> 한 줄\n> 두 줄\n').single;
      expect(quote.kind, MarkdownBlockKind.blockquote);
      expect(quote.content, contains('두 줄'));
    });

    test('들여쓰기 코드 블록을 한 덩어리로 묶는다', () {
      final code = nonBlank(
        _hard,
      ).firstWhere((b) => b.kind == MarkdownBlockKind.indentedCode);
      expect(code.content, contains('들여쓰기 코드 블록'));
      expect(code.content, contains('두 번째 줄'));
    });
  });
}
