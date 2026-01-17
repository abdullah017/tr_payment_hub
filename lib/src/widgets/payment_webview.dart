import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/models/three_ds_result.dart';
import 'payment_webview_result.dart';
import 'payment_webview_theme.dart';

/// Built-in WebView widget for 3D Secure payment flows.
///
/// Supports both iyzico (HTML content) and PayTR (redirect URL) payment flows.
/// Automatically detects the callback URL and extracts payment data.
///
/// ## Features
///
/// * Handles both HTML content (iyzico) and redirect URLs (PayTR)
/// * Automatic callback URL detection
/// * Configurable timeout
/// * Customizable theme
/// * Loading and error states
/// * Cancel support with confirmation dialog
///
/// ## Example Usage
///
/// ```dart
/// // Initialize 3DS payment
/// final threeDSResult = await provider.init3DSPayment(request);
///
/// if (threeDSResult.needsWebView) {
///   // Show WebView and wait for result
///   final result = await PaymentWebView.show(
///     context: context,
///     threeDSResult: threeDSResult,
///     callbackUrl: 'https://yoursite.com/callback',
///   );
///
///   if (result.isSuccess) {
///     // Complete the payment
///     final payment = await provider.complete3DSPayment(
///       threeDSResult.transactionId!,
///       callbackData: result.callbackData,
///     );
///   } else if (result.isCancelled) {
///     print('Payment cancelled by user');
///   }
/// }
/// ```
///
/// ## iyzico Integration
///
/// iyzico returns HTML content that should be rendered in the WebView:
///
/// ```dart
/// if (threeDSResult.htmlContent != null) {
///   // PaymentWebView handles this automatically
/// }
/// ```
///
/// ## PayTR Integration
///
/// PayTR returns an iframe URL that should be loaded:
///
/// ```dart
/// if (threeDSResult.redirectUrl != null) {
///   // PaymentWebView handles this automatically
/// }
/// ```
class PaymentWebView extends StatefulWidget {
  /// Creates a [PaymentWebView] widget.
  ///
  /// Either [htmlContent] or [redirectUrl] must be provided.
  const PaymentWebView({
    super.key,
    this.htmlContent,
    this.redirectUrl,
    required this.callbackUrl,
    this.theme,
    this.timeout = const Duration(minutes: 5),
    this.onResult,
    this.showAppBar = true,
  }) : assert(
          htmlContent != null || redirectUrl != null,
          'Either htmlContent or redirectUrl must be provided',
        );

  /// HTML content to render in the WebView.
  ///
  /// Used by iyzico which returns Base64 encoded HTML.
  /// The content will be decoded and loaded as HTML.
  final String? htmlContent;

  /// URL to load in the WebView.
  ///
  /// Used by PayTR which returns an iframe URL.
  final String? redirectUrl;

  /// Callback URL that signals payment completion.
  ///
  /// When the WebView navigates to a URL starting with this value,
  /// the widget extracts query parameters and returns the result.
  final String callbackUrl;

  /// Theme configuration for the WebView appearance.
  ///
  /// If not provided, uses [PaymentWebViewTheme.defaultTheme].
  final PaymentWebViewTheme? theme;

  /// Timeout duration for the payment flow.
  ///
  /// If the payment is not completed within this duration,
  /// a timeout result is returned. Defaults to 5 minutes.
  final Duration timeout;

  /// Callback when payment result is available.
  ///
  /// This is called in addition to returning the result.
  /// Useful for analytics or logging.
  final void Function(PaymentWebViewResult result)? onResult;

  /// Whether to show the app bar with close button.
  ///
  /// Defaults to true. Set to false for embedded use cases.
  final bool showAppBar;

