import 'package:meta/meta.dart';

/// Status of the WebView payment interaction.
enum PaymentWebViewStatus {
  /// Payment completed successfully with callback data.
  success,

  /// User cancelled the payment (pressed back or close button).
  cancelled,

  /// Payment timed out.
  timeout,

  /// An error occurred during the payment process.
  error,
}

/// Result from 3DS WebView interaction.
///
/// This class represents the outcome of a 3D Secure payment flow
/// handled through the [PaymentWebView] widget.
///
/// ## Example Usage
///
/// ```dart
/// final result = await PaymentWebView.show(
///   context: context,
///   threeDSResult: initResult,
///   callbackUrl: 'https://yoursite.com/callback',
/// );
///
/// if (result.isSuccess) {
///   // Complete the payment with callback data
///   final payment = await provider.complete3DSPayment(
///     initResult.transactionId!,
///     callbackData: result.callbackData,
///   );
/// } else if (result.isCancelled) {
///   // User cancelled the payment
///   print('Payment was cancelled by user');
/// } else if (result.isTimeout) {
///   // Payment timed out
///   print('Payment timed out');
/// } else {
///   // Error occurred
///   print('Error: ${result.errorMessage}');
/// }
/// ```
@immutable
class PaymentWebViewResult {
  /// Creates a PaymentWebViewResult.
  const PaymentWebViewResult._({
    required this.status,
    this.callbackData,
    this.errorMessage,
  });

  /// Creates a successful result with callback data.
  ///
  /// [callbackData] contains the parameters returned from the payment
  /// provider's callback URL (query parameters or POST data).
  const PaymentWebViewResult.success(Map<String, dynamic> callbackData)
      : this._(
          status: PaymentWebViewStatus.success,
          callbackData: callbackData,
        );

  /// Creates a cancelled result.
  ///
  /// Used when the user explicitly cancels the payment flow
  /// by pressing back button or close button.
  const PaymentWebViewResult.cancelled()
      : this._(status: PaymentWebViewStatus.cancelled);

  /// Creates a timeout result.
  ///
  /// Used when the payment flow exceeds the configured timeout duration.
  const PaymentWebViewResult.timeout()
      : this._(
          status: PaymentWebViewStatus.timeout,
          errorMessage: 'Payment timed out',
        );

  /// Creates an error result with an error message.
  ///
  /// [errorMessage] describes what went wrong during the payment process.
  const PaymentWebViewResult.error(String errorMessage)
      : this._(
          status: PaymentWebViewStatus.error,
          errorMessage: errorMessage,
        );

  /// The status of the payment interaction.
  final PaymentWebViewStatus status;

  /// Callback data returned from the payment provider.
  ///
  /// This contains query parameters from the callback URL after
  /// 3DS authentication completes. Pass this to `complete3DSPayment()`.
  ///
  /// Only available when [status] is [PaymentWebViewStatus.success].
  final Map<String, dynamic>? callbackData;

  /// Error message describing what went wrong.
  ///
  /// Only available when [status] is [PaymentWebViewStatus.error]
  /// or [PaymentWebViewStatus.timeout].
  final String? errorMessage;

  /// Whether the payment completed successfully with callback data.
  bool get isSuccess => status == PaymentWebViewStatus.success;

  /// Whether the user cancelled the payment.
  bool get isCancelled => status == PaymentWebViewStatus.cancelled;

  /// Whether the payment timed out.
  bool get isTimeout => status == PaymentWebViewStatus.timeout;

  /// Whether an error occurred.
  bool get isError => status == PaymentWebViewStatus.error;

  @override
  String toString() {
    switch (status) {
      case PaymentWebViewStatus.success:
        return 'PaymentWebViewResult.success(callbackData: $callbackData)';
      case PaymentWebViewStatus.cancelled:
        return 'PaymentWebViewResult.cancelled()';
      case PaymentWebViewStatus.timeout:
        return 'PaymentWebViewResult.timeout()';
      case PaymentWebViewStatus.error:
        return 'PaymentWebViewResult.error($errorMessage)';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PaymentWebViewResult &&
        other.status == status &&
        _mapsEqual(other.callbackData, callbackData) &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode => Object.hash(status, callbackData, errorMessage);

  /// Helper method to compare maps for equality.
  static bool _mapsEqual(
    Map<String, dynamic>? a,
    Map<String, dynamic>? b,
  ) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}
