import 'package:xml/xml.dart';

import '../../core/enums.dart';
import '../../core/models/installment_info.dart';
import '../../core/models/payment_request.dart';
import '../../core/models/payment_result.dart';
import '../../core/models/three_ds_result.dart';
import 'param_error_mapper.dart';

/// Param SOAP/XML request/response mapper
class ParamMapper {
  ParamMapper._();

  // ============================================
  // SOAP ENVELOPE TEMPLATES
  // ============================================

  /// SOAP envelope wrapper
  static String wrapSoapEnvelope(String body) =>
      '''
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               xmlns:xsd="http://www.w3.org/2001/XMLSchema"
               xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    $body
  </soap:Body>
</soap:Envelope>
''';

  // ============================================
  // REQUEST MAPPERS
  // ============================================

  /// Non-3DS ödeme isteği oluştur
  static String toPaymentRequest({
    required PaymentRequest request,
    required String clientCode,
    required String clientUsername,
    required String clientPassword,
    required String guid,
    required String hash,
    required String orderId,
  }) {
    final amount = _formatAmount(request.effectivePaidAmount);
    final card = request.card;
    final buyer = request.buyer;

    final body =
        '''
<TP_WMD_Pay xmlns="https://turkpos.com.tr/">
  <G>
    <CLIENT_CODE>$clientCode</CLIENT_CODE>
    <CLIENT_USERNAME>$clientUsername</CLIENT_USERNAME>
    <CLIENT_PASSWORD>$clientPassword</CLIENT_PASSWORD>
  </G>
  <GUID>$guid</GUID>
  <KK_Sahibi>${_escapeXml(card.cardHolderName)}</KK_Sahibi>
  <KK_No>${card.cardNumber}</KK_No>
  <KK_SK_Ay>${card.expireMonth}</KK_SK_Ay>
  <KK_SK_Yil>${card.expireYear}</KK_SK_Yil>
  <KK_CVC>${card.cvc}</KK_CVC>
  <KK_Sahibi_GSM>${buyer.phone}</KK_Sahibi_GSM>
  <Hata_URL></Hata_URL>
  <Basarili_URL></Basarili_URL>
  <Siparis_ID>$orderId</Siparis_ID>
  <Siparis_Aciklama>${_escapeXml(request.orderId)}</Siparis_Aciklama>
  <Taksit>${request.installment}</Taksit>
  <Islem_Tutar>$amount</Islem_Tutar>
  <Toplam_Tutar>$amount</Toplam_Tutar>
  <Islem_Hash>$hash</Islem_Hash>
  <Islem_Guvenlik_Tip>NS</Islem_Guvenlik_Tip>
  <Islem_ID></Islem_ID>
  <IPAdr>${buyer.ip}</IPAdr>
  <Ref_URL></Ref_URL>
  <Data1></Data1>
  <Data2></Data2>
  <Data3></Data3>
  <Data4></Data4>
  <Data5></Data5>
</TP_WMD_Pay>
''';

    return wrapSoapEnvelope(body);
  }

