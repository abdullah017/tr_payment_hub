import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tr_payment_hub/tr_payment_hub.dart';

import '../../core/providers/app_state.dart';
import '../../widgets/info_card.dart';
import '../payment/payment_result_screen.dart';

/// Screen for managing saved/tokenized cards.
class SavedCardsScreen extends StatefulWidget {
  const SavedCardsScreen({super.key});

  @override
  State<SavedCardsScreen> createState() => _SavedCardsScreenState();
}

class _SavedCardsScreenState extends State<SavedCardsScreen> {
  final _cardUserKeyController = TextEditingController();

  bool _isLoading = false;
  List<SavedCard>? _savedCards;
  String? _error;

  @override
  void dispose() {
    _cardUserKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Cards'),
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

          if (!state.paymentService.supportsSavedCards) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: InfoCard.warning(
                  title: 'Feature Not Supported',
                  message: '${state.currentProvider.toUpperCase()} does not support '
                      'saved cards. Try iyzico or Sipay for this feature.',
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Info Card
              InfoCard.info(
                title: 'Card User Key',
                message: 'Enter the Card User Key returned after saving a card '
                    'during payment to retrieve saved cards.',
              ),
              const SizedBox(height: 24),

              // Card User Key Input
              TextFormField(
                controller: _cardUserKeyController,
                enabled: !_isLoading,
                decoration: const InputDecoration(
                  labelText: 'Card User Key',
                  prefixIcon: Icon(Icons.key),
                  hintText: 'Enter card user key from payment result',
                ),
              ),
              const SizedBox(height: 16),

              // Fetch Button
              FilledButton.icon(
                onPressed: _isLoading ? null : () => _fetchSavedCards(state),
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.credit_card),
                label: Text(_isLoading ? 'Loading...' : 'Fetch Saved Cards'),
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
              if (_savedCards != null) ...[
                const SizedBox(height: 24),
                _buildSavedCardsSection(state),
              ],

              const SizedBox(height: 32),

              // Add New Card Section
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Register New Card',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              InfoCard.info(
                title: 'Save a Card',
                message: 'To save a new card, make a payment with the '
                    '"Save Card" option enabled. The card will be tokenized '
                    'and you can use it for future payments.',
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSavedCardsSection(AppState state) {
    final theme = Theme.of(context);

    if (_savedCards!.isEmpty) {
      return InfoCard.warning(
        title: 'No Saved Cards',
        message: 'No cards are saved for this Card User Key.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Saved Cards (${_savedCards!.length})',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed: _isLoading ? null : () => _fetchSavedCards(state),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._savedCards!.map((card) => _buildSavedCardItem(card, state)),
      ],
    );
  }

  Widget _buildSavedCardItem(SavedCard card, AppState state) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.credit_card, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.cardAlias ?? 'Saved Card',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '**** **** **** ${card.lastFourDigits}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                if (card.cardAssociation != null)
                  Chip(
                    label: Text(
                      card.cardAssociation!.name.toUpperCase(),
                      style: const TextStyle(fontSize: 10),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Card Details
            if (card.bankName != null || card.cardFamily != null)
              Wrap(
                spacing: 8,
                children: [
                  if (card.bankName != null)
                    Text(
                      card.bankName!,
                      style: theme.textTheme.bodySmall,
                    ),
                  if (card.cardFamily != null)
                    Text(
                      card.cardFamily!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                ],
              ),

            const Divider(height: 24),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showCardDetails(card),
                  icon: const Icon(Icons.info_outline, size: 18),
                  label: const Text('Details'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _chargeCard(card, state),
                  icon: const Icon(Icons.payment, size: 18),
                  label: const Text('Charge'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _confirmDeleteCard(card, state),
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCardDetails(SavedCard card) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Card Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('Card Alias', card.cardAlias ?? '-'),
              _detailRow('Card Token', card.cardToken),
              _detailRow('BIN Number', card.binNumber ?? '-'),
              _detailRow('Last Four', card.lastFourDigits),
              _detailRow('Association', card.cardAssociation?.name ?? '-'),
              _detailRow('Card Family', card.cardFamily ?? '-'),
              _detailRow('Bank Name', card.bankName ?? '-'),
              if (card.expiryMonth != null && card.expiryYear != null)
                _detailRow('Expiry', '${card.expiryMonth}/${card.expiryYear}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(value),
          ),
        ],
      ),
    );
  }

  void _chargeCard(SavedCard card, AppState state) {
    final amountController = TextEditingController(text: '10.00');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Charge Saved Card'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Card: ${card.cardAlias ?? '**** ${card.lastFourDigits}'}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: 'Amount (TL)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _processChargeCard(card, state, amountController.text);
            },
            child: const Text('Charge'),
          ),
        ],
      ),
    );
  }

  Future<void> _processChargeCard(
    SavedCard card,
    AppState state,
    String amountStr,
  ) async {
    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Invalid amount');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final provider = state.paymentService.provider!;

      final result = await provider.chargeWithSavedCard(
        cardToken: card.cardToken,
        cardUserKey: _cardUserKeyController.text,
        orderId: 'SAVED_${DateTime.now().millisecondsSinceEpoch}',
        amount: amount,
        currency: Currency.tryLira,
        buyer: BuyerInfo(
          id: 'BUYER_${DateTime.now().millisecondsSinceEpoch}',
          name: 'John',
          surname: 'Doe',
          email: 'customer@example.com',
          phone: '+905551234567',
          ip: '127.0.0.1',
          city: 'Istanbul',
          country: 'Turkey',
          address: 'Test Address',
          identityNumber: '11111111111',
        ),
      );

      // Save to transaction history
      state.addTransaction({
        'orderId': 'SAVED_${DateTime.now().millisecondsSinceEpoch}',
        'amount': amount,
        'provider': state.currentProvider,
        'isSuccess': result.isSuccess,
        'transactionId': result.transactionId,
        'errorMessage': result.errorMessage,
        'savedCard': true,
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
      setState(() => _error = '${e.code}: ${e.message}');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _confirmDeleteCard(SavedCard card, AppState state) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Card?'),
        content: Text(
          'Are you sure you want to delete "${card.cardAlias ?? '**** ${card.lastFourDigits}'}"? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteCard(card, state);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCard(SavedCard card, AppState state) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final provider = state.paymentService.provider!;

      await provider.deleteSavedCard(
        cardUserKey: _cardUserKeyController.text,
        cardToken: card.cardToken,
      );

      // Refresh the list
      await _fetchSavedCards(state);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Card deleted successfully')),
        );
      }
    } on PaymentException catch (e) {
      setState(() => _error = '${e.code}: ${e.message}');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchSavedCards(AppState state) async {
    if (_cardUserKeyController.text.isEmpty) {
      setState(() => _error = 'Please enter a Card User Key');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final provider = state.paymentService.provider!;

      final cards = await provider.getSavedCards(
        _cardUserKeyController.text,
      );

      setState(() => _savedCards = cards);
    } on PaymentException catch (e) {
      setState(() => _error = '${e.code}: ${e.message}');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
