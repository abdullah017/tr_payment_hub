import 'package:meta/meta.dart';

import '../exceptions/validation_exception.dart';

/// Buyer information for payment requests.
///
/// Contains all necessary customer details required by Turkish payment
/// providers for processing transactions. Both iyzico and PayTR require
/// buyer information for fraud prevention and regulatory compliance.
///
/// ## Example
///
/// ```dart
/// final buyer = BuyerInfo(
///   id: 'CUSTOMER_123',
///   name: 'Ahmet',
///   surname: 'Yilmaz',
///   email: 'ahmet@example.com',
///   phone: '+905551234567',
///   ip: '192.168.1.1',
///   city: 'Istanbul',
///   country: 'Turkey',
///   address: 'Kadikoy, Istanbul',
/// );
/// ```
///
/// ## Required Fields
///
/// All fields except [identityNumber] and [zipCode] are required for
/// successful payment processing.
@immutable
class BuyerInfo {
  /// Creates a new [BuyerInfo] instance.
  ///
  /// All parameters except [identityNumber] and [zipCode] are required.
  const BuyerInfo({
    required this.id,
    required this.name,
    required this.surname,
    required this.email,
    required this.phone,
    required this.ip,
    required this.city,
    required this.country,
    required this.address,
    this.identityNumber,
    this.zipCode,
  });

