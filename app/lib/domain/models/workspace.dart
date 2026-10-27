import 'package:path/path.dart' as p;

/// 노트 파일이 저장되는 루트 폴더와 그 하위 구조.
class Workspace {
  const Workspace(this.rootPath);

  final String rootPath;

  /// 이 기기와 사용자 본인의 기기끼리만 동기화되는 영역.
  String get personalPath => p.join(rootPath, personalFolderName);

  /// 다른 사람과 공유되는 영역.
  String get sharedPath => p.join(rootPath, sharedFolderName);

  static const personalFolderName = 'personal';
  static const sharedFolderName = 'shared';

  @override
  bool operator ==(Object other) =>
      other is Workspace && other.rootPath == rootPath;

  @override
  int get hashCode => rootPath.hashCode;
}
