import 'package:flutter/foundation.dart';

/// 비동기 동작 하나의 실행 상태를 보유한다.
///
/// 실행 중에는 중복 실행을 받지 않으며, 던져진 예외는 [error]에 담긴다.
abstract class _CommandBase extends ChangeNotifier {
  bool _running = false;
  Object? _error;

  bool get running => _running;
  Object? get error => _error;

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<void> runGuarded(Future<void> Function() action) async {
    if (_running) return;
    _running = true;
    _error = null;
    notifyListeners();
    try {
      await action();
    } catch (error) {
      _error = error;
    } finally {
      _running = false;
      notifyListeners();
    }
  }
}

/// 인자를 받지 않는 명령.
class Command0 extends _CommandBase {
  Command0(this._action);

  final Future<void> Function() _action;

  Future<void> execute() => runGuarded(_action);
}

/// 인자 하나를 받는 명령.
class Command1<A> extends _CommandBase {
  Command1(this._action);

  final Future<void> Function(A argument) _action;

  Future<void> execute(A argument) => runGuarded(() => _action(argument));
}
