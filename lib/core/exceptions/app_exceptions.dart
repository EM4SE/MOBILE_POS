/// Base application exception
abstract class AppException implements Exception {
  final String message;
  final String? details;

  const AppException(this.message, [this.details]);

  @override
  String toString() => details == null ? message : '$message ($details)';
}

/// Thrown when database queries or connections fail
class DatabaseException extends AppException {
  const DatabaseException(super.message, [super.details]);
}

/// Thrown when user credentials/PIN are invalid
class AuthenticationException extends AppException {
  const AuthenticationException(super.message, [super.details]);
}

/// Thrown when entity validation fails
class ValidationException extends AppException {
  const ValidationException(super.message, [super.details]);
}

/// Thrown when an entity cannot be found
class NotFoundException extends AppException {
  const NotFoundException(super.message, [super.details]);
}

/// Thrown when POS operation (e.g. empty cart checkout, invalid quantity) is invalid
class PosOperationException extends AppException {
  const PosOperationException(super.message, [super.details]);
}
