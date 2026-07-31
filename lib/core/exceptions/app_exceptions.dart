/// Base class for all application-specific exceptions.
abstract class AppException implements Exception {
  final String message;
  final dynamic cause;

  AppException(this.message, {this.cause});

  @override
  String toString() {
    if (cause != null) {
      return 'AppException: $message (Cause: $cause)';
    }
    return 'AppException: $message';
  }
}

/// Thrown when a database operation fails.
class DatabaseException extends AppException {
  DatabaseException(super.message, {super.cause});
}

/// Thrown when input data is invalid.
class ValidationException extends AppException {
  ValidationException(super.message, {super.cause});
}
