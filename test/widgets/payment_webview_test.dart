import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tr_payment_hub/src/widgets/payment_webview_result.dart';
import 'package:tr_payment_hub/src/widgets/payment_webview_theme.dart';

// Note: PaymentWebView widget tests are skipped because they require
// platform-specific WebView rendering which doesn't work in pure Dart tests.
// These tests would need to be run as integration tests on a real device/emulator.
//
// The widget tests below focus on the non-webview components:
// - PaymentWebViewTheme
// - PaymentWebViewResult

void main() {
  group('PaymentWebViewTheme', () {
    test('creates default theme', () {
      const theme = PaymentWebViewTheme.defaultTheme;

      expect(theme.backgroundColor, isNull);
      expect(theme.progressColor, isNull);
      expect(theme.loadingText, isNull);
      expect(theme.showCloseButton, isTrue);
      expect(theme.showProgressIndicator, isTrue);
    });

    test('copyWith creates new theme with specified values', () {
      const original = PaymentWebViewTheme(
        backgroundColor: Colors.white,
        loadingText: 'Original',
      );

      final copied = original.copyWith(
        loadingText: 'Copied',
        progressColor: Colors.blue,
      );

      expect(copied.backgroundColor, equals(Colors.white)); // Unchanged
      expect(copied.loadingText, equals('Copied')); // Changed
      expect(copied.progressColor, equals(Colors.blue)); // Added
    });

    test('equality works correctly', () {
      const theme1 = PaymentWebViewTheme(
        backgroundColor: Colors.white,
        loadingText: 'Loading',
      );

      const theme2 = PaymentWebViewTheme(
        backgroundColor: Colors.white,
        loadingText: 'Loading',
      );

      const theme3 = PaymentWebViewTheme(
        backgroundColor: Colors.black,
        loadingText: 'Loading',
      );

      expect(theme1, equals(theme2));
      expect(theme1, isNot(equals(theme3)));
    });

    test('hashCode is consistent', () {
      const theme1 = PaymentWebViewTheme(
        backgroundColor: Colors.white,
        loadingText: 'Loading',
      );

      const theme2 = PaymentWebViewTheme(
        backgroundColor: Colors.white,
        loadingText: 'Loading',
      );

      expect(theme1.hashCode, equals(theme2.hashCode));
    });
  });

  group('PaymentWebViewResult', () {
    test('creates success result with callback data', () {
      const result = PaymentWebViewResult.success({'status': 'success'});

      expect(result.isSuccess, isTrue);
      expect(result.isCancelled, isFalse);
      expect(result.isTimeout, isFalse);
      expect(result.isError, isFalse);
      expect(result.callbackData, equals({'status': 'success'}));
    });

    test('creates cancelled result', () {
      const result = PaymentWebViewResult.cancelled();

      expect(result.isSuccess, isFalse);
      expect(result.isCancelled, isTrue);
      expect(result.isTimeout, isFalse);
      expect(result.isError, isFalse);
    });

    test('creates timeout result', () {
      const result = PaymentWebViewResult.timeout();

      expect(result.isSuccess, isFalse);
      expect(result.isCancelled, isFalse);
      expect(result.isTimeout, isTrue);
      expect(result.isError, isFalse);
      expect(result.errorMessage, equals('Payment timed out'));
    });

    test('creates error result', () {
      const result = PaymentWebViewResult.error('Connection failed');

      expect(result.isSuccess, isFalse);
      expect(result.isCancelled, isFalse);
      expect(result.isTimeout, isFalse);
      expect(result.isError, isTrue);
      expect(result.errorMessage, equals('Connection failed'));
    });

    test('toString returns correct format', () {
      const success = PaymentWebViewResult.success({'key': 'value'});
      const cancelled = PaymentWebViewResult.cancelled();
      const timeout = PaymentWebViewResult.timeout();
      const error = PaymentWebViewResult.error('Error');

      expect(success.toString(), contains('success'));
      expect(cancelled.toString(), contains('cancelled'));
      expect(timeout.toString(), contains('timeout'));
      expect(error.toString(), contains('error'));
    });

    test('equality works correctly', () {
      const result1 = PaymentWebViewResult.success({'key': 'value'});
      const result2 = PaymentWebViewResult.success({'key': 'value'});
      const result3 = PaymentWebViewResult.success({'key': 'other'});

      expect(result1, equals(result2));
      expect(result1, isNot(equals(result3)));
    });
  });
}
