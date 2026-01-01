import '../core/config.dart';
import '../core/enums.dart';
import '../core/exceptions/payment_exception.dart';
import '../core/models/buyer_info.dart';
import '../core/models/installment_info.dart';
import '../core/models/payment_request.dart';
import '../core/models/payment_result.dart';
import '../core/models/refund_request.dart';
import '../core/models/saved_card.dart';
import '../core/models/three_ds_result.dart';
import '../core/payment_provider.dart';

/// Simulated error scenarios for testing.
///
/// Use this enum to configure [MockPaymentProvider] to simulate
/// different failure modes.
///
/// ## Example
///
/// ```dart
/// final provider = MockPaymentProvider(
///   errorScenario: MockErrorScenario.insufficientFunds,
/// );
/// ```
enum MockErrorScenario {
  /// No error - payment succeeds.
  none,

  /// Insufficient funds error.
  insufficientFunds,

  /// Invalid card number.
  invalidCard,

  /// Expired card.
  expiredCard,

  /// Invalid CVV.
  invalidCVV,

  /// Payment declined by bank.
  declined,

  /// 3DS authentication failed.
  threeDSFailed,

  /// Network/connection error.
  networkError,

  /// Request timeout.
  timeout,
}

/// Mock payment provider for testing.
///
/// Simulates payment operations without making real API calls.
/// Configurable success/failure modes, delays, and error scenarios.
///
/// ## Basic Usage
///
/// ```dart
/// final provider = MockPaymentProvider();
/// await provider.initialize(mockConfig);
/// final result = await provider.createPayment(request);
/// ```
///
/// ## Simulating Failures
///
/// ```dart
/// final provider = MockPaymentProvider(
///   shouldSucceed: false,
///   errorScenario: MockErrorScenario.insufficientFunds,
/// );
/// ```
///
/// ## Call Tracking
///
/// ```dart
/// final provider = MockPaymentProvider();
/// await provider.createPayment(request);
///
/// expect(provider.createPaymentCallCount, 1);
/// expect(provider.createPaymentCalls.first.amount, 100);
/// ```
class MockPaymentProvider implements PaymentProvider {
  /// Creates a mock payment provider with configurable behavior.
  ///
  /// - [shouldSucceed]: Whether operations should succeed (default: true)
  /// - [delay]: Simulated network delay (default: 500ms)
  /// - [customError]: Custom exception to throw on failure
  /// - [mockProviderType]: Provider type to return (default: iyzico)
  /// - [errorScenario]: Predefined error scenario to simulate
  /// - [operationDelays]: Per-operation delay overrides
  MockPaymentProvider({
    this.shouldSucceed = true,
    this.delay = const Duration(milliseconds: 500),
    this.customError,
    this.mockProviderType = ProviderType.iyzico,
    this.errorScenario = MockErrorScenario.none,
    Map<String, Duration>? operationDelays,
  }) : _operationDelays = operationDelays ?? {};

  /// Whether operations should succeed.
  final bool shouldSucceed;

  /// Default delay for all operations.
  final Duration delay;

  /// Custom error to throw on failure.
  final PaymentException? customError;

  /// Provider type to return.
  final ProviderType mockProviderType;

  /// Predefined error scenario.
  final MockErrorScenario errorScenario;

  /// Per-operation delay overrides.
  final Map<String, Duration> _operationDelays;

  bool _initialized = false;

  // Call tracking
  final List<PaymentRequest> _createPaymentCalls = [];
  final List<PaymentRequest> _init3DSPaymentCalls = [];
  final List<RefundRequest> _refundCalls = [];
  int _getInstallmentsCallCount = 0;
  int _getPaymentStatusCallCount = 0;

  /// Number of times [createPayment] was called.
  int get createPaymentCallCount => _createPaymentCalls.length;

  /// All [PaymentRequest]s passed to [createPayment].
  List<PaymentRequest> get createPaymentCalls =>
      List.unmodifiable(_createPaymentCalls);

  /// Number of times [init3DSPayment] was called.
  int get init3DSPaymentCallCount => _init3DSPaymentCalls.length;

  /// All [PaymentRequest]s passed to [init3DSPayment].
  List<PaymentRequest> get init3DSPaymentCalls =>
      List.unmodifiable(_init3DSPaymentCalls);

  /// Number of times [refund] was called.
  int get refundCallCount => _refundCalls.length;

  /// All [RefundRequest]s passed to [refund].
  List<RefundRequest> get refundCalls => List.unmodifiable(_refundCalls);

  /// Number of times [getInstallments] was called.
  int get getInstallmentsCallCount => _getInstallmentsCallCount;

  /// Number of times [getPaymentStatus] was called.
  int get getPaymentStatusCallCount => _getPaymentStatusCallCount;

  /// Resets all call tracking counters and histories.
  void resetCallTracking() {
    _createPaymentCalls.clear();
    _init3DSPaymentCalls.clear();
    _refundCalls.clear();
    _getInstallmentsCallCount = 0;
    _getPaymentStatusCallCount = 0;
  }

  @override
  ProviderType get providerType => mockProviderType;

