import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tr_payment_hub/src/widgets/payment_webview_theme.dart';

void main() {
  group('PaymentWebViewTheme', () {
    group('constructor', () {
      test('should create theme with default values', () {
        const theme = PaymentWebViewTheme.defaultTheme;

        expect(theme.backgroundColor, isNull);
        expect(theme.progressColor, isNull);
        expect(theme.loadingText, isNull);
        expect(theme.loadingTextStyle, isNull);
        expect(theme.loadingWidget, isNull);
        expect(theme.appBarColor, isNull);
        expect(theme.appBarTitle, isNull);
        expect(theme.appBarTitleStyle, isNull);
        expect(theme.showCloseButton, isTrue);
        expect(theme.closeButtonIcon, isNull);
        expect(theme.errorWidget, isNull);
        expect(theme.showProgressIndicator, isTrue);
      });

      test('should create theme with custom values', () {
        const theme = PaymentWebViewTheme(
          backgroundColor: Colors.white,
          progressColor: Colors.blue,
          loadingText: 'Loading...',
          appBarColor: Colors.green,
          appBarTitle: 'Payment',
          showCloseButton: false,
          closeButtonIcon: Icons.arrow_back,
          showProgressIndicator: false,
        );

        expect(theme.backgroundColor, equals(Colors.white));
        expect(theme.progressColor, equals(Colors.blue));
        expect(theme.loadingText, equals('Loading...'));
        expect(theme.appBarColor, equals(Colors.green));
        expect(theme.appBarTitle, equals('Payment'));
        expect(theme.showCloseButton, isFalse);
        expect(theme.closeButtonIcon, equals(Icons.arrow_back));
        expect(theme.showProgressIndicator, isFalse);
      });
    });

    group('defaultTheme', () {
      test('should have default values', () {
        const theme = PaymentWebViewTheme.defaultTheme;

        expect(theme.backgroundColor, isNull);
        expect(theme.progressColor, isNull);
        expect(theme.loadingText, isNull);
        expect(theme.showCloseButton, isTrue);
        expect(theme.showProgressIndicator, isTrue);
      });
    });

    group('copyWith', () {
      test('should copy with new backgroundColor', () {
        const original = PaymentWebViewTheme(backgroundColor: Colors.white);
        final copied = original.copyWith(backgroundColor: Colors.black);

        expect(copied.backgroundColor, equals(Colors.black));
        expect(original.backgroundColor, equals(Colors.white));
      });

      test('should copy with new progressColor', () {
        const original = PaymentWebViewTheme(progressColor: Colors.blue);
        final copied = original.copyWith(progressColor: Colors.red);

        expect(copied.progressColor, equals(Colors.red));
        expect(original.progressColor, equals(Colors.blue));
      });

      test('should copy with new loadingText', () {
        const original = PaymentWebViewTheme(loadingText: 'Original');
        final copied = original.copyWith(loadingText: 'New');

        expect(copied.loadingText, equals('New'));
        expect(original.loadingText, equals('Original'));
      });

      test('should copy with new appBarColor', () {
        const original = PaymentWebViewTheme(appBarColor: Colors.green);
        final copied = original.copyWith(appBarColor: Colors.purple);

        expect(copied.appBarColor, equals(Colors.purple));
        expect(original.appBarColor, equals(Colors.green));
      });

      test('should copy with new appBarTitle', () {
        const original = PaymentWebViewTheme(appBarTitle: 'Title 1');
        final copied = original.copyWith(appBarTitle: 'Title 2');

        expect(copied.appBarTitle, equals('Title 2'));
        expect(original.appBarTitle, equals('Title 1'));
      });

      test('should copy with new showCloseButton', () {
        const original = PaymentWebViewTheme(showCloseButton: false);
        final copied = original.copyWith(showCloseButton: true);

        expect(copied.showCloseButton, isTrue);
        expect(original.showCloseButton, isFalse);
      });

      test('should copy with new closeButtonIcon', () {
        const original = PaymentWebViewTheme(closeButtonIcon: Icons.close);
        final copied = original.copyWith(closeButtonIcon: Icons.arrow_back);

        expect(copied.closeButtonIcon, equals(Icons.arrow_back));
        expect(original.closeButtonIcon, equals(Icons.close));
      });

      test('should copy with new showProgressIndicator', () {
        const original = PaymentWebViewTheme(showProgressIndicator: false);
        final copied = original.copyWith(showProgressIndicator: true);

        expect(copied.showProgressIndicator, isTrue);
        expect(original.showProgressIndicator, isFalse);
      });

      test('should preserve unmodified values', () {
        const original = PaymentWebViewTheme(
          backgroundColor: Colors.white,
          progressColor: Colors.blue,
          loadingText: 'Loading',
          appBarColor: Colors.green,
          appBarTitle: 'Title',
          showCloseButton: false,
          showProgressIndicator: false,
        );

        final copied = original.copyWith(backgroundColor: Colors.black);

        expect(copied.backgroundColor, equals(Colors.black));
        expect(copied.progressColor, equals(Colors.blue));
        expect(copied.loadingText, equals('Loading'));
        expect(copied.appBarColor, equals(Colors.green));
        expect(copied.appBarTitle, equals('Title'));
        expect(copied.showCloseButton, isFalse);
        expect(copied.showProgressIndicator, isFalse);
      });

      test('should copy with multiple values', () {
        const original = PaymentWebViewTheme.defaultTheme;
        final copied = original.copyWith(
          backgroundColor: Colors.white,
          progressColor: Colors.blue,
          loadingText: 'Loading...',
          showCloseButton: false,
        );

        expect(copied.backgroundColor, equals(Colors.white));
        expect(copied.progressColor, equals(Colors.blue));
        expect(copied.loadingText, equals('Loading...'));
        expect(copied.showCloseButton, isFalse);
      });

      test('should copy with loadingTextStyle', () {
        const original = PaymentWebViewTheme.defaultTheme;
        const newStyle = TextStyle(fontSize: 16, color: Colors.grey);
        final copied = original.copyWith(loadingTextStyle: newStyle);

        expect(copied.loadingTextStyle, equals(newStyle));
      });

      test('should copy with appBarTitleStyle', () {
        const original = PaymentWebViewTheme.defaultTheme;
        const newStyle = TextStyle(fontSize: 20, fontWeight: FontWeight.bold);
        final copied = original.copyWith(appBarTitleStyle: newStyle);

        expect(copied.appBarTitleStyle, equals(newStyle));
      });

      test('should copy with custom widgets', () {
        const original = PaymentWebViewTheme.defaultTheme;
        const loadingWidget = CircularProgressIndicator();
        const errorWidget = Text('Error');

        final copied = original.copyWith(
          loadingWidget: loadingWidget,
          errorWidget: errorWidget,
        );

        expect(copied.loadingWidget, equals(loadingWidget));
        expect(copied.errorWidget, equals(errorWidget));
      });
    });

    group('equality', () {
      test('same themes should be equal', () {
        const theme1 = PaymentWebViewTheme(
          backgroundColor: Colors.white,
          progressColor: Colors.blue,
          loadingText: 'Loading',
        );
        const theme2 = PaymentWebViewTheme(
          backgroundColor: Colors.white,
          progressColor: Colors.blue,
          loadingText: 'Loading',
        );

        expect(theme1, equals(theme2));
        expect(theme1.hashCode, equals(theme2.hashCode));
      });

      test('different themes should not be equal', () {
        const theme1 = PaymentWebViewTheme(backgroundColor: Colors.white);
        const theme2 = PaymentWebViewTheme(backgroundColor: Colors.black);

        expect(theme1, isNot(equals(theme2)));
      });

      test('default themes should be equal', () {
        const theme1 = PaymentWebViewTheme.defaultTheme;
        const theme2 = PaymentWebViewTheme.defaultTheme;

        expect(theme1, equals(theme2));
        expect(theme1.hashCode, equals(theme2.hashCode));
      });

      test('identical theme should equal itself', () {
        const theme = PaymentWebViewTheme(backgroundColor: Colors.red);

        expect(theme, equals(theme));
      });

      test('theme should not equal non-theme object', () {
        const theme = PaymentWebViewTheme.defaultTheme;
        // ignore: unrelated_type_equality_checks
        final equalsString = theme == ('not a theme' as Object);
        // ignore: unrelated_type_equality_checks
        final equalsInt = theme == (123 as Object);
        const Object? nullObj = null;
        const equalsNull = theme == nullObj;

        expect(equalsString, isFalse);
        expect(equalsInt, isFalse);
        expect(equalsNull, isFalse);
      });

      test('themes with all different values should not be equal', () {
        const theme1 = PaymentWebViewTheme(
          backgroundColor: Colors.white,
          progressColor: Colors.blue,
          loadingText: 'Loading 1',
          appBarColor: Colors.green,
          appBarTitle: 'Title 1',
          showCloseButton: false,
          showProgressIndicator: false,
        );
        const theme2 = PaymentWebViewTheme(
          backgroundColor: Colors.black,
          progressColor: Colors.red,
          loadingText: 'Loading 2',
          appBarColor: Colors.purple,
          appBarTitle: 'Title 2',
          showCloseButton: true,
          showProgressIndicator: true,
        );

        expect(theme1, isNot(equals(theme2)));
      });
    });

    group('immutability', () {
      test('theme should be immutable', () {
        const theme = PaymentWebViewTheme(
          backgroundColor: Colors.white,
          progressColor: Colors.blue,
        );

        // copyWith should return a new instance
        final copied = theme.copyWith(backgroundColor: Colors.black);

        expect(theme.backgroundColor, equals(Colors.white));
        expect(copied.backgroundColor, equals(Colors.black));
      });
    });
  });
}
