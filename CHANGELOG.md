# Changelog

## 1.0.0

- Initial release
- iyzico payment provider integration
  - Non-3DS and 3D Secure payment support
  - Installment query by BIN number
  - Refund operations
  - Payment status query
- PayTR payment provider integration
  - iFrame token based payments
  - 3D Secure payment flow
  - Callback hash verification
  - Refund support
- Core features
  - Unified `PaymentProvider` interface
  - `PaymentRequest`, `PaymentResult`, `RefundRequest` models
  - `CardInfo` with Luhn validation and masking
  - `BuyerInfo`, `BasketItem`, `AddressInfo` models
  - `PaymentException` with standardized error codes
  - `LogSanitizer` for secure logging
- Testing utilities
  - `MockPaymentProvider` for unit testing
  - Configurable success/failure scenarios
  - Custom delay support
