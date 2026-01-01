import 'package:meta/meta.dart';

import '../enums.dart';

/// Result of 3D Secure payment initialization.
///
/// When a 3DS payment is initiated, this result contains the necessary
/// data to complete the authentication flow.
///
/// ## Example
///
/// ```dart
/// final result = await provider.init3DSPayment(request);
///
/// if (result.needsWebView) {
///   // For iyzico: display htmlContent in WebView
///   if (result.htmlContent != null) {
///     webViewController.loadHtmlString(result.htmlContent!);
///   }
///
///   // For PayTR: redirect to URL
///   if (result.redirectUrl != null) {
///     webViewController.loadRequest(Uri.parse(result.redirectUrl!));
///   }
/// }
///
/// // After user completes 3DS verification:
/// final paymentResult = await provider.complete3DSPayment(
///   result.transactionId!,
///   callbackData: callbackData,
/// );
/// ```
///
/// ## Factory Constructors
///
/// * [ThreeDSInitResult.pending] - 3DS verification required
/// * [ThreeDSInitResult.failed] - Initialization failed
/// * [ThreeDSInitResult.notRequired] - 3DS not required for this card
@immutable
class ThreeDSInitResult {
  /// Creates a new [ThreeDSInitResult] instance.
  const ThreeDSInitResult({
    required this.status,
    this.htmlContent,
    this.redirectUrl,
    this.transactionId,
    this.errorCode,
    this.errorMessage,
  });

  /// Creates a pending result that requires 3DS verification.
  factory ThreeDSInitResult.pending({
    String? htmlContent,
    String? redirectUrl,
    String? transactionId,
  }) =>
      ThreeDSInitResult(
        status: ThreeDSStatus.pending,
        htmlContent: htmlContent,
        redirectUrl: redirectUrl,
        transactionId: transactionId,
      );

  /// Creates a failed result.
  factory ThreeDSInitResult.failed({
    required String errorCode,
    required String errorMessage,
  }) =>
      ThreeDSInitResult(
        status: ThreeDSStatus.failed,
        errorCode: errorCode,
        errorMessage: errorMessage,
      );

  /// Creates a result indicating 3DS is not required.
  factory ThreeDSInitResult.notRequired() =>
      const ThreeDSInitResult(status: ThreeDSStatus.notRequired);

  /// Current status of the 3DS flow.
  final ThreeDSStatus status;

  /// HTML content for 3DS verification (iyzico).
  ///
  /// Load this content in a WebView to display the 3DS form.
  /// The content is typically base64 encoded HTML from iyzico.
  final String? htmlContent;

  /// Redirect URL for 3DS verification (PayTR).
  ///
  /// Navigate to this URL in a WebView or browser to complete
  /// the 3DS verification.
  final String? redirectUrl;

  /// Transaction ID for completing the payment.
  ///
  /// Pass this ID to `complete3DSPayment` after
  /// the user completes the 3DS verification.
  final String? transactionId;

  /// Error code if initialization failed.
  final String? errorCode;

  /// Error message if initialization failed.
  final String? errorMessage;

  /// Whether a WebView is needed to complete verification.
  ///
  /// Returns true if the status is pending and either
  /// [htmlContent] or [redirectUrl] is available.
  bool get needsWebView =>
      status == ThreeDSStatus.pending &&
      (htmlContent != null || redirectUrl != null);

  /// Whether the 3DS flow completed successfully.
  bool get isSuccess => status == ThreeDSStatus.completed;

  /// Whether the 3DS initialization failed.
  bool get isFailure => status == ThreeDSStatus.failed;

  @override
  String toString() {
    switch (status) {
      case ThreeDSStatus.pending:
        return 'ThreeDSInitResult.pending(transactionId: $transactionId)';
      case ThreeDSStatus.failed:
        return 'ThreeDSInitResult.failed(errorCode: $errorCode)';
      case ThreeDSStatus.completed:
        return 'ThreeDSInitResult.completed(transactionId: $transactionId)';
      case ThreeDSStatus.notRequired:
        return 'ThreeDSInitResult.notRequired()';
    }
  }
}
