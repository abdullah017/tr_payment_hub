import 'dart:math';

import '../enums.dart';
import '../models/installment_info.dart';

/// Shared utilities for payment providers.
///
/// This class provides common functionality used across multiple payment providers
/// to eliminate code duplication and ensure consistency.
///
/// ## Features
///
/// * Currency mapping (ISO 4217 codes)
/// * Amount formatting (cents conversion, decimal formatting)
/// * Secure ID generation
/// * Default installment options
///
/// ## Example
///
/// ```dart
/// // Currency mapping
/// final currencyCode = PaymentUtils.currencyToIso(Currency.tryLira); // 'TRY'
///
/// // Amount formatting
/// final cents = PaymentUtils.amountToCents(99.99); // 9999
///
/// // Secure ID generation
/// final orderId = PaymentUtils.generateOrderId(prefix: 'ORD'); // 'ORD1704700000000_a1b2c3d4e5f6'
/// ```
class PaymentUtils {
  PaymentUtils._();

  // ============================================
  // CURRENCY MAPPING
  // ============================================

  /// Maps [Currency] enum to ISO 4217 currency code.
  ///
  /// Returns the standard 3-letter currency code:
  /// * [Currency.tryLira] → 'TRY'
  /// * [Currency.usd] → 'USD'
  /// * [Currency.eur] → 'EUR'
  /// * [Currency.gbp] → 'GBP'
  static String currencyToIso(Currency currency) {
    switch (currency) {
      case Currency.tryLira:
        return 'TRY';
      case Currency.usd:
        return 'USD';
      case Currency.eur:
        return 'EUR';
      case Currency.gbp:
        return 'GBP';
    }
  }

  /// Maps [Currency] to provider-specific code.
  ///
  /// Some providers (like PayTR) use 'TL' instead of 'TRY' for Turkish Lira.
  /// Use [useTL] parameter to get the alternative format.
  ///
  /// Example:
  /// ```dart
  /// PaymentUtils.currencyToProviderCode(Currency.tryLira); // 'TRY'
  /// PaymentUtils.currencyToProviderCode(Currency.tryLira, useTL: true); // 'TL'
  /// ```
  static String currencyToProviderCode(
    Currency currency, {
    bool useTL = false,
  }) {
    if (currency == Currency.tryLira && useTL) {
      return 'TL';
    }
    return currencyToIso(currency);
  }

  // ============================================
  // AMOUNT FORMATTING
  // ============================================

  /// Converts amount to cents (smallest currency unit).
  ///
  /// Multiplies by 100 and rounds to avoid floating-point precision issues.
  ///
  /// Example:
  /// ```dart
  /// PaymentUtils.amountToCents(99.99); // 9999
  /// PaymentUtils.amountToCents(100.0); // 10000
  /// ```
  static int amountToCents(double amount) => (amount * 100).round();

  /// Converts amount to cents as a string.
  ///
  /// Useful for APIs that expect string values.
  ///
  /// Example:
  /// ```dart
  /// PaymentUtils.amountToCentsString(99.99); // '9999'
  /// ```
  static String amountToCentsString(double amount) =>
      amountToCents(amount).toString();

  /// Converts cents to amount (decimal).
  ///
  /// Example:
  /// ```dart
  /// PaymentUtils.centsToAmount(9999); // 99.99
  /// ```
  static double centsToAmount(int cents) => cents / 100;

  /// Formats amount with fixed decimal places.
  ///
  /// Default is 2 decimal places for currency.
  ///
  /// Example:
  /// ```dart
  /// PaymentUtils.formatAmount(99.9); // '99.90'
  /// PaymentUtils.formatAmount(99.999, decimals: 3); // '99.999'
  /// ```
  static String formatAmount(double amount, {int decimals = 2}) =>
      amount.toStringAsFixed(decimals);

  /// Parses amount from various string formats.
  ///
  /// Handles both comma and dot as decimal separators.
  /// Returns 0 for null, empty, or invalid input.
  ///
  /// Example:
  /// ```dart
  /// PaymentUtils.parseAmount('99.99'); // 99.99
  /// PaymentUtils.parseAmount('99,99'); // 99.99 (European format)
  /// PaymentUtils.parseAmount(null); // 0.0
  /// ```
  static double parseAmount(String? value) {
    if (value == null || value.isEmpty) return 0;
    // Handle both comma and dot as decimal separator
    final normalized = value.replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0;
  }

  // ============================================
  // ID GENERATION
  // ============================================

