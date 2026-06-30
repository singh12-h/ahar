import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'app_state.dart';
import 'tenant_db_manager.dart';

class FirestoreService {
  static FirebaseFirestore get _db => TenantDbManager.instance;

  // Sync Invoices to Firestore
  static Future<void> syncInvoices(List<InvoiceModel> invoices, String licenseKey) async {
    if (licenseKey.isEmpty) return;
    try {
      final batch = _db.batch();
      for (final inv in invoices) {
        final docRef = _db.collection('${licenseKey}_invoices').doc(inv.id);
        batch.set(docRef, inv.toJson(), SetOptions(merge: true));
      }
      await batch.commit().timeout(const Duration(seconds: 4));
      debugPrint('[Firestore] Invoices synced successfully.');
    } catch (e) {
      debugPrint('[Firestore] Error syncing invoices: $e');
    }
  }

  // Sync Tables to Firestore
  static Future<void> syncTables(
    List<TableModel> tables,
    String licenseKey, {
    Map<String, List<CartItem>>? activeCarts,
    Map<String, String>? tableOccupiedTimes,
  }) async {
    if (licenseKey.isEmpty) return;
    try {
      final batch = _db.batch();
      for (final table in tables) {
        final docRef = _db.collection('${licenseKey}_tables').doc(table.id);
        
        final cartList = activeCarts != null ? (activeCarts[table.id] ?? []) : [];
        final occupyTime = tableOccupiedTimes != null ? (tableOccupiedTimes[table.id] ?? '') : '';
        
        final Map<String, dynamic> data = {
          'id': table.id,
          'type': table.type,
          'occupied': cartList.isNotEmpty || occupyTime.isNotEmpty,
          'occupyTime': occupyTime,
          'items': cartList.map((item) => item.toJson()).toList(),
          'subtotal': cartList.fold<double>(0, (sum, item) => sum + (item.price * item.qty)),
        };
        batch.set(docRef, data, SetOptions(merge: true));
      }
      await batch.commit().timeout(const Duration(seconds: 4));
      debugPrint('[Firestore] Tables synced successfully.');
    } catch (e) {
      debugPrint('[Firestore] Error syncing tables: $e');
    }
  }

  // Sync Menu Items to Firestore
  static Future<void> syncMenu(List<MenuItem> menu, String licenseKey) async {
    if (licenseKey.isEmpty) return;
    try {
      final batch = _db.batch();
      for (final item in menu) {
        final docRef = _db.collection('${licenseKey}_menu_items').doc(item.id.toString());
        batch.set(docRef, item.toJson(), SetOptions(merge: true));
      }
      await batch.commit().timeout(const Duration(seconds: 4));
      debugPrint('[Firestore] Menu items synced successfully.');
    } catch (e) {
      debugPrint('[Firestore] Error syncing menu items: $e');
    }
  }

  // Sync Categories to Firestore
  static Future<void> syncCategories(List<CategoryModel> categories, String licenseKey) async {
    if (licenseKey.isEmpty) return;
    try {
      final batch = _db.batch();
      for (final cat in categories) {
        final docRef = _db.collection('${licenseKey}_categories').doc(cat.name);
        batch.set(docRef, cat.toJson(), SetOptions(merge: true));
      }
      await batch.commit().timeout(const Duration(seconds: 4));
      debugPrint('[Firestore] Categories synced successfully.');
    } catch (e) {
      debugPrint('[Firestore] Error syncing categories: $e');
    }
  }

  // Sync Users to Firestore
  static Future<void> syncUsers(List<UserProfile> usersList, String licenseKey) async {
    if (licenseKey.isEmpty) return;
    try {
      final batch = _db.batch();
      for (final user in usersList) {
        final docRef = _db.collection('${licenseKey}_users').doc(user.name);
        batch.set(docRef, user.toJson(), SetOptions(merge: true));
      }
      await batch.commit().timeout(const Duration(seconds: 4));
      debugPrint('[Firestore] Users synced successfully.');
    } catch (e) {
      debugPrint('[Firestore] Error syncing users: $e');
    }
  }

