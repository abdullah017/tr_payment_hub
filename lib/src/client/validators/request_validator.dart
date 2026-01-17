import 'package:meta/meta.dart';

import '../../core/models/buyer_info.dart';
import '../../core/models/payment_request.dart';

/// Client-side payment request validation utilities.
///
/// This class provides static methods for validating payment requests
/// before sending to the backend. No network calls are made.
///
/// ## Example
///
/// ```dart
/// final result = RequestValidator.validate(request);
///
/// if (!result.isValid) {
///   for (final error in result.allErrors) {
///     print(error);
///   }
///   return;
/// }
///
/// // Request is valid, send to backend
/// await provider.createPayment(request);
/// ```
class RequestValidator {
  RequestValidator._();

  /// Validates a [PaymentRequest].
  ///
  /// Checks all required fields and validates nested objects.
  /// Returns a [RequestValidationResult] with validation status and errors.
  static RequestValidationResult validate(PaymentRequest request) {
    final errors = <String, String>{};

    // Order ID validation
    if (request.orderId.isEmpty) {
      errors['orderId'] = 'Siparis ID bos olamaz';
    } else if (request.orderId.length > 50) {
      errors['orderId'] = 'Siparis ID 50 karakterden uzun olamaz';
    }

    // Amount validation
    if (request.amount <= 0) {
      errors['amount'] = 'Tutar 0\'dan buyuk olmalidir';
    } else if (request.amount > 999999.99) {
      errors['amount'] = 'Tutar cok yuksek';
    }

    // Installment validation
    if (request.installment < 1) {
      errors['installment'] = 'Taksit sayisi en az 1 olmalidir';
    } else if (request.installment > 12) {
      errors['installment'] = 'Taksit sayisi en fazla 12 olabilir';
    }

    // Basket items validation
    if (request.basketItems.isEmpty) {
      errors['basketItems'] = 'En az bir urun gereklidir';
    } else {
      final basketTotal = request.basketItems.fold<double>(
        0,
        (sum, item) => sum + (item.price * item.quantity),
      );

      // Allow small rounding differences (0.01)
      final diff = (basketTotal - request.amount).abs();
      if (diff > 0.01) {
        errors['basketItems'] =
            'Sepet toplami ($basketTotal) ile tutar (${request.amount}) uyusmuyor';
      }

      // Validate individual items
      for (var i = 0; i < request.basketItems.length; i++) {
        final item = request.basketItems[i];
        if (item.id.isEmpty) {
          errors['basketItems[$i].id'] = 'Urun ID bos olamaz';
        }
        if (item.name.isEmpty) {
          errors['basketItems[$i].name'] = 'Urun adi bos olamaz';
        }
        if (item.price <= 0) {
          errors['basketItems[$i].price'] =
              'Urun fiyati 0\'dan buyuk olmalidir';
        }
      }
    }

    // 3DS validation
    if (request.use3DS &&
        (request.callbackUrl == null || request.callbackUrl!.isEmpty)) {
      errors['callbackUrl'] = '3DS icin callback URL gereklidir';
    }

    // Buyer validation
    final buyerErrors = validateBuyer(request.buyer);
    errors.addAll(buyerErrors);

    return RequestValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  /// Validates buyer information.
  ///
  /// Returns a map of field names to error messages.
  static Map<String, String> validateBuyer(BuyerInfo buyer) {
    final errors = <String, String>{};

    if (buyer.id.isEmpty) {
      errors['buyer.id'] = 'Alici ID bos olamaz';
    }

    if (buyer.name.isEmpty) {
      errors['buyer.name'] = 'Alici adi bos olamaz';
    }

    if (buyer.surname.isEmpty) {
      errors['buyer.surname'] = 'Alici soyadi bos olamaz';
    }

    if (!_isValidEmail(buyer.email)) {
      errors['buyer.email'] = 'Gecersiz email adresi';
    }

    if (!_isValidPhone(buyer.phone)) {
      errors['buyer.phone'] = 'Gecersiz telefon numarasi';
    }

    if (!_isValidIP(buyer.ip)) {
      errors['buyer.ip'] = 'Gecersiz IP adresi';
    }

    if (buyer.city.isEmpty) {
      errors['buyer.city'] = 'Sehir bos olamaz';
    }

    if (buyer.country.isEmpty) {
      errors['buyer.country'] = 'Ulke bos olamaz';
    }

    if (buyer.address.isEmpty) {
      errors['buyer.address'] = 'Adres bos olamaz';
    }

    return errors;
  }

  /// Validates an email address format.
  static bool _isValidEmail(String email) {
    if (email.isEmpty) return false;

    // Basic email regex
    final regex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return regex.hasMatch(email);
  }

  /// Validates a phone number format.
  static bool _isValidPhone(String phone) {
    // Remove common formatting characters
    final cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');

    // Should be 10-15 digits
    if (cleaned.length < 10 || cleaned.length > 15) return false;

    // Should contain only digits
    return RegExp(r'^\d+$').hasMatch(cleaned);
  }

  /// Validates an IP address (IPv4 or IPv6).
  static bool _isValidIP(String ip) {
    if (ip.isEmpty) return false;

    // IPv4
    final ipv4Regex = RegExp(
      r'^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.){3}(25[0-5]|(2[0-4]|1\d|[1-9]|)\d)$',
    );
    if (ipv4Regex.hasMatch(ip)) return true;

    // Basic IPv6 check (contains colons and reasonable length)
    if (ip.contains(':') && ip.length >= 2 && ip.length <= 45) {
      // More strict IPv6 validation
      final ipv6Regex = RegExp(
        r'^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$|' // Full form
        r'^([0-9a-fA-F]{1,4}:){1,7}:$|' // Trailing ::
        r'^([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}$|' // :: in middle
        r'^([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}$|'
        r'^([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}$|'
        r'^([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}$|'
        r'^([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}$|'
        r'^[0-9a-fA-F]{1,4}:(:[0-9a-fA-F]{1,4}){1,6}$|'
        r'^:((:[0-9a-fA-F]{1,4}){1,7}|:)$|' // Leading ::
        r'^::$', // Just ::
      );
      if (ipv6Regex.hasMatch(ip)) return true;

      // Also accept loopback
      if (ip == '::1') return true;
    }

    return false;
  }
}

/// Result of payment request validation.
@immutable
class RequestValidationResult {
  /// Creates a new [RequestValidationResult] instance.
  const RequestValidationResult({
    required this.isValid,
    required this.errors,
  });

  /// Whether all validation checks passed.
  final bool isValid;

  /// Map of field names to error messages.
  ///
  /// Empty if [isValid] is true.
  final Map<String, String> errors;

  /// Returns true if the specified field has an error.
  bool hasError(String field) => errors.containsKey(field);

  /// Returns the error message for the specified field, or null if no error.
  String? getError(String field) => errors[field];

  /// Returns all error messages as a list.
  List<String> get allErrors => errors.values.toList();

  /// Returns the number of errors.
  int get errorCount => errors.length;

  @override
  String toString() => isValid
      ? 'RequestValidationResult.valid()'
      : 'RequestValidationResult.invalid(errors: ${errors.length})';
}
