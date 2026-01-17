import 'package:tr_payment_hub/tr_payment_hub.dart';

import 'storage_service.dart';

export 'package:tr_payment_hub/tr_payment_hub.dart' show ProxyConfig;

/// Central service for managing payment providers and operations.
class PaymentService {
  PaymentService._();
  static PaymentService? _instance;
  static PaymentService get instance => _instance ??= PaymentService._();

  PaymentProvider? _provider;
  String _currentProviderType = 'mock';
  bool _isInitialized = false;

  // Logging
  final List<RequestLogEntry> _logs = [];
  List<RequestLogEntry> get logs => List.unmodifiable(_logs);
  void Function(RequestLogEntry)? onLog;

  // Metrics
  InMemoryMetricsCollector? _metricsCollector;
  InMemoryMetricsCollector? get metricsCollector => _metricsCollector;

  /// Currently active provider
  PaymentProvider? get provider => _provider;

  /// Current provider type
  String get currentProviderType => _currentProviderType;

  /// Whether provider is initialized
  bool get isInitialized => _isInitialized;

  /// Provider capabilities
  bool get supportsSavedCards => _provider?.supportsSavedCards ?? false;
  bool get supportsInstallments => _provider?.supportsInstallments ?? false;

  /// Initialize provider with configuration from storage
  Future<void> initializeProvider(String providerType) async {
    // Dispose existing provider
    _provider?.dispose();
    _isInitialized = false;
    _currentProviderType = providerType;

    // Create metrics collector
    _metricsCollector = InMemoryMetricsCollector();

    // Create request logger
    final requestLogger = RequestLogger(
      config: RequestLoggerConfig.full,
      onLog: (entry) {
        _logs.add(entry);
        if (_logs.length > 200) {
          _logs.removeAt(0);
        }
        onLog?.call(entry);
      },
    );

    final storage = StorageService.instance;
    final isSandbox = storage.useSandbox;

    // Check if proxy mode is enabled
    if (storage.useProxyMode && providerType != 'mock') {
      await _initializeProxyProvider(providerType, requestLogger);
      return;
    }

    if (providerType == 'mock') {
      _provider = TrPaymentHub.createMock(shouldSucceed: true);
      // Mock doesn't need real config, use iyzico config for compatibility
      await _provider!.initialize(
        IyzicoConfig(
          merchantId: 'mock_merchant',
          apiKey: 'mock_api_key',
          secretKey: 'mock_secret',
          isSandbox: true,
        ),
      );
      _isInitialized = true;
      return;
    }

    final config = storage.getProviderConfig(providerType);
    if (config == null || config.isEmpty) {
      throw PaymentException(
        code: 'CONFIG_MISSING',
        message: 'Provider configuration not found. Please configure $providerType in Settings.',
      );
    }

    // Create HTTP network client with logging
    final httpClient = HttpNetworkClient(requestLogger: requestLogger);

    switch (providerType) {
      case 'iyzico':
        _provider = IyzicoProvider(
          networkClient: httpClient,
          metricsCollector: _metricsCollector,
        );
        await _provider!.initialize(
          IyzicoConfig(
            merchantId: config['merchantId'] ?? '',
            apiKey: config['apiKey'] ?? '',
            secretKey: config['secretKey'] ?? '',
            isSandbox: isSandbox,
          ),
        );
        break;

      case 'paytr':
        _provider = PayTRProvider(
          networkClient: httpClient,
          metricsCollector: _metricsCollector,
        );
        await _provider!.initialize(
          PayTRConfig(
            merchantId: config['merchantId'] ?? '',
            apiKey: config['apiKey'] ?? '',
            secretKey: config['secretKey'] ?? '',
            successUrl: config['successUrl'] ?? 'https://example.com/success',
            failUrl: config['failUrl'] ?? 'https://example.com/fail',
            callbackUrl: config['callbackUrl'] ?? 'https://example.com/callback',
            isSandbox: isSandbox,
          ),
        );
        break;

      case 'sipay':
        _provider = SipayProvider(
          networkClient: httpClient,
          metricsCollector: _metricsCollector,
        );
        await _provider!.initialize(
          SipayConfig(
            merchantId: config['merchantId'] ?? '',
            apiKey: config['apiKey'] ?? '',
            secretKey: config['secretKey'] ?? '',
            merchantKey: config['merchantKey'] ?? '',
            isSandbox: isSandbox,
          ),
        );
        break;

      case 'param':
        _provider = ParamProvider(
          networkClient: httpClient,
          metricsCollector: _metricsCollector,
        );
        await _provider!.initialize(
          ParamConfig(
            merchantId: config['merchantId'] ?? '',
            apiKey: config['apiKey'] ?? '',
            secretKey: config['secretKey'] ?? '',
            guid: config['guid'] ?? '',
            isSandbox: isSandbox,
          ),
        );
        break;

      default:
        throw PaymentException(
          code: 'UNKNOWN_PROVIDER',
          message: 'Unknown provider type: $providerType',
        );
    }

    _isInitialized = true;
  }