  @override
  Future<void> initialize(PaymentConfig config) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (!config.validate()) {
      throw PaymentException.configError(message: 'Invalid config');
    }
    _initialized = true;
  }

  @override
  Future<PaymentResult> createPayment(PaymentRequest request) async {
    _checkInitialized();
    _createPaymentCalls.add(request);
    await Future<void>.delayed(_getDelay('createPayment'));

    if (!shouldSucceed || errorScenario != MockErrorScenario.none) {
      throw _getError();
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
    _init3DSPaymentCalls.add(request);
    await Future<void>.delayed(_getDelay('init3DSPayment'));

    if (!shouldSucceed || errorScenario != MockErrorScenario.none) {
      final error = _getError();
      return ThreeDSInitResult.failed(
        errorCode: error.code,
        errorMessage: error.message,
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
    await Future<void>.delayed(_getDelay('complete3DSPayment'));

    if (!shouldSucceed || errorScenario != MockErrorScenario.none) {
      throw _getError();
    }

    return PaymentResult.success(transactionId: transactionId, amount: 100);
  }

  @override
  Future<RefundResult> refund(RefundRequest request) async {
    _checkInitialized();
    _refundCalls.add(request);
    await Future<void>.delayed(_getDelay('refund'));

    if (!shouldSucceed || errorScenario != MockErrorScenario.none) {
      final error = _getError();
      return RefundResult.failure(
        errorCode: error.code,
        errorMessage: error.message,
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
    _getInstallmentsCallCount++;
    await Future<void>.delayed(_getDelay('getInstallments'));

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
    _getPaymentStatusCallCount++;
    await Future<void>.delayed(_getDelay('getPaymentStatus'));

    return shouldSucceed ? PaymentStatus.success : PaymentStatus.failed;
  }

  // ============================================
  // SAVED CARD / TOKENIZATION METHODS
  // ============================================

  @override
  Future<PaymentResult> chargeWithSavedCard({
    required String cardToken,
    required String orderId,
    required double amount,
    required BuyerInfo buyer,
    String? cardUserKey,
    int installment = 1,
    Currency currency = Currency.tryLira,
  }) async {
    _checkInitialized();
    await Future<void>.delayed(_getDelay('chargeWithSavedCard'));

    if (!shouldSucceed || errorScenario != MockErrorScenario.none) {
      throw _getError();
    }

    return PaymentResult.success(
      transactionId: 'mock_saved_${DateTime.now().millisecondsSinceEpoch}',
      amount: amount,
      paidAmount: amount,
      installment: installment,
      cardToken: cardToken,
      cardUserKey: cardUserKey,
      lastFourDigits: '0008',
    );
  }

  @override
  Future<List<SavedCard>> getSavedCards(String cardUserKey) async {
    _checkInitialized();
    await Future<void>.delayed(_getDelay('getSavedCards'));

    if (!shouldSucceed) {
      return [];
    }

    return [
      SavedCard(
        cardToken: 'mock_token_1',
        cardUserKey: cardUserKey,
        lastFourDigits: '0008',
        cardAssociation: CardAssociation.masterCard,
        cardFamily: 'Bonus',
        binNumber: '552879',
      ),
      SavedCard(
        cardToken: 'mock_token_2',
        cardUserKey: cardUserKey,
        lastFourDigits: '1234',
        cardAssociation: CardAssociation.visa,
        cardFamily: 'Maximum',
        binNumber: '405418',
      ),
    ];
  }

  @override
  Future<bool> deleteSavedCard({
    required String cardToken,
    String? cardUserKey,
  }) async {
    _checkInitialized();
    await Future<void>.delayed(_getDelay('deleteSavedCard'));

    return shouldSucceed;
  }

  @override
  void dispose() {
    _initialized = false;
  }

  Duration _getDelay(String operation) => _operationDelays[operation] ?? delay;

  PaymentException _getError() {
    if (customError != null) return customError!;

    switch (errorScenario) {
      case MockErrorScenario.none:
        return PaymentException.declined(provider: mockProviderType);
      case MockErrorScenario.insufficientFunds:
        return PaymentException.insufficientFunds(provider: mockProviderType);
      case MockErrorScenario.invalidCard:
        return PaymentException.invalidCard(provider: mockProviderType);
      case MockErrorScenario.expiredCard:
        return PaymentException.expiredCard(provider: mockProviderType);
      case MockErrorScenario.invalidCVV:
        return PaymentException.invalidCVV(provider: mockProviderType);
      case MockErrorScenario.declined:
        return PaymentException.declined(provider: mockProviderType);
      case MockErrorScenario.threeDSFailed:
        return PaymentException.threeDSFailed(provider: mockProviderType);
      case MockErrorScenario.networkError:
        return PaymentException.networkError(provider: mockProviderType);
      case MockErrorScenario.timeout:
        return PaymentException.timeout(provider: mockProviderType);
    }
  }

  void _checkInitialized() {
    if (!_initialized) {
      throw PaymentException.configError(
        message: 'Provider not initialized. Call initialize() first.',
      );
    }
  }
}
