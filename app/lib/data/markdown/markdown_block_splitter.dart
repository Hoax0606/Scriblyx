import 'markdown_block.dart';

/// 마크다운 문서를 최상위 블록들로 나눈다.
///
/// 나온 블록들의 `source` 를 순서대로 이어붙이면 [markdown] 과 같다.
List<MarkdownBlock> splitMarkdownBlocks(String markdown) {
  if (markdown.isEmpty) return const [];
  return _Splitter(markdown).run();
}

final _headingPattern = RegExp(r'^ {0,3}#{1,6}(\s|$)');
final _fencePattern = RegExp(r'^ {0,3}(`{3,}|~{3,})');
final _thematicBreakPattern = RegExp(r'^ {0,3}((-\s*){3,}|(\*\s*){3,}|(_\s*){3,})$');
final _bulletPattern = RegExp(r'^ {0,3}[-*+](\s|$)');
final _orderedPattern = RegExp(r'^ {0,3}\d{1,9}[.)](\s|$)');
final _blockquotePattern = RegExp(r'^ {0,3}>');
final _htmlOpenPattern = RegExp(r'^ {0,3}<[a-zA-Z!/?]');

/// 안에 빈 줄을 품을 수 있어 닫는 태그까지 읽어야 하는 요소들.
///
/// CommonMark 가 `pre`·`script`·`style`·`textarea` 에 같은 규칙을 둔다.
/// `details` 는 토글을 저장하는 형태라 함께 다룬다.
const _htmlContainerTags = {'details', 'pre', 'script', 'style', 'textarea'};

final _htmlTagNamePattern = RegExp(r'^ {0,3}<([a-zA-Z][a-zA-Z0-9-]*)');
final _tableDelimiterPattern = RegExp(r'^ {0,3}\|?[\s:|-]+\|[\s:|-]*$');
final _indentedCodePattern = RegExp(r'^(    |\t)');

class _Splitter {
  _Splitter(String markdown)
    : _lines = _splitKeepingLineEndings(markdown);

  final List<String> _lines;
  final List<MarkdownBlock> _blocks = [];

  int _index = 0;

  List<MarkdownBlock> run() {
    if (_index < _lines.length && _isFrontmatterStart()) {
      _takeFrontmatter();
    }
    while (_index < _lines.length) {
      _takeNext();
    }
    return _blocks;
  }

  String get _current => _lines[_index];

  bool _isBlank(int index) =>
      index < _lines.length && _lines[index].trim().isEmpty;

  /// 블록 뒤에 붙은 빈 줄들을 그 블록에 포함시킨다.
  void _emit(int startLine, int endLine, MarkdownBlockKind kind) {
    var end = endLine;
    while (_isBlank(end)) {
      end++;
    }
    _blocks.add(
      MarkdownBlock(
        source: _lines.sublist(startLine, end).join(),
        kind: kind,
      ),
    );
    _index = end;
  }

  bool _isFrontmatterStart() => _current.trimRight() == '---';

  void _takeFrontmatter() {
    final start = _index;
    var cursor = _index + 1;
    while (cursor < _lines.length) {
      final text = _lines[cursor].trimRight();
      cursor++;
      if (text == '---' || text == '...') {
        _emit(start, cursor, MarkdownBlockKind.frontmatter);
        return;
      }
    }
    // 닫히지 않으면 frontmatter 가 아니다. 일반 블록으로 다시 읽는다.
  }

  void _takeNext() {
    if (_current.trim().isEmpty) {
      final start = _index;
      var cursor = _index;
      while (_isBlank(cursor)) {
        cursor++;
      }
      _blocks.add(
        MarkdownBlock(
          source: _lines.sublist(start, cursor).join(),
          kind: MarkdownBlockKind.blank,
        ),
      );
      _index = cursor;
      return;
    }

    if (_fencePattern.hasMatch(_current)) return _takeFencedCode();
    if (_thematicBreakPattern.hasMatch(_current)) {
      return _emit(_index, _index + 1, MarkdownBlockKind.thematicBreak);
    }
    if (_headingPattern.hasMatch(_current)) {
      return _emit(_index, _index + 1, MarkdownBlockKind.heading);
    }
    if (_htmlOpenPattern.hasMatch(_current)) return _takeHtml();
    if (_blockquotePattern.hasMatch(_current)) return _takeBlockquote();
    if (_isListStart(_current)) return _takeList();
    if (_indentedCodePattern.hasMatch(_current)) return _takeIndentedCode();
    if (_isTableStart()) return _takeTable();
    _takeParagraph();
  }

  bool _isListStart(String line) =>
      _bulletPattern.hasMatch(line) || _orderedPattern.hasMatch(line);

  void _takeFencedCode() {
    final opener = _fencePattern.firstMatch(_current)!.group(1)!;
    final start = _index;
    var cursor = _index + 1;
    while (cursor < _lines.length) {
      final closer = _fencePattern.firstMatch(_lines[cursor]);
      final isClose = closer != null &&
          closer.group(1)![0] == opener[0] &&
          closer.group(1)!.length >= opener.length &&
          _lines[cursor].trimRight() == closer.group(1);
      cursor++;
      if (isClose) break;
    }
    _emit(start, cursor, MarkdownBlockKind.fencedCode);
  }

