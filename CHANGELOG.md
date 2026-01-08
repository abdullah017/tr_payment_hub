# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [3.0.0] - 2026-01-08

### Added
- **Proxy Mode** - New architecture for Flutter + Custom Backend integration
  - `ProxyPaymentProvider` - HTTP client that forwards requests to your backend
  - `ProxyConfig` - Configuration class for proxy settings (baseUrl, authToken, headers, timeout, retries)
  - `TrPaymentHub.createProxy()` - Factory method for creating proxy providers
  - API credentials stay secure on your backend (Node.js, Python, Go, PHP, etc.)
  - Built-in retry logic with exponential backoff
  - Configurable timeout and max retries

- **Client-Side Validation** - Validate payment data before sending to backend
  - `CardValidator` - Independent card validation utilities
    - `isValidCardNumber()` - Luhn algorithm validation
    - `isValidExpiry()` - Expiry date validation
    - `isValidCVV()` - CVV format validation (3 or 4 digits for Amex)
    - `isValidHolderName()` - Cardholder name validation
    - `detectCardBrand()` - Detect Visa, Mastercard, Amex, Troy
    - `formatCardNumber()` - Add spaces for display
    - `maskCardNumber()` - Show BIN + last 4 digits
    - `extractBin()` - Extract BIN from card number
    - `validate()` - Full validation returning `CardValidationResult`
  - `RequestValidator` - Payment request validation
    - `validate()` - Full request validation returning `RequestValidationResult`
    - `validateBuyer()` - Buyer info validation (email, phone, IP)
  - `CardBrand` enum - visa, mastercard, amex, troy, unknown
  - `CardValidationResult` - Validation result with errors and card brand
  - `RequestValidationResult` - Validation result with field-specific errors

- **Client-Only Export** - `tr_payment_hub_client.dart`
  - Exports only client-safe components (no provider credentials)
  - Includes: models, enums, validators, proxy provider, testing utilities
  - Ideal for Flutter apps that use Proxy Mode

- **JSON Serialization** - Added toJson/fromJson to remaining models
  - `PaymentRequest.toJson()` / `PaymentRequest.fromJson()`
  - `PaymentResult.toJson()` / `PaymentResult.fromJson()`
  - `RefundResult.toJson()` / `RefundResult.fromJson()`
  - `ThreeDSInitResult.toJson()` / `ThreeDSInitResult.fromJson()`
  - `PaymentException.toJson()` / `PaymentException.fromJson()`

- **Backend Examples** - Reference implementations
  - Node.js Express example (`backend-examples/nodejs-express/`)
  - Python FastAPI example (`backend-examples/python-fastapi/`)

### Changed
- Version bumped to 3.0.0 (major version for new feature set)
- README updated with Usage Modes section (Proxy vs Direct)
- Main export file now includes client module exports

### Documentation
- Added comprehensive Proxy Mode documentation in README
- Added Client-Side Validation examples
- Created MIGRATION.md for v2.x → v3.0 upgrade guide
- Backend API contract documentation

### No Breaking Changes
- All existing v2.x code continues to work unchanged
- Proxy Mode is additive - Direct Mode remains fully supported
- Existing tests pass without modification

## [2.0.1] - 2026-01-08

### Added
- **PaymentUtils** - Shared utility class eliminating code duplication across providers
  - `currencyToIso()` - ISO 4217 currency mapping
  - `currencyToProviderCode()` - Provider-specific currency codes (TL vs TRY)
  - `amountToCents()` / `amountToCentsString()` - Amount formatting
  - `parseAmount()` - Safe amount parsing with comma/dot handling
  - `generateSecureHex()` - Cryptographically secure random hex generation
  - `generateOrderId()` / `generateConversationId()` - Unique ID generation
  - `generateDefaultInstallmentOptions()` / `generateDefaultInstallmentInfo()` - Fallback installment data
  - `isValidBin()` / `extractBin()` - BIN number validation utilities
- **PaymentConfigProductionValidation** extension - Production environment safety checks
  - `validateForProduction()` - Returns list of potential issues
  - `assertProduction()` - Throws if sandbox mode in production
- **PaymentException.sanitizedProviderMessage** - Filtered error messages (removes SQL, paths, stack traces)
- **BuyerInfo IPv6 support** - Now validates both IPv4 and IPv6 addresses

