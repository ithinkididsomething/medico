/// Base class for all application exceptions.
sealed class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  const AppException(this.message, [this.code, this.details]);

  @override
  String toString() => 'AppException: $message ${code != null ? '($code)' : ''}';
}

/// Thrown when network connectivity fails or timeouts occur.
/// Essential for rural clinic settings with spotty connectivity.
class NetworkException extends AppException {
  const NetworkException([
    super.message = 'Network connection unavailable. Operating in offline mode.',
    super.code = 'ERR_NETWORK_UNAVAILABLE',
    super.details,
  ]);
}

/// Thrown when local database or cached referral storage fails.
class StorageException extends AppException {
  const StorageException([
    super.message = 'Local clinical database access error.',
    super.code = 'ERR_STORAGE_FAILURE',
    super.details,
  ]);
}

/// Thrown when clinical assessment input fails validation rules.
class ValidationException extends AppException {
  const ValidationException([
    super.message = 'Please check the entered clinical information.',
    super.code = 'ERR_VALIDATION_FAILED',
    super.details,
  ]);
}

/// Thrown when clinical referral protocol rules or triage guidelines encounter conflicts.
class ClinicalProtocolException extends AppException {
  const ClinicalProtocolException([
    super.message = 'Clinical triage guideline evaluation could not be processed.',
    super.code = 'ERR_PROTOCOL_EVALUATION',
    super.details,
  ]);
}

/// Thrown for unhandled or unexpected runtime errors.
class UnexpectedException extends AppException {
  const UnexpectedException([
    super.message = 'An unexpected system error occurred. Please try again.',
    super.code = 'ERR_UNEXPECTED',
    super.details,
  ]);
}