  /// 보통 HTML 블록은 빈 줄에서 끝난다. 다만 [_htmlContainerTags] 에 속한
  /// 요소는 안에 빈 줄을 품을 수 있어 닫는 태그까지 읽는다.
  void _takeHtml() {
    final tag = _htmlTagNamePattern
        .firstMatch(_current)
        ?.group(1)
        ?.toLowerCase();

    if (tag != null && _htmlContainerTags.contains(tag)) {
      final closing = '</$tag>';
      var cursor = _index;
      while (cursor < _lines.length) {
        final found = _lines[cursor].toLowerCase().contains(closing);
        cursor++;
        if (found) {
          _emit(_index, cursor, MarkdownBlockKind.html);
          return;
        }
      }
      // 닫히지 않으면 문서 끝까지 한 덩어리로 본다.
      _emit(_index, _lines.length, MarkdownBlockKind.html);
      return;
    }

    final start = _index;
    var cursor = _index;
    while (cursor < _lines.length && _lines[cursor].trim().isNotEmpty) {
      cursor++;
    }
    _emit(start, cursor, MarkdownBlockKind.html);
  }

  void _takeBlockquote() {
    final start = _index;
    var cursor = _index;
    while (cursor < _lines.length &&
        (_blockquotePattern.hasMatch(_lines[cursor]) ||
            (_lines[cursor].trim().isNotEmpty && cursor > start))) {
      cursor++;
    }
    _emit(start, cursor, MarkdownBlockKind.blockquote);
  }

  /// 목록은 빈 줄 하나로 끊기지 않는다. 빈 줄 뒤에도 항목이나 들여쓴 줄이
  /// 이어지면 같은 목록으로 본다.
  void _takeList() {
    final start = _index;
    var cursor = _index + 1;
    while (cursor < _lines.length) {
      final line = _lines[cursor];
      if (line.trim().isEmpty) {
        var lookahead = cursor;
        while (_isBlank(lookahead)) {
          lookahead++;
        }
        if (lookahead >= _lines.length) break;
        final next = _lines[lookahead];
        if (!_isListStart(next) && !_indentedCodePattern.hasMatch(next)) break;
        cursor = lookahead;
        continue;
      }
      if (_isListStart(line) ||
          _indentedCodePattern.hasMatch(line) ||
          line.startsWith('  ')) {
        cursor++;
        continue;
      }
      break;
    }
    _emit(start, cursor, MarkdownBlockKind.list);
  }

  void _takeIndentedCode() {
    final start = _index;
    var cursor = _index;
    while (cursor < _lines.length &&
        (_indentedCodePattern.hasMatch(_lines[cursor]) ||
            _lines[cursor].trim().isEmpty)) {
      if (_lines[cursor].trim().isEmpty) {
        var lookahead = cursor;
        while (_isBlank(lookahead)) {
          lookahead++;
        }
        if (lookahead >= _lines.length ||
            !_indentedCodePattern.hasMatch(_lines[lookahead])) {
          break;
        }
        cursor = lookahead;
        continue;
      }
      cursor++;
    }
    _emit(start, cursor, MarkdownBlockKind.indentedCode);
  }

  bool _isTableStart() =>
      _current.contains('|') &&
      _index + 1 < _lines.length &&
      _lines[_index + 1].contains('-') &&
      _tableDelimiterPattern.hasMatch(_lines[_index + 1]);

  void _takeTable() {
    final start = _index;
    var cursor = _index + 2;
    while (cursor < _lines.length &&
        _lines[cursor].trim().isNotEmpty &&
        _lines[cursor].contains('|')) {
      cursor++;
    }
    _emit(start, cursor, MarkdownBlockKind.table);
  }

  void _takeParagraph() {
    final start = _index;
    var cursor = _index + 1;
    while (cursor < _lines.length) {
      final line = _lines[cursor];
      if (line.trim().isEmpty) break;
      if (_headingPattern.hasMatch(line) ||
          _fencePattern.hasMatch(line) ||
          _thematicBreakPattern.hasMatch(line) ||
          _blockquotePattern.hasMatch(line) ||
          _htmlOpenPattern.hasMatch(line) ||
          _isListStart(line)) {
        break;
      }
      cursor++;
    }
    _emit(start, cursor, MarkdownBlockKind.paragraph);
  }
}

/// 줄바꿈 문자를 각 줄 끝에 남긴 채로 나눈다. 이어붙이면 원본이 된다.
List<String> _splitKeepingLineEndings(String text) {
  final lines = <String>[];
  var start = 0;
  for (var i = 0; i < text.length; i++) {
    if (text[i] != '\n') continue;
    lines.add(text.substring(start, i + 1));
    start = i + 1;
  }
  if (start < text.length) {
    lines.add(text.substring(start));
  }
  return lines;
}
