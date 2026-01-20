import 'package:flutter/material.dart';

import 'app.dart';

/// Entry point for the TR Payment Hub Example Application.
///
/// This example app demonstrates all features of the tr_payment_hub package:
///
/// **Core Features:**
/// - Payment processing with multiple providers (iyzico, PayTR, Sipay, Param)
/// - 3D Secure verification via WebView
/// - Installment queries by card BIN
/// - Saved/tokenized card management
/// - Refund processing (full and partial)
/// - Transaction status queries
///
/// **Developer Tools:**
/// - HTTP request/response logging
/// - Payment metrics collection
/// - Transaction history tracking
///
/// **Provider Configuration:**
/// - Sandbox/Production mode toggle
/// - API credential management
/// - Real-time provider switching
///
/// To run the example:
/// ```bash
/// cd example
/// flutter run
/// ```
///
/// Test Cards (Sandbox Mode):
/// - Success: 5528790000000008, CVV: 123, Expiry: 12/30
/// - Failure: 4543590000000006, CVV: 123, Expiry: 12/30
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TRPaymentHubExampleApp());
}
