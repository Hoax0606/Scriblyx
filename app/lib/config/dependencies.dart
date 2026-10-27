import '../data/repositories/file_note_repository.dart';
import '../data/repositories/note_repository.dart';
import '../data/services/settings_service.dart';
import '../data/services/workspace_file_service.dart';
import '../data/services/workspace_locator.dart';
import '../data/services/workspace_watch_service.dart';
import '../domain/models/workspace.dart';
import '../ui/core/editor/note_editor.dart';
import '../ui/core/editor/plain_text_editor.dart';
import '../ui/note_edit/view_model/note_edit_viewmodel.dart';
import '../ui/note_list/view_model/note_list_viewmodel.dart';

/// 구체 구현을 서로 연결하는 유일한 지점.
///
/// 에디터나 저장소 구현을 바꿀 때 수정하는 곳은 여기뿐이다.
class AppDependencies {
  AppDependencies._({
    required this.workspace,
    required this.editorFactory,
    required NoteRepository repository,
  }) : _repository = repository,
       listViewModel = NoteListViewModel(repository),
       editViewModel = NoteEditViewModel(
         repository: repository,
         controller: editorFactory.createController(),
       );

  final Workspace workspace;
  final NoteEditorFactory editorFactory;
  final NoteRepository _repository;

  final NoteListViewModel listViewModel;
  final NoteEditViewModel editViewModel;

  static Future<AppDependencies> create() async {
    final workspace = await WorkspaceLocator(SettingsService()).resolve();
    final files = WorkspaceFileService(workspace);

    return AppDependencies._(
      workspace: workspace,
      editorFactory: plainTextEditorFactory(),
      repository: FileNoteRepository(
        files: files,
        watcher: WorkspaceWatchService(files),
      ),
    );
  }

  Future<void> dispose() async {
    listViewModel.dispose();
    editViewModel.dispose();
    await _repository.dispose();
  }
}
