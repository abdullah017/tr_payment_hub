import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tr_payment_hub/tr_payment_hub.dart';

import '../../core/providers/app_state.dart';
import '../../widgets/card_input_field.dart';
import '../../widgets/info_card.dart';

/// Screen for querying installment options by card BIN.
class InstallmentsScreen extends StatefulWidget {
  const InstallmentsScreen({super.key});

  @override
  State<InstallmentsScreen> createState() => _InstallmentsScreenState();
}

class _InstallmentsScreenState extends State<InstallmentsScreen> {
  final _cardNumberController =
      TextEditingController(text: '5528 7900 0000 0008');
  final _amountController = TextEditingController(text: '1000.00');

  bool _isLoading = false;
  InstallmentInfo? _installmentInfo;
  String? _error;

  @override
  void dispose() {
    _cardNumberController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Installment Options'),
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
                title: 'How it works',
                message:
                    'Enter the first 6-8 digits of a card number (BIN) and '
                    'the payment amount to see available installment options.',
              ),
              const SizedBox(height: 24),

              // Card Number Input
              Text(
                'Card Information',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),

              CardNumberField(
                controller: _cardNumberController,
                enabled: !_isLoading,
                validator: (v) {
                  final number = v?.replaceAll(' ', '') ?? '';
                  if (number.length < 6) return 'Enter at least 6 digits';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _amountController,
                enabled: !_isLoading,
                decoration: const InputDecoration(
                  labelText: 'Amount (TL)',
                  prefixIcon: Icon(Icons.attach_money),
                  hintText: '1000.00',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),

              // Query Button
              FilledButton.icon(
                onPressed: _isLoading ? null : () => _queryInstallments(state),
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: Text(_isLoading ? 'Querying...' : 'Query Installments'),
              ),

              // Error Display
              if (_error != null) ...[
                const SizedBox(height: 16),
                InfoCard.error(
                  title: 'Error',
                  message: _error!,
                ),
              ],

              // Results Display
              if (_installmentInfo != null) ...[
                const SizedBox(height: 24),
                _buildResultsSection(),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildResultsSection() {
    final info = _installmentInfo!;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Available Options',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        // Card Info
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.credit_card),
                    const SizedBox(width: 8),
                    Text(
                      info.cardAssociation.name.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    if (info.cardFamily.isNotEmpty)
                      Chip(
                        label: Text(info.cardFamily),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                if (info.bankName.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Bank: ${info.bankName}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                if (info.binNumber != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'BIN: ${info.binNumber}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Installment Options
        if (info.options.isEmpty)
          InfoCard.warning(
            title: 'No Installments',
            message: 'This card does not support installment payments.',
          )
        else
          ...info.options.map((option) => _buildInstallmentOption(option)),
      ],
    );
  }

  Widget _buildInstallmentOption(InstallmentOption option) {
    final theme = Theme.of(context);
    final totalAmount = option.totalPrice;
    final extraCost =
        totalAmount - (double.tryParse(_amountController.text) ?? 0);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Text('${option.installmentNumber}'),
        ),
        title: Text(
          option.installmentNumber == 1
              ? 'Single Payment'
              : '${option.installmentNumber} Installments',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${option.installmentPrice.toStringAsFixed(2)} TL / month'),
            if (extraCost > 0)
              Text(
                '+${extraCost.toStringAsFixed(2)} TL interest',
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: Text(
          '${totalAmount.toStringAsFixed(2)} TL',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<void> _queryInstallments(AppState state) async {
    final cardNumber = _cardNumberController.text.replaceAll(' ', '');
    if (cardNumber.length < 6) {
      setState(() => _error = 'Please enter at least 6 digits');
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Please enter a valid amount');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _installmentInfo = null;
    });

    try {
      final provider = state.paymentService.provider!;
      final binNumber = cardNumber.substring(0, cardNumber.length >= 8 ? 8 : 6);

      final result = await provider.getInstallments(
        binNumber: binNumber,
        amount: amount,
      );

      setState(() {
        _installmentInfo = result;
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
