import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for persisting app settings and data.
class StorageService {
  StorageService._();
  static StorageService? _instance;
  static StorageService get instance => _instance ??= StorageService._();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Provider Settings
  static const _keySelectedProvider = 'selected_provider';
  static const _keyProviderConfigs = 'provider_configs';

  String get selectedProvider =>
      _prefs?.getString(_keySelectedProvider) ?? 'mock';

  set selectedProvider(String value) {
    _prefs?.setString(_keySelectedProvider, value);
  }

  Map<String, Map<String, String>> get providerConfigs {
    final json = _prefs?.getString(_keyProviderConfigs);
    if (json == null) return {};
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    return decoded.map(
      (k, v) => MapEntry(k, Map<String, String>.from(v as Map)),
    );
  }

  set providerConfigs(Map<String, Map<String, String>> value) {
    _prefs?.setString(_keyProviderConfigs, jsonEncode(value));
  }

  void saveProviderConfig(String provider, Map<String, String> config) {
    final configs = providerConfigs;
    configs[provider] = config;
    providerConfigs = configs;
  }

  Map<String, String>? getProviderConfig(String provider) {
    return providerConfigs[provider];
  }

  // App Settings
  static const _keyUseSandbox = 'use_sandbox';
  static const _keyUse3DS = 'use_3ds';
  static const _keyEnableLogging = 'enable_logging';
  static const _keyThemeMode = 'theme_mode';
  static const _keyUseProxyMode = 'use_proxy_mode';
  static const _keyProxyBaseUrl = 'proxy_base_url';
  static const _keyProxyAuthToken = 'proxy_auth_token';

  bool get useSandbox => _prefs?.getBool(_keyUseSandbox) ?? true;
  set useSandbox(bool value) => _prefs?.setBool(_keyUseSandbox, value);

  bool get use3DS => _prefs?.getBool(_keyUse3DS) ?? true;
  set use3DS(bool value) => _prefs?.setBool(_keyUse3DS, value);

  bool get enableLogging => _prefs?.getBool(_keyEnableLogging) ?? true;
  set enableLogging(bool value) => _prefs?.setBool(_keyEnableLogging, value);

  String get themeMode => _prefs?.getString(_keyThemeMode) ?? 'system';
  set themeMode(String value) => _prefs?.setString(_keyThemeMode, value);

  // Proxy Mode Settings
  bool get useProxyMode => _prefs?.getBool(_keyUseProxyMode) ?? false;
  set useProxyMode(bool value) => _prefs?.setBool(_keyUseProxyMode, value);

  String get proxyBaseUrl =>
      _prefs?.getString(_keyProxyBaseUrl) ??
      'http://localhost:3000/api/payment';
  set proxyBaseUrl(String value) => _prefs?.setString(_keyProxyBaseUrl, value);

  String? get proxyAuthToken => _prefs?.getString(_keyProxyAuthToken);
  set proxyAuthToken(String? value) {
    if (value == null || value.isEmpty) {
      _prefs?.remove(_keyProxyAuthToken);
    } else {
      _prefs?.setString(_keyProxyAuthToken, value);
    }
  }

  // Transaction History (for demo purposes)
  static const _keyTransactionHistory = 'transaction_history';

  List<Map<String, dynamic>> get transactionHistory {
    final json = _prefs?.getString(_keyTransactionHistory);
    if (json == null) return [];
    final list = jsonDecode(json) as List;
    return list.cast<Map<String, dynamic>>();
  }

  void addTransaction(Map<String, dynamic> transaction) {
    final history = transactionHistory;
    history.insert(0, {
      ...transaction,
      'timestamp': DateTime.now().toIso8601String(),
    });
    // Keep only last 50 transactions
    if (history.length > 50) {
      history.removeRange(50, history.length);
    }
    _prefs?.setString(_keyTransactionHistory, jsonEncode(history));
  }

  void clearTransactionHistory() {
    _prefs?.remove(_keyTransactionHistory);
  }

  // Clear all data
  Future<void> clearAll() async {
    await _prefs?.clear();
  }
}
