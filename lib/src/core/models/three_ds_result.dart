import '../enums.dart';

/// 3DS başlatma sonucu
class ThreeDSInitResult {
  final ThreeDSStatus status;
  final String? htmlContent; // iyzico için base64 encoded HTML
  final String? redirectUrl; // PayTR için
  final String? transactionId;
  final String? errorCode;
  final String? errorMessage;

  const ThreeDSInitResult({
    required this.status,
    this.htmlContent,
    this.redirectUrl,
    this.transactionId,
    this.errorCode,
    this.errorMessage,
  });

  /// WebView gösterilmeli mi?
  bool get needsWebView =>
      status == ThreeDSStatus.pending &&
      (htmlContent != null || redirectUrl != null);

  /// Başarılı mı?
  bool get isSuccess => status == ThreeDSStatus.completed;

  /// Başarısız mı?
  bool get isFailure => status == ThreeDSStatus.failed;

  factory ThreeDSInitResult.pending({
    String? htmlContent,
    String? redirectUrl,
    String? transactionId,
  }) {
    return ThreeDSInitResult(
      status: ThreeDSStatus.pending,
      htmlContent: htmlContent,
      redirectUrl: redirectUrl,
      transactionId: transactionId,
    );
  }

  factory ThreeDSInitResult.failed({
    required String errorCode,
    required String errorMessage,
  }) {
    return ThreeDSInitResult(
      status: ThreeDSStatus.failed,
      errorCode: errorCode,
      errorMessage: errorMessage,
    );
  }

  factory ThreeDSInitResult.notRequired() {
    return const ThreeDSInitResult(status: ThreeDSStatus.notRequired);
  }
}
