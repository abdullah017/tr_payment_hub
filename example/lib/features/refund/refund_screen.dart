import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tr_payment_hub/tr_payment_hub.dart';

import '../../core/providers/app_state.dart';
import '../../widgets/info_card.dart';

/// Screen for processing refunds.
class RefundScreen extends StatefulWidget {
  const RefundScreen({super.key});

  @override
  State<RefundScreen> createState() => _RefundScreenState();
}

class _RefundScreenState extends State<RefundScreen> {
  final _formKey = GlobalKey<FormState>();
  final _transactionIdController = TextEditingController();
  final _amountController = TextEditingController();
  final _ipController = TextEditingController(text: '127.0.0.1');

  bool _isLoading = false;
  bool _isPartialRefund = false;
  RefundResult? _refundResult;
  String? _error;

  @override
  void dispose() {
    _transactionIdController.dispose();
    _amountController.dispose();
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Process Refund'),
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
                // Info Card
                InfoCard.info(
                  title: 'Refund Processing',
                  message: 'Enter the transaction ID from a successful payment '
                      'to process a full or partial refund.',
                ),
                const SizedBox(height: 24),

                // Transaction ID
                Text(
                  'Transaction Details',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _transactionIdController,
                  enabled: !_isLoading,
                  decoration: const InputDecoration(
                    labelText: 'Transaction ID',
                    prefixIcon: Icon(Icons.receipt),
                    hintText: 'Enter the payment transaction ID',
                  ),
                  validator: (v) =>
                      v?.isEmpty ?? true ? 'Transaction ID is required' : null,
                ),
                const SizedBox(height: 16),

                // Refund Type
                Card(
                  child: SwitchListTile(
                    title: const Text('Partial Refund'),
                    subtitle: Text(
                      _isPartialRefund
                          ? 'Refund a specific amount'
                          : 'Full refund of original payment',
                    ),
                    value: _isPartialRefund,
                    onChanged: _isLoading
                        ? null
                        : (v) => setState(() => _isPartialRefund = v),
                  ),
                ),
                const SizedBox(height: 16),

                // Amount (for partial refund)
                if (_isPartialRefund)
                  TextFormField(
                    controller: _amountController,
                    enabled: !_isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Refund Amount (TL)',
                      prefixIcon: Icon(Icons.attach_money),
                      hintText: 'Enter amount to refund',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (!_isPartialRefund) return null;
                      final amount = double.tryParse(v ?? '');
                      if (amount == null || amount <= 0) {
                        return 'Enter a valid amount';
                      }
                      return null;
                    },
                  ),

                if (_isPartialRefund) const SizedBox(height: 16),

                // IP Address (required by some providers)
                TextFormField(
                  controller: _ipController,
                  enabled: !_isLoading,
                  decoration: const InputDecoration(
                    labelText: 'IP Address',
                    prefixIcon: Icon(Icons.computer),
                    hintText: '127.0.0.1',
                    helperText: 'IP address for audit logging',
                  ),
                  validator: (v) =>
                      v?.isEmpty ?? true ? 'IP address is required' : null,
                ),
                const SizedBox(height: 24),

                // Process Button
                FilledButton.icon(
                  onPressed: _isLoading ? null : () => _processRefund(state),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(_isLoading ? 'Processing...' : 'Process Refund'),
                ),

                // Error Display
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  InfoCard.error(
                    title: 'Refund Error',
                    message: _error!,
                  ),
                ],

                // Result Display
                if (_refundResult != null) ...[
                  const SizedBox(height: 24),
                  _buildResultSection(),
                ],

                // Recent Transactions
                if (state.transactionHistory.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),
                  _buildRecentTransactions(state),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildResultSection() {
    final result = _refundResult!;
    final isSuccess = result.isSuccess;
    final theme = Theme.of(context);

    return Card(
      color: isSuccess ? Colors.green.shade50 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSuccess ? Icons.check_circle : Icons.error,
                  color: isSuccess ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  isSuccess ? 'Refund Successful' : 'Refund Failed',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color:
                        isSuccess ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _resultRow('Refund ID', result.refundId ?? '-'),
            if (result.refundedAmount != null)
              _resultRow('Refunded Amount',
                  '${result.refundedAmount!.toStringAsFixed(2)} TL'),
            if (result.errorMessage != null)
              _resultRow('Error', result.errorMessage!, isError: true),
            if (result.errorCode != null)
              _resultRow('Error Code', result.errorCode!, isError: true),
          ],
        ),
      ),
    );
  }

  Widget _resultRow(String label, String value, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
            child: SelectableText(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isError ? Colors.red : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions(AppState state) {
    final successfulTransactions = state.transactionHistory
        .where((t) => t['isSuccess'] == true && t['transactionId'] != null)
        .take(5)
        .toList();

    if (successfulTransactions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Successful Transactions',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tap to fill transaction ID',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
        ),
        const SizedBox(height: 12),
        ...successfulTransactions.map((tx) => ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: Text(
                tx['orderId'] ?? 'Unknown',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                '${tx['amount']} TL • ${tx['provider']}',
              ),
              trailing: Text(
                tx['transactionId']?.toString().substring(0, 8) ?? '',
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              onTap: () {
                setState(() {
                  _transactionIdController.text = tx['transactionId'] ?? '';
                  if (tx['amount'] != null) {
                    _amountController.text = tx['amount'].toString();
                  }
                });
              },
            )),
      ],
    );
  }

  Future<void> _processRefund(AppState state) async {
    if (!_formKey.currentState!.validate()) return;

    // Confirm refund
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Refund'),
        content: Text(
          _isPartialRefund
              ? 'Are you sure you want to refund ${_amountController.text} TL '
                  'for transaction ${_transactionIdController.text}?'
              : 'Are you sure you want to process a full refund for '
                  'transaction ${_transactionIdController.text}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _refundResult = null;
    });

    try {
      final provider = state.paymentService.provider!;

      final request = RefundRequest(
        transactionId: _transactionIdController.text,
        amount: _isPartialRefund
            ? double.parse(_amountController.text)
            : 0.01, // Amount is required, use minimal for full refund
        ip: _ipController.text,
      );

      final result = await provider.refund(request);

      setState(() => _refundResult = result);

      // Add to transaction history
      state.addTransaction({
        'orderId': 'REFUND_${DateTime.now().millisecondsSinceEpoch}',
        'amount': result.refundedAmount ?? 0,
        'provider': state.currentProvider,
        'isSuccess': result.isSuccess,
        'transactionId': result.refundId,
        'errorMessage': result.errorMessage,
        'type': 'refund',
        'originalTransactionId': _transactionIdController.text,
      });
    } on PaymentException catch (e) {
      setState(() => _error = '${e.code}: ${e.message}');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