  /// Shows the [PaymentWebView] as a full-screen modal.
  ///
  /// This is the recommended way to display the WebView for 3DS flows.
  ///
  /// Returns [PaymentWebViewResult] with the payment outcome.
  static Future<PaymentWebViewResult> show({
    required BuildContext context,
    required ThreeDSInitResult threeDSResult,
    required String callbackUrl,
    PaymentWebViewTheme? theme,
    Duration timeout = const Duration(minutes: 5),
    bool showConfirmOnCancel = true,
  }) async {
    final result = await Navigator.of(context).push<PaymentWebViewResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => _PaymentWebViewPage(
          htmlContent: threeDSResult.htmlContent,
          redirectUrl: threeDSResult.redirectUrl,
          callbackUrl: callbackUrl,
          theme: theme,
          timeout: timeout,
          showConfirmOnCancel: showConfirmOnCancel,
        ),
      ),
    );

    return result ?? const PaymentWebViewResult.cancelled();
  }

  /// Shows the [PaymentWebView] as a bottom sheet.
  ///
  /// Useful for a less intrusive payment flow.
  static Future<PaymentWebViewResult> showBottomSheet({
    required BuildContext context,
    required ThreeDSInitResult threeDSResult,
    required String callbackUrl,
    PaymentWebViewTheme? theme,
    Duration timeout = const Duration(minutes: 5),
    bool isDismissible = false,
    bool enableDrag = false,
  }) async {
    final result = await showModalBottomSheet<PaymentWebViewResult>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: PaymentWebView(
          htmlContent: threeDSResult.htmlContent,
          redirectUrl: threeDSResult.redirectUrl,
          callbackUrl: callbackUrl,
          theme: theme,
          timeout: timeout,
          showAppBar: true,
        ),
      ),
    );

    return result ?? const PaymentWebViewResult.cancelled();
  }

  @override
  State<PaymentWebView> createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends State<PaymentWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  Timer? _timeoutTimer;

  PaymentWebViewTheme get _theme =>
      widget.theme ?? PaymentWebViewTheme.defaultTheme;

  @override
  void initState() {
    super.initState();
    _initWebView();
    _startTimeoutTimer();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: _onPageStarted,
          onPageFinished: _onPageFinished,
          onWebResourceError: _onWebResourceError,
          onNavigationRequest: _onNavigationRequest,
        ),
      );

    // Load content based on type
    if (widget.htmlContent != null) {
      _loadHtmlContent();
    } else if (widget.redirectUrl != null) {
      _controller.loadRequest(Uri.parse(widget.redirectUrl!));
    }
  }

  void _loadHtmlContent() {
    String htmlContent = widget.htmlContent!;

    // Try to decode if Base64 encoded
    try {
      final decoded = utf8.decode(base64.decode(htmlContent));
      htmlContent = decoded;
    } catch (_) {
      // Not Base64 encoded, use as-is
    }

    // Wrap in basic HTML structure if needed
    if (!htmlContent.toLowerCase().contains('<html')) {
      htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body>
$htmlContent
</body>
</html>
''';
    }

    _controller.loadHtmlString(htmlContent);
  }

  void _startTimeoutTimer() {
    _timeoutTimer = Timer(widget.timeout, () {
      if (mounted) {
        _returnResult(const PaymentWebViewResult.timeout());
      }
    });
  }

  void _onPageStarted(String url) {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
  }

  void _onPageFinished(String url) {
    setState(() {
      _isLoading = false;
    });
  }

  void _onWebResourceError(WebResourceError error) {
    setState(() {
      _hasError = true;
      _errorMessage = error.description;
      _isLoading = false;
    });
  }

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    final url = request.url;

    // Check if this is the callback URL
    if (url.startsWith(widget.callbackUrl)) {
      final uri = Uri.parse(url);
      final callbackData = <String, dynamic>{};

      // Extract query parameters
      uri.queryParameters.forEach((key, value) {
        callbackData[key] = value;
      });

      // Return success with callback data
      _returnResult(PaymentWebViewResult.success(callbackData));
      return NavigationDecision.prevent;
    }

    return NavigationDecision.navigate;
  }

  void _returnResult(PaymentWebViewResult result) {
    _timeoutTimer?.cancel();
    widget.onResult?.call(result);

    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop(result);
    }
  }

  Future<void> _handleCancel() async {
    _returnResult(const PaymentWebViewResult.cancelled());
  }

  Future<void> _handleRetry() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    if (widget.htmlContent != null) {
      _loadHtmlContent();
    } else if (widget.redirectUrl != null) {
      await _controller.loadRequest(Uri.parse(widget.redirectUrl!));
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        if (widget.showAppBar) _buildAppBar(theme),
        if (_theme.showProgressIndicator && _isLoading) _buildProgressBar(),
        Expanded(child: _buildBody(theme)),
      ],
    );
  }

  Widget _buildAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: _theme.appBarColor ?? theme.primaryColor,
      title: Text(
        _theme.appBarTitle ?? '3D Secure Doğrulama',
        style: _theme.appBarTitleStyle,
      ),
      leading: _theme.showCloseButton
          ? IconButton(
              icon: Icon(_theme.closeButtonIcon ?? Icons.close),
              onPressed: _handleCancel,
            )
          : null,
      automaticallyImplyLeading: false,
    );
  }

  Widget _buildProgressBar() {
    return LinearProgressIndicator(
      backgroundColor: Colors.grey.shade200,
      valueColor: AlwaysStoppedAnimation<Color>(
        _theme.progressColor ?? Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_hasError) {
      return _buildErrorView(theme);
    }

    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading) _buildLoadingOverlay(theme),
      ],
    );
  }

  Widget _buildLoadingOverlay(ThemeData theme) {
    if (_theme.loadingWidget != null) {
      return _theme.loadingWidget!;
    }

    return Container(
      color: _theme.backgroundColor ?? theme.scaffoldBackgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              _theme.loadingText ?? 'Yükleniyor...',
              style: _theme.loadingTextStyle ??
                  theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.secondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(ThemeData theme) {
    if (_theme.errorWidget != null) {
      return _theme.errorWidget!;
    }

    return Container(
      color: _theme.backgroundColor ?? theme.scaffoldBackgroundColor,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Sayfa yüklenemedi',
              style: theme.textTheme.titleLarge,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: _handleCancel,
                  child: const Text('İptal'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _handleRetry,
                  child: const Text('Tekrar Dene'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Internal page wrapper for full-screen modal usage.
class _PaymentWebViewPage extends StatelessWidget {
  const _PaymentWebViewPage({
    this.htmlContent,
    this.redirectUrl,
    required this.callbackUrl,
    this.theme,
    required this.timeout,
    required this.showConfirmOnCancel,
  });

  final String? htmlContent;
  final String? redirectUrl;
  final String callbackUrl;
  final PaymentWebViewTheme? theme;
  final Duration timeout;
  final bool showConfirmOnCancel;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !showConfirmOnCancel,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final shouldPop = await _showCancelConfirmation(context);
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop(const PaymentWebViewResult.cancelled());
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: PaymentWebView(
            htmlContent: htmlContent,
            redirectUrl: redirectUrl,
            callbackUrl: callbackUrl,
            theme: theme,
            timeout: timeout,
          ),
        ),
      ),
    );
  }

  Future<bool> _showCancelConfirmation(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ödemeyi İptal Et'),
        content: const Text(
          'Ödeme işlemini iptal etmek istediğinizden emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hayır'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Evet, İptal Et'),
          ),
        ],
      ),
    );

    return result ?? false;
  }
}
