import 'package:flutter/material.dart';

/// Theme configuration for [PaymentWebView] widget.
///
/// Allows customization of the WebView appearance including colors,
/// loading indicators, and navigation elements.
///
/// ## Example Usage
///
/// ```dart
/// final result = await PaymentWebView.show(
///   context: context,
///   threeDSResult: initResult,
///   callbackUrl: 'https://yoursite.com/callback',
///   theme: PaymentWebViewTheme(
///     backgroundColor: Colors.white,
///     progressColor: Colors.blue,
///     loadingText: 'Ödeme işleniyor...',
///     appBarColor: Colors.blue,
///     appBarTitle: '3D Secure Doğrulama',
///     showCloseButton: true,
///   ),
/// );
/// ```
@immutable
class PaymentWebViewTheme {
  /// Creates a [PaymentWebViewTheme] with optional customization.
  const PaymentWebViewTheme({
    this.backgroundColor,
    this.progressColor,
    this.loadingText,
    this.loadingTextStyle,
    this.loadingWidget,
    this.appBarColor,
    this.appBarTitle,
    this.appBarTitleStyle,
    this.showCloseButton = true,
    this.closeButtonIcon,
    this.errorWidget,
    this.showProgressIndicator = true,
  });

  /// Background color of the WebView container.
  ///
  /// Defaults to the theme's scaffold background color if not specified.
  final Color? backgroundColor;

  /// Color of the linear progress indicator shown while loading.
  ///
  /// Defaults to the theme's primary color if not specified.
  final Color? progressColor;

  /// Text displayed below the loading indicator.
  ///
  /// Defaults to 'Yükleniyor...' (Turkish for 'Loading...').
  final String? loadingText;

  /// Text style for the loading text.
  ///
  /// If not specified, uses default body text style with secondary color.
  final TextStyle? loadingTextStyle;

  /// Custom widget to show while the WebView is loading.
  ///
  /// If provided, this replaces the default loading indicator.
  final Widget? loadingWidget;

  /// Color of the app bar background.
  ///
  /// Defaults to the theme's primary color if not specified.
  final Color? appBarColor;

  /// Title displayed in the app bar.
  ///
  /// Defaults to '3D Secure Doğrulama'.
  final String? appBarTitle;

  /// Text style for the app bar title.
  ///
  /// If not specified, uses default app bar title style.
  final TextStyle? appBarTitleStyle;

  /// Whether to show a close button in the app bar.
  ///
  /// Defaults to true. When tapped, closes the WebView and
  /// returns a cancelled result.
  final bool showCloseButton;

  /// Icon to use for the close button.
  ///
  /// Defaults to [Icons.close] if not specified.
  final IconData? closeButtonIcon;

  /// Custom widget to show when an error occurs.
  ///
  /// If not provided, shows a default error message with retry button.
  final Widget? errorWidget;

  /// Whether to show a progress indicator while loading.
  ///
  /// Defaults to true.
  final bool showProgressIndicator;

  /// Default theme with sensible defaults for Turkish payment flows.
  static const PaymentWebViewTheme defaultTheme = PaymentWebViewTheme();

  /// Creates a copy of this theme with the given fields replaced.
  PaymentWebViewTheme copyWith({
    Color? backgroundColor,
    Color? progressColor,
    String? loadingText,
    TextStyle? loadingTextStyle,
    Widget? loadingWidget,
    Color? appBarColor,
    String? appBarTitle,
    TextStyle? appBarTitleStyle,
    bool? showCloseButton,
    IconData? closeButtonIcon,
    Widget? errorWidget,
    bool? showProgressIndicator,
  }) {
    return PaymentWebViewTheme(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      progressColor: progressColor ?? this.progressColor,
      loadingText: loadingText ?? this.loadingText,
      loadingTextStyle: loadingTextStyle ?? this.loadingTextStyle,
      loadingWidget: loadingWidget ?? this.loadingWidget,
      appBarColor: appBarColor ?? this.appBarColor,
      appBarTitle: appBarTitle ?? this.appBarTitle,
      appBarTitleStyle: appBarTitleStyle ?? this.appBarTitleStyle,
      showCloseButton: showCloseButton ?? this.showCloseButton,
      closeButtonIcon: closeButtonIcon ?? this.closeButtonIcon,
      errorWidget: errorWidget ?? this.errorWidget,
      showProgressIndicator:
          showProgressIndicator ?? this.showProgressIndicator,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PaymentWebViewTheme &&
        other.backgroundColor == backgroundColor &&
        other.progressColor == progressColor &&
        other.loadingText == loadingText &&
        other.loadingTextStyle == loadingTextStyle &&
        other.loadingWidget == loadingWidget &&
        other.appBarColor == appBarColor &&
        other.appBarTitle == appBarTitle &&
        other.appBarTitleStyle == appBarTitleStyle &&
        other.showCloseButton == showCloseButton &&
        other.closeButtonIcon == closeButtonIcon &&
        other.errorWidget == errorWidget &&
        other.showProgressIndicator == showProgressIndicator;
  }

  @override
  int get hashCode => Object.hash(
        backgroundColor,
        progressColor,
        loadingText,
        loadingTextStyle,
        loadingWidget,
        appBarColor,
        appBarTitle,
        appBarTitleStyle,
        showCloseButton,
        closeButtonIcon,
        errorWidget,
        showProgressIndicator,
      );
}
