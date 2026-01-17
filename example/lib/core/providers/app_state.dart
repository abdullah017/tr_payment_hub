import 'package:flutter/material.dart';
import 'package:tr_payment_hub/tr_payment_hub.dart';

import '../services/payment_service.dart';
import '../services/storage_service.dart';

/// Application state management using Provider pattern.
class AppState extends ChangeNotifier {
  /// Initialize the app state.
  Future<void> initialize() async {
    await _init();
  }

  bool _isLoading = true;
  String? _error;
  ThemeMode _themeMode = ThemeMode.system;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  ThemeMode get themeMode => _themeMode;

  PaymentService get paymentService => PaymentService.instance;
  StorageService get storage => StorageService.instance;

  String get currentProvider => paymentService.currentProviderType;
  bool get isProviderInitialized => paymentService.isInitialized;
  List<RequestLogEntry> get logs => paymentService.logs;

  Future<void> _init() async {
    try {
      await StorageService.instance.init();
      _loadThemeMode();

      // Initialize with stored provider
      final provider = storage.selectedProvider;
      if (provider == 'mock') {
        await initializeProvider('mock');
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void _loadThemeMode() {
    final mode = storage.themeMode;
    _themeMode = switch (mode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    storage.themeMode = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    notifyListeners();
  }

  Future<void> initializeProvider(String providerType) async {
    _error = null;
    notifyListeners();

    try {
      await paymentService.initializeProvider(providerType);
      storage.selectedProvider = providerType;
      notifyListeners();
    } on PaymentException catch (e) {
      _error = '${e.code}: ${e.message}';
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void saveProviderConfig(String provider, Map<String, String> config) {
    storage.saveProviderConfig(provider, config);
    notifyListeners();
  }

  Map<String, String>? getProviderConfig(String provider) {
    return storage.getProviderConfig(provider);
  }

  // Settings
  bool get useSandbox => storage.useSandbox;
  set useSandbox(bool value) {
    storage.useSandbox = value;
    notifyListeners();
  }

  bool get use3DS => storage.use3DS;
  set use3DS(bool value) {
    storage.use3DS = value;
    notifyListeners();
  }

  bool get enableLogging => storage.enableLogging;
  set enableLogging(bool value) {
    storage.enableLogging = value;
    notifyListeners();
  }

  // Proxy Mode Settings
  bool get useProxyMode => storage.useProxyMode;
  set useProxyMode(bool value) {
    storage.useProxyMode = value;
    notifyListeners();
  }

  String get proxyBaseUrl => storage.proxyBaseUrl;
  set proxyBaseUrl(String value) {
    storage.proxyBaseUrl = value;
    notifyListeners();
  }

  String? get proxyAuthToken => storage.proxyAuthToken;
  set proxyAuthToken(String? value) {
    storage.proxyAuthToken = value;
    notifyListeners();
  }

  // Transaction history
  List<Map<String, dynamic>> get transactionHistory => storage.transactionHistory;

  void addTransaction(Map<String, dynamic> transaction) {
    storage.addTransaction(transaction);
    notifyListeners();
  }

  void clearTransactionHistory() {
    storage.clearTransactionHistory();
    notifyListeners();
  }

  // Logs
  void clearLogs() {
    paymentService.clearLogs();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    paymentService.dispose();
    super.dispose();
  }
}
