class AppException implements Exception {
  final String message;
  final String code;

  const AppException(this.message, {this.code = 'unknown'});

  @override
  String toString() => message;
}

class DatabaseException extends AppException {
  const DatabaseException(super.message) : super(code: 'database');
}

class ValidationException extends AppException {
  const ValidationException(super.message) : super(code: 'validation');
}

class NotFoundException extends AppException {
  const NotFoundException(super.message) : super(code: 'not_found');
}