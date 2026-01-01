import 'package:meta/meta.dart';

import '../enums.dart';

/// Represents a saved/tokenized card for recurring payments.
///
/// When a card is saved during payment (using `CardInfo.saveCard = true`),
/// the payment provider returns a token that can be used for future charges
/// without requiring the full card details.
///
/// ## Example
///
/// ```dart
/// // After a successful payment with saveCard = true
/// final savedCard = SavedCard(
///   cardToken: 'tok_xxx',
///   cardUserKey: 'cuk_xxx',
///   lastFourDigits: '0008',
///   cardAssociation: CardAssociation.masterCard,
///   cardFamily: 'Bonus',
/// );
///
/// // Use the token for future charges
/// await provider.chargeWithSavedCard(
///   cardToken: savedCard.cardToken,
///   cardUserKey: savedCard.cardUserKey,
///   amount: 100,
///   orderId: 'ORDER_123',
///   buyer: buyerInfo,
/// );
/// ```
@immutable
class SavedCard {
  /// Creates a new [SavedCard] instance.
  const SavedCard({
    required this.cardToken,
    required this.lastFourDigits,
    this.cardUserKey,
    this.cardAssociation,
    this.cardFamily,
    this.cardAlias,
    this.binNumber,
    this.bankName,
    this.expiryMonth,
    this.expiryYear,
  });

  /// Creates a [SavedCard] from a JSON map.
  factory SavedCard.fromJson(Map<String, dynamic> json) => SavedCard(
        cardToken: json['cardToken'] as String,
        cardUserKey: json['cardUserKey'] as String?,
        lastFourDigits: json['lastFourDigits'] as String,
        cardAssociation: json['cardAssociation'] != null
            ? CardAssociation.values.firstWhere(
                (e) => e.name == json['cardAssociation'],
                orElse: () => CardAssociation.visa,
              )
            : null,
        cardFamily: json['cardFamily'] as String?,
        cardAlias: json['cardAlias'] as String?,
        binNumber: json['binNumber'] as String?,
        bankName: json['bankName'] as String?,
        expiryMonth: json['expiryMonth'] as String?,
        expiryYear: json['expiryYear'] as String?,
      );

  /// Unique token for this saved card.
  ///
  /// This token is provider-specific and can be used to charge
  /// the card without requiring full card details.
  ///
  /// For iyzico: This is the `cardToken` returned after saving.
  final String cardToken;

  /// Card user key (iyzico specific).
  ///
  /// In iyzico, this identifies the customer and their saved cards.
  /// Required for listing and managing saved cards.
  final String? cardUserKey;

  /// Last 4 digits of the card number.
  ///
  /// Used for display purposes to help customers identify their cards.
  final String lastFourDigits;

  /// Card network (Visa, Mastercard, etc.).
  final CardAssociation? cardAssociation;

  /// Card family name (Bonus, Maximum, Axess, etc.).
  final String? cardFamily;

  /// User-defined alias for this card.
  ///
  /// E.g., "My Main Card", "Work Card"
  final String? cardAlias;

  /// First 6 digits of the card (BIN number).
  final String? binNumber;

  /// Issuing bank name.
  final String? bankName;

  /// Card expiry month (2 digits, e.g., "12").
  final String? expiryMonth;

  /// Card expiry year (2 or 4 digits, e.g., "25" or "2025").
  final String? expiryYear;

  /// Returns a masked representation of the card number.
  ///
  /// Example: "**** **** **** 0008"
  String get maskedCardNumber => '**** **** **** $lastFourDigits';

  /// Returns a display name for the card.
  ///
  /// Combines card family/association with last 4 digits.
  /// Example: "Mastercard •••• 0008" or "Bonus •••• 0008"
  String get displayName {
    final prefix = cardFamily ?? cardAssociation?.name ?? 'Card';
    return '$prefix •••• $lastFourDigits';
  }

  /// Converts this instance to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'cardToken': cardToken,
        if (cardUserKey != null) 'cardUserKey': cardUserKey,
        'lastFourDigits': lastFourDigits,
        if (cardAssociation != null) 'cardAssociation': cardAssociation!.name,
        if (cardFamily != null) 'cardFamily': cardFamily,
        if (cardAlias != null) 'cardAlias': cardAlias,
        if (binNumber != null) 'binNumber': binNumber,
        if (bankName != null) 'bankName': bankName,
        if (expiryMonth != null) 'expiryMonth': expiryMonth,
        if (expiryYear != null) 'expiryYear': expiryYear,
      };

  /// Creates a copy with the specified fields replaced.
  SavedCard copyWith({
    String? cardToken,
    String? cardUserKey,
    String? lastFourDigits,
    CardAssociation? cardAssociation,
    String? cardFamily,
    String? cardAlias,
    String? binNumber,
    String? bankName,
    String? expiryMonth,
    String? expiryYear,
  }) =>
      SavedCard(
        cardToken: cardToken ?? this.cardToken,
        cardUserKey: cardUserKey ?? this.cardUserKey,
        lastFourDigits: lastFourDigits ?? this.lastFourDigits,
        cardAssociation: cardAssociation ?? this.cardAssociation,
        cardFamily: cardFamily ?? this.cardFamily,
        cardAlias: cardAlias ?? this.cardAlias,
        binNumber: binNumber ?? this.binNumber,
        bankName: bankName ?? this.bankName,
        expiryMonth: expiryMonth ?? this.expiryMonth,
        expiryYear: expiryYear ?? this.expiryYear,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedCard &&
          runtimeType == other.runtimeType &&
          cardToken == other.cardToken &&
          cardUserKey == other.cardUserKey &&
          lastFourDigits == other.lastFourDigits;

  @override
  int get hashCode => Object.hash(cardToken, cardUserKey, lastFourDigits);

  @override
  String toString() => 'SavedCard($displayName)';
}
