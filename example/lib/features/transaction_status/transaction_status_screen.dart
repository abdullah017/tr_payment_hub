import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tr_payment_hub/tr_payment_hub.dart';

import '../../core/providers/app_state.dart';
import '../../widgets/info_card.dart';

/// Screen for querying transaction status.
class TransactionStatusScreen extends StatefulWidget {
  const TransactionStatusScreen({super.key});

  @override
  State<TransactionStatusScreen> createState() =>
      _TransactionStatusScreenState();
}

class _TransactionStatusScreenState extends State<TransactionStatusScreen> {
  final _transactionIdController = TextEditingController();

  bool _isLoading = false;
  PaymentStatus? _status;
  String? _error;

  @override
  void dispose() {
    _transactionIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Status'),
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

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Info Card
              InfoCard.info(
                title: 'Query Status',
                message: 'Enter a transaction ID to check its current status.',
              ),
              const SizedBox(height: 24),

              // Transaction ID Input
              Text(
                'Transaction ID',
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
              ),
              const SizedBox(height: 16),

              // Query Button
              FilledButton.icon(
                onPressed: _isLoading ? null : () => _queryStatus(state),
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: Text(_isLoading ? 'Querying...' : 'Query Status'),
              ),

              // Error Display
              if (_error != null) ...[
                const SizedBox(height: 16),
                InfoCard.error(
                  title: 'Query Error',
                  message: _error!,
                ),
              ],

              // Result Display
              if (_status != null) ...[
                const SizedBox(height: 24),
                _buildStatusResult(),
              ],

              // Recent Transactions
              if (state.transactionHistory.isNotEmpty) ...[
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 16),
                _buildRecentTransactions(state),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusResult() {
    final status = _status!;
    final theme = Theme.of(context);

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case PaymentStatus.success:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Success';
        break;
      case PaymentStatus.pending:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
        statusText = 'Pending';
        break;
      case PaymentStatus.failed:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'Failed';
        break;
      case PaymentStatus.refunded:
        statusColor = Colors.blue;
        statusIcon = Icons.refresh;
        statusText = 'Refunded';
        break;
      case PaymentStatus.partiallyRefunded:
        statusColor = Colors.indigo;
        statusIcon = Icons.refresh;
        statusText = 'Partially Refunded';
        break;
    }

    return Card(
      color: statusColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(statusIcon, size: 48, color: statusColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusText,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Transaction: ${_transactionIdController.text}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactions(AppState state) {
    final transactions = state.transactionHistory
        .where((t) => t['transactionId'] != null)
        .take(5)
        .toList();

    if (transactions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Transactions',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tap to query status',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
        ),
        const SizedBox(height: 12),
        ...transactions.map((tx) {
          final isSuccess = tx['isSuccess'] == true;
          return ListTile(
            leading: Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              color: isSuccess ? Colors.green : Colors.red,
            ),
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
              });
            },
          );
        }),
      ],
    );
  }

  Future<void> _queryStatus(AppState state) async {
    if (_transactionIdController.text.isEmpty) {
      setState(() => _error = 'Please enter a transaction ID');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _status = null;
    });

    try {
      final provider = state.paymentService.provider!;

      final result = await provider.getPaymentStatus(
        _transactionIdController.text,
      );

      setState(() => _status = result);
    } on PaymentException catch (e) {
      setState(() => _error = '${e.code}: ${e.message}');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
