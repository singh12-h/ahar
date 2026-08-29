import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'storage_helper.dart';
import 'app_state.dart';
import 'tenant_db_manager.dart';

class FirestoreService {
  static FirebaseFirestore get _db => TenantDbManager.instance;

  static void _queueOfflineDelete(String collection, String docId) {
    final rawQueue = LocalStorageHelper.getString('ahar_offline_deletes') ?? '[]';
    final List<dynamic> queue = jsonDecode(rawQueue);
    queue.add({'collection': collection, 'docId': docId});
    LocalStorageHelper.setString('ahar_offline_deletes', jsonEncode(queue));
  }

  static Future<void> processOfflineDeletes() async {
    final rawQueue = LocalStorageHelper.getString('ahar_offline_deletes');
    if (rawQueue == null) return;
    
    final List<dynamic> queue = jsonDecode(rawQueue);
    if (queue.isEmpty) return;
    
    try {
      final chunkSize = 500;
      for (var i = 0; i < queue.length; i += chunkSize) {
        final batch = _db.batch();
        final end = (i + chunkSize < queue.length) ? i + chunkSize : queue.length;
        final chunk = queue.sublist(i, end);
        
        for (var item in chunk) {
          final docRef = _db.collection(item['collection']).doc(item['docId']);
          batch.delete(docRef);
        }
        await batch.commit();
      }
      LocalStorageHelper.remove('ahar_offline_deletes');
      debugPrint('[Firestore] Offline deletes processed successfully.');
    } catch (e) {
      debugPrint('[Firestore] Error processing offline deletes: $e');
    }
  }

  // Sync Invoices to Firestore
  static Future<void> syncInvoices(List<InvoiceModel> invoices, String licenseKey, {void Function(String)? onProgress, List<String>? itemsToSync, bool forceAll = false}) async {
    final cleanKey = licenseKey.trim().toUpperCase();
    if (cleanKey.isEmpty) return;
    if (itemsToSync == null && !forceAll) {
      debugPrint('[Firestore] syncInvoices called with null itemsToSync and forceAll is false. Skipping bulk upload to save writes.');
      return;
    }
    await processOfflineDeletes();
    try {
      final chunkSize = 400;
      for (var i = 0; i < invoices.length; i += chunkSize) {
        final batch = _db.batch();
        final end = (i + chunkSize < invoices.length) ? i + chunkSize : invoices.length;
        final chunk = invoices.sublist(i, end);
        
        if (onProgress != null) {
          onProgress('Uploading Invoices: $end / ${invoices.length}...');
        }
        
        for (final inv in chunk) {
          if (!forceAll && itemsToSync != null && !itemsToSync.contains(inv.id)) continue;
          final docRef = _db.collection('${cleanKey}_invoices').doc(inv.id);
          batch.set(docRef, inv.toJson(), SetOptions(merge: true));
        }
        await batch.commit();
      }
      debugPrint('[Firestore] Invoices synced successfully.');
    } catch (e) {
      debugPrint('[Firestore] Error syncing invoices: $e');
      rethrow;
    }
  }

  static Future<void> deleteInvoice(String invoiceId, String licenseKey) async {
    final cleanKey = licenseKey.trim().toUpperCase();
    if (cleanKey.isEmpty) return;
    final coll = '${cleanKey}_invoices';
    try {
      await _db.collection(coll).doc(invoiceId).delete();
      debugPrint('[Firestore] Invoice $invoiceId deleted successfully.');
    } catch (e) {
      debugPrint('[Firestore] Error deleting invoice $invoiceId: $e');
      _queueOfflineDelete(coll, invoiceId);
    }
  }