  // Pull Initial data from Firestore on Startup
  static Future<Map<String, dynamic>> pullInitialData(String licenseKey) async {
    final Map<String, dynamic> result = {};
    if (licenseKey.isEmpty) return result;
    try {
      // 1. Invoices
      final invoicesSnap = await _db.collection('${licenseKey}_invoices').get().timeout(const Duration(seconds: 4));
      if (invoicesSnap.docs.isNotEmpty) {
        result['invoices'] = invoicesSnap.docs.map((d) => InvoiceModel.fromJson(d.data())).toList();
      }

      // 2. Tables
      final tablesSnap = await _db.collection('${licenseKey}_tables').get().timeout(const Duration(seconds: 4));
      if (tablesSnap.docs.isNotEmpty) {
        result['tables'] = tablesSnap.docs.map((d) => TableModel.fromJson(d.data())).toList();
        final Map<String, List<CartItem>> activeCarts = {};
        final Map<String, String> occupiedTimes = {};
        for (final doc in tablesSnap.docs) {
          final data = doc.data();
          final tableId = doc.id;
          final occupyTime = data['occupyTime'] as String?;
          if (occupyTime != null && occupyTime.isNotEmpty) {
            occupiedTimes[tableId] = occupyTime;
          }
          final itemsList = data['items'] as List?;
          if (itemsList != null && itemsList.isNotEmpty) {
            activeCarts[tableId] = itemsList.map((i) => CartItem.fromJson(Map<String, dynamic>.from(i))).toList();
          }
        }
        result['activeCarts'] = activeCarts;
        result['tableOccupiedTimes'] = occupiedTimes;
      }

      // 3. Menu Items
      final menuSnap = await _db.collection('${licenseKey}_menu_items').get().timeout(const Duration(seconds: 4));
      if (menuSnap.docs.isNotEmpty) {
        result['menu'] = menuSnap.docs.map((d) => MenuItem.fromJson(d.data())).toList();
      }

      // 4. Categories
      final categoriesSnap = await _db.collection('${licenseKey}_categories').get().timeout(const Duration(seconds: 4));
      if (categoriesSnap.docs.isNotEmpty) {
        result['categories'] = categoriesSnap.docs.map((d) => CategoryModel.fromJson(d.data())).toList();
      }

      // 5. Users
      final usersSnap = await _db.collection('${licenseKey}_users').get().timeout(const Duration(seconds: 4));
      if (usersSnap.docs.isNotEmpty) {
        result['users'] = usersSnap.docs.map((d) => UserProfile.fromJson(d.data())).toList();
      }

      debugPrint('[Firestore] Initial data pulled successfully from cloud.');
    } catch (e) {
      debugPrint('[Firestore] Error pulling initial data: $e');
    }
    return result;
  }

  // Sync Diagnostics/Bluetooth logs to Firestore
  static Future<void> syncDiagnostics(List<BluetoothLogEntry> logs, String licenseKey) async {
    if (licenseKey.isEmpty) return;
    try {
      final batch = _db.batch();
      // Only keep the most recent 15 logs to prevent excessive document counts on Firestore
      final recentLogs = logs.length > 15 ? logs.sublist(0, 15) : logs;
      for (final log in recentLogs) {
        final docRef = _db
            .collection('logs')
            .doc(log.timestamp.millisecondsSinceEpoch.toString());
        batch.set(docRef, log.toJson(), SetOptions(merge: true));
      }
      await batch.commit().timeout(const Duration(seconds: 4));
      debugPrint('[Firestore] Diagnostics synced to cloud successfully.');
    } catch (e) {
      debugPrint('[Firestore] Error syncing diagnostics to cloud: $e');
    }
  }
}
