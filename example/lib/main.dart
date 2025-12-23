import 'package:flutter/material.dart';
import 'package:tr_payment_hub/tr_payment_hub.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TR Payment Hub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const PaymentFormScreen(),
    );
  }
}

/// Step 1: Payment Form - User enters card details
class PaymentFormScreen extends StatefulWidget {
  const PaymentFormScreen({super.key});

  @override
  State<PaymentFormScreen> createState() => _PaymentFormScreenState();
}

class _PaymentFormScreenState extends State<PaymentFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers with test card data
  final _cardNumber = TextEditingController(text: '5528790000000008');
  final _expiry = TextEditingController(text: '12/30');
  final _cvv = TextEditingController(text: '123');
  final _amount = TextEditingController(text: '100');
  final _name = TextEditingController(text: 'John Doe');

  String _provider = 'mock';
  bool _use3DS = true;
  bool _isLoading = false;

  PaymentProvider? _paymentProvider;

  @override
  void dispose() {
    _cardNumber.dispose();
    _expiry.dispose();
    _cvv.dispose();
    _amount.dispose();
    _name.dispose();
    _paymentProvider?.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1. Create provider
      _paymentProvider?.dispose();
      _paymentProvider = TrPaymentHub.createMock(shouldSucceed: true);

      // 2. Initialize with config
      await _paymentProvider!.initialize(
        IyzicoConfig(
          merchantId: 'sandbox_merchant',
          apiKey: 'sandbox_api_key',
          secretKey: 'sandbox_secret',
          isSandbox: true,
        ),
      );

      // 3. Build payment request
      final request = _buildRequest();

      if (_use3DS) {
        // 3DS Flow: Get HTML → Show WebView → Complete
        await _process3DSPayment(request);
      } else {
        // Non-3DS: Direct payment
        await _processDirectPayment(request);
      }
    } on PaymentException catch (e) {
      _showError(e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  PaymentRequest _buildRequest() {
    final expiryParts = _expiry.text.split('/');
    return PaymentRequest(
      orderId: 'ORDER_${DateTime.now().millisecondsSinceEpoch}',
      amount: double.parse(_amount.text),
      currency: Currency.tryLira,
      installment: 1,
      callbackUrl: 'https://myapp.com/payment/callback',
      card: CardInfo(
        cardHolderName: _name.text,
        cardNumber: _cardNumber.text.replaceAll(' ', ''),
        expireMonth: expiryParts[0],
        expireYear: '20${expiryParts[1]}',
        cvc: _cvv.text,
      ),
      buyer: BuyerInfo(
        id: 'BUYER_1',
        name: _name.text.split(' ').first,
        surname: _name.text.split(' ').last,
        email: 'customer@example.com',
        phone: '+905551234567',
        ip: '127.0.0.1',
        city: 'Istanbul',
        country: 'Turkey',
        address: 'Test Address',
      ),
      basketItems: [
        BasketItem(
          id: 'ITEM_1',
          name: 'Product',
          category: 'General',
          price: double.parse(_amount.text),
          itemType: ItemType.physical,
        ),
      ],
    );
  }

  Future<void> _processDirectPayment(PaymentRequest request) async {
    final result = await _paymentProvider!.createPayment(request);
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ResultScreen(result: result)),
      );
    }
  }

  Future<void> _process3DSPayment(PaymentRequest request) async {
    // Step 1: Initialize 3DS - provider returns HTML
    final threeDSResult = await _paymentProvider!.init3DSPayment(request);

    if (!mounted) return;

    if (threeDSResult.htmlContent != null ||
        threeDSResult.redirectUrl != null) {
      // Step 2: Show WebView for user verification
      final callbackData = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (_) => ThreeDSWebViewScreen(
            htmlContent: threeDSResult.htmlContent,
            redirectUrl: threeDSResult.redirectUrl,
            callbackUrl: request.callbackUrl!,
          ),
        ),
      );

      if (callbackData != null && mounted) {
        // Step 3: Complete payment with callback data
        final result = await _paymentProvider!.complete3DSPayment(
          threeDSResult.transactionId!,
          callbackData: callbackData,
        );

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ResultScreen(result: result)),
          );
        }
      }
    }
  }

  void _showError(PaymentException e) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Payment Error'),
        content: Text('${e.code}: ${e.message}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Provider Selection
            DropdownButtonFormField<String>(
              value: _provider,
              decoration: const InputDecoration(
                labelText: 'Provider',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'mock', child: Text('Mock (Demo)')),
                DropdownMenuItem(value: 'iyzico', child: Text('iyzico')),
                DropdownMenuItem(value: 'paytr', child: Text('PayTR')),
              ],
              onChanged: (v) => setState(() => _provider = v!),
            ),
            const SizedBox(height: 16),

            // Card Holder Name
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Card Holder Name',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Card Number
            TextFormField(
              controller: _cardNumber,
              decoration: const InputDecoration(
                labelText: 'Card Number',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (v) => v!.length < 16 ? 'Invalid card' : null,
            ),
            const SizedBox(height: 16),

            // Expiry & CVV
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _expiry,
                    decoration: const InputDecoration(
                      labelText: 'MM/YY',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v!.length < 5 ? 'Invalid' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _cvv,
                    decoration: const InputDecoration(
                      labelText: 'CVV',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: (v) => v!.length < 3 ? 'Invalid' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Amount
            TextFormField(
              controller: _amount,
              decoration: const InputDecoration(
                labelText: 'Amount (TL)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (v) => double.tryParse(v!) == null ? 'Invalid' : null,
            ),
            const SizedBox(height: 16),

            // 3DS Toggle
            SwitchListTile(
              title: const Text('Use 3D Secure'),
              subtitle: Text(
                _use3DS ? 'Bank verification required' : 'Direct payment',
              ),
              value: _use3DS,
              onChanged: (v) => setState(() => _use3DS = v),
            ),
            const SizedBox(height: 24),

            // Pay Button
            FilledButton(
              onPressed: _isLoading ? null : _pay,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('Pay ${_amount.text} TL'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Step 2: 3DS WebView - Shows bank verification page
class ThreeDSWebViewScreen extends StatefulWidget {
  final String? htmlContent;
  final String? redirectUrl;
  final String callbackUrl;

  const ThreeDSWebViewScreen({
    super.key,
    this.htmlContent,
    this.redirectUrl,
    required this.callbackUrl,
  });

  @override
  State<ThreeDSWebViewScreen> createState() => _ThreeDSWebViewScreenState();
}

class _ThreeDSWebViewScreenState extends State<ThreeDSWebViewScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            // Intercept callback URL
            if (request.url.startsWith(widget.callbackUrl)) {
              final uri = Uri.parse(request.url);
              Navigator.pop(context, uri.queryParameters);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );

    // Load HTML content or redirect URL
    if (widget.htmlContent != null) {
      _controller.loadHtmlString(widget.htmlContent!);
    } else if (widget.redirectUrl != null) {
      _controller.loadRequest(Uri.parse(widget.redirectUrl!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('3D Secure Verification'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}

/// Step 3: Result Screen - Shows payment result
class ResultScreen extends StatelessWidget {
  final PaymentResult result;

  const ResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Result')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                result.isSuccess ? Icons.check_circle : Icons.error,
                size: 80,
                color: result.isSuccess ? Colors.green : Colors.red,
              ),
              const SizedBox(height: 24),
              Text(
                result.isSuccess ? 'Payment Successful!' : 'Payment Failed',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 32),
              _info('Transaction ID', result.transactionId ?? '-'),
              _info('Amount', '${result.amount?.toStringAsFixed(2) ?? '-'} TL'),
              if (result.errorMessage != null)
                _info('Error', result.errorMessage!),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }
}
