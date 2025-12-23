/// PayTR API endpoint sabitleri
class PayTREndpoints {
  PayTREndpoints._();

  static const String baseUrl = 'https://www.paytr.com';
  static const String directPayment = '/odeme';
  static const String iframeToken = '/odeme/api/get-token';
  static const String installmentRates = '/odeme/taksit-oranlari';
  static const String binLookup = '/odeme/api/bin-detail';
  static const String refund = '/odeme/iade';
  static const String statusQuery = '/odeme/durum-sorgu';
}
