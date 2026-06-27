import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class TenantDbManager {
  static FirebaseApp? _tenantApp;
  static FirebaseFirestore? _tenantFirestore;

  /// Initializes a secondary Firebase App using the tenant's specific credentials
  static Future<void> initialize(Map<String, dynamic> config) async {
    try {
      if (_tenantApp != null) {
        if (_tenantApp!.options.projectId == config['projectId']) {
          return; // Already initialized for this tenant
        } else {
          // Delete old instance if switching tenants (edge case)
          await _tenantApp!.delete();
          _tenantApp = null;
        }
      }

      final options = FirebaseOptions(
        apiKey: config['apiKey'] ?? '',
        appId: config['appId'] ?? '',
        messagingSenderId: config['messagingSenderId'] ?? '',
        projectId: config['projectId'] ?? '',
        authDomain: config['authDomain'],
        storageBucket: config['storageBucket'],
      );

      _tenantApp = await Firebase.initializeApp(
        name: 'TenantApp_${config['projectId']}',
        options: options,
      );

      _tenantFirestore = FirebaseFirestore.instanceFor(app: _tenantApp!);
      debugPrint('[TenantDbManager] Initialized isolated database for ${config['projectId']}');
    } catch (e) {
      debugPrint('[TenantDbManager] Error initializing tenant DB: $e');
      rethrow;
    }
  }

  static bool _warned = false;

  /// Returns the Firestore instance for the active tenant
  static FirebaseFirestore get instance {
    if (_tenantFirestore == null) {
      if (!_warned) {
        debugPrint('[TenantDbManager] WARNING: Using master fallback DB because tenant DB is not initialized. Check your license config.');
        _warned = true;
      }
      return FirebaseFirestore.instance; // Fallback to master if missing
    }
    return _tenantFirestore!;
  }
  
  static bool get isInitialized => _tenantFirestore != null;
}