  static final _random = Random.secure();

  /// Generates a cryptographically secure random hex string.
  ///
  /// Uses [Random.secure()] for cryptographic randomness.
  /// Default length is 8 bytes (16 hex characters).
  ///
  /// Example:
  /// ```dart
  /// PaymentUtils.generateSecureHex(); // 'a1b2c3d4e5f6g7h8'
  /// PaymentUtils.generateSecureHex(bytes: 4); // 'a1b2c3d4'
  /// ```
  static String generateSecureHex({int bytes = 8}) {
    final randomBytes = List<int>.generate(bytes, (_) => _random.nextInt(256));
    return randomBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Generates a unique order/transaction ID.
  ///
  /// Format: `{prefix}{timestamp}_{randomHex}`
  ///
  /// Example:
  /// ```dart
  /// PaymentUtils.generateOrderId(); // 'ORD1704700000000_a1b2c3d4e5f6'
  /// PaymentUtils.generateOrderId(prefix: 'TXN'); // 'TXN1704700000000_a1b2c3d4e5f6'
  /// ```
  static String generateOrderId({String prefix = 'ORD'}) =>
      '$prefix${DateTime.now().millisecondsSinceEpoch}_${generateSecureHex(bytes: 6)}';

  /// Generates a conversation/request ID.
  ///
  /// Format: `{prefix}{timestamp}`
  ///
  /// Example:
  /// ```dart
  /// PaymentUtils.generateConversationId(); // 'TR1704700000000'
  /// ```
  static String generateConversationId({String prefix = 'TR'}) =>
      '$prefix${DateTime.now().millisecondsSinceEpoch}';

  // ============================================
  // INSTALLMENT DEFAULTS
  // ============================================

  /// Default installment rates for Turkish banks.
  ///
  /// These rates are approximations used as fallbacks when
  /// provider API doesn't return installment information.
  ///
  /// Key: installment count, Value: rate multiplier
  static const defaultInstallmentRates = <int, double>{
    1: 1.00, // Single payment (no interest)
    2: 1.02, // 2% total interest
    3: 1.03, // 3% total interest
    6: 1.05, // 5% total interest
    9: 1.07, // 7% total interest
    12: 1.10, // 10% total interest
  };

  /// Generates default installment options for a given amount.
  ///
  /// Used as fallback when provider API fails to return installment data.
  ///
  /// Example:
  /// ```dart
  /// final options = PaymentUtils.generateDefaultInstallmentOptions(1000.0);
  /// // Returns options for 1, 2, 3, 6, 9, 12 installments
  /// ```
  static List<InstallmentOption> generateDefaultInstallmentOptions(
    double amount, {
    Map<int, double>? customRates,
  }) {
    final rates = customRates ?? defaultInstallmentRates;

    return rates.entries.map((entry) {
      final total = amount * entry.value;
      return InstallmentOption(
        installmentNumber: entry.key,
        installmentPrice: total / entry.key,
        totalPrice: total,
      );
    }).toList();
  }

  /// Generates default installment info for API fallback.
  ///
  /// Returns a basic [InstallmentInfo] with default values when
  /// the provider's installment query fails.
  ///
  /// This ensures the payment flow can continue even if
  /// installment information is temporarily unavailable.
  static InstallmentInfo generateDefaultInstallmentInfo(
    String binNumber,
    double amount,
  ) =>
      InstallmentInfo(
        binNumber: binNumber,
        price: amount,
        cardType: CardType.creditCard,
        cardAssociation: CardAssociation.visa,
        cardFamily: 'Unknown',
        bankName: 'Unknown',
        bankCode: 0,
        force3DS: true,
        forceCVC: true,
        options: generateDefaultInstallmentOptions(amount),
      );

  // ============================================
  // VALIDATION HELPERS
  // ============================================

  /// Validates BIN number format.
  ///
  /// BIN (Bank Identification Number) should be 6-8 digits.
  static bool isValidBin(String bin) =>
      bin.length >= 6 && bin.length <= 8 && RegExp(r'^\d+$').hasMatch(bin);

  /// Extracts BIN from card number.
  ///
  /// Returns first [length] digits (default 6) from card number.
  static String extractBin(String cardNumber, {int length = 6}) {
    final cleanNumber = cardNumber.replaceAll(RegExp(r'\s|-'), '');
    return cleanNumber.length >= length
        ? cleanNumber.substring(0, length)
        : cleanNumber;
  }
}
