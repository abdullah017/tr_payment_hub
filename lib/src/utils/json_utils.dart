/// Null-safe JSON parsing utilities.
///
/// This class provides helper methods for safely parsing JSON values
/// with proper null handling and type checking.
///
/// ## Example
///
/// ```dart
/// final json = {'name': 'John', 'age': 30, 'active': true};
///
/// // Safe parsing with defaults
/// final name = JsonUtils.getString(json, 'name'); // 'John'
/// final missing = JsonUtils.getString(json, 'missing'); // null
/// final required = JsonUtils.getRequiredString(json, 'name'); // 'John'
/// ```
class JsonUtils {
  JsonUtils._();

  /// Gets a String value from a JSON map, returning null if not found or not a String.
  ///
  /// Example:
  /// ```dart
  /// final name = JsonUtils.getString(json, 'name');
  /// ```
  static String? getString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  /// Gets a required String value from a JSON map.
  ///
  /// Throws [ArgumentError] if the key is missing or value is null.
  ///
  /// Example:
  /// ```dart
  /// final name = JsonUtils.getRequiredString(json, 'name');
  /// ```
  static String getRequiredString(
    Map<String, dynamic> json,
    String key, {
    String? fieldName,
  }) {
    final value = getString(json, key);
    if (value == null) {
      throw ArgumentError(
        'Required field "${fieldName ?? key}" is missing or null',
      );
    }
    return value;
  }

  /// Gets an int value from a JSON map, returning null if not found or not numeric.
  ///
  /// Handles both int and double values by converting to int.
  ///
  /// Example:
  /// ```dart
  /// final age = JsonUtils.getInt(json, 'age');
  /// ```
  static int? getInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Gets a required int value from a JSON map.
  ///
  /// Throws [ArgumentError] if the key is missing or value is null.
  static int getRequiredInt(
    Map<String, dynamic> json,
    String key, {
    String? fieldName,
  }) {
    final value = getInt(json, key);
    if (value == null) {
      throw ArgumentError(
        'Required field "${fieldName ?? key}" is missing or not a valid integer',
      );
    }
    return value;
  }

  /// Gets a double value from a JSON map, returning null if not found or not numeric.
  ///
  /// Example:
  /// ```dart
  /// final price = JsonUtils.getDouble(json, 'price');
  /// ```
  static double? getDouble(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Gets a required double value from a JSON map.
  ///
  /// Throws [ArgumentError] if the key is missing or value is null.
  static double getRequiredDouble(
    Map<String, dynamic> json,
    String key, {
    String? fieldName,
  }) {
    final value = getDouble(json, key);
    if (value == null) {
      throw ArgumentError(
        'Required field "${fieldName ?? key}" is missing or not a valid number',
      );
    }
    return value;
  }

  /// Gets a bool value from a JSON map, returning null if not found.
  ///
  /// Handles various truthy/falsy values:
  /// - true, 'true', '1', 1 → true
  /// - false, 'false', '0', 0 → false
  ///
  /// Example:
  /// ```dart
  /// final active = JsonUtils.getBool(json, 'active');
  /// ```
  static bool? getBool(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true' || lower == '1') return true;
      if (lower == 'false' || lower == '0') return false;
    }
    return null;
  }

  /// Gets a bool value from a JSON map with a default value.
  ///
  /// Returns the default if the key is not found or value is null.
  static bool getBoolOrDefault(
    Map<String, dynamic> json,
    String key, {
    bool defaultValue = false,
  }) =>
      getBool(json, key) ?? defaultValue;

  /// Gets a nested Map from a JSON map.
  ///
  /// Example:
  /// ```dart
  /// final address = JsonUtils.getMap(json, 'address');
  /// ```
  static Map<String, dynamic>? getMap(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  /// Gets a List from a JSON map.
  ///
  /// Example:
  /// ```dart
  /// final items = JsonUtils.getList(json, 'items');
  /// ```
  static List<dynamic>? getList(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is List) return value;
    return null;
  }

  /// Gets a typed List from a JSON map.
  ///
  /// Returns null if the key is not found or the value is not a List.
  /// Non-matching items are filtered out.
  ///
  /// Example:
  /// ```dart
  /// final names = JsonUtils.getTypedList<String>(json, 'names');
  /// ```
  static List<T>? getTypedList<T>(Map<String, dynamic> json, String key) {
    final list = getList(json, key);
    if (list == null) return null;
    return list.whereType<T>().toList();
  }

  /// Gets a DateTime from a JSON map.
  ///
  /// Supports ISO 8601 strings and Unix timestamps (seconds or milliseconds).
  ///
  /// Example:
  /// ```dart
  /// final createdAt = JsonUtils.getDateTime(json, 'created_at');
  /// ```
  static DateTime? getDateTime(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) {
      // Check if milliseconds or seconds
      if (value > 99999999999) {
        // Milliseconds
        return DateTime.fromMillisecondsSinceEpoch(value);
      } else {
        // Seconds
        return DateTime.fromMillisecondsSinceEpoch(value * 1000);
      }
    }
    return null;
  }

  /// Safely parses a JSON map from dynamic value.
  ///
  /// Returns null if the value is not a valid map.
  ///
  /// Example:
  /// ```dart
  /// final map = JsonUtils.parseMap(dynamicValue);
  /// ```
  static Map<String, dynamic>? parseMap(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  /// Parses an enum value from a JSON map.
  ///
  /// Returns the default value if the key is not found or the value
  /// doesn't match any enum value.
  ///
  /// Example:
  /// ```dart
  /// final status = JsonUtils.getEnum(
  ///   json,
  ///   'status',
  ///   PaymentStatus.values,
  ///   PaymentStatus.pending,
  /// );
  /// ```
  static T getEnum<T extends Enum>(
    Map<String, dynamic> json,
    String key,
    List<T> values,
    T defaultValue,
  ) {
    final value = getString(json, key);
    if (value == null) return defaultValue;

    try {
      return values.firstWhere(
        (e) => e.name == value || e.name.toLowerCase() == value.toLowerCase(),
        orElse: () => defaultValue,
      );
    } catch (_) {
      return defaultValue;
    }
  }

  /// Gets an enum value from a JSON map, returning null if not found.
  ///
  /// Example:
  /// ```dart
  /// final status = JsonUtils.getEnumOrNull(json, 'status', PaymentStatus.values);
  /// ```
  static T? getEnumOrNull<T extends Enum>(
    Map<String, dynamic> json,
    String key,
    List<T> values,
  ) {
    final value = getString(json, key);
    if (value == null) return null;

    try {
      return values.firstWhere(
        (e) => e.name == value || e.name.toLowerCase() == value.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }
}
