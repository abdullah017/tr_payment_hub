import 'package:meta/meta.dart';

import '../enums.dart';

/// Single installment option with pricing details.
///
/// ## Example
///
/// ```dart
/// final option = InstallmentOption(
///   installmentNumber: 6,
///   installmentPrice: 175.0,
///   totalPrice: 1050.0,
/// );
///
/// // Calculate interest rate
/// final rate = option.calculateInterestRate(1000.0);
/// print('Interest: $rate%'); // 5.0%
/// ```
@immutable
class InstallmentOption {
  /// Creates a new [InstallmentOption] instance.
  const InstallmentOption({
    required this.installmentNumber,
    required this.installmentPrice,
    required this.totalPrice,
  });

  /// Creates an [InstallmentOption] from a JSON map.
  factory InstallmentOption.fromJson(Map<String, dynamic> json) =>
      InstallmentOption(
        installmentNumber: json['installmentNumber'] as int,
        installmentPrice: (json['installmentPrice'] as num).toDouble(),
        totalPrice: (json['totalPrice'] as num).toDouble(),
      );

  /// Number of installments (e.g., 3, 6, 9, 12).
  final int installmentNumber;

  /// Monthly payment amount.
  final double installmentPrice;

  /// Total amount to be paid including any interest.
  final double totalPrice;

  /// Calculates the interest rate as a percentage.
  ///
  /// Returns 0 for single payment or if [baseAmount] is invalid.
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Base amount: 1000 TL, Total: 1050 TL
  /// final rate = option.calculateInterestRate(1000.0);
  /// // Returns 5.0 (5% interest)
  /// ```
  double calculateInterestRate(double baseAmount) {
    if (installmentNumber <= 1 || baseAmount <= 0) return 0;
    return ((totalPrice - baseAmount) / baseAmount) * 100;
  }

  /// Converts this instance to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'installmentNumber': installmentNumber,
    'installmentPrice': installmentPrice,
    'totalPrice': totalPrice,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstallmentOption &&
          runtimeType == other.runtimeType &&
          installmentNumber == other.installmentNumber &&
          installmentPrice == other.installmentPrice &&
          totalPrice == other.totalPrice;

  @override
  int get hashCode =>
      Object.hash(installmentNumber, installmentPrice, totalPrice);

  @override
  String toString() =>
      'InstallmentOption($installmentNumber x $installmentPrice = $totalPrice)';
}

/// Installment information for a specific card BIN.
///
/// Contains available installment options based on the card's BIN number
/// and the payment amount.
///
/// ## Example
///
/// ```dart
/// final info = await provider.getInstallments(
///   binNumber: '552879',
///   amount: 1000.0,
/// );
///
/// print('Bank: ${info.bankName}');
/// print('Max installment: ${info.maxInstallment}');
///
/// for (final option in info.options) {
///   print('${option.installmentNumber}x: ${option.totalPrice} TL');
/// }
/// ```
@immutable
class InstallmentInfo {
  /// Creates a new [InstallmentInfo] instance.
  const InstallmentInfo({
    required this.price,
    required this.cardType,
    required this.cardAssociation,
    required this.cardFamily,
    required this.bankName,
    required this.bankCode,
    required this.force3DS,
    required this.forceCVC,
    required this.options,
    this.binNumber,
  });

  /// Creates an [InstallmentInfo] from a JSON map.
  factory InstallmentInfo.fromJson(Map<String, dynamic> json) =>
      InstallmentInfo(
        binNumber: json['binNumber'] as String?,
        price: (json['price'] as num).toDouble(),
        cardType: CardType.values.firstWhere(
          (e) => e.name == json['cardType'],
          orElse: () => CardType.creditCard,
        ),
        cardAssociation: CardAssociation.values.firstWhere(
          (e) => e.name == json['cardAssociation'],
          orElse: () => CardAssociation.visa,
        ),
        cardFamily: json['cardFamily'] as String,
        bankName: json['bankName'] as String,
        bankCode: json['bankCode'] as int,
        force3DS: json['force3DS'] as bool,
        forceCVC: json['forceCVC'] as bool,
        options: (json['options'] as List)
            .map((e) => InstallmentOption.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// Card BIN number used for the query.
  final String? binNumber;

  /// Base price used for calculating installment amounts.
  final double price;

  /// Type of card (credit, debit, prepaid).
  final CardType cardType;

  /// Card network (Visa, Mastercard, etc.).
  final CardAssociation cardAssociation;

  /// Card family name (Bonus, Maximum, Axess, etc.).
  final String cardFamily;

  /// Issuing bank name.
  final String bankName;

  /// Issuing bank code.
  final int bankCode;

  /// Whether 3D Secure is required for this card.
  final bool force3DS;

  /// Whether CVC is required for this card.
  final bool forceCVC;

  /// Available installment options.
  final List<InstallmentOption> options;

  /// Maximum available installment number.
  int get maxInstallment => options.isEmpty
      ? 1
      : options.map((o) => o.installmentNumber).reduce((a, b) => a > b ? a : b);

  /// Gets the installment option for a specific number of installments.
  ///
  /// Returns null if the requested installment number is not available.
  InstallmentOption? getOption(int installmentNumber) {
    try {
      return options.firstWhere(
        (o) => o.installmentNumber == installmentNumber,
      );
    } catch (_) {
      return null;
    }
  }

  /// Converts this instance to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    if (binNumber != null) 'binNumber': binNumber,
    'price': price,
    'cardType': cardType.name,
    'cardAssociation': cardAssociation.name,
    'cardFamily': cardFamily,
    'bankName': bankName,
    'bankCode': bankCode,
    'force3DS': force3DS,
    'forceCVC': forceCVC,
    'options': options.map((o) => o.toJson()).toList(),
  };

  @override
  String toString() =>
      'InstallmentInfo(bank: $bankName, options: ${options.length}, max: $maxInstallment)';
}
