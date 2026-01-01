import 'package:meta/meta.dart';

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
