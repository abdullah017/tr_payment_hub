import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/app_state.dart';
import '../../core/services/payment_service.dart';
import '../../widgets/info_card.dart';

/// Settings screen for configuring providers and app options.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Consumer<AppState>(
        builder: (context, state, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Provider Selection
              Text(
                'Payment Provider',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),

              ...ProviderInfo.all.map((provider) {
                final isSelected = state.currentProvider == provider.id;
                final hasConfig = provider.id == 'mock' ||
                    (state.getProviderConfig(provider.id)?.isNotEmpty ?? false);

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: isSelected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                  child: InkWell(
                    onTap: () => _selectProvider(context, state, provider),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Radio<String>(
                            value: provider.id,
                            groupValue: state.currentProvider,
                            onChanged: (_) =>
                                _selectProvider(context, state, provider),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      provider.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (hasConfig && provider.id != 'mock') ...[
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.check_circle,
                                        size: 16,
                                        color: Colors.green,
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  provider.description,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          if (provider.id != 'mock')
                            IconButton(
                              icon: const Icon(Icons.settings),
                              onPressed: () =>
                                  _configureProvider(context, state, provider),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(height: 24),

              // Connection Mode
              Text(
                'Connection Mode',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),

              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Proxy Mode (Backend)'),
                      subtitle: Text(
                        state.useProxyMode
                            ? 'Using backend server'
                            : 'Direct API connection',
                      ),
                      value: state.useProxyMode,
                      onChanged: (v) {
                        state.useProxyMode = v;
                        if (!v) {
                          // Re-initialize with direct mode
                          state.initializeProvider(state.currentProvider);
                        }
                      },
                    ),
                    if (state.useProxyMode) ...[
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('Backend URL'),
                        subtitle: Text(state.proxyBaseUrl),
                        trailing: const Icon(Icons.edit),
                        onTap: () => _editProxyConfig(context, state),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // App Settings
              Text(
                'Payment Settings',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),

              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Sandbox Mode'),
                      subtitle: const Text('Use test environment'),
                      value: state.useSandbox,
                      onChanged: (v) => state.useSandbox = v,
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('3D Secure by Default'),
                      subtitle: const Text('Enable 3DS verification'),
                      value: state.use3DS,
                      onChanged: (v) => state.use3DS = v,
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Request Logging'),
                      subtitle: const Text('Log HTTP requests/responses'),
                      value: state.enableLogging,
                      onChanged: (v) => state.enableLogging = v,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Theme Settings
              Text(
                'Appearance',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),

              Card(
                child: Column(
                  children: [
                    RadioListTile<ThemeMode>(
                      title: const Text('System'),
                      value: ThemeMode.system,
                      groupValue: state.themeMode,
                      onChanged: (v) => state.setThemeMode(v!),
                    ),
                    RadioListTile<ThemeMode>(
                      title: const Text('Light'),
                      value: ThemeMode.light,
                      groupValue: state.themeMode,
                      onChanged: (v) => state.setThemeMode(v!),
                    ),
                    RadioListTile<ThemeMode>(
                      title: const Text('Dark'),
                      value: ThemeMode.dark,
                      groupValue: state.themeMode,
                      onChanged: (v) => state.setThemeMode(v!),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Data Management
              Text(
                'Data Management',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),

              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.delete_outline),
                      title: const Text('Clear Logs'),
                      subtitle: Text('${state.logs.length} entries'),
                      onTap: () {
                        state.clearLogs();
                        _showSnackBar(context, 'Logs cleared');
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.history),
                      title: const Text('Clear Transaction History'),
                      subtitle: Text(
                          '${state.transactionHistory.length} transactions'),
                      onTap: () {
                        state.clearTransactionHistory();
                        _showSnackBar(context, 'History cleared');
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading:
                          const Icon(Icons.delete_forever, color: Colors.red),
                      title: const Text('Reset All Settings'),
                      subtitle: const Text('Clear all data and configurations'),
                      onTap: () => _confirmReset(context, state),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Version Info
              Center(
                child: Text(
                  'tr_payment_hub v3.2.0',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  Future<void> _selectProvider(
    BuildContext context,
    AppState state,
    ProviderInfo provider,
  ) async {
    if (provider.id == 'mock') {
      await state.initializeProvider('mock');
      if (context.mounted) {
        _showSnackBar(context, 'Switched to ${provider.name}');
      }
      return;
    }

    final config = state.getProviderConfig(provider.id);
    if (config == null || config.isEmpty) {
      if (context.mounted) {
        _configureProvider(context, state, provider);
      }
      return;
    }

    try {
      await state.initializeProvider(provider.id);
      if (context.mounted) {
        _showSnackBar(context, 'Switched to ${provider.name}');
      }
    } catch (e) {
      if (context.mounted) {
        _showSnackBar(context, 'Error: $e', isError: true);
      }
    }
  }

  void _configureProvider(
    BuildContext context,
    AppState state,
    ProviderInfo provider,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProviderConfigScreen(provider: provider),
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message,
      {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  void _editProxyConfig(BuildContext context, AppState state) {
    final urlController = TextEditingController(text: state.proxyBaseUrl);
    final tokenController =
        TextEditingController(text: state.proxyAuthToken ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Backend Configuration'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: 'Backend URL',
                  hintText: 'http://localhost:3000/api/payment',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: tokenController,
                decoration: const InputDecoration(
                  labelText: 'Auth Token (optional)',
                  hintText: 'JWT or API token',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              state.proxyBaseUrl = urlController.text;
              state.proxyAuthToken =
                  tokenController.text.isEmpty ? null : tokenController.text;
              Navigator.pop(context);
              _showSnackBar(context, 'Backend configuration saved');
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context, AppState state) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset All Settings?'),
        content: const Text(
          'This will clear all provider configurations, logs, and transaction history. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await state.storage.clearAll();
              await state.initializeProvider('mock');
              if (context.mounted) {
                _showSnackBar(context, 'All settings reset');
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

/// Screen for configuring a specific provider.
class ProviderConfigScreen extends StatefulWidget {
  final ProviderInfo provider;

  const ProviderConfigScreen({super.key, required this.provider});

  @override
  State<ProviderConfigScreen> createState() => _ProviderConfigScreenState();
}

class _ProviderConfigScreenState extends State<ProviderConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    final state = context.read<AppState>();
    final existingConfig = state.getProviderConfig(widget.provider.id) ?? {};

    for (final field in widget.provider.requiredFields) {
      _controllers[field] = TextEditingController(
        text: existingConfig[field] ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Configure ${widget.provider.name}'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            InfoCard.info(
              title: 'Configuration Required',
              message:
                  'Enter your ${widget.provider.name} API credentials. These are stored locally on your device.',
            ),
            const SizedBox(height: 24),
            ...widget.provider.requiredFields.map((field) {
              final isSecret = field.toLowerCase().contains('secret') ||
                  field.toLowerCase().contains('key');
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextFormField(
                  controller: _controllers[field],
                  decoration: InputDecoration(
                    labelText: _formatFieldName(field),
                    border: const OutlineInputBorder(),
                  ),
                  obscureText: isSecret,
                  validator: (v) => v?.isEmpty ?? true
                      ? '${_formatFieldName(field)} is required'
                      : null,
                ),
              );
            }),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isLoading ? null : _saveConfig,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save & Activate'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFieldName(String field) {
    // Convert camelCase to Title Case
    return field
        .replaceAllMapped(
          RegExp(r'([A-Z])'),
          (m) => ' ${m.group(1)}',
        )
        .trim()
        .split(' ')
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final config = <String, String>{};
      for (final entry in _controllers.entries) {
        config[entry.key] = entry.value.text;
      }

      final state = context.read<AppState>();
      state.saveProviderConfig(widget.provider.id, config);
      await state.initializeProvider(widget.provider.id);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('${widget.provider.name} configured and activated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
