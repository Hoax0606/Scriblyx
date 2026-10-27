import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/models/workspace.dart';

/// 워크스페이스 안의 파일 하나에 대한 원시 정보.
class WorkspaceFile {
  const WorkspaceFile({required this.relativePath, required this.modifiedAt});

  final String relativePath;
  final DateTime modifiedAt;
}

/// 워크스페이스 폴더에 대한 파일 입출력. 도메인 모델을 다루지 않는다.
class WorkspaceFileService {
  WorkspaceFileService(this.workspace);

  final Workspace workspace;

  static const markdownExtension = '.md';

  Future<List<WorkspaceFile>> listMarkdownFiles() async {
    final root = Directory(workspace.rootPath);
    if (!await root.exists()) return const [];

    final files = <WorkspaceFile>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File || !isMarkdown(entity.path)) continue;
      final stat = await entity.stat();
      files.add(
        WorkspaceFile(
          relativePath: toRelative(entity.path),
          modifiedAt: stat.modified,
        ),
      );
    }
    return files;
  }

  Future<String> read(String relativePath) =>
      _fileAt(relativePath).readAsString();

  /// 파일을 쓰고 기록된 수정 시각을 돌려준다.
  Future<DateTime> write(String relativePath, String content) async {
    final file = _fileAt(relativePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(content, flush: true);
    return (await file.stat()).modified;
  }

  /// 파일을 옮기고 옮겨진 뒤의 수정 시각을 돌려준다.
  Future<DateTime> move(String fromRelativePath, String toRelativePath) async {
    final target = _fileAt(toRelativePath);
    await target.parent.create(recursive: true);
    final moved = await _fileAt(fromRelativePath).rename(target.path);
    return (await moved.stat()).modified;
  }

  Future<void> delete(String relativePath) async {
    final file = _fileAt(relativePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<bool> exists(String relativePath) => _fileAt(relativePath).exists();

  Future<DateTime> modifiedAt(String relativePath) async =>
      (await _fileAt(relativePath).stat()).modified;

  bool isMarkdown(String path) =>
      p.extension(path).toLowerCase() == markdownExtension;

  String toRelative(String absolutePath) =>
      p.relative(absolutePath, from: workspace.rootPath);

  File _fileAt(String relativePath) =>
      File(p.join(workspace.rootPath, relativePath));
}
