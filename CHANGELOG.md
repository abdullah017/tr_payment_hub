# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.4] - 2026-01-01

### Added
- **Param POS Provider** - Full SOAP/XML integration
  - Non-3DS and 3D Secure payment support
  - Installment query by BIN number
  - Refund operations
  - Payment status query
- **Sipay Provider** - Full REST/JSON integration
  - Bearer token authentication
  - Non-3DS and 3D Secure payment support
  - Saved card (tokenization) support
  - Installment query
  - Refund operations
- **HTTP Mocking Infrastructure** for testing without real API credentials
  - `PaymentMockClient` factory class with provider-specific mock clients
  - Constructor injection for all providers (`httpClient` parameter)
  - Realistic mock responses for all endpoints
- **Test Fixtures** - JSON/XML response files for all providers
  - `test/fixtures/iyzico/` - 5 fixture files
  - `test/fixtures/paytr/` - 4 fixture files
  - `test/fixtures/param/` - 4 XML fixture files
  - `test/fixtures/sipay/` - 6 fixture files
  - `TestFixtures` helper class for loading fixtures
- **GitHub Actions CI/CD** pipeline
  - Automated testing on push/PR
  - Code formatting check
  - Static analysis
  - SDK compatibility tests (3.0.0, stable, beta)
  - pub.dev score check

### Changed
- Updated README.md with new providers, test cards, and sandbox URLs
- All providers now support dependency injection for testing
- Documentation now includes testing instructions
- **SDK constraint** relaxed from `^3.10.4` to `>=3.0.0 <4.0.0` for wider compatibility
- Removed deprecated lint rules (`package_api_docs`, `avoid_returning_null_for_future`)

### Fixed
- Provider table now correctly shows Param and Sipay as stable
- CI/CD SDK compatibility issue resolved

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

[Unreleased]: https://github.com/abdullah017/tr_payment_hub/compare/v1.0.4...HEAD
[1.0.4]: https://github.com/abdullah017/tr_payment_hub/compare/v1.0.3...v1.0.4
[1.0.3]: https://github.com/abdullah017/tr_payment_hub/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/abdullah017/tr_payment_hub/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/abdullah017/tr_payment_hub/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/abdullah017/tr_payment_hub/releases/tag/v1.0.0