  /// Creates a [BuyerInfo] instance from a JSON map.
  ///
  /// Throws [TypeError] if required fields are missing or have wrong types.
  factory BuyerInfo.fromJson(Map<String, dynamic> json) => BuyerInfo(
        id: json['id'] as String,
        name: json['name'] as String,
        surname: json['surname'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String,
        ip: json['ip'] as String,
        city: json['city'] as String,
        country: json['country'] as String,
        address: json['address'] as String,
        identityNumber: json['identityNumber'] as String?,
        zipCode: json['zipCode'] as String?,
      );

  /// Unique identifier for the buyer in your system.
  ///
  /// This should be a stable identifier that you can use to track
  /// the customer across multiple transactions.
  final String id;

  /// Buyer's first name.
  ///
  /// Should match the name on the payment card for best approval rates.
  final String name;

  /// Buyer's last name (surname).
  ///
  /// Should match the surname on the payment card for best approval rates.
  final String surname;

  /// Buyer's email address.
  ///
  /// Used for transaction notifications and receipts.
  /// Must be a valid email format.
  final String email;

  /// Buyer's phone number.
  ///
  /// Should include country code (e.g., '+905551234567').
  /// Required for 3D Secure verification SMS.
  final String phone;

  /// Turkish National ID number (TC Kimlik No).
  ///
  /// Optional but recommended for Turkish customers.
  /// 11-digit number for Turkish citizens.
  final String? identityNumber;

  /// Buyer's IP address.
  ///
  /// Required for fraud prevention. Must be the actual IP address
  /// of the customer making the purchase, not your server's IP.
  final String ip;

  /// Buyer's city of residence.
  final String city;

  /// Buyer's country of residence.
  ///
  /// Use full country name (e.g., 'Turkey', 'United States').
  final String country;

  /// Buyer's full address.
  ///
  /// Street address including district/neighborhood information.
  final String address;

  /// Postal/ZIP code.
  ///
  /// Optional but recommended for address verification.
  final String? zipCode;

  /// Returns the buyer's full name.
  ///
  /// Combines [name] and [surname] with a space separator.
  String get fullName => '$name $surname';

  /// Email regex pattern
  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  /// Turkish phone regex pattern (supports +90, 90, 0 prefixes)
  static final _phoneRegex = RegExp(
    r'^(\+?90|0)?[5][0-9]{9}$',
  );

  /// IP address regex pattern (IPv4)
  static final _ipv4Regex = RegExp(
    r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$',
  );

  /// IPv6 address regex pattern (supports common formats)
  /// Full: 2001:0db8:85a3:0000:0000:8a2e:0370:7334
  /// Compressed: 2001:db8:85a3::8a2e:370:7334
  /// Loopback: ::1
  static final _ipv6Regex = RegExp(
    r'^('
    // Full IPv6
    r'([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}|'
    // Leading ::
    r'::([0-9a-fA-F]{1,4}:){0,6}[0-9a-fA-F]{1,4}|'
    // Trailing ::
    r'([0-9a-fA-F]{1,4}:){1,7}:|'
    // Mixed with ::
    r'([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|'
    r'([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|'
    r'([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|'
    r'([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|'
    r'([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|'
    r'[0-9a-fA-F]{1,4}:(:[0-9a-fA-F]{1,4}){1,6}|'
    // Just ::
    r'::)$',
  );

  /// Loopback addresses for local development
  static const _loopbackAddresses = ['127.0.0.1', '::1', 'localhost'];

  /// Validates IP address (supports both IPv4 and IPv6)
  static bool _isValidIpAddress(String ip) {
    if (_loopbackAddresses.contains(ip)) return true;
    if (_ipv4Regex.hasMatch(ip)) return true;
    if (_ipv6Regex.hasMatch(ip)) return true;
    return false;
  }

  /// Validates the buyer information and throws [ValidationException] if invalid.
  ///
  /// Checks:
  /// * ID is not empty
  /// * Name and surname have at least 2 characters
  /// * Email is valid format
  /// * Phone is valid Turkish phone format
  /// * IP is valid format (IPv4, IPv6, or loopback addresses)
  /// * City, country, and address are not empty
  /// * Identity number (if provided) is valid TC Kimlik format
  ///
  /// Throws [ValidationException] with all validation errors.
  void validate() {
    final errors = <String>[];

    // ID validation
    if (id.isEmpty) {
      errors.add('buyer id cannot be empty');
    }

    // Name validation
    if (name.isEmpty) {
      errors.add('buyer name cannot be empty');
    } else if (name.trim().length < 2) {
      errors.add('buyer name must be at least 2 characters');
    }

    // Surname validation
    if (surname.isEmpty) {
      errors.add('buyer surname cannot be empty');
    } else if (surname.trim().length < 2) {
      errors.add('buyer surname must be at least 2 characters');
    }

    // Email validation
    if (email.isEmpty) {
      errors.add('buyer email cannot be empty');
    } else if (!_emailRegex.hasMatch(email)) {
      errors.add('buyer email format is invalid');
    }

    // Phone validation
    if (phone.isEmpty) {
      errors.add('buyer phone cannot be empty');
    } else {
      final cleanPhone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
      if (!_phoneRegex.hasMatch(cleanPhone)) {
        errors.add('buyer phone format is invalid (expected Turkish format)');
      }
    }

    // IP validation (supports IPv4, IPv6, and loopback addresses)
    if (ip.isEmpty) {
      errors.add('buyer IP cannot be empty');
    } else if (!_isValidIpAddress(ip)) {
      errors.add('buyer IP format is invalid (supports IPv4 and IPv6)');
    }

    // City validation
    if (city.isEmpty) {
      errors.add('buyer city cannot be empty');
    }

    // Country validation
    if (country.isEmpty) {
      errors.add('buyer country cannot be empty');
    }

    // Address validation
    if (address.isEmpty) {
      errors.add('buyer address cannot be empty');
    } else if (address.trim().length < 10) {
      errors.add('buyer address must be at least 10 characters');
    }

    // Turkish ID validation (if provided)
    if (identityNumber != null && identityNumber!.isNotEmpty) {
      if (!_isValidTurkishId(identityNumber!)) {
        errors.add('buyer identityNumber is invalid');
      }
    }

    if (errors.isNotEmpty) {
      throw ValidationException(errors: errors);
    }
  }

  /// Validates Turkish National ID number (TC Kimlik No)
  ///
  /// Turkish ID is 11 digits with specific checksum rules:
  /// * First digit cannot be 0
  /// * 10th digit = ((sum of odd positions * 7) - sum of even positions) mod 10
  /// * 11th digit = sum of first 10 digits mod 10
  static bool _isValidTurkishId(String id) {
    if (id.length != 11) return false;
    if (!RegExp(r'^\d{11}$').hasMatch(id)) return false;
    if (id.startsWith('0')) return false;

    final digits = id.split('').map(int.parse).toList();

    // Checksum for 10th digit
    final oddSum = digits[0] + digits[2] + digits[4] + digits[6] + digits[8];
    final evenSum = digits[1] + digits[3] + digits[5] + digits[7];
    final check10 = ((oddSum * 7) - evenSum) % 10;

    if (check10 != digits[9]) return false;

    // Checksum for 11th digit
    final total = digits.sublist(0, 10).reduce((a, b) => a + b);
    if (total % 10 != digits[10]) return false;

    return true;
  }

  /// Converts this instance to a JSON-compatible map.
  ///
  /// Useful for debugging, logging (with sanitization), and serialization.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'surname': surname,
        'email': email,
        'phone': phone,
        if (identityNumber != null) 'identityNumber': identityNumber,
        'ip': ip,
        'city': city,
        'country': country,
        'address': address,
        if (zipCode != null) 'zipCode': zipCode,
      };

  /// Creates a copy of this instance with the given fields replaced.
  BuyerInfo copyWith({
    String? id,
    String? name,
    String? surname,
    String? email,
    String? phone,
    String? ip,
    String? city,
    String? country,
    String? address,
    String? identityNumber,
    String? zipCode,
  }) =>
      BuyerInfo(
        id: id ?? this.id,
        name: name ?? this.name,
        surname: surname ?? this.surname,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        ip: ip ?? this.ip,
        city: city ?? this.city,
        country: country ?? this.country,
        address: address ?? this.address,
        identityNumber: identityNumber ?? this.identityNumber,
        zipCode: zipCode ?? this.zipCode,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BuyerInfo &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          surname == other.surname &&
          email == other.email &&
          phone == other.phone &&
          identityNumber == other.identityNumber &&
          ip == other.ip &&
          city == other.city &&
          country == other.country &&
          address == other.address &&
          zipCode == other.zipCode;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        surname,
        email,
        phone,
        identityNumber,
        ip,
        city,
        country,
        address,
        zipCode,
      );

  @override
  String toString() => 'BuyerInfo(id: $id, name: $fullName, email: $email)';
}
