import 'package:flutter/foundation.dart';
import 'js_interface.dart' as js;
import 'dart:io';
import 'dart:convert';

class LocalStorageHelper {
  static final Map<String, String> _memoryStorage = {};
  static bool _initialized = false;

  static String get _filePath {
    try {
      if (Platform.isWindows) {
        final appData = Platform.environment['APPDATA'];
        if (appData != null) {
          return '$appData/AharPOS/storage.json';
        }
      }
      final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      if (home != null) {
        return '$home/.ahar_pos_storage.json';
      }
    } catch (_) {}
    return 'ahar_pos_storage.json';
  }

  static Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) {
      _initialized = true;
      return;
    }
    try {
      final file = File(_filePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final Map<String, dynamic> decoded = jsonDecode(content);
        decoded.forEach((key, value) {
          _memoryStorage[key] = value.toString();
        });
      }
      _initialized = true;
    } catch (e) {
      debugPrint('Error initializing LocalStorageHelper from file: $e');
    }
  }

  static String? getString(String key) {
    if (kIsWeb) {
      try {
        final result = js.context.callMethod('getLocalStorageKey', [key]);
        return result as String?;
      } catch (e) {
        debugPrint('Error reading Web localStorage for key "$key": $e');
        return null;
      }
    } else {
      return _memoryStorage[key];
    }
  }

  static Future<bool> setString(String key, String value) async {
    if (kIsWeb) {
      try {
        js.context.callMethod('setLocalStorageKey', [key, value]);
        return true;
      } catch (e) {
        debugPrint('Error writing Web localStorage for key "$key": $e');
        return false;
      }
    } else {
      _memoryStorage[key] = value;
      return _saveToFile();
    }
  }

  static Future<bool> remove(String key) async {
    if (kIsWeb) {
      try {
        js.context.callMethod('removeLocalStorageKey', [key]);
        return true;
      } catch (e) {
        debugPrint('Error removing Web localStorage for key "$key": $e');
        return false;
      }
    } else {
      _memoryStorage.remove(key);
      return _saveToFile();
    }
  }

  static Future<bool> _saveToFile() async {
    try {
      final file = File(_filePath);
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
      await file.writeAsString(jsonEncode(_memoryStorage));
      return true;
    } catch (e) {
      debugPrint('Error writing LocalStorageHelper to file: $e');
      return false;
    }
  }
}