  /// 3DS başlatma isteği oluştur
  static String to3DSInitRequest({
    required PaymentRequest request,
    required String clientCode,
    required String clientUsername,
    required String clientPassword,
    required String guid,
    required String hash,
    required String orderId,
    required String successUrl,
    required String failUrl,
  }) {
    final amount = _formatAmount(request.effectivePaidAmount);
    final card = request.card;
    final buyer = request.buyer;

    final body =
        '''
<TP_WMD_UCD xmlns="https://turkpos.com.tr/">
  <G>
    <CLIENT_CODE>$clientCode</CLIENT_CODE>
    <CLIENT_USERNAME>$clientUsername</CLIENT_USERNAME>
    <CLIENT_PASSWORD>$clientPassword</CLIENT_PASSWORD>
  </G>
  <GUID>$guid</GUID>
  <KK_Sahibi>${_escapeXml(card.cardHolderName)}</KK_Sahibi>
  <KK_No>${card.cardNumber}</KK_No>
  <KK_SK_Ay>${card.expireMonth}</KK_SK_Ay>
  <KK_SK_Yil>${card.expireYear}</KK_SK_Yil>
  <KK_CVC>${card.cvc}</KK_CVC>
  <KK_Sahibi_GSM>${buyer.phone}</KK_Sahibi_GSM>
  <Hata_URL>$failUrl</Hata_URL>
  <Basarili_URL>$successUrl</Basarili_URL>
  <Siparis_ID>$orderId</Siparis_ID>
  <Siparis_Aciklama>${_escapeXml(request.orderId)}</Siparis_Aciklama>
  <Taksit>${request.installment}</Taksit>
  <Islem_Tutar>$amount</Islem_Tutar>
  <Toplam_Tutar>$amount</Toplam_Tutar>
  <Islem_Hash>$hash</Islem_Hash>
  <Islem_Guvenlik_Tip>3D</Islem_Guvenlik_Tip>
  <Islem_ID></Islem_ID>
  <IPAdr>${buyer.ip}</IPAdr>
  <Ref_URL></Ref_URL>
  <Data1></Data1>
  <Data2></Data2>
  <Data3></Data3>
  <Data4></Data4>
  <Data5></Data5>
</TP_WMD_UCD>
''';

    return wrapSoapEnvelope(body);
  }

  /// İade isteği oluştur
  static String toRefundRequest({
    required String transactionId,
    required double amount,
    required String clientCode,
    required String clientUsername,
    required String clientPassword,
    required String guid,
    required String hash,
  }) {
    final body =
        '''
<TP_WMD_Iade xmlns="https://turkpos.com.tr/">
  <G>
    <CLIENT_CODE>$clientCode</CLIENT_CODE>
    <CLIENT_USERNAME>$clientUsername</CLIENT_USERNAME>
    <CLIENT_PASSWORD>$clientPassword</CLIENT_PASSWORD>
  </G>
  <GUID>$guid</GUID>
  <Durum>IADE</Durum>
  <Siparis_ID>$transactionId</Siparis_ID>
  <Tutar>${_formatAmount(amount)}</Tutar>
</TP_WMD_Iade>
''';

    return wrapSoapEnvelope(body);
  }

  /// İşlem sorgulama isteği oluştur
  static String toStatusRequest({
    required String transactionId,
    required String clientCode,
    required String clientUsername,
    required String clientPassword,
    required String guid,
  }) {
    final body =
        '''
<TP_Islem_Sorgulama xmlns="https://turkpos.com.tr/">
  <G>
    <CLIENT_CODE>$clientCode</CLIENT_CODE>
    <CLIENT_USERNAME>$clientUsername</CLIENT_USERNAME>
    <CLIENT_PASSWORD>$clientPassword</CLIENT_PASSWORD>
  </G>
  <GUID>$guid</GUID>
  <Siparis_ID>$transactionId</Siparis_ID>
</TP_Islem_Sorgulama>
''';

    return wrapSoapEnvelope(body);
  }

  /// Taksit oranları sorgulama isteği
  static String toInstallmentRequest({
    required String binNumber,
    required double amount,
    required String clientCode,
    required String clientUsername,
    required String clientPassword,
    required String guid,
  }) {
    final body =
        '''
<TP_Islem_Odeme_WKO xmlns="https://turkpos.com.tr/">
  <G>
    <CLIENT_CODE>$clientCode</CLIENT_CODE>
    <CLIENT_USERNAME>$clientUsername</CLIENT_USERNAME>
    <CLIENT_PASSWORD>$clientPassword</CLIENT_PASSWORD>
  </G>
  <GUID>$guid</GUID>
  <BIN>$binNumber</BIN>
  <Tutar>${_formatAmount(amount)}</Tutar>
</TP_Islem_Odeme_WKO>
''';

    return wrapSoapEnvelope(body);
  }

  // ============================================
  // RESPONSE MAPPERS
  // ============================================

