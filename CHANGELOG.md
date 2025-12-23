# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.3] - 2025-12-24

### Added
- Comprehensive dartdoc documentation for all public APIs
- `toJson()` and `fromJson()` methods for all model classes
- `copyWith()` methods for immutable model updates
- `equals` and `hashCode` overrides for value equality
- `toString()` overrides for better debugging
- English README.md with full API documentation
- Turkish README_TR.md for local users
- Enhanced lint rules in analysis_options.yaml
- **Flutter example app** with realistic payment flow:
  - Payment form with card input
  - 3D Secure WebView integration
  - Callback URL interception
  - Result screen

### Changed
- Updated pubspec.yaml description to meet pub.dev guidelines
- Improved code documentation coverage
- Exports are now alphabetically sorted

## [1.0.2] - 2025-12-20

### Changed
- **BREAKING**: Enum naming to follow Dart lowerCamelCase conventions
  - `Currency.TRY` -> `Currency.tryLira`
  - `Currency.USD` -> `Currency.usd`
  - `Currency.EUR` -> `Currency.eur`
  - `Currency.GBP` -> `Currency.gbp`

### Migration Guide

```dart
// Before (1.0.1)
currency: Currency.TRY

// After (1.0.2)
currency: Currency.tryLira
```

## [1.0.1] - 2025-12-18

### Fixed
- Repository URLs in pubspec.yaml
- Homepage and issue tracker links

## [1.0.0] - 2025-12-15

### Added
- Initial release
- **iyzico** payment provider integration
  - Non-3DS and 3D Secure payment support
  - Installment query by BIN number
  - Refund operations
  - Payment status query
- **PayTR** payment provider integration
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

[Unreleased]: https://github.com/abdullah017/tr_payment_hub/compare/v1.0.2...HEAD
[1.0.2]: https://github.com/abdullah017/tr_payment_hub/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/abdullah017/tr_payment_hub/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/abdullah017/tr_payment_hub/releases/tag/v1.0.0