### Changed
- **Network timeout reduced** - 30s → 15s (security hardening against resource exhaustion)
- **All providers now use PaymentUtils** - Reduced ~120 lines of duplicate code
  - `PayTRProvider` - Uses PaymentUtils for ID generation, amount formatting, currency mapping
  - `SipayProvider` - Uses PaymentUtils for currency mapping, installment defaults
  - `ParamProvider` - Uses PaymentUtils for ID generation, amount formatting, installment defaults
- **LogSanitizer card pattern improved** - Now correctly masks 13-19 digit card numbers (was 14-20)

### Security
- **CardInfo.toJson() @Deprecated warning** - Warns developers about PAN/CVV exposure risk
- **Param SHA1 security documentation** - Added warning about SHA1 being cryptographically weak (Param API requirement)
- **Provider message sanitization** - Filters potentially sensitive data from error messages

### Documentation
- Added comprehensive dartdoc to PaymentUtils class
- Updated provider classes with PaymentUtils usage examples

## [2.0.0] - 2026-01-08

### Breaking Changes
- **Validation is now mandatory** - All model classes (`CardInfo`, `BuyerInfo`, `PaymentRequest`, `RefundRequest`) now have `validate()` methods that throw `ValidationException` for invalid input
- **CardInfo.toJson() is now @internal** - Use `toSafeJson()` for logging which masks sensitive data (CVV, card number)
- **Config classes updated** - New optional parameters: `connectionTimeout` and `enableRetry`
- **New exception types** - `ValidationException` and `CircuitBreakerOpenException` added

### Added
- **ValidationException** - Comprehensive input validation with detailed error messages
  - `errors` list for multiple validation errors
  - `field` property to identify the invalid field
  - `allErrors` getter for combined error message
- **RetryHandler** - Exponential backoff retry mechanism
  - `RetryConfig.noRetry` - Single attempt only
  - `RetryConfig.conservative` - Safe retry for payment operations
  - `RetryConfig.aggressive` - Fast retry for read operations
  - Jitter support to prevent thundering herd
  - Custom retry predicates
- **CircuitBreaker** - Fault tolerance pattern implementation
  - Three states: `closed`, `open`, `halfOpen`
  - Automatic state transitions
  - `CircuitBreakerManager` for managing multiple breakers
  - `CircuitBreakerOpenException` with remaining time info
- **PaymentLogger** - Secure logging with automatic sanitization
  - Multiple log levels (debug, info, warning, error)
  - Automatic sensitive data masking
  - Payment-specific logging methods
- **CardInfo.isExpired** - Check if card has expired
- **CardInfo.toSafeJson()** - Safe JSON representation with masked CVV and card number
- **BuyerInfo validation** - Turkish phone format, TC Kimlik validation, email regex
- **PaymentRequest validation** - Amount, installment range, basket total verification, 3DS callback URL check
- **RefundRequest validation** - Transaction ID and amount validation
- **Secure random generation** - All providers now use `Random.secure()` for order IDs

### Changed
- All provider files (`IyzicoProvider`, `PayTRProvider`, `ParamProvider`, `SipayProvider`) now use secure random for ID generation
- Config classes now include `connectionTimeout` (default: 30s) and `enableRetry` (default: true)
- **LogSanitizer enhanced** - Now masks additional sensitive data patterns:
  - `api_key`, `apiKey` values
  - `secret_key`, `secretKey` values
  - `token` values
  - `password` values
  - CVV/CVC in various formats (lowercase, uppercase, JSON strings)

### Security
- Replaced weak `Random()` with `Random.secure()` in all providers
- CVV is now never exposed in logs or JSON output
- Card numbers are automatically masked in logging
- API keys, secrets, tokens, and passwords are automatically masked in logs

### Documentation
- Added `MIGRATION.md` for upgrading from v1.x to v2.0.0
- Updated README with security best practices

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

[Unreleased]: https://github.com/abdullah017/tr_payment_hub/compare/v3.0.0...HEAD
[3.0.0]: https://github.com/abdullah017/tr_payment_hub/compare/v2.0.1...v3.0.0
[2.0.1]: https://github.com/abdullah017/tr_payment_hub/compare/v2.0.0...v2.0.1
[2.0.0]: https://github.com/abdullah017/tr_payment_hub/compare/v1.0.4...v2.0.0
[1.0.4]: https://github.com/abdullah017/tr_payment_hub/compare/v1.0.3...v1.0.4
[1.0.3]: https://github.com/abdullah017/tr_payment_hub/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/abdullah017/tr_payment_hub/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/abdullah017/tr_payment_hub/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/abdullah017/tr_payment_hub/releases/tag/v1.0.0
