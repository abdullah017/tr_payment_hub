/// iyzico API endpoint sabitleri
class IyzicoEndpoints {
  IyzicoEndpoints._();

  // Base URLs
  static const String productionBaseUrl = 'https://api.iyzipay.com';
  static const String sandboxBaseUrl = 'https://sandbox-api.iyzipay.com';

  // Payment endpoints
  static const String createPayment = '/payment/auth';
  static const String paymentDetail = '/payment/detail';

  // 3DS endpoints
  static const String init3DS = '/payment/3dsecure/initialize';
  static const String complete3DS = '/payment/3dsecure/auth';

  // Installment & BIN
  static const String installmentInfo = '/payment/iyzipos/installment';
  static const String binCheck = '/payment/bin/check';

  // Refund & Cancel
  static const String refund = '/payment/refund';
  static const String cancel = '/payment/cancel';

  // Checkout Form (alternatif yöntem)
  static const String checkoutFormInit =
      '/payment/iyzipos/checkoutform/initialize/auth/ecom';
  static const String checkoutFormRetrieve =
      '/payment/iyzipos/checkoutform/auth/ecom/detail';
}
