import 'package:shared_preferences/shared_preferences.dart';

/// 앱 설정을 기기에 영속화한다.
class SettingsService {
  static const _workspacePathKey = 'workspace_path';

  Future<String?> readWorkspacePath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_workspacePathKey);
  }

  Future<void> writeWorkspacePath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_workspacePathKey, path);
  }
}
