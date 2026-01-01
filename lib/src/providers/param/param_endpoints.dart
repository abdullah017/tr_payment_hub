/// Param POS API endpoint sabitleri
///
/// Param SOAP/XML tabanlı bir API kullanır.
/// Tüm istekler TurkPos servisine gönderilir.
class ParamEndpoints {
  ParamEndpoints._();

  /// SOAP API servis yolu
  static const String servicePath = '/turkpos.ws/service_turkpos_prod.asmx';

  /// SOAP Action header'ları
  static const String soapAction =
      'https://turkpos.com.tr/TP_Odeme_WS/TP_WMD_Pay';

  /// Ödeme işlemi
  static const String soapActionPayment =
      'https://turkpos.com.tr/TP_Odeme_WS/TP_WMD_Pay';

  /// 3DS başlatma
  static const String soapAction3DSInit =
      'https://turkpos.com.tr/TP_Odeme_WS/TP_WMD_UCD';

  /// 3DS tamamlama
  static const String soapAction3DSComplete =
      'https://turkpos.com.tr/TP_Odeme_WS/TP_WMD_Pay';

  /// İade
  static const String soapActionRefund =
      'https://turkpos.com.tr/TP_Odeme_WS/TP_WMD_Iade';

  /// Taksit sorgulama
  static const String soapActionInstallment =
      'https://turkpos.com.tr/TP_Odeme_WS/TP_Islem_Odeme_WKO';

  /// İşlem sorgulama
  static const String soapActionStatus =
      'https://turkpos.com.tr/TP_Odeme_WS/TP_Islem_Sorgulama';
}
