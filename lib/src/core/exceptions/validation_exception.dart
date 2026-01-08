/// Input validation exception - thrown when validation fails
///
/// Bu exception, model sınıflarının validate() metodları tarafından fırlatılır.
/// Birden fazla validation hatası içerebilir.
///
/// Örnek kullanım:
/// ```dart
/// try {
///   request.validate();
/// } on ValidationException catch (e) {
///   print('Validation failed: ${e.allErrors}');
/// }
/// ```
class ValidationException implements Exception {
  /// Creates a validation exception with the given errors
  const ValidationException({
    required this.errors,
    this.field,
  });

  /// Creates a validation exception with a single error
  factory ValidationException.single(String error, {String? field}) =>
      ValidationException(
        errors: [error],
        field: field,
      );

  /// Creates a validation exception for an invalid field
  factory ValidationException.invalidField(String fieldName, String reason) =>
      ValidationException(
        errors: ['$fieldName: $reason'],
        field: fieldName,
      );

  /// List of validation error messages
  final List<String> errors;

  /// Optional: The specific field that failed validation
  final String? field;

  /// Returns the first error message
  String get message => errors.isNotEmpty ? errors.first : 'Validation failed';

  /// Returns all errors as a semicolon-separated string
  String get allErrors => errors.join('; ');

  /// Returns true if there are any errors
  bool get hasErrors => errors.isNotEmpty;

  /// Returns the number of errors
  int get errorCount => errors.length;

  /// User-friendly message in Turkish
  String get userFriendlyMessage {
    if (errors.isEmpty) return 'Doğrulama hatası';
    if (errors.length == 1) return errors.first;
    return '${errors.length} doğrulama hatası: ${errors.take(3).join(", ")}${errors.length > 3 ? "..." : ""}';
  }

  @override
  String toString() => 'ValidationException: $allErrors';

  /// Debug information
  String get debugInfo => 'ValidationException(field: $field, errors: $errors)';
}
