import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:scriblyx/data/repositories/file_note_repository.dart';
import 'package:scriblyx/data/repositories/note_repository.dart';
import 'package:scriblyx/data/services/workspace_file_service.dart';
import 'package:scriblyx/data/services/workspace_watch_service.dart';
import 'package:scriblyx/domain/models/note_id.dart';
import 'package:scriblyx/domain/models/workspace.dart';

void main() {
  late Directory root;
  late NoteRepository repository;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('scriblyx_test_');
    final workspace = Workspace(root.path);
    await Directory(workspace.personalPath).create(recursive: true);
    await Directory(workspace.sharedPath).create(recursive: true);

    final files = WorkspaceFileService(workspace);
    repository = FileNoteRepository(
      files: files,
      watcher: WorkspaceWatchService(files),
    );
  });

  tearDown(() async {
    await repository.dispose();
    await _deleteWithRetry(root);
  });

  test('새 노트는 personal 폴더에 빈 파일로 만들어진다', () async {
    final created = await repository.create();

    expect(p.dirname(created.id.relativePath), Workspace.personalFolderName);
    expect(created.title, '새 노트');
    expect(await File(p.join(root.path, created.id.relativePath)).exists(), isTrue);
  });

  test('이름이 겹치면 번호가 붙는다', () async {
    final first = await repository.create();
    final second = await repository.create();

    expect(first.title, '새 노트');
    expect(second.title, '새 노트 2');
  });

  test('저장한 본문을 그대로 다시 읽는다', () async {
    final created = await repository.create();
    const body = '# 제목\n\n한글 본문입니다.';

    await repository.write(created.id, body);
    final note = await repository.read(created.id);

    expect(note.body, body);
  });

  test('목록은 최근 수정순으로 정렬된다', () async {
    final older = await repository.create();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final newer = await repository.create();

    final notes = await repository.list();

    expect(notes.first.id, newer.id);
    expect(notes.last.id, older.id);
  });

  test('이름을 바꾸면 파일이 옮겨지고 본문이 유지된다', () async {
    final created = await repository.create();
    const body = '내용 유지 확인';
    await repository.write(created.id, body);

    final renamed = await repository.rename(created.id, '회의록');

    expect(renamed.title, '회의록');
    expect(await repository.read(renamed.id).then((n) => n.body), body);
    expect(await File(p.join(root.path, created.id.relativePath)).exists(), isFalse);
  });

  test('파일명에 쓸 수 없는 문자는 공백으로 바뀐다', () async {
    final created = await repository.create();

    final renamed = await repository.rename(created.id, 'a/b:c*d');

    expect(renamed.title, 'a b c d');
  });

  test('이미 쓰이는 이름으로는 바꿀 수 없다', () async {
    final first = await repository.create();
    final second = await repository.create();
    await repository.rename(first.id, '회의록');

    expect(
      () => repository.rename(second.id, '회의록'),
      throwsA(isA<NoteNameTakenException>()),
    );
  });

  test('삭제하면 목록에서 사라진다', () async {
    final created = await repository.create();

    await repository.delete(created.id);

    expect(await repository.list(), isEmpty);
  });

  test('앱 밖에서 바뀐 파일은 외부 변경으로 보고된다', () async {
    final created = await repository.create();
    await repository.write(created.id, '앱이 쓴 내용');

    final reported = repository.externalChanges.first;
    // 저장소는 자신의 쓰기 직후 잠깐 감시 이벤트를 무시한다. 그보다 늦게 쓴다.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await File(
      p.join(root.path, created.id.relativePath),
    ).writeAsString('밖에서 바꾼 내용', flush: true);

    final change = await reported.timeout(const Duration(seconds: 5));
    expect(change.id, NoteId(created.id.relativePath));
  });
}

/// Windows는 감시 핸들을 비동기로 해제하므로 바로 지워지지 않을 수 있다.
Future<void> _deleteWithRetry(Directory directory) async {
  for (var attempt = 0; attempt < 10; attempt++) {
    try {
      await directory.delete(recursive: true);
      return;
    } on FileSystemException {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }
}