  /// Initialize proxy provider for backend mode
  Future<void> _initializeProxyProvider(String providerType, RequestLogger requestLogger) async {
    final storage = StorageService.instance;

    final proxyConfig = ProxyConfig(
      baseUrl: storage.proxyBaseUrl,
      authToken: storage.proxyAuthToken,
    );

    final httpClient = HttpNetworkClient(requestLogger: requestLogger);

    final proxyProvider = ProxyPaymentProvider(
      config: proxyConfig,
      networkClient: httpClient,
    );

    // Map string to ProviderType enum
    final providerTypeEnum = switch (providerType) {
      'iyzico' => ProviderType.iyzico,
      'paytr' => ProviderType.paytr,
      'sipay' => ProviderType.sipay,
      'param' => ProviderType.param,
      _ => ProviderType.iyzico,
    };

    await proxyProvider.initializeWithProvider(providerTypeEnum);

    _provider = proxyProvider;
    _isInitialized = true;
  }

  /// Clear logs
  void clearLogs() {
    _logs.clear();
  }

  /// Dispose current provider
  void dispose() {
    _provider?.dispose();
    _provider = null;
    _isInitialized = false;
  }
}

/// Provider type information
class ProviderInfo {
  final String id;
  final String name;
  final String description;
  final bool supportsSavedCards;
  final bool supports3DS;
  final List<String> requiredFields;

  const ProviderInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.supportsSavedCards,
    required this.supports3DS,
    required this.requiredFields,
  });

  static const List<ProviderInfo> all = [
    ProviderInfo(
      id: 'mock',
      name: 'Mock (Demo)',
      description: 'Test provider for development - no real transactions',
      supportsSavedCards: true,
      supports3DS: true,
      requiredFields: [],
    ),
    ProviderInfo(
      id: 'iyzico',
      name: 'iyzico',
      description: 'Turkey\'s leading payment platform',
      supportsSavedCards: true,
      supports3DS: true,
      requiredFields: ['merchantId', 'apiKey', 'secretKey'],
    ),
    ProviderInfo(
      id: 'paytr',
      name: 'PayTR',
      description: 'Popular Turkish payment gateway with iframe checkout',
      supportsSavedCards: false,
      supports3DS: true,
      requiredFields: ['merchantId', 'apiKey', 'secretKey', 'successUrl', 'failUrl', 'callbackUrl'],
    ),
    ProviderInfo(
      id: 'sipay',
      name: 'Sipay',
      description: 'Modern payment solution with card storage',
      supportsSavedCards: true,
      supports3DS: true,
      requiredFields: ['merchantId', 'apiKey', 'secretKey', 'merchantKey'],
    ),
    ProviderInfo(
      id: 'param',
      name: 'Param',
      description: 'TurkPos integration via SOAP/XML API',
      supportsSavedCards: false,
      supports3DS: true,
      requiredFields: ['merchantId', 'apiKey', 'secretKey', 'guid'],
    ),
  ];

  static ProviderInfo? getById(String id) {
    return all.where((p) => p.id == id).firstOrNull;
  }
}
