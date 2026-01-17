import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tr_payment_hub/tr_payment_hub.dart';

import '../../core/providers/app_state.dart';
import '../../widgets/card_input_field.dart';
import '../../widgets/info_card.dart';
import 'payment_result_screen.dart';

/// Payment screen for processing card payments.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _formKey = GlobalKey<FormState>();

  // Card controllers
  final _nameController = TextEditingController(text: 'JOHN DOE');
  final _cardNumberController =
      TextEditingController(text: '5528 7900 0000 0008');
  final _expiryController = TextEditingController(text: '12/30');
  final _cvvController = TextEditingController(text: '123');

  // Payment details
  final _amountController = TextEditingController(text: '100.00');
  final _emailController = TextEditingController(text: 'customer@example.com');

  bool _use3DS = true;
  bool _saveCard = false;
  int _installment = 1;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _use3DS = state.use3DS;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _amountController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Make Payment'),
      ),
      body: Consumer<AppState>(
        builder: (context, state, _) {
          if (!state.isProviderInitialized) {
            return Center(
              child: InfoCard.warning(
                title: 'Provider Not Configured',
                message: 'Please configure a payment provider in Settings.',
                action: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go to Settings'),
                ),
              ),
            );
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Provider Info
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.payment),
                        const SizedBox(width: 8),
                        Text(
                            'Provider: ${state.currentProvider.toUpperCase()}'),
                        const Spacer(),
                        Chip(
                          label:
                              Text(state.useSandbox ? 'Sandbox' : 'Production'),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Card Details Section
                Text(
                  'Card Details',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),

                CardInputSection(
                  nameController: _nameController,
                  cardNumberController: _cardNumberController,
                  expiryController: _expiryController,
                  cvvController: _cvvController,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 24),

                // Payment Details Section
                Text(
                  'Payment Details',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _amountController,
                  enabled: !_isLoading,
                  decoration: const InputDecoration(
                    labelText: 'Amount (TL)',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final amount = double.tryParse(v ?? '');
                    if (amount == null || amount <= 0)
                      return 'Enter valid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _emailController,
                  enabled: !_isLoading,
                  decoration: const InputDecoration(
                    labelText: 'Customer Email',
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      v?.contains('@') != true ? 'Enter valid email' : null,
                ),
                const SizedBox(height: 16),

                // Installment Selection
                DropdownButtonFormField<int>(
                  value: _installment,
                  decoration: const InputDecoration(
                    labelText: 'Installments',
                    prefixIcon: Icon(Icons.format_list_numbered),
                  ),
                  items: List.generate(12, (i) => i + 1)
                      .map((n) => DropdownMenuItem(
                            value: n,
                            child: Text(
                                n == 1 ? 'Single Payment' : '$n Installments'),
                          ))
                      .toList(),
                  onChanged: _isLoading
                      ? null
                      : (v) => setState(() => _installment = v!),
                ),
                const SizedBox(height: 24),

                // Options Section
                Text(
                  'Options',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),

                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('3D Secure'),
                        subtitle: Text(
                          _use3DS
                              ? 'Bank verification required'
                              : 'Direct payment (if supported)',
                        ),
                        value: _use3DS,
                        onChanged: _isLoading
                            ? null
                            : (v) => setState(() => _use3DS = v),
                      ),
                      if (state.paymentService.supportsSavedCards) ...[
                        const Divider(height: 1),
                        SwitchListTile(
                          title: const Text('Save Card'),
                          subtitle: const Text('Save for future payments'),
                          value: _saveCard,
                          onChanged: _isLoading
                              ? null
                              : (v) => setState(() => _saveCard = v),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Pay Button
                FilledButton(
                  onPressed: _isLoading ? null : () => _processPayment(state),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            'Pay ${_amountController.text} TL',
                            style: const TextStyle(fontSize: 18),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // Test Cards Info
                InfoCard.info(
                  title: 'Test Cards',
                  message: 'Success: 5528790000000008\n'
                      'Fail: 4543590000000006',
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _processPayment(AppState state) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final provider = state.paymentService.provider!;
      final request = _buildPaymentRequest();

      PaymentResult result;

      if (_use3DS) {
        result = await _process3DSPayment(provider, request);
      } else {
        result = await provider.createPayment(request);
      }

      // Save to transaction history
      state.addTransaction({
        'orderId': request.orderId,
        'amount': request.amount,
        'provider': state.currentProvider,
        'isSuccess': result.isSuccess,
        'transactionId': result.transactionId,
        'errorMessage': result.errorMessage,
      });

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentResultScreen(result: result),
          ),
        );
      }
    } on PaymentException catch (e) {
      _showError('${e.code}: ${e.message}');
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  PaymentRequest _buildPaymentRequest() {
    final expiryParts = _expiryController.text.split('/');
    final expireYear =
        expiryParts[1].length == 2 ? '20${expiryParts[1]}' : expiryParts[1];

    return PaymentRequest(
      orderId: 'ORDER_${DateTime.now().millisecondsSinceEpoch}',
      amount: double.parse(_amountController.text),
      currency: Currency.tryLira,
      installment: _installment,
      callbackUrl: 'https://example.com/payment/callback',
      card: CardInfo(
        cardHolderName: _nameController.text.toUpperCase(),
        cardNumber: _cardNumberController.text.replaceAll(' ', ''),
        expireMonth: expiryParts[0],
        expireYear: expireYear,
        cvc: _cvvController.text,
        saveCard: _saveCard,
      ),
      buyer: BuyerInfo(
        id: 'BUYER_${DateTime.now().millisecondsSinceEpoch}',
        name: _nameController.text.split(' ').first,
        surname: _nameController.text.split(' ').last,
        email: _emailController.text,
        phone: '+905551234567',
        ip: '127.0.0.1',
        city: 'Istanbul',
        country: 'Turkey',
        address: 'Test Address No:1',
        identityNumber: '11111111111',
      ),
      shippingAddress: const AddressInfo(
        contactName: 'John Doe',
        city: 'Istanbul',
        country: 'Turkey',
        address: 'Test Address No:1',
      ),
      billingAddress: const AddressInfo(
        contactName: 'John Doe',
        city: 'Istanbul',
        country: 'Turkey',
        address: 'Test Address No:1',
      ),
      basketItems: [
        BasketItem(
          id: 'ITEM_1',
          name: 'Test Product',
          category: 'General',
          price: double.parse(_amountController.text),
          itemType: ItemType.physical,
        ),
      ],
    );
  }

  Future<PaymentResult> _process3DSPayment(
    PaymentProvider provider,
    PaymentRequest request,
  ) async {
    // Initialize 3DS
    final threeDSResult = await provider.init3DSPayment(request);

    if (!mounted) throw Exception('Widget disposed');

    // Check if WebView is needed
    if (threeDSResult.htmlContent == null &&
        threeDSResult.redirectUrl == null) {
      // 3DS not required, direct result
      if (threeDSResult.status == ThreeDSStatus.completed) {
        return PaymentResult(
          isSuccess: true,
          transactionId: threeDSResult.transactionId,
          amount: request.amount,
        );
      }
      throw PaymentException(
        code: '3DS_FAILED',
        message: threeDSResult.errorMessage ?? 'Unknown error',
      );
    }

    // Show WebView
    final webViewResult = await PaymentWebView.show(
      context: context,
      threeDSResult: threeDSResult,
      callbackUrl: request.callbackUrl!,
      theme: PaymentWebViewTheme(
        appBarTitle: '3D Secure Verification',
        loadingText: 'Loading bank page...',
        progressColor: Theme.of(context).colorScheme.primary,
        appBarColor: Theme.of(context).colorScheme.primary,
      ),
      timeout: const Duration(minutes: 5),
    );

    if (!mounted) throw Exception('Widget disposed');

    // Handle WebView result
    if (webViewResult.isCancelled) {
      throw PaymentException(
        code: 'CANCELLED',
        message: 'Payment cancelled by user',
      );
    }

    if (webViewResult.isTimeout) {
      throw PaymentException(
        code: 'TIMEOUT',
        message: '3D Secure verification timed out',
      );
    }

    if (webViewResult.isError) {
      throw PaymentException(
        code: 'WEBVIEW_ERROR',
        message: webViewResult.errorMessage ?? 'WebView error',
      );
    }

    // Complete 3DS payment
    return await provider.complete3DSPayment(
      threeDSResult.transactionId!,
      callbackData: webViewResult.callbackData,
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Payment Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
