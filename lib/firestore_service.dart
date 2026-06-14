import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'app_state.dart';

class FirestoreService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  // Sync Invoices to Firestore
  static Future<void> syncInvoices(List<InvoiceModel> invoices, String licenseKey) async {
    if (licenseKey.isEmpty) return;
    try {
      final batch = _db.batch();
      for (final inv in invoices) {
        final docRef = _db.collection('licenses').doc(licenseKey).collection('invoices').doc(inv.id);
        batch.set(docRef, inv.toJson(), SetOptions(merge: true));
      }
      await batch.commit();
      debugPrint('[Firestore] Invoices synced successfully.');
    } catch (e) {
      debugPrint('[Firestore] Error syncing invoices: $e');
    }
  }

  // Sync Tables to Firestore
  static Future<void> syncTables(List<TableModel> tables, String licenseKey) async {
    if (licenseKey.isEmpty) return;
    try {
      final batch = _db.batch();
      for (final table in tables) {
        final docRef = _db.collection('licenses').doc(licenseKey).collection('tables').doc(table.id);
        batch.set(docRef, table.toJson(), SetOptions(merge: true));
      }
      await batch.commit();
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
        final docRef = _db.collection('licenses').doc(licenseKey).collection('menu_items').doc(item.id.toString());
        batch.set(docRef, item.toJson(), SetOptions(merge: true));
      }
      await batch.commit();
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
        final docRef = _db.collection('licenses').doc(licenseKey).collection('categories').doc(cat.name);
        batch.set(docRef, cat.toJson(), SetOptions(merge: true));
      }
      await batch.commit();
      debugPrint('[Firestore] Categories synced successfully.');
    } catch (e) {
      debugPrint('[Firestore] Error syncing categories: $e');
    }
  }

  // Pull Initial data from Firestore on Startup
  static Future<Map<String, dynamic>> pullInitialData(String licenseKey) async {
    final Map<String, dynamic> result = {};
    if (licenseKey.isEmpty) return result;
    try {
      // 1. Invoices
      final invoicesSnap = await _db.collection('licenses').doc(licenseKey).collection('invoices').get();
      if (invoicesSnap.docs.isNotEmpty) {
        result['invoices'] = invoicesSnap.docs.map((d) => InvoiceModel.fromJson(d.data())).toList();
      }

      // 2. Tables
      final tablesSnap = await _db.collection('licenses').doc(licenseKey).collection('tables').get();
      if (tablesSnap.docs.isNotEmpty) {
        result['tables'] = tablesSnap.docs.map((d) => TableModel.fromJson(d.data())).toList();
      }

      // 3. Menu Items
      final menuSnap = await _db.collection('licenses').doc(licenseKey).collection('menu_items').get();
      if (menuSnap.docs.isNotEmpty) {
        result['menu'] = menuSnap.docs.map((d) => MenuItem.fromJson(d.data())).toList();
      }

      // 4. Categories
      final categoriesSnap = await _db.collection('licenses').doc(licenseKey).collection('categories').get();
      if (categoriesSnap.docs.isNotEmpty) {
        result['categories'] = categoriesSnap.docs.map((d) => CategoryModel.fromJson(d.data())).toList();
      }

      debugPrint('[Firestore] Initial data pulled successfully from cloud.');
    } catch (e) {
      debugPrint('[Firestore] Error pulling initial data: $e');
    }
    return result;
  }
}