  /// XML response'dan belirli bir element değerini al
  static String? _getElementText(XmlDocument doc, String elementName) {
    try {
      final elements = doc.findAllElements(elementName);
      if (elements.isEmpty) return null;
      return elements.first.innerText;
    } catch (_) {
      return null;
    }
  }

  /// Ödeme response'unu parse et
  static PaymentResult fromPaymentResponse(String xmlResponse) {
    try {
      final doc = XmlDocument.parse(xmlResponse);

      final resultCode =
          _getElementText(doc, 'Sonuc') ??
          _getElementText(doc, 'UCD_HTML') ??
          '';
      final resultMessage =
          _getElementText(doc, 'Sonuc_Str') ?? 'Bilinmeyen sonuc';
      final transactionId =
          _getElementText(doc, 'Dekont_ID') ?? _getElementText(doc, 'Islem_ID');
      final orderId = _getElementText(doc, 'Siparis_ID');

      if (ParamErrorMapper.isSuccess(resultCode)) {
        return PaymentResult.success(
          transactionId: transactionId ?? orderId ?? '',
          amount: _parseAmount(_getElementText(doc, 'Islem_Tutar')),
          paidAmount: _parseAmount(_getElementText(doc, 'Toplam_Tutar')),
          rawResponse: {'xml': xmlResponse},
        );
      } else {
        return PaymentResult.failure(
          errorCode: resultCode,
          errorMessage: resultMessage,
          rawResponse: {'xml': xmlResponse},
        );
      }
    } catch (e) {
      return PaymentResult.failure(
        errorCode: 'parse_error',
        errorMessage: 'XML parse hatasi: $e',
        rawResponse: {'xml': xmlResponse},
      );
    }
  }

  /// 3DS init response'unu parse et
  static ThreeDSInitResult from3DSInitResponse(String xmlResponse) {
    try {
      final doc = XmlDocument.parse(xmlResponse);

      final resultCode = _getElementText(doc, 'Sonuc') ?? '';
      final htmlContent = _getElementText(doc, 'UCD_HTML');
      final transactionId = _getElementText(doc, 'Islem_ID');

      if (htmlContent != null && htmlContent.isNotEmpty) {
        return ThreeDSInitResult.pending(
          htmlContent: htmlContent,
          transactionId: transactionId,
        );
      } else if (ParamErrorMapper.isSuccess(resultCode)) {
        return ThreeDSInitResult.pending(transactionId: transactionId);
      } else {
        final errorMessage =
            _getElementText(doc, 'Sonuc_Str') ?? 'Bilinmeyen hata';
        return ThreeDSInitResult.failed(
          errorCode: resultCode,
          errorMessage: errorMessage,
        );
      }
    } catch (e) {
      return ThreeDSInitResult.failed(
        errorCode: 'parse_error',
        errorMessage: 'XML parse hatasi: $e',
      );
    }
  }

  /// İade response'unu parse et
  static RefundResult fromRefundResponse(String xmlResponse) {
    try {
      final doc = XmlDocument.parse(xmlResponse);

      final resultCode = _getElementText(doc, 'Sonuc') ?? '';
      final resultMessage =
          _getElementText(doc, 'Sonuc_Str') ?? 'Bilinmeyen sonuc';

      if (ParamErrorMapper.isSuccess(resultCode)) {
        final refundId =
            _getElementText(doc, 'Dekont_ID') ??
            _getElementText(doc, 'Islem_ID');
        return RefundResult.success(
          refundId: refundId ?? '',
          refundedAmount: _parseAmount(_getElementText(doc, 'Tutar')),
        );
      } else {
        return RefundResult.failure(
          errorCode: resultCode,
          errorMessage: resultMessage,
        );
      }
    } catch (e) {
      return RefundResult.failure(
        errorCode: 'parse_error',
        errorMessage: 'XML parse hatasi: $e',
      );
    }
  }

