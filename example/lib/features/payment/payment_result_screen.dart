import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tr_payment_hub/tr_payment_hub.dart';

/// Screen displaying payment result details.
class PaymentResultScreen extends StatelessWidget {
  final PaymentResult result;

  const PaymentResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSuccess = result.isSuccess;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Result'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 32),

            // Status Icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isSuccess ? Colors.green : Colors.red).withOpacity(0.1),
              ),
              child: Icon(
                isSuccess ? Icons.check_circle : Icons.error,
                size: 60,
                color: isSuccess ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 24),

            // Status Text
            Text(
              isSuccess ? 'Payment Successful!' : 'Payment Failed',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isSuccess ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 8),

            if (result.amount != null)
              Text(
                '${result.amount!.toStringAsFixed(2)} TL',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 32),

            // Details Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transaction Details',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    _DetailRow(
                      label: 'Transaction ID',
                      value: result.transactionId ?? '-',
                      copyable: true,
                    ),
                    _DetailRow(
                      label: 'Status',
                      value: isSuccess ? 'Success' : 'Failed',
                    ),
                    if (result.amount != null)
                      _DetailRow(
                        label: 'Amount',
                        value: '${result.amount!.toStringAsFixed(2)} TL',
                      ),
                    if (result.paymentId != null)
                      _DetailRow(
                        label: 'Payment ID',
                        value: result.paymentId!,
                      ),
                    if (result.errorMessage != null)
                      _DetailRow(
                        label: 'Error',
                        value: result.errorMessage!,
                        isError: true,
                      ),
                    if (result.errorCode != null)
                      _DetailRow(
                        label: 'Error Code',
                        value: result.errorCode!,
                        isError: true,
                      ),
                  ],
                ),
              ),
            ),

            // Card Saved Info
            if (result.cardToken != null || result.cardUserKey != null) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.credit_card, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            'Card Saved',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (result.cardUserKey != null)
                        _DetailRow(
                          label: 'Card User Key',
                          value: result.cardUserKey!,
                          copyable: true,
                        ),
                      if (result.cardToken != null)
                        _DetailRow(
                          label: 'Card Token',
                          value: result.cardToken!,
                          copyable: true,
                        ),
                      const SizedBox(height: 8),
                      const Text(
                        'Save these values to use the card for future payments.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Raw Response (for debugging)
            if (result.rawResponse != null) ...[
              const SizedBox(height: 16),
              ExpansionTile(
                title: const Text('Raw Response'),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      result.rawResponse.toString(),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 32),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('New Payment'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.popUntil(context, (r) => r.isFirst),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool copyable;
  final bool isError;

  const _DetailRow({
    required this.label,
    required this.value,
    this.copyable = false,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: isError ? Colors.red : null,
                    ),
                  ),
                ),
                if (copyable)
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Copied to clipboard'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
