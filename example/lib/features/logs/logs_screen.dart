import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tr_payment_hub/tr_payment_hub.dart';

import '../../core/providers/app_state.dart';
import '../../widgets/info_card.dart';

/// Screen for viewing HTTP request/response logs.
class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  String _filterText = '';
  bool _showOnlyErrors = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filter logs',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmClearLogs(context),
            tooltip: 'Clear logs',
          ),
        ],
      ),
      body: Consumer<AppState>(
        builder: (context, state, _) {
          if (!state.enableLogging) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: InfoCard.warning(
                  title: 'Logging Disabled',
                  message: 'Enable request logging in Settings to view '
                      'HTTP requests and responses.',
                  action: FilledButton(
                    onPressed: () => state.enableLogging = true,
                    child: const Text('Enable Logging'),
                  ),
                ),
              ),
            );
          }

          final logs = _filterLogs(state.logs);

          if (logs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: InfoCard.info(
                  title: 'No Logs',
                  message: _filterText.isNotEmpty || _showOnlyErrors
                      ? 'No logs match your filter criteria.'
                      : 'Make API requests to see logs here. '
                          'Logs will appear in real-time.',
                ),
              ),
            );
          }

          return Column(
            children: [
              // Filter chip display
              if (_filterText.isNotEmpty || _showOnlyErrors)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Row(
                    children: [
                      const Icon(Icons.filter_alt, size: 16),
                      const SizedBox(width: 8),
                      const Text('Filters: '),
                      if (_filterText.isNotEmpty)
                        Chip(
                          label: Text(_filterText),
                          onDeleted: () => setState(() => _filterText = ''),
                          visualDensity: VisualDensity.compact,
                        ),
                      if (_showOnlyErrors) ...[
                        const SizedBox(width: 4),
                        Chip(
                          label: const Text('Errors only'),
                          onDeleted: () => setState(() => _showOnlyErrors = false),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                      const Spacer(),
                      TextButton(
                        onPressed: () => setState(() {
                          _filterText = '';
                          _showOnlyErrors = false;
                        }),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                ),

              // Log count
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${logs.length} log entries',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      'Tap for details',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ],
                ),
              ),

              // Logs list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[logs.length - 1 - index]; // Newest first
                    return _buildLogItem(log);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<RequestLogEntry> _filterLogs(List<RequestLogEntry> logs) {
    return logs.where((log) {
      // Filter by text
      if (_filterText.isNotEmpty) {
        final searchLower = _filterText.toLowerCase();
        final matchesText =
            log.method.toLowerCase().contains(searchLower) ||
                log.url.toLowerCase().contains(searchLower) ||
                (log.statusCode?.toString().contains(searchLower) ?? false);
        if (!matchesText) return false;
      }

      // Filter errors only
      if (_showOnlyErrors && !log.isError) {
        return false;
      }

      return true;
    }).toList();
  }

  Widget _buildLogItem(RequestLogEntry log) {
    final theme = Theme.of(context);
    final isError = log.isError;
    final statusColor = _getStatusColor(log.statusCode);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () => _showLogDetails(log),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Method and URL
              Row(
                children: [
                  _buildMethodChip(log.method),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _formatUrl(log.url),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (log.statusCode != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${log.statusCode}',
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Time and duration
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatTimestamp(log.timestamp),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (log.duration != null) ...[
                    const SizedBox(width: 12),
                    Icon(
                      Icons.timer,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${log.duration!.inMilliseconds}ms',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (isError)
                    Icon(
                      Icons.error,
                      size: 16,
                      color: Colors.red.shade600,
                    ),
                ],
              ),

              // Error message preview
              if (log.error != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    log.error!,
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMethodChip(String method) {
    Color color;
    switch (method.toUpperCase()) {
      case 'GET':
        color = Colors.blue;
        break;
      case 'POST':
        color = Colors.green;
        break;
      case 'PUT':
        color = Colors.orange;
        break;
      case 'DELETE':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        method.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  Color _getStatusColor(int? statusCode) {
    if (statusCode == null) return Colors.grey;
    if (statusCode >= 200 && statusCode < 300) return Colors.green;
    if (statusCode >= 300 && statusCode < 400) return Colors.orange;
    if (statusCode >= 400 && statusCode < 500) return Colors.red;
    if (statusCode >= 500) return Colors.purple;
    return Colors.grey;
  }

  String _formatUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return '${uri.host}${uri.path}';
    } catch (_) {
      return url;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
  }

  void _showLogDetails(RequestLogEntry log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, controller) => LogDetailSheet(
          log: log,
          scrollController: controller,
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Filter Logs'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search',
                hintText: 'URL, method, status code...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => _filterText = v,
              controller: TextEditingController(text: _filterText),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Errors only'),
              value: _showOnlyErrors,
              onChanged: (v) => _showOnlyErrors = v,
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
              setState(() {});
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _confirmClearLogs(BuildContext context) {
    final state = context.read<AppState>();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear Logs?'),
        content: Text('Are you sure you want to clear ${state.logs.length} log entries?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              state.clearLogs();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

/// Detailed view of a single log entry.
class LogDetailSheet extends StatelessWidget {
  final RequestLogEntry log;
  final ScrollController scrollController;

  const LogDetailSheet({
    super.key,
    required this.log,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildMethodChip(log.method),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Request Details',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () => _copyToClipboard(context),
                  tooltip: 'Copy all',
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                // Basic Info
                _sectionTitle('Request'),
                _detailRow('Method', log.method),
                _detailRow('URL', log.url),
                _detailRow('Timestamp', log.timestamp.toIso8601String()),
                if (log.duration != null)
                  _detailRow('Duration', '${log.duration!.inMilliseconds}ms'),
                if (log.statusCode != null)
                  _detailRow('Status', '${log.statusCode}'),

                // Request Headers
                if (log.headers != null &&
                    log.headers!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _sectionTitle('Headers'),
                  _codeBlock(_formatHeaders(log.headers!)),
                ],

                // Request Body
                if (log.body != null) ...[
                  const SizedBox(height: 16),
                  _sectionTitle('Request Body'),
                  _codeBlock(log.body!),
                ],

                // Response Body
                if (log.response != null) ...[
                  const SizedBox(height: 16),
                  _sectionTitle('Response Body'),
                  _codeBlock(log.response!),
                ],

                // Error
                if (log.error != null) ...[
                  const SizedBox(height: 16),
                  _sectionTitle('Error', isError: true),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: SelectableText(
                      log.error!,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodChip(String method) {
    Color color;
    switch (method.toUpperCase()) {
      case 'GET':
        color = Colors.blue;
        break;
      case 'POST':
        color = Colors.green;
        break;
      case 'PUT':
        color = Colors.orange;
        break;
      case 'DELETE':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        method.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isError ? Colors.red : null,
        ),
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
            width: 80,
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
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _codeBlock(String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(
        content,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
        ),
      ),
    );
  }

  String _formatHeaders(Map<String, dynamic> headers) {
    return headers.entries.map((e) => '${e.key}: ${e.value}').join('\n');
  }

  void _copyToClipboard(BuildContext context) {
    final buffer = StringBuffer();
    buffer.writeln('=== REQUEST ===');
    buffer.writeln('${log.method} ${log.url}');
    buffer.writeln('Timestamp: ${log.timestamp.toIso8601String()}');
    if (log.duration != null) {
      buffer.writeln('Duration: ${log.duration!.inMilliseconds}ms');
    }
    if (log.statusCode != null) {
      buffer.writeln('Status: ${log.statusCode}');
    }

    if (log.headers != null) {
      buffer.writeln('\n=== HEADERS ===');
      buffer.writeln(_formatHeaders(log.headers!));
    }

    if (log.body != null) {
      buffer.writeln('\n=== REQUEST BODY ===');
      buffer.writeln(log.body!);
    }

    if (log.response != null) {
      buffer.writeln('\n=== RESPONSE BODY ===');
      buffer.writeln(log.response!);
    }

    if (log.error != null) {
      buffer.writeln('\n=== ERROR ===');
      buffer.writeln(log.error);
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }
}