  /// İşlem durumu response'unu parse et
  static PaymentStatus fromStatusResponse(String xmlResponse) {
    try {
      final doc = XmlDocument.parse(xmlResponse);

      final status = _getElementText(doc, 'Islem_Durum') ?? '';

      switch (status.toUpperCase()) {
        case 'BASARILI':
        case 'SUCCESS':
        case '1':
          return PaymentStatus.success;
        case 'BASARISIZ':
        case 'FAILED':
        case '0':
          return PaymentStatus.failed;
        case 'BEKLEMEDE':
        case 'PENDING':
          return PaymentStatus.pending;
        case 'IADE':
        case 'REFUNDED':
          return PaymentStatus.refunded;
        default:
          return PaymentStatus.pending;
      }
    } catch (_) {
      return PaymentStatus.failed;
    }
  }

  /// Taksit response'unu parse et
  static InstallmentInfo? fromInstallmentResponse({
    required String xmlResponse,
    required String binNumber,
    required double amount,
  }) {
    try {
      final doc = XmlDocument.parse(xmlResponse);

      final resultCode = _getElementText(doc, 'Sonuc') ?? '';

      if (!ParamErrorMapper.isSuccess(resultCode)) {
        return null;
      }

      final options = <InstallmentOption>[];

      // Taksit seçeneklerini bul
      final installmentElements = doc.findAllElements('Taksit_Sayisi');
      final priceElements = doc.findAllElements('Taksit_Tutar');
      final totalElements = doc.findAllElements('Toplam_Tutar');

      final count = installmentElements.length;
      for (var i = 0; i < count; i++) {
        final installmentNumber =
            int.tryParse(installmentElements.elementAt(i).innerText) ?? 1;
        final installmentPrice = i < priceElements.length
            ? _parseAmount(priceElements.elementAt(i).innerText)
            : amount / installmentNumber;
        final totalPrice = i < totalElements.length
            ? _parseAmount(totalElements.elementAt(i).innerText)
            : amount;

        options.add(
          InstallmentOption(
            installmentNumber: installmentNumber,
            installmentPrice: installmentPrice,
            totalPrice: totalPrice,
          ),
        );
      }

      // Eğer taksit seçeneği yoksa varsayılan olarak tek çekim ekle
      if (options.isEmpty) {
        options.add(
          InstallmentOption(
            installmentNumber: 1,
            installmentPrice: amount,
            totalPrice: amount,
          ),
        );
      }

      final bankName = _getElementText(doc, 'Banka_Adi');
      final cardFamily = _getElementText(doc, 'Kart_Ailesi');

      return InstallmentInfo(
        binNumber: binNumber,
        price: amount,
        cardType:
            ParamErrorMapper.parseCardType(_getElementText(doc, 'Kart_Tip')) ??
            CardType.creditCard,
        cardAssociation:
            ParamErrorMapper.parseCardAssociation(
              _getElementText(doc, 'Kart_Marka'),
            ) ??
            CardAssociation.visa,
        cardFamily: cardFamily ?? '',
        bankName: bankName ?? '',
        bankCode: int.tryParse(_getElementText(doc, 'Banka_Kodu') ?? '') ?? 0,
        force3DS: _getElementText(doc, 'Force3DS') == '1',
        forceCVC: true,
        options: options,
      );
    } catch (_) {
      return null;
    }
  }

  // ============================================
  // HELPERS
  // ============================================

  /// Tutarı Param formatına çevir (kuruş, nokta ile)
  static String _formatAmount(double amount) {
    // Param kuruş cinsinden ve 2 ondalık ile alır: 100.50 TL -> "10050"
    return (amount * 100).round().toString();
  }

  /// String tutarı double'a çevir
  static double _parseAmount(String? value) {
    if (value == null || value.isEmpty) return 0;
    // Kuruştan TL'ye çevir
    final cents = double.tryParse(value.replaceAll(',', '.')) ?? 0;
    return cents / 100;
  }

  /// XML için özel karakterleri escape et
  static String _escapeXml(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

/// Kayıtlı kart için ek mapper (Param kayıtlı kart desteklemez)
extension ParamSavedCardMapper on ParamMapper {
  /// Param kayıtlı kart özelliğini desteklemez.
  /// Bu uzantı sadece uyumluluk için eklendi.
}
