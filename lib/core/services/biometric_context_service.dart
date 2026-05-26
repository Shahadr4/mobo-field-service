
/// Service to manage biometric authentication context
/// Prevents biometric prompts during account operations and provides grace periods
class BiometricContextService {
  static final BiometricContextService _instance =
      BiometricContextService._internal();
  factory BiometricContextService() => _instance;
  BiometricContextService._internal();

  bool _isAccountOperation = false;
  DateTime? _lastAccountOperationTime;
  final List<String> _activeOperations = [];
  static const Duration _accountOperationGracePeriod = Duration(seconds: 3);

  bool get isAccountOperation => _isAccountOperation;
  List<String> get activeOperations => List.unmodifiable(_activeOperations);

  /// Check if biometric authentication should be skipped
  bool get shouldSkipBiometric {
    if (_isAccountOperation) {
      return true;
    }

    // Grace period after account operations
    if (_lastAccountOperationTime != null) {
      final timeSinceOperation = DateTime.now().difference(
        _lastAccountOperationTime!,
      );
      if (timeSinceOperation < _accountOperationGracePeriod) {
        return true;
      }
    }

    return false;
  }

  /// Mark the start of an account operation (login, logout, account switch)
  void startAccountOperation(String operation) {
    _activeOperations.add(operation);
    _isAccountOperation = true;
    _lastAccountOperationTime = DateTime.now();
  }

  /// Mark the end of an account operation
  void endAccountOperation(String operation) {
    _activeOperations.remove(operation);
    _isAccountOperation = _activeOperations.isNotEmpty;
    _lastAccountOperationTime = DateTime.now();
  }

  /// Reset the biometric context state
  void reset() {
    _isAccountOperation = false;
    _lastAccountOperationTime = null;
    _activeOperations.clear();
  }
}