  // Sync Tables to Firestore
  static Future<void> syncTables(
    List<TableModel> tablesList,
    String licenseKey, {
    required Map<String, List<CartItem>> activeCarts,
    required Map<String, String> tableOccupiedTimes,
    List<String>? tablesToSync,
    bool forceAll = false,
  }) async {
    if (licenseKey.isEmpty) return;
    if (tablesToSync == null && !forceAll) {
      debugPrint('[Firestore] syncTables called with null tablesToSync and forceAll is false. Skipping bulk upload to save writes.');
      return;
    }
    await processOfflineDeletes();
    try {
      final batch = _db.batch();
      for (final table in tablesList) {
        if (!forceAll && tablesToSync != null && tablesToSync.isNotEmpty && !tablesToSync.contains(table.id)) continue;
        
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
      await batch.commit();
      debugPrint('[Firestore] Tables synced successfully.');
    } catch (e) {
      debugPrint('[Firestore] Error syncing tables: $e');
      rethrow;
    }
  }

  // Sync Menu Items to Firestore
  static Future<void> syncMenu(List<MenuItem> menu, String licenseKey, {List<String>? itemsToSync, bool forceAll = false}) async {
    if (licenseKey.isEmpty) return;
    if (itemsToSync == null && !forceAll) {
      debugPrint('[Firestore] syncMenu called with null itemsToSync and forceAll is false. Skipping bulk upload to save writes.');
      return;
    }
    await processOfflineDeletes();
    try {
      final chunkSize = 50;
      for (var i = 0; i < menu.length; i += chunkSize) {
        final batch = _db.batch();
        final end = (i + chunkSize < menu.length) ? i + chunkSize : menu.length;
        final chunk = menu.sublist(i, end);
        for (final item in chunk) {
          if (!forceAll && itemsToSync != null && !itemsToSync.contains(item.id.toString())) continue;
          final docRef = _db.collection('${licenseKey}_menu_items').doc(item.id.toString());
          batch.set(docRef, item.toJson(), SetOptions(merge: true));
        }
        await batch.commit().timeout(const Duration(seconds: 15), onTimeout: () {
          throw Exception('Timeout while syncing menu chunk.');
        });
      }
      debugPrint('[Firestore] Menu items synced successfully.');
    } catch (e) {
      debugPrint('[Firestore] Error syncing menu items: $e');
      rethrow;
    }
  }

  // Sync Categories to Firestore
  static Future<void> syncCategories(List<CategoryModel> categories, String licenseKey, {List<String>? itemsToSync, bool forceAll = false}) async {
    if (licenseKey.isEmpty) return;
    if (itemsToSync == null && !forceAll) {
      debugPrint('[Firestore] syncCategories called with null itemsToSync and forceAll is false. Skipping bulk upload to save writes.');
      return;
    }
    await processOfflineDeletes();
    try {
      final chunkSize = 50;
      for (var i = 0; i < categories.length; i += chunkSize) {
        final batch = _db.batch();
        final end = (i + chunkSize < categories.length) ? i + chunkSize : categories.length;
        final chunk = categories.sublist(i, end);
        for (final cat in chunk) {
          if (!forceAll && itemsToSync != null && !itemsToSync.contains(cat.name)) continue;
          final docRef = _db.collection('${licenseKey}_categories').doc(cat.name);
          batch.set(docRef, cat.toJson(), SetOptions(merge: true));
        }
        await batch.commit().timeout(const Duration(seconds: 15), onTimeout: () {
          throw Exception('Timeout while syncing categories chunk.');
        });
      }
      debugPrint('[Firestore] Categories synced successfully.');
    } catch (e) {
      debugPrint('[Firestore] Error syncing categories: $e');
      rethrow;
    }
  }

  // Sync Users to Firestore
  static Future<void> syncUsers(List<UserProfile> usersList, String licenseKey, {List<String>? itemsToSync, bool forceAll = false}) async {
    if (licenseKey.isEmpty) return;
    if (itemsToSync == null && !forceAll) {
      debugPrint('[Firestore] syncUsers called with null itemsToSync and forceAll is false. Skipping bulk upload to save writes.');
      return;
    }
    await processOfflineDeletes();
    try {
      final batch = _db.batch();
      for (final user in usersList) {
        if (!forceAll && itemsToSync != null && !itemsToSync.contains(user.name)) continue;
        final docRef = _db.collection('${licenseKey}_users').doc(user.name);
        batch.set(docRef, user.toJson(), SetOptions(merge: true));
      }
      await batch.commit();
      debugPrint('[Firestore] Users synced successfully.');
    } catch (e) {
      debugPrint('[Firestore] Error syncing users: $e');
      rethrow;
    }
  }

  // Deletion Methods
  static Future<void> deleteTable(String tableId, String licenseKey) async {
    if (licenseKey.isEmpty) return;
    final coll = '${licenseKey}_tables';
    try {
      await _db.collection(coll).doc(tableId).delete();
      debugPrint('[Firestore] Table $tableId deleted successfully.');
    } catch (e) {
      debugPrint('[Firestore] Error deleting table $tableId: $e');
      _queueOfflineDelete(coll, tableId);
    }
  }

  static Future<void> deleteMenuItem(String menuId, String licenseKey) async {
    if (licenseKey.isEmpty) return;
    final coll = '${licenseKey}_menu_items';
    try {
      await _db.collection(coll).doc(menuId).delete();
      debugPrint('[Firestore] Menu Item $menuId deleted successfully.');
    } catch (e) {
      debugPrint('[Firestore] Error deleting menu item $menuId: $e');
      _queueOfflineDelete(coll, menuId);
    }
  }

  static Future<void> deleteCategory(String categoryName, String licenseKey) async {
    if (licenseKey.isEmpty) return;
    final coll = '${licenseKey}_categories';
    try {
      await _db.collection(coll).doc(categoryName).delete();
      debugPrint('[Firestore] Category $categoryName deleted successfully.');
    } catch (e) {
      debugPrint('[Firestore] Error deleting category $categoryName: $e');
      _queueOfflineDelete(coll, categoryName);
    }
  }

  static Future<void> deleteUser(String userName, String licenseKey) async {
    if (licenseKey.isEmpty) return;
    final coll = '${licenseKey}_users';
    try {
      await _db.collection(coll).doc(userName).delete();
      debugPrint('[Firestore] User $userName deleted successfully.');
    } catch (e) {
      debugPrint('[Firestore] Error deleting user $userName: $e');
      _queueOfflineDelete(coll, userName);
    }
  }

  // Pull Initial data from Firestore on Startup (Optimized for minimal reads)
  static Future<Map<String, dynamic>> pullInitialData(String licenseKey) async {
    final Map<String, dynamic> result = {};
    if (licenseKey.isEmpty) return result;
    try {
      // Just check if menu exists to see if the database is brand new.
      // We use limit(1) so it costs exactly 1 read, instead of fetching the whole menu!
      final menuSnap = await _db.collection('${licenseKey}_menu_items').limit(1).get(const GetOptions(source: Source.server)).timeout(const Duration(seconds: 4));
      if (menuSnap.docs.isNotEmpty) {
        // If menu is not empty, we assume the DB is initialized.
        result['is_initialized'] = true;
      }
      debugPrint('[Firestore] Initialization check completed.');
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
      await batch.commit();
      debugPrint('[Firestore] Diagnostics synced to cloud successfully.');
    } catch (e) {
      debugPrint('[Firestore] Error syncing diagnostics to cloud: $e');
    }
  }
}
