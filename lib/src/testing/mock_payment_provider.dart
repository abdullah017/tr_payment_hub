import '../core/enums.dart';
import '../core/config.dart';
import '../core/payment_provider.dart';
import '../core/models/payment_request.dart';
import '../core/models/payment_result.dart';
import '../core/models/installment_info.dart';
import '../core/models/three_ds_result.dart';
import '../core/exceptions/payment_exception.dart';

/// Test için mock provider
class MockPaymentProvider implements PaymentProvider {
  final bool shouldSucceed;
  final Duration delay;
  final PaymentException? customError;

  bool _initialized = false;

  MockPaymentProvider({
    this.shouldSucceed = true,
    this.delay = const Duration(milliseconds: 500),
    this.customError,
  });

  @override
  ProviderType get providerType => ProviderType.iyzico;

  @override
  Future<void> initialize(PaymentConfig config) async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (!config.validate()) {
      throw PaymentException.configError(message: 'Invalid config');
    }
    _initialized = true;
  }

  @override
  Future<PaymentResult> createPayment(PaymentRequest request) async {
    _checkInitialized();
    await Future.delayed(delay);

    if (!shouldSucceed) {
      throw customError ?? PaymentException.declined();
    }

    return PaymentResult.success(
      transactionId: 'mock_${DateTime.now().millisecondsSinceEpoch}',
      amount: request.amount,
      paidAmount: request.effectivePaidAmount,
      installment: request.installment,
      binNumber: request.card.binNumber,
      lastFourDigits: request.card.lastFourDigits,
    );
  }

  @override
  Future<ThreeDSInitResult> init3DSPayment(PaymentRequest request) async {
    _checkInitialized();
    await Future.delayed(delay);

    if (!shouldSucceed) {
      return ThreeDSInitResult.failed(
        errorCode: 'mock_error',
        errorMessage: 'Mock 3DS failed',
      );
    }

    return ThreeDSInitResult.pending(
      htmlContent: '<html><body>Mock 3DS Page</body></html>',
      transactionId: 'mock_3ds_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  @override
  Future<PaymentResult> complete3DSPayment(
    String transactionId, {
    Map<String, dynamic>? callbackData,
  }) async {
    _checkInitialized();
    await Future.delayed(delay);

    if (!shouldSucceed) {
      throw PaymentException.threeDSFailed();
    }

    return PaymentResult.success(transactionId: transactionId, amount: 100.0);
  }

  @override
  Future<RefundResult> refund(RefundRequest request) async {
    _checkInitialized();
    await Future.delayed(delay);

    if (!shouldSucceed) {
      return RefundResult.failure(
        errorCode: 'refund_failed',
        errorMessage: 'Mock refund failed',
      );
    }

    return RefundResult.success(
      refundId: 'mock_refund_${DateTime.now().millisecondsSinceEpoch}',
      refundedAmount: request.amount,
    );
  }

  @override
  Future<InstallmentInfo> getInstallments({
    required String binNumber,
    required double amount,
  }) async {
    _checkInitialized();
    await Future.delayed(delay);

    return InstallmentInfo(
      binNumber: binNumber,
      price: amount,
      cardType: CardType.creditCard,
      cardAssociation: CardAssociation.masterCard,
      cardFamily: 'Axess',
      bankName: 'Mock Bank',
      bankCode: 999,
      force3DS: false,
      forceCVC: true,
      options: [
        InstallmentOption(
          installmentNumber: 1,
          installmentPrice: amount,
          totalPrice: amount,
        ),
        InstallmentOption(
          installmentNumber: 2,
          installmentPrice: amount / 2 * 1.02,
          totalPrice: amount * 1.02,
        ),
        InstallmentOption(
          installmentNumber: 3,
          installmentPrice: amount / 3 * 1.03,
          totalPrice: amount * 1.03,
        ),
        InstallmentOption(
          installmentNumber: 6,
          installmentPrice: amount / 6 * 1.06,
          totalPrice: amount * 1.06,
        ),
        InstallmentOption(
          installmentNumber: 9,
          installmentPrice: amount / 9 * 1.09,
          totalPrice: amount * 1.09,
        ),
        InstallmentOption(
          installmentNumber: 12,
          installmentPrice: amount / 12 * 1.12,
          totalPrice: amount * 1.12,
        ),
      ],
    );
  }

  @override
  Future<PaymentStatus> getPaymentStatus(String transactionId) async {
    _checkInitialized();
    await Future.delayed(delay);

    return shouldSucceed ? PaymentStatus.success : PaymentStatus.failed;
  }

  @override
  void dispose() {
    _initialized = false;
  }

  void _checkInitialized() {
    if (!_initialized) {
      throw PaymentException.configError(
        message: 'Provider not initialized. Call initialize() first.',
      );
    }
  }
}
