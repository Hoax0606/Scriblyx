import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/models/workspace.dart';
import 'settings_service.dart';

/// 워크스페이스 위치를 결정하고 폴더 구조가 존재하도록 보장한다.
class WorkspaceLocator {
  WorkspaceLocator(this._settings);

  final SettingsService _settings;

  static const defaultFolderName = 'Scriblyx';

  /// 저장된 경로가 없으면 문서 폴더 아래에 기본 워크스페이스를 만든다.
  Future<Workspace> resolve() async {
    final saved = await _settings.readWorkspacePath();
    final workspace = Workspace(saved ?? await _defaultRootPath());
    await _ensureStructure(workspace);
    if (saved == null) {
      await _settings.writeWorkspacePath(workspace.rootPath);
    }
    return workspace;
  }

  Future<Workspace> moveTo(String rootPath) async {
    final workspace = Workspace(rootPath);
    await _ensureStructure(workspace);
    await _settings.writeWorkspacePath(rootPath);
    return workspace;
  }

  Future<String> _defaultRootPath() async {
    final documents = await getApplicationDocumentsDirectory();
    return p.join(documents.path, defaultFolderName);
  }

  Future<void> _ensureStructure(Workspace workspace) async {
    await Directory(workspace.personalPath).create(recursive: true);
    await Directory(workspace.sharedPath).create(recursive: true);
  }
}
