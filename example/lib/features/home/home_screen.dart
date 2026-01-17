import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/app_state.dart';
import '../../core/services/payment_service.dart';
import '../../widgets/info_card.dart';
import '../installments/installments_screen.dart';
import '../logs/logs_screen.dart';
import '../payment/payment_screen.dart';
import '../refund/refund_screen.dart';
import '../saved_cards/saved_cards_screen.dart';
import '../settings/settings_screen.dart';
import '../transaction_status/transaction_status_screen.dart';

/// Home screen with navigation to all features.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TR Payment Hub'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Consumer<AppState>(
        builder: (context, state, _) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Provider Status Card
              _buildProviderStatusCard(context, state),
              const SizedBox(height: 24),

              // Core Features Section
              Text(
                'Core Features',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),

              FeatureCard(
                icon: Icons.payment,
                title: 'Make Payment',
                description: 'Process card payments with 3DS support',
                onTap: () => _navigateTo(context, const PaymentScreen()),
              ),

              FeatureCard(
                icon: Icons.format_list_numbered,
                title: 'Installments',
                description: 'Query installment options by card BIN',
                onTap: () => _navigateTo(context, const InstallmentsScreen()),
              ),

              FeatureCard(
                icon: Icons.credit_card,
                title: 'Saved Cards',
                description: 'Manage tokenized cards for one-click payments',
                badge:
                    state.paymentService.supportsSavedCards ? null : 'Limited',
                onTap: () => _navigateTo(context, const SavedCardsScreen()),
              ),

              FeatureCard(
                icon: Icons.refresh,
                title: 'Process Refund',
                description: 'Full or partial refund for transactions',
                onTap: () => _navigateTo(context, const RefundScreen()),
              ),

              FeatureCard(
                icon: Icons.search,
                title: 'Transaction Status',
                description: 'Query payment status by transaction ID',
                onTap: () =>
                    _navigateTo(context, const TransactionStatusScreen()),
              ),

              const SizedBox(height: 24),

              // Developer Tools Section
              Text(
                'Developer Tools',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),

              FeatureCard(
                icon: Icons.terminal,
                title: 'Request Logs',
                description: 'View HTTP requests and responses',
                badge: '${state.logs.length}',
                onTap: () => _navigateTo(context, const LogsScreen()),
              ),

              FeatureCard(
                icon: Icons.history,
                title: 'Transaction History',
                description: 'View past transactions (local)',
                badge: '${state.transactionHistory.length}',
                onTap: () => _showTransactionHistory(context, state),
              ),

              const SizedBox(height: 24),

              // Quick Actions
              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.credit_card, size: 18),
                    label: const Text('Test Card'),
                    onPressed: () => _showTestCards(context),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.code, size: 18),
                    label: const Text('API Docs'),
                    onPressed: () => _showApiInfo(context),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.help_outline, size: 18),
                    label: const Text('Provider Info'),
                    onPressed: () => _showProviderInfo(context),
                  ),
                ],
              ),

              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProviderStatusCard(BuildContext context, AppState state) {
    final providerInfo = ProviderInfo.getById(state.currentProvider);
    final isConfigured = state.isProviderInitialized;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isConfigured ? Colors.green : Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Active Provider: ${providerInfo?.name ?? state.currentProvider}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                  child: const Text('Change'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _buildCapabilityChip(
                  '3DS',
                  providerInfo?.supports3DS ?? false,
                ),
                _buildCapabilityChip(
                  'Saved Cards',
                  providerInfo?.supportsSavedCards ?? false,
                ),
                _buildCapabilityChip(
                  'Sandbox',
                  state.useSandbox,
                ),
              ],
            ),
            if (state.error != null) ...[
              const SizedBox(height: 8),
              Text(
                state.error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCapabilityChip(String label, bool enabled) {
    return Chip(
      avatar: Icon(
        enabled ? Icons.check : Icons.close,
        size: 16,
        color: enabled ? Colors.green : Colors.grey,
      ),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _showTestCards(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Test Cards'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _testCardItem('Success', '5528790000000008', '12/30', '123'),
              _testCardItem(
                  'Insufficient Funds', '4543590000000006', '12/30', '123'),
              _testCardItem('Invalid Card', '4111111111111111', '12/30', '123'),
              const SizedBox(height: 16),
              const Text(
                'Note: Test cards only work in sandbox mode.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
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

  Widget _testCardItem(String name, String number, String expiry, String cvv) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
          SelectableText('$number | $expiry | $cvv'),
        ],
      ),
    );
  }

  void _showApiInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('API Information'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Endpoints:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('iyzico Sandbox:\nsandbox-api.iyzipay.com'),
              SizedBox(height: 8),
              Text('PayTR:\nwww.paytr.com'),
              SizedBox(height: 8),
              Text('Sipay Sandbox:\nsandbox.sipay.com.tr'),
              SizedBox(height: 8),
              Text('Param Sandbox:\ntest-dmz.param.com.tr'),
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

  void _showProviderInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Provider Capabilities'),
        content: SingleChildScrollView(
          child: DataTable(
            columnSpacing: 16,
            columns: const [
              DataColumn(label: Text('Provider')),
              DataColumn(label: Text('Cards')),
              DataColumn(label: Text('3DS')),
            ],
            rows: ProviderInfo.all.map((p) {
              return DataRow(cells: [
                DataCell(Text(p.name)),
                DataCell(Icon(
                  p.supportsSavedCards ? Icons.check : Icons.close,
                  color: p.supportsSavedCards ? Colors.green : Colors.red,
                  size: 20,
                )),
                DataCell(Icon(
                  p.supports3DS ? Icons.check : Icons.close,
                  color: p.supports3DS ? Colors.green : Colors.red,
                  size: 20,
                )),
              ]);
            }).toList(),
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

  void _showTransactionHistory(BuildContext context, AppState state) {
    final history = state.transactionHistory;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (_, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Transaction History',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (history.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        state.clearTransactionHistory();
                        Navigator.pop(context);
                      },
                      child: const Text('Clear'),
                    ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: history.isEmpty
                  ? const Center(child: Text('No transactions yet'))
                  : ListView.builder(
                      controller: controller,
                      itemCount: history.length,
                      itemBuilder: (_, i) {
                        final tx = history[i];
                        final isSuccess = tx['isSuccess'] == true;
                        return ListTile(
                          leading: Icon(
                            isSuccess ? Icons.check_circle : Icons.error,
                            color: isSuccess ? Colors.green : Colors.red,
                          ),
                          title: Text(tx['orderId'] ?? 'Unknown'),
                          subtitle: Text(
                            '${tx['amount']} TL',
                          ),
                          trailing: Text(
                            tx['provider'] ?? '',
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
