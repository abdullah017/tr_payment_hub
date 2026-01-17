#!/usr/bin/env dart

/// Real Payment Integration Test Script
///
/// Bu script gerçek sandbox API'lerini test eder.
/// Çalıştırmadan önce environment variable'ları set edin:
///
/// ```bash
/// # iyzico (sandbox-merchant.iyzipay.com'dan alın)
/// export IYZICO_MERCHANT_ID=your_merchant_id
/// export IYZICO_API_KEY=your_api_key
/// export IYZICO_SECRET_KEY=your_secret_key
///
/// # Çalıştır
/// dart scripts/test_real_payment.dart
/// ```
///
/// NOT: Bu script GERÇEK sandbox API çağrıları yapar!
/// Para çekmez ama gerçek API entegrasyonunu test eder.

import 'dart:io';
import 'package:tr_payment_hub/tr_payment_hub.dart';

void main() async {
  print('╔════════════════════════════════════════════════════════════╗');
  print('║       TR Payment Hub - Real Integration Test               ║');
  print('╚════════════════════════════════════════════════════════════╝\n');

  // Environment variables kontrolü
  final iyzicoMerchantId = Platform.environment['IYZICO_MERCHANT_ID'];
  final iyzicoApiKey = Platform.environment['IYZICO_API_KEY'];
  final iyzicoSecretKey = Platform.environment['IYZICO_SECRET_KEY'];

  if (iyzicoMerchantId == null ||
      iyzicoApiKey == null ||
      iyzicoSecretKey == null) {
    print('❌ Environment variables eksik!\n');
    print('Lütfen aşağıdaki değişkenleri set edin:');
    print('  export IYZICO_MERCHANT_ID=xxx');
    print('  export IYZICO_API_KEY=xxx');
    print('  export IYZICO_SECRET_KEY=xxx\n');
    print('Sandbox hesabı için: https://sandbox-merchant.iyzipay.com');
    exit(1);
  }

  print('✓ Environment variables bulundu\n');

  // Provider oluştur ve initialize et
  final provider = IyzicoProvider();
  final config = IyzicoConfig(
    merchantId: iyzicoMerchantId,
    apiKey: iyzicoApiKey,
    secretKey: iyzicoSecretKey,
    isSandbox: true, // ÖNEMLİ: Sandbox mode!
  );

  try {
    await provider.initialize(config);
    print('✓ Provider initialized\n');
  } catch (e) {
    print('❌ Initialize failed: $e');
    exit(1);
  }

  // Test 1: BIN Sorgulama
  print('─────────────────────────────────────────');
  print('TEST 1: BIN Sorgulama (Taksit bilgisi)');
  print('─────────────────────────────────────────');

  try {
    final installments = await provider.getInstallments(
      binNumber: '552879', // Test MasterCard BIN
      amount: 100.0,
    );

    print('✓ BIN Sorgusu başarılı!');
    print('  Banka: ${installments.bankName}');
    print('  Kart Tipi: ${installments.cardType}');
    print('  Taksit Seçenekleri:');
    for (final opt in installments.options.take(3)) {
      print(
          '    ${opt.installmentNumber}x: ${opt.totalPrice.toStringAsFixed(2)} TL');
    }
    print('');
  } catch (e) {
    print('❌ BIN Sorgusu başarısız: $e\n');
  }

  // Test 2: Non-3DS Ödeme
  print('─────────────────────────────────────────');
  print('TEST 2: Non-3DS Ödeme (1 TL test)');
  print('─────────────────────────────────────────');

  final paymentRequest = PaymentRequest(
    orderId: 'TEST_${DateTime.now().millisecondsSinceEpoch}',
    amount: 1.0, // Minimum tutar
    currency: Currency.tryLira,
    installment: 1,
    card: const CardInfo(
      cardHolderName: 'Test User',
      cardNumber: '5528790000000008', // iyzico test kartı
      expireMonth: '12',
      expireYear: '2030',
      cvc: '123',
    ),
    buyer: const BuyerInfo(
      id: 'BUYER_TEST',
      name: 'Test',
      surname: 'User',
      email: 'test@test.com',
      phone: '+905551234567',
      identityNumber: '11111111111',
      ip: '127.0.0.1',
      city: 'Istanbul',
      country: 'Turkey',
      address: 'Test Adres Mahallesi No:1',
      zipCode: '34000',
    ),
    shippingAddress: const AddressInfo(
      contactName: 'Test User',
      city: 'Istanbul',
      country: 'Turkey',
      address: 'Test Adres Mahallesi No:1',
    ),
    billingAddress: const AddressInfo(
      contactName: 'Test User',
      city: 'Istanbul',
      country: 'Turkey',
      address: 'Test Adres Mahallesi No:1',
    ),
    basketItems: const [
      BasketItem(
        id: 'ITEM_1',
        name: 'Test Ürün',
        category: 'Test',
        price: 1.0,
        itemType: ItemType.physical,
      ),
    ],
  );

  try {
    final result = await provider.createPayment(paymentRequest);

    if (result.isSuccess) {
      print('✓ Ödeme başarılı!');
      print('  Transaction ID: ${result.transactionId}');
      print('  Tutar: ${result.paidAmount ?? result.amount} TL');
      print('');

      // Test 3: Refund
      print('─────────────────────────────────────────');
      print('TEST 3: İade (Refund)');
      print('─────────────────────────────────────────');

      try {
        final refundResult = await provider.refund(RefundRequest(
          transactionId: result.transactionId!,
          amount: 1.0,
        ));

        if (refundResult.isSuccess) {
          print('✓ İade başarılı!');
          print('  Refund ID: ${refundResult.refundId}');
        } else {
          print('❌ İade başarısız: ${refundResult.errorMessage}');
        }
      } catch (e) {
        print('❌ İade hatası: $e');
      }
    } else {
      print('❌ Ödeme başarısız: ${result.errorMessage}');
    }
    print('');
  } on PaymentException catch (e) {
    print('❌ Ödeme hatası: ${e.code} - ${e.message}');
    if (e.providerMessage != null) {
      print('  Provider: ${e.providerMessage}');
    }
    print('');
  }

  // Test 4: 3DS Init
  print('─────────────────────────────────────────');
  print('TEST 4: 3DS Başlatma');
  print('─────────────────────────────────────────');

  try {
    final threeDSRequest = paymentRequest.copyWith(
      orderId: 'TEST_3DS_${DateTime.now().millisecondsSinceEpoch}',
      callbackUrl: 'https://example.com/callback',
    );

    final threeDSResult = await provider.init3DSPayment(threeDSRequest);

    if (threeDSResult.status == ThreeDSStatus.pending) {
      print('✓ 3DS başlatıldı!');
      print('  Transaction ID: ${threeDSResult.transactionId}');
      print(
          '  HTML Content: ${threeDSResult.htmlContent?.substring(0, 100)}...');
      print('  (WebView\'de gösterilmesi gereken HTML)');
    } else {
      print('❌ 3DS başlatılamadı: ${threeDSResult.errorMessage}');
    }
    print('');
  } catch (e) {
    print('❌ 3DS hatası: $e\n');
  }

  // Test 5: Hatalı kart
  print('─────────────────────────────────────────');
  print('TEST 5: Yetersiz Bakiye Kartı');
  print('─────────────────────────────────────────');

  try {
    final failRequest = paymentRequest.copyWith(
      orderId: 'TEST_FAIL_${DateTime.now().millisecondsSinceEpoch}',
      card: const CardInfo(
        cardHolderName: 'Test User',
        cardNumber: '4543590000000006', // Yetersiz bakiye test kartı
        expireMonth: '12',
        expireYear: '2030',
        cvc: '123',
      ),
    );

    await provider.createPayment(failRequest);
    print('⚠️ Ödeme geçti ama başarısız olmalıydı!');
  } on PaymentException catch (e) {
    print('✓ Beklenen hata yakalandı: ${e.code}');
    print('  Mesaj: ${e.message}');
  }

  print('\n════════════════════════════════════════════════════════════');
  print('               TEST SONUCU                                   ');
  print('════════════════════════════════════════════════════════════');
  print('Tüm testler tamamlandı. Yukarıdaki sonuçları kontrol edin.');
  print('✓ işaretli testler başarılı demektir.');
  print('');

  provider.dispose();
}
