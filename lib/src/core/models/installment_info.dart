import '../enums.dart';

/// Taksit seçeneği
class InstallmentOption {
  final int installmentNumber;
  final double installmentPrice;
  final double totalPrice;

  const InstallmentOption({
    required this.installmentNumber,
    required this.installmentPrice,
    required this.totalPrice,
  });

  /// Faiz oranı (yüzde olarak)
  double calculateInterestRate(double baseAmount) {
    if (installmentNumber <= 1 || baseAmount <= 0) return 0;
    return ((totalPrice - baseAmount) / baseAmount) * 100;
  }
}

/// Taksit bilgisi
class InstallmentInfo {
  final String? binNumber;
  final double price;
  final CardType cardType;
  final CardAssociation cardAssociation;
  final String cardFamily;
  final String bankName;
  final int bankCode;
  final bool force3DS;
  final bool forceCVC;
  final List<InstallmentOption> options;

  const InstallmentInfo({
    this.binNumber,
    required this.price,
    required this.cardType,
    required this.cardAssociation,
    required this.cardFamily,
    required this.bankName,
    required this.bankCode,
    required this.force3DS,
    required this.forceCVC,
    required this.options,
  });

  /// Maksimum taksit sayısı
  int get maxInstallment => options.isEmpty
      ? 1
      : options.map((o) => o.installmentNumber).reduce((a, b) => a > b ? a : b);

  /// Belirli taksit sayısı için seçenek getir
  InstallmentOption? getOption(int installmentNumber) {
    try {
      return options.firstWhere(
        (o) => o.installmentNumber == installmentNumber,
      );
    } catch (_) {
      return null;
    }
  }
}
