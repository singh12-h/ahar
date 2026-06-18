import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'js_interface.dart' as js;
import 'dart:io';
import 'dart:convert';

class LocalStorageHelper {
  static final Map<String, String> _memoryStorage = {};
  static SharedPreferences? _prefs;
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
    try {
      _prefs = await SharedPreferences.getInstance();

      // 1. Migrate old native file-based storage if it exists
      if (!kIsWeb) {
        try {
          final file = File(_filePath);
          if (await file.exists()) {
            final content = await file.readAsString();
            final Map<String, dynamic> decoded = jsonDecode(content);
            for (final entry in decoded.entries) {
              final key = entry.key;
              final val = entry.value.toString();
              if (!_prefs!.containsKey(key)) {
                await _prefs!.setString(key, val);
              }
            }
            final migratedFile = File('${file.path}.migrated');
            if (await migratedFile.exists()) {
              await migratedFile.delete();
            }
            await file.rename(migratedFile.path);
            debugPrint('Successfully migrated native file storage to SharedPreferences.');
          }
        } catch (e) {
          debugPrint('Error migrating native file storage: $e');
        }
      }

      // 2. Migrate old web raw local storage if it exists
      if (kIsWeb) {
        try {
          final String? keysJson = js.context.callMethod('eval', ['JSON.stringify(Object.keys(localStorage))']) as String?;
          if (keysJson != null) {
            final List<dynamic> keys = jsonDecode(keysJson);
            for (final rawKey in keys) {
              final String key = rawKey.toString();
              if (!key.startsWith('flutter.')) {
                final String? value = js.context.callMethod('getLocalStorageKey', [key]) as String?;
                if (value != null) {
                  if (!_prefs!.containsKey(key)) {
                    await _prefs!.setString(key, value);
                  }
                  js.context.callMethod('removeLocalStorageKey', [key]);
                  debugPrint('Successfully migrated web local storage key "$key" to SharedPreferences.');
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Error migrating web local storage: $e');
        }
      }

      // 3. Load all preferences into memory cache for synchronous reads
      final keys = _prefs!.getKeys();
      for (final key in keys) {
        final val = _prefs!.get(key);
        if (val != null) {
          _memoryStorage[key] = val.toString();
        }
      }

      _initialized = true;
    } catch (e) {
      debugPrint('Error initializing LocalStorageHelper: $e');
    }
  }

  static String? getString(String key) {
    return _memoryStorage[key];
  }

  static Future<bool> setString(String key, String value) async {
    _memoryStorage[key] = value;
    if (_prefs != null) {
      return _prefs!.setString(key, value);
    }
    return false;
  }

  static Future<bool> remove(String key) async {
    _memoryStorage.remove(key);
    if (_prefs != null) {
      return _prefs!.remove(key);
    }
    return false;
  }
}

