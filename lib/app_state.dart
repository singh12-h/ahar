import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'storage_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'firestore_service.dart';
import 'js_interface.dart' as js;
import 'tenant_db_manager.dart';
import 'default_menu_data.dart';

// --- DATA MODELS ---

class UserProfile {
  final String name;
  final String pin;
  final String role; // 'owner' or 'cashier'

  UserProfile({required this.name, required this.pin, required this.role});

  Map<String, dynamic> toJson() => {'name': name, 'pin': pin, 'role': role};
  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    name: json['name'],
    pin: json['pin'],
    role: json['role'] ?? 'cashier',
  );
}

class MenuItem {
  final int id;
  final String name;
  final int price;
  final String category;
  final String desc;
  final int serialNumber;
  final bool isVeg;
  final int gstRate;

  MenuItem({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    this.desc = '',
    int? serialNumber,
    this.isVeg = true,
    this.gstRate = 5,
  }) : this.serialNumber = serialNumber ?? id;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
    'category': category,
    'desc': desc,
    'serialNumber': serialNumber,
    'isVeg': isVeg,
    'gstRate': gstRate,
  };

  factory MenuItem.fromJson(Map<String, dynamic> json) => MenuItem(
    id: json['id'],
    name: json['name'],
    price: json['price'],
    category: json['category'],
    desc: json['desc'] ?? '',
    serialNumber: json['serialNumber'] ?? json['id'],
    isVeg: json['isVeg'] ?? true,
    gstRate: json['gstRate'] ?? 5,
  );
}

class CartItem {
  final int id;
  final String name;
  final int price;
  final String category;
  final int gstRate;
  int qty;
  int printedQty;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.qty,
    this.gstRate = 5,
    this.printedQty = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
    'category': category,
    'qty': qty,
    'gstRate': gstRate,
    'printedQty': printedQty,
  };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
    id: json['id'],
    name: json['name'],
    price: json['price'],
    category: json['category'],
    qty: json['qty'],
    gstRate: json['gstRate'] ?? 5,
    printedQty: json['printedQty'] ?? 0,
  );
}

class TableModel {
  final String id;
  final String type; // 'table' or 'parcel'

  TableModel({required this.id, required this.type});

  Map<String, dynamic> toJson() => {'id': id, 'type': type};

  factory TableModel.fromJson(Map<String, dynamic> json) => TableModel(
    id: json['id'],
    type: json['type'],
  );
}

class CategoryModel {
  final String name;
  final int serialNumber;

  CategoryModel({required this.name, required this.serialNumber});

  Map<String, dynamic> toJson() => {
    'name': name,
    'serialNumber': serialNumber,
  };

  factory CategoryModel.fromJson(Map<String, dynamic> json) => CategoryModel(
    name: json['name'],
    serialNumber: json['serialNumber'] ?? 0,
  );
}

DateTime? parseInvoiceDateHelper(String dateStr) {
  try {
    final parts = dateStr.split(', ');
    final dateParts = parts[0].split('/');
    final day = int.parse(dateParts[0]);
    final month = int.parse(dateParts[1]);
    final year = int.parse(dateParts[2]);

    final timeParts = parts[1].split(' ');
    final timeHMS = timeParts[0].split(':');
    var hour = int.parse(timeHMS[0]);
    final minute = int.parse(timeHMS[1]);
    final second = int.parse(timeHMS[2]);
    final ampm = timeParts[1].toUpperCase();

    if (ampm == 'PM' && hour < 12) {
      hour += 12;
    } else if (ampm == 'AM' && hour == 12) {
      hour = 0;
    }

    return DateTime(year, month, day, hour, minute, second);
  } catch (e) {
    return null;
  }
}

class InvoiceModel {
  final String id;
  final String tableId;
  final String dateTime;
  final String? checkInTime;
  final List<CartItem> items;
  final int subtotal;
  final int gst;
  final int packaging;
  final int total;
  final int? originalTotal;
  final double discountPercent;

  DateTime? _cachedDateTime;
  DateTime get parsedDateTime {
    _cachedDateTime ??= parseInvoiceDateHelper(dateTime) ?? DateTime.now();
    return _cachedDateTime!;
  }

  InvoiceModel({
    required this.id,
    required this.tableId,
    required this.dateTime,
    this.checkInTime,
    required this.items,
    required this.subtotal,
    required this.gst,
    required this.packaging,
    required this.total,
    this.originalTotal,
    this.discountPercent = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'tableId': tableId,
    'dateTime': dateTime,
    'checkInTime': checkInTime,
    'items': items.map((i) => i.toJson()).toList(),
    'subtotal': subtotal,
    'gst': gst,
    'packaging': packaging,
    'total': total,
    'originalTotal': originalTotal ?? total,
    'discountPercent': discountPercent,
  };

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    var itemsList = json['items'] as List? ?? [];
    return InvoiceModel(
      id: json['id'],
      tableId: json['tableId'],
      dateTime: json['dateTime'],
      checkInTime: json['checkInTime'],
      items: itemsList.map((i) => CartItem.fromJson(i)).toList(),
      subtotal: json['subtotal'],
      gst: json['gst'],
      packaging: json['packaging'],
      total: json['total'],
      originalTotal: json['originalTotal'] ?? json['total'],
      discountPercent: (json['discountPercent'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// --- BLUETOOTH DIAGNOSTIC LOG MODEL ---

class BluetoothLogEntry {
  final DateTime timestamp;
  final String event;      // e.g. 'CONNECT', 'DISCONNECT', 'PRINT', 'SCAN', 'ERROR'
  final String message;    // Human-readable description
  final String diagnosis;  // 'APP_SIDE', 'MACHINE_SIDE', 'NETWORK', 'UNKNOWN'
  final String? macAddress;
  final String? errorDetail;

  BluetoothLogEntry({
    required this.event,
    required this.message,
    required this.diagnosis,
    this.macAddress,
    this.errorDetail,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String get formattedDate {
    final d = timestamp.day.toString().padLeft(2, '0');
    final mo = timestamp.month.toString().padLeft(2, '0');
    final y = timestamp.year;
    return '$d/$mo/$y';
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'event': event,
      'message': message,
      'diagnosis': diagnosis,
      'macAddress': macAddress,
      'errorDetail': errorDetail,
    };
  }

  factory BluetoothLogEntry.fromJson(Map<String, dynamic> json) {
    return BluetoothLogEntry(
      event: json['event'] ?? 'UNKNOWN',
      message: json['message'] ?? '',
      diagnosis: json['diagnosis'] ?? 'UNKNOWN',
      macAddress: json['macAddress'],
      errorDetail: json['errorDetail'],
      timestamp: json['timestamp'] != null ? DateTime.tryParse(json['timestamp']) : null,
    );
  }
}

// --- APP STATE NOTIFIER ---

class AppState extends ChangeNotifier {
  int appId = 104;

  // Branding variables
  String storeName = "AAHAR SANDWICH & CHINESE";
  String storeGstin = "24ACAPR9698D1Z8";
  double parcelDeliveryCharge = 40.0;
  bool isGstInclusive = true;
  double cartDiscountPercent = 0.0;
  bool showGstOnBills = true;
  bool allowDiscounts = true;
  int defaultGstRate = 5;

  // Printer Connection
  bool isPrinterConnected = false;
  List<BluetoothInfo> availablePrinters = [];
  bool isBtScanning = false;
  String connectedPrinterMac = '';
  String connectedPrinterName = '';
  bool isBluetoothEnabled = true;
  String selectedPrinterType = 'bluetooth'; // 'bluetooth', 'wifi'
  String printerIpAddress = '192.168.1.100';

  // Bluetooth Diagnostic Logs
  List<BluetoothLogEntry> btLogs = [];
  static const int _maxBtLogs = 200;

  DateTime? _lastDiagnosticsSync;

  void addBtLog(String event, String message, String diagnosis, {String? mac, String? error}) {
    btLogs.insert(0, BluetoothLogEntry(
      event: event,
      message: message,
      diagnosis: diagnosis,
      macAddress: mac ?? connectedPrinterMac,
      errorDetail: error,
    ));
    if (btLogs.length > _maxBtLogs) {
      btLogs = btLogs.sublist(0, _maxBtLogs);
    }
    debugPrint('[BT-LOG] [$event] $message | Diagnosis: $diagnosis${error != null ? ' | Error: $error' : ''}');
    notifyListeners();

    // Throttled: sync diagnostics at most once every 5 minutes to save Firestore writes
    if (saasLicenseKey.isNotEmpty && (event == 'ERROR' || event == 'CONNECT' || event == 'DISCONNECT' || event == 'SYNC')) {
      final now = DateTime.now();
      if (_lastDiagnosticsSync == null || now.difference(_lastDiagnosticsSync!).inMinutes >= 5) {
        _lastDiagnosticsSync = now;
        FirestoreService.syncDiagnostics(btLogs, saasLicenseKey).catchError((e) {
          debugPrint('[Firestore] Error backing up diagnostics log: $e');
        });
      }
    }
  }

  void clearBtLogs() {
    btLogs.clear();
    notifyListeners();
  }

  bool get isPrinterReady {
    if (kIsWeb) return true;
    if (selectedPrinterType == 'wifi') {
      return printerIpAddress.isNotEmpty;
    }
    return isPrinterConnected;
  }

  // Cached reporting properties
  List<double> _cachedLast7DaysSales = [];
  List<String> _cachedLast7DaysLabels = [];
  double _cachedTodayCashSales = 0.0;
  Map<int, int> _cachedMenuPerformance = {};
  bool _isCacheValid = false;

  void invalidateCache() {
    _isCacheValid = false;
  }


  // Invoice Filters State
  String? activeInvoiceFilter;
  DateTime? customFilterStartDate;
  DateTime? customFilterEndDate;

  // Device Configuration States
  String terminalId = 'TERMINAL-01';
  bool isBarcodeScannerEnabled = false;
  bool isCashDrawerEnabled = false;
  int rollWidth = 2;
  String invoiceCode = 'INV';
  bool playSound = true;

  // Account & Cashier Shift States
  String _cashierName = 'Himanshu';
  String _cashierPin = '1234';
  bool isRegisterShiftLocked = true;
  double openingFloat = 500.0;

  // Security & Account Recovery States
  String securityQuestion = 'What was the name of your first restaurant?';
  String securityAnswer = 'ahar';
  String lastLoginTime = '';

  // Multi-user profiles
  UserProfile? loggedInUser;
  List<UserProfile> users = [];

  String get cashierName => loggedInUser?.name ?? _cashierName;
  String get cashierPin => loggedInUser?.pin ?? _cashierPin;
  String get cashierRole => loggedInUser?.role ?? (loggedInUser?.name == 'Himanshu (Owner)' ? 'owner' : 'cashier');

  set cashierName(String val) {
    _cashierName = val;
    notifyListeners();
  }

  set cashierPin(String val) {
    _cashierPin = val;
    notifyListeners();
  }

  // Data lists
  List<TableModel> tables = [];
  Map<String, List<CartItem>> activeCarts = {};
  Map<String, String> tableOccupiedTimes = {};
  List<InvoiceModel> invoices = [];
  List<MenuItem> menu = [];
  List<CategoryModel> categories = [];
  List<String> get categoriesList => categories.map((c) => c.name).toList();
  String cachedDeviceName = 'Unknown Device';

  // Active UI Navigation state
  String? selectedTableId;
  List<CartItem> draftCart = [];
  String currentCategory = 'SANDWICH';
  String activeView = 'home'; // home, invoices, search, reports-revenue, reports-menu, reports-accounts, etc.
  List<String> viewHistory = [];
  bool searchBarVisible = false;
  String menuSearchQuery = '';

  // SaaS state
  bool saasLocked = false;
  bool saasActivationRequired = false;
  String saasLicenseKey = "";
  int saasRate = 0;
  String saasTitle = "Service Suspended";
  String saasQRCodeUrl = "https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=upi%3A%2F%2Fpay%3Fpa%3D9979711149%40ybl%26pn%3DRestroSaaS%26cu%3DINR";
  String saasAnnouncement = "Scan to Pay & Renew";
  String saasSupportPhone = "9979711149";
  List<String> saasRegisteredDevices = [];

  bool _hasFetchedCloudDb = false;
  String licenseErrorMessage = '';

  String getOrCreateDeviceId() {
    String? storedId = LocalStorageHelper.getString('ahar_device_id');
    if (storedId == null || storedId.isEmpty) {
      final randomPart = (100000 + Random().nextInt(900000)).toString();
      final timePart = DateTime.now().microsecondsSinceEpoch.toString();
      storedId = 'DEV-$timePart-$randomPart';
      LocalStorageHelper.setString('ahar_device_id', storedId);
    }
    return storedId;
  }

  String adminEmail = "admin@aharpos.com";
  bool _didMigrateThisLaunch = false;

  // Cloud connectivity state
  String cloudStatus = "syncing"; // 'syncing', 'connected', 'offline'

  // Real internet connectivity state
  bool hasRealInternet = true;
  bool _isMockOffline = false;
  bool get isMockOffline => _isMockOffline;
  Timer? _internetCheckTimer;
  bool _isPushingLocalData = false;

  String _defaultParcelMode = 'delivery'; // 'pickup' or 'delivery'
  String get defaultParcelMode => _defaultParcelMode;

  void setDefaultParcelMode(String mode) {
    _defaultParcelMode = mode;
    LocalStorageHelper.setString('ahar_default_parcel_mode', mode);
    notifyListeners();
  }

  void updateAdminEmail(String email) {
    adminEmail = email;
    LocalStorageHelper.setString('ahar_admin_email', email);
    notifyListeners();
  }

  int cloudInvoicesLimit = 100;
  bool shownCloudFullAlert = false;

  double get cloudUsagePercentage => (invoices.length / cloudInvoicesLimit) * 100.0;
  
  bool get isCloudAlmostFull {
    final almostFull = cloudUsagePercentage >= 80.0;
    if (!almostFull) {
      shownCloudFullAlert = false;
    }
    return almostFull;
  }
  
  bool get isCloudFull => cloudUsagePercentage >= 100.0;

  void setShownCloudFullAlert(bool value) {
    shownCloudFullAlert = value;
    notifyListeners();
  }

  String get saasMessage {
    if (saasTitle == "Subscription Expired") {
      return "Your premium subscription to Ahar OS portal has expired. Please pay ₹$saasRate to renew service.";
    } else if (saasTitle == "Verification Pending") {
      return "We are verifying your payment. Central command has been notified. Please wait for admin approval.";
    } else if (saasTitle == "Payment Rejected") {
      return "Your payment could not be verified by the admin. Please verify payment details/receipt and try again.";
    } else {
      return "Your food portal service has been paused by the administrator. Please pay ₹$saasRate to reactivate.";
    }
  }

  // Active invoice receipt detail overlay state
  InvoiceModel? _selectedReceiptInvoice;
  InvoiceModel? get selectedReceiptInvoice => _selectedReceiptInvoice;
  set selectedReceiptInvoice(InvoiceModel? val) {
    _selectedReceiptInvoice = val;
    notifyListeners();
  }

  // Defaults
  final List<MenuItem> _oldDefaultMenu = [
    MenuItem(id: 1, name: "Sada Paper Dhosa", price: 60, category: "PAPER DHOSA", serialNumber: 1),
    MenuItem(id: 2, name: "Baby Paper Dhosa", price: 50, category: "PAPER DHOSA", serialNumber: 2),
    MenuItem(id: 3, name: "Butter Paper Dhosa", price: 70, category: "PAPER DHOSA", serialNumber: 3),
    MenuItem(id: 4, name: "Nylon Paper Dhosa", price: 80, category: "PAPER DHOSA", serialNumber: 4),
    MenuItem(id: 5, name: "Jira Paper Dhosa", price: 70, category: "PAPER DHOSA", serialNumber: 5),
    MenuItem(id: 6, name: "Garlic Paper Dhosa", price: 80, category: "PAPER DHOSA", serialNumber: 6),
    MenuItem(id: 7, name: "Cheese Paper Dhosa", price: 100, category: "PAPER DHOSA", serialNumber: 7),
    MenuItem(id: 8, name: "Garlic Cheese Paper Dhosa", price: 130, category: "PAPER DHOSA", serialNumber: 8),
    MenuItem(id: 9, name: "Chocolate Paper Dhosa", price: 100, category: "PAPER DHOSA", serialNumber: 9),
    MenuItem(id: 10, name: "Cheese Periperi Paper Dhosa", price: 120, category: "PAPER DHOSA", serialNumber: 10),
    MenuItem(id: 11, name: "Masala Dhosa (Oil)", price: 120, category: "MASALA DHOSA", serialNumber: 11),
    MenuItem(id: 12, name: "Butter Masala Dhosa", price: 140, category: "MASALA DHOSA", serialNumber: 12),
    MenuItem(id: 13, name: "Sezwan Masala Dhosa", price: 120, category: "MASALA DHOSA", serialNumber: 13),
    MenuItem(id: 14, name: "Cheese Palak Masala Dhosa", price: 140, category: "MASALA DHOSA", serialNumber: 14),
    MenuItem(id: 15, name: "Cheese Masala Dhosa", price: 140, category: "MASALA DHOSA", serialNumber: 15),
    MenuItem(id: 16, name: "Paneer Masala Dhosa", price: 140, category: "MASALA DHOSA", serialNumber: 16),
    MenuItem(id: 17, name: "Chese Allo Palak Masala Dhosa", price: 150, category: "MASALA DHOSA", serialNumber: 17),
    MenuItem(id: 18, name: "Sp. 99 Masala Dhosa", price: 200, category: "MASALA DHOSA", serialNumber: 18),
    MenuItem(id: 19, name: "Mysore Masala (Oil)", price: 140, category: "MYSORE DHOSA", serialNumber: 19),
    MenuItem(id: 20, name: "Butter Mysore Masala", price: 160, category: "MYSORE DHOSA", serialNumber: 20),
    MenuItem(id: 21, name: "Cheese Mysore Masala", price: 180, category: "MYSORE DHOSA", serialNumber: 21),
    MenuItem(id: 22, name: "Paneer Mysore Masala", price: 190, category: "MYSORE DHOSA", serialNumber: 22),
    MenuItem(id: 23, name: "Cheese Paneer Mysore Masala", price: 200, category: "MYSORE DHOSA", serialNumber: 23),
    MenuItem(id: 24, name: "Paneer Tukda Mysore Masala", price: 160, category: "MYSORE DHOSA", serialNumber: 24),
    MenuItem(id: 25, name: "Cheese Paneer Tukda Mysore", price: 180, category: "MYSORE DHOSA", serialNumber: 25),
    MenuItem(id: 26, name: "Gotala Mysore", price: 170, category: "MYSORE DHOSA", serialNumber: 26),
    MenuItem(id: 27, name: "Green Gotala", price: 190, category: "MYSORE DHOSA", serialNumber: 27),
    MenuItem(id: 28, name: "Sp. 99 Mysore Masala", price: 220, category: "MYSORE DHOSA", serialNumber: 28),
    MenuItem(id: 29, name: "Jini Roll", price: 170, category: "FANCY DHOSA", serialNumber: 29),
    MenuItem(id: 30, name: "Dilkhush", price: 170, category: "FANCY DHOSA", serialNumber: 30),
    MenuItem(id: 31, name: "Palak Paneer", price: 150, category: "FANCY DHOSA", serialNumber: 31),
    MenuItem(id: 32, name: "Cheese Palak Paneer", price: 170, category: "FANCY DHOSA", serialNumber: 32),
    MenuItem(id: 33, name: "Paneer Chilli Dhosa", price: 150, category: "FANCY DHOSA", serialNumber: 33),
    MenuItem(id: 34, name: "Raja-Rani Dhosa", price: 160, category: "FANCY DHOSA", serialNumber: 34),
    MenuItem(id: 35, name: "Pizza Dhosa", price: 180, category: "FANCY DHOSA", serialNumber: 35),
    MenuItem(id: 36, name: "Spring Roll Dhosa", price: 180, category: "FANCY DHOSA", serialNumber: 36),
    MenuItem(id: 37, name: "Sweet Corn Dhosa", price: 150, category: "FANCY DHOSA", serialNumber: 37),
    MenuItem(id: 38, name: "Chinese Dhosa", price: 160, category: "FANCY DHOSA", serialNumber: 38),
    MenuItem(id: 39, name: "Veg. Tufani Dhosa", price: 180, category: "FANCY DHOSA", serialNumber: 39),
    MenuItem(id: 40, name: "Sp. 99 Matka Dhosa", price: 220, category: "FANCY DHOSA", serialNumber: 40),
    MenuItem(id: 41, name: "FRENCH FRIES", price: 80, category: "KIDS SPECIAL", serialNumber: 41),
    MenuItem(id: 42, name: "CHEESE FRENCH FRIES", price: 100, category: "KIDS SPECIAL", serialNumber: 42),
    MenuItem(id: 43, name: "PERI PERI FRENCH FRIES", price: 90, category: "KIDS SPECIAL", serialNumber: 43),
    MenuItem(id: 44, name: "ONION RING", price: 90, category: "KIDS SPECIAL", serialNumber: 44),
    MenuItem(id: 45, name: "SMILLEY", price: 90, category: "KIDS SPECIAL", serialNumber: 45),
    MenuItem(id: 46, name: "POTETO WHEELS", price: 90, category: "KIDS SPECIAL", serialNumber: 46),
    MenuItem(id: 47, name: "CHEESE BALL", price: 100, category: "KIDS SPECIAL", serialNumber: 47),
    MenuItem(id: 48, name: "PLAIN MAGGI", price: 60, category: "MAGGI SPECIAL", serialNumber: 48),
    MenuItem(id: 49, name: "MASALA MAGGI", price: 70, category: "MAGGI SPECIAL", serialNumber: 49),
    MenuItem(id: 50, name: "VEG. MAGGI", price: 80, category: "MAGGI SPECIAL", serialNumber: 50),
    MenuItem(id: 51, name: "BUTTER MAGGI", price: 90, category: "MAGGI SPECIAL", serialNumber: 51),
    MenuItem(id: 52, name: "CHEESE MAGGI", price: 100, category: "MAGGI SPECIAL", serialNumber: 52),
    MenuItem(id: 53, name: "WHITE SAUCES PASTA", price: 120, category: "PASTA", serialNumber: 53),
    MenuItem(id: 54, name: "RED SAUCES PASTA", price: 120, category: "PASTA", serialNumber: 54),
    MenuItem(id: 55, name: "PINK SAUCES PASTA", price: 130, category: "PASTA", serialNumber: 55),
    MenuItem(id: 56, name: "CHEESE CORN PASTA", price: 150, category: "PASTA", serialNumber: 56),
    MenuItem(id: 57, name: "VEG. STEAM MOMOS", price: 80, category: "MOMOS", serialNumber: 57),
    MenuItem(id: 58, name: "VEG. FRIED MOMOS", price: 90, category: "MOMOS", serialNumber: 58),
    MenuItem(id: 59, name: "VEG. TANDOORI MOMOS", price: 110, category: "MOMOS", serialNumber: 59),
    MenuItem(id: 60, name: "VEG. CHEESE MOMOS", price: 100, category: "MOMOS", serialNumber: 60),
    MenuItem(id: 61, name: "VEG. PERI PERI MOMOS", price: 100, category: "MOMOS", serialNumber: 61),
    MenuItem(id: 62, name: "VEG. CHEESE CORN MOMOS", price: 110, category: "MOMOS", serialNumber: 62),
    MenuItem(id: 63, name: "CHEESE GARLIC BREAD", price: 80, category: "GARLIC BREAD", serialNumber: 63),
    MenuItem(id: 64, name: "CHEESE GARLIC BREAD (PEPRICA, OLIVE JALAPENOS)", price: 100, category: "GARLIC BREAD", serialNumber: 64),
    MenuItem(id: 65, name: "CHEESE CHILLI GARLIC BREAD", price: 90, category: "GARLIC BREAD", serialNumber: 65),
    MenuItem(id: 66, name: "PANEER TIKKA BREAD", price: 120, category: "GARLIC BREAD", serialNumber: 66),
    MenuItem(id: 67, name: "ALOO TIKKI BURGER", price: 60, category: "BURGER", serialNumber: 67),
    MenuItem(id: 68, name: "VEG. BURGER", price: 70, category: "BURGER", serialNumber: 68),
    MenuItem(id: 69, name: "VEG. CHEESE BURGER", price: 80, category: "BURGER", serialNumber: 69),
    MenuItem(id: 70, name: "VEG. PERI PERI BURGER", price: 80, category: "BURGER", serialNumber: 70),
    MenuItem(id: 71, name: "SEZWAN CHEESE BURGER", price: 80, category: "BURGER", serialNumber: 71),
    MenuItem(id: 72, name: "VEG. PANEER BURGER", price: 110, category: "BURGER", serialNumber: 72),
    MenuItem(id: 73, name: "BREAD BUTTER", price: 40, category: "SANDWICH", serialNumber: 73),
    MenuItem(id: 74, name: "GRILL GREEN CHUTNEY SANDWICH", price: 50, category: "SANDWICH", serialNumber: 74),
    MenuItem(id: 75, name: "VEG. SANDWICH", price: 60, category: "SANDWICH", serialNumber: 75),
    MenuItem(id: 76, name: "VEG. CHEESE SANDWICH", price: 80, category: "SANDWICH", serialNumber: 76),
    MenuItem(id: 77, name: "GARDEN GRILL SANDWICH", price: 80, category: "SANDWICH", serialNumber: 77),
    MenuItem(id: 78, name: "VEG. CHEESE GRILL 2 Layer", price: 100, category: "SANDWICH", serialNumber: 78),
    MenuItem(id: 79, name: "VEG. CHEESE CLUB 3 Layer", price: 140, category: "SANDWICH", serialNumber: 79),
    MenuItem(id: 80, name: "VEG. CORN PANEER SANDWICH", price: 150, category: "SANDWICH", serialNumber: 80),
    MenuItem(id: 81, name: "99 SPECIAL SANDWICH", price: 160, category: "SANDWICH", serialNumber: 81),
    MenuItem(id: 82, name: "MARGHERITA PIZZA", price: 110, category: "PIZZA", serialNumber: 82),
    MenuItem(id: 83, name: "GOLDEN DELIGHT PIZZA", price: 140, category: "PIZZA", serialNumber: 83),
    MenuItem(id: 84, name: "JALAPENO SPECIAL PIZZA", price: 160, category: "PIZZA", serialNumber: 84),
    MenuItem(id: 85, name: "EXTRAVAGANZA PIZZA", price: 160, category: "PIZZA", serialNumber: 85),
    MenuItem(id: 86, name: "PANEER TIKA PIZZA", price: 170, category: "PIZZA", serialNumber: 86),
    MenuItem(id: 87, name: "PAPPY PANEER PIZZA", price: 180, category: "PIZZA", serialNumber: 87),
    MenuItem(id: 88, name: "99 SPECIAL PIZZA", price: 200, category: "PIZZA", serialNumber: 88),
    MenuItem(id: 89, name: "FARM HOUSE PIZZA", price: 220, category: "PIZZA", serialNumber: 89),
    MenuItem(id: 90, name: "STRAWBERRY SHAKE", price: 110, category: "SHAKES", serialNumber: 90),
    MenuItem(id: 91, name: "MANGO SHAKE", price: 110, category: "SHAKES", serialNumber: 91),
    MenuItem(id: 92, name: "VENILA SHAKE", price: 110, category: "SHAKES", serialNumber: 92),
    MenuItem(id: 93, name: "CHOCOLATE SHAKE", price: 110, category: "SHAKES", serialNumber: 93),
    MenuItem(id: 94, name: "BUTTER SCOTCH SHAKE", price: 110, category: "SHAKES", serialNumber: 94),
    MenuItem(id: 95, name: "BLACK CURRENT SHAKE", price: 110, category: "SHAKES", serialNumber: 95),
    MenuItem(id: 96, name: "OREO SHAKE", price: 120, category: "SHAKES", serialNumber: 96),
    MenuItem(id: 97, name: "KIT KAT SHAKE", price: 120, category: "SHAKES", serialNumber: 97),
    MenuItem(id: 98, name: "MAGIC MINT MOJITO", price: 80, category: "MOCKTAILS", serialNumber: 98),
    MenuItem(id: 99, name: "ORANGE MOJITO", price: 80, category: "MOCKTAILS", serialNumber: 99),
    MenuItem(id: 100, name: "GREEN APPLE MOJITO", price: 80, category: "MOCKTAILS", serialNumber: 100),
    MenuItem(id: 101, name: "BLUE LAGOON MOJITO", price: 90, category: "MOCKTAILS", serialNumber: 101),
    MenuItem(id: 102, name: "TEA", price: 25, category: "TEA AND COFFEE", serialNumber: 102),
    MenuItem(id: 103, name: "MASALA TEA", price: 30, category: "TEA AND COFFEE", serialNumber: 103),
    MenuItem(id: 104, name: "ELICHI TEA", price: 30, category: "TEA AND COFFEE", serialNumber: 104),
    MenuItem(id: 105, name: "HOT COFFEE", price: 30, category: "TEA AND COFFEE", serialNumber: 105),
    MenuItem(id: 106, name: "COLD COFFEE", price: 80, category: "TEA AND COFFEE", serialNumber: 106),
    MenuItem(id: 107, name: "MINERAL WATER BOTTLE", price: 20, category: "OTHER", serialNumber: 107),
    MenuItem(id: 108, name: "COLD DRINKS", price: 20, category: "OTHER", serialNumber: 108),
  ];

  final List<MenuItem> oldDefaultMenu = [];
  final List<MenuItem> ignoredOldMenu = [
    MenuItem(id: 1, name: "Toast Sandwich", price: 60, category: "Sandwich AC", serialNumber: 1, desc: "Crispy toasted sandwich with potato and spice filling."),
    MenuItem(id: 2, name: "Veg.Sandwich", price: 60, category: "Sandwich AC", serialNumber: 2, desc: "Fresh raw vegetable sandwich with mint chutney."),
    MenuItem(id: 3, name: "Jain Veg. Sandwich", price: 60, category: "Sandwich AC", serialNumber: 3, desc: "Vegetable sandwich prepared without onion"),
    MenuItem(id: 4, name: "Bread Butter", price: 60, category: "Sandwich AC", serialNumber: 4, desc: "Fresh bread slices with premium butter spread."),
    MenuItem(id: 5, name: "Chatni Bread Butter", price: 60, category: "Sandwich AC", serialNumber: 5, desc: "Fresh bread spread with spicy mint chutney and butter."),
    MenuItem(id: 6, name: "Jam Bread Butter", price: 60, category: "Sandwich AC", serialNumber: 6, desc: "Sweet fruit jam and butter spread on soft bread slices."),
    MenuItem(id: 7, name: "Jain Veg. Toast Sandwich", price: 60, category: "Sandwich AC", serialNumber: 7, desc: "Toasted sandwich cooked with Jain-friendly ingredients."),
    MenuItem(id: 8, name: "Bread Butter Toast Sandwich", price: 60, category: "Sandwich AC", serialNumber: 8, desc: "Crispy toasted bread sandwich with butter spread."),
    MenuItem(id: 9, name: "Chatni Toast Sandwich", price: 60, category: "Sandwich AC", serialNumber: 9, desc: "Toasted sandwich with spicy chutney."),
    MenuItem(id: 10, name: "Jam Toast Sandwich", price: 70, category: "Sandwich AC", serialNumber: 10, desc: "Toasted sandwich with sweet fruit jam."),
    MenuItem(id: 11, name: "Pizza Masala Toast Sandwich", price: 70, category: "Sandwich AC", serialNumber: 11, desc: "Toasted sandwich with pizza spices and masala."),
    MenuItem(id: 12, name: "Jam Veg. Sandwich", price: 60, category: "Sandwich AC", serialNumber: 12, desc: "Fresh sandwich with jam and veggies."),
    MenuItem(id: 13, name: "Aahar Sp.Sandwich", price: 90, category: "Sandwich AC", serialNumber: 13, desc: "Special house sandwich with signature ingredients."),
    MenuItem(id: 14, name: "Veg. Cheese Sandwich", price: 90, category: "Sandwich AC", serialNumber: 14, desc: "Fresh sandwich with cheese and vegetables."),
    MenuItem(id: 15, name: "Bread Butter Cheese Sandwich", price: 90, category: "Sandwich AC", serialNumber: 15, desc: "Bread butter sandwich with added cheese slice."),
    MenuItem(id: 16, name: "Jam Cheese Sandwich", price: 90, category: "Sandwich AC", serialNumber: 16, desc: "Fresh sandwich with fruit jam and cheese."),
    MenuItem(id: 17, name: "Cheese Toast Sandwich", price: 90, category: "Sandwich AC", serialNumber: 17, desc: "Toasted sandwich loaded with melted cheese."),
    MenuItem(id: 18, name: "Veg.Cheese Toast Sandwich", price: 90, category: "Sandwich AC", serialNumber: 18, desc: "Toasted sandwich with cheese and fresh veggies."),
    MenuItem(id: 19, name: "Masala Cheese Toast Sandwich", price: 90, category: "Sandwich AC", serialNumber: 19, desc: "Spiced masala toast sandwich with melted cheese."),
    MenuItem(id: 20, name: "Jam Cheese Toast Sandwich", price: 90, category: "Sandwich AC", serialNumber: 20, desc: "Sweet jam and cheese in a crispy toasted sandwich."),
    MenuItem(id: 21, name: "Capsicum Cheese Sandwich", price: 90, category: "Sandwich AC", serialNumber: 21, desc: "Fresh sandwich with crunchy capsicum and cheese."),
    MenuItem(id: 22, name: "Sp.Cheese Pizza Toast Sandwich", price: 90, category: "Sandwich AC", serialNumber: 22, desc: "Special pizza style toast sandwich loaded with cheese."),
    MenuItem(id: 23, name: "Icey Picey Cheese Toast Sandwich", price: 120, category: "Sandwich AC", serialNumber: 23, desc: "Chilled and spicy cheese toast sandwich."),
    MenuItem(id: 24, name: "Cocktail Cheese Toast Sandwich", price: 110, category: "Sandwich AC", serialNumber: 24, desc: "Unique cocktail style cheese toast sandwich."),
    MenuItem(id: 25, name: "Pineapple Cheese Toast Sandwich", price: 100, category: "Sandwich AC", serialNumber: 25, desc: "Toasted sandwich with sweet pineapple slices and cheese."),
    MenuItem(id: 26, name: "Garlic Cheese Toast", price: 90, category: "Sandwich AC", serialNumber: 26, desc: "Toasted bread with aromatic garlic and cheese."),
    MenuItem(id: 27, name: "Tometo Cheese Toast", price: 90, category: "Sandwich AC", serialNumber: 27, desc: "Toasted bread topped with tomatoes and cheese."),
    MenuItem(id: 28, name: "Club Sandwich", price: 120, category: "Sandwich AC", serialNumber: 28, desc: "Double decker sandwich with layers of veggies and spreads."),
    MenuItem(id: 29, name: "Paneer Pakoda Toast Sandwich", price: 100, category: "Sandwich AC", serialNumber: 29, desc: "Toasted sandwich with paneer pakoda filling."),
    MenuItem(id: 30, name: "Icey Picey Toast Sandwich", price: 90, category: "Sandwich AC", serialNumber: 30, desc: "Toasted sandwich with a special spicy chilled flavor."),
    MenuItem(id: 31, name: "Cocktail Toast Sandwich", price: 90, category: "Sandwich AC", serialNumber: 31, desc: "Toasted sandwich with a cocktail flavor mix."),
    MenuItem(id: 32, name: "Pineapple Toast Sandwich", price: 80, category: "Sandwich AC", serialNumber: 32, desc: "Toasted sandwich with sweet pineapple slices."),

    // Grilled AC
    MenuItem(id: 33, name: "Only Cheese Grilled Sandwich", price: 200, category: "Grilled AC", serialNumber: 33, desc: "Melted cheese inside crispy grilled sandwich."),
    MenuItem(id: 34, name: "Mini Only Cheese Grilled Sandwich", price: 170, category: "Grilled AC", serialNumber: 34, desc: "Smaller size of only cheese grilled sandwich."),
    MenuItem(id: 35, name: "Sp. Veg. Cheese Grilled Sandwich", price: 190, category: "Grilled AC", serialNumber: 35, desc: "Spiced veg and cheese grilled sandwich."),
    MenuItem(id: 36, name: "Mini Sp. Veg. Cheese Grilled Sandwich", price: 160, category: "Grilled AC", serialNumber: 36, desc: "Mini spiced veg and cheese grilled sandwich."),
    MenuItem(id: 37, name: "Pineapple Cheese Grilled Sandwich", price: 200, category: "Grilled AC", serialNumber: 37, desc: "Sweet pineapple and cheese grilled sandwich."),
    MenuItem(id: 38, name: "Mini Pineapple Cheese Grilled Sandwich", price: 170, category: "Grilled AC", serialNumber: 38, desc: "Mini pineapple and cheese grilled sandwich."),
    MenuItem(id: 39, name: "Schezwan Cheese Grilled Sandwich", price: 210, category: "Grilled AC", serialNumber: 39, desc: "Spicy Schezwan sauce and cheese grilled sandwich."),
    MenuItem(id: 40, name: "Mini Schezwan Cheese Grilled Sandwich", price: 180, category: "Grilled AC", serialNumber: 40, desc: "Mini spicy Schezwan sauce and cheese grilled sandwich."),
    MenuItem(id: 41, name: "Mushroom Cheese Grilled Sandwich", price: 220, category: "Grilled AC", serialNumber: 41, desc: "Savory mushrooms and cheese grilled sandwich."),
    MenuItem(id: 42, name: "Mini Mushroom Cheese Grilled Sandwich", price: 180, category: "Grilled AC", serialNumber: 42, desc: "Mini mushrooms and cheese grilled sandwich."),
    MenuItem(id: 43, name: "Capsicum Onion Cheese Grilled Sandwich", price: 170, category: "Grilled AC", serialNumber: 43, desc: "Capsicum"),
    MenuItem(id: 44, name: "Mini Capsicum Onion Cheese Grilled Sandwich", price: 150, category: "Grilled AC", serialNumber: 44, desc: "Mini capsicum"),
    MenuItem(id: 45, name: "Masala Cheese Grilled Sandwich", price: 200, category: "Grilled AC", serialNumber: 45, desc: "Spiced potato masala and cheese grilled sandwich."),
    MenuItem(id: 46, name: "Mini Masala Cheese Grilled Sandwich", price: 170, category: "Grilled AC", serialNumber: 46, desc: "Mini potato masala and cheese grilled sandwich."),
    MenuItem(id: 47, name: "Veg. Grilled Sandwich", price: 160, category: "Grilled AC", serialNumber: 47, desc: "Classic fresh vegetable grilled sandwich."),
    MenuItem(id: 48, name: "Mini Veg. Grilled Sandwich", price: 130, category: "Grilled AC", serialNumber: 48, desc: "Mini classic fresh vegetable grilled sandwich."),
    MenuItem(id: 49, name: "Italian Cheese Grilled Sandwich", price: 210, category: "Grilled AC", serialNumber: 49, desc: "Italian herbs"),
    MenuItem(id: 50, name: "Mini Italian Cheese Grilled Sandwich", price: 180, category: "Grilled AC", serialNumber: 50, desc: "Mini Italian herbs"),
    MenuItem(id: 51, name: "Jam Veg. Cheese Grilled Sandwich", price: 200, category: "Grilled AC", serialNumber: 51, desc: "Sweet jam"),
    MenuItem(id: 52, name: "Mini Jam Veg. Cheese Grilled Sandwich", price: 180, category: "Grilled AC", serialNumber: 52, desc: "Mini sweet jam"),
    MenuItem(id: 53, name: "Veg. Corn Cheese Grilled Sandwich", price: 200, category: "Grilled AC", serialNumber: 53, desc: "Veggies"),
    MenuItem(id: 54, name: "Veg. Paneer Grilled Sandwich", price: 200, category: "Grilled AC", serialNumber: 54, desc: "Veggies and paneer chunks grilled sandwich."),
    MenuItem(id: 55, name: "Sp. Veg. Paneer Cheese Grilled Sandwich", price: 220, category: "Grilled AC", serialNumber: 55, desc: "Spicy veg"),
    MenuItem(id: 56, name: "Lumsum Cheese Grilled Sandwich", price: 220, category: "Grilled AC", serialNumber: 56, desc: "Heavily loaded cheese grilled sandwich."),
    MenuItem(id: 57, name: "Chinese Grilled Sandwich", price: 210, category: "Grilled AC", serialNumber: 57, desc: "Chinese style noodles/veggies grilled sandwich."),

    // Pizza AC
    MenuItem(id: 58, name: "Aahar Sp. Veg. Cheese Pizza", price: 180, category: "Pizza AC", serialNumber: 58, desc: "House special veg cheese pizza."),
    MenuItem(id: 59, name: "Mini Aahar Sp. Veg. Cheese Pizza", price: 160, category: "Pizza AC", serialNumber: 59, desc: "Mini house special veg cheese pizza."),
    MenuItem(id: 60, name: "Veg. Cheese Pizza", price: 160, category: "Pizza AC", serialNumber: 60, desc: "Classic vegetable cheese pizza."),
    MenuItem(id: 61, name: "Mini Veg. Cheese Pizza", price: 140, category: "Pizza AC", serialNumber: 61, desc: "Mini vegetable cheese pizza."),
    MenuItem(id: 62, name: "Sp. Jain Veg. Cheese Pizza", price: 160, category: "Pizza AC", serialNumber: 62, desc: "Jain special veg cheese pizza without onion/garlic."),
    MenuItem(id: 63, name: "Mini Sp. Jain Veg. Cheese Pizza", price: 130, category: "Pizza AC", serialNumber: 63, desc: "Mini Jain special veg cheese pizza."),
    MenuItem(id: 64, name: "Italian Pizza", price: 170, category: "Pizza AC", serialNumber: 64, desc: "Italian style cheese and herb pizza."),
    MenuItem(id: 65, name: "Mini Italian Pizza", price: 150, category: "Pizza AC", serialNumber: 65, desc: "Mini Italian style cheese and herb pizza."),
    MenuItem(id: 66, name: "Jam Cheese Pizza", price: 180, category: "Pizza AC", serialNumber: 66, desc: "Sweet jam and cheese pizza."),
    MenuItem(id: 67, name: "Mini Jam Cheese Pizza", price: 150, category: "Pizza AC", serialNumber: 67, desc: "Mini sweet jam and cheese pizza."),
    MenuItem(id: 68, name: "Capsicum Cheese Pizza", price: 160, category: "Pizza AC", serialNumber: 68, desc: "Crunchy capsicum and cheese pizza."),
    MenuItem(id: 69, name: "Mini Capsicum Cheese Pizza", price: 140, category: "Pizza AC", serialNumber: 69, desc: "Mini capsicum and cheese pizza."),
    MenuItem(id: 70, name: "Tomato Cheese Pizza", price: 150, category: "Pizza AC", serialNumber: 70, desc: "Tomato slices and cheese pizza."),
    MenuItem(id: 71, name: "Mini Tomato Cheese Pizza", price: 130, category: "Pizza AC", serialNumber: 71, desc: "Mini tomato slices and cheese pizza."),
    MenuItem(id: 72, name: "Only Cheese Pizza", price: 180, category: "Pizza AC", serialNumber: 72, desc: "Mouthwatering extra cheese pizza."),
    MenuItem(id: 73, name: "Mini Only Cheese Pizza", price: 160, category: "Pizza AC", serialNumber: 73, desc: "Mini extra cheese pizza."),
    MenuItem(id: 74, name: "Mushroom Cheese Pizza", price: 220, category: "Pizza AC", serialNumber: 74, desc: "Savory mushroom and cheese pizza."),
    MenuItem(id: 75, name: "Mini Mushroom Cheese Pizza", price: 190, category: "Pizza AC", serialNumber: 75, desc: "Mini mushroom and cheese pizza."),
    MenuItem(id: 76, name: "Pineapple Cheese Pizza", price: 200, category: "Pizza AC", serialNumber: 76, desc: "Sweet pineapple and cheese pizza."),
    MenuItem(id: 77, name: "Mini Pineapple Cheese Pizza", price: 170, category: "Pizza AC", serialNumber: 77, desc: "Mini pineapple and cheese pizza."),
    MenuItem(id: 78, name: "Chinese Pizza", price: 180, category: "Pizza AC", serialNumber: 78, desc: "Chinese noodle style cheese pizza."),
    MenuItem(id: 79, name: "Mini Chinese Pizza", price: 150, category: "Pizza AC", serialNumber: 79, desc: "Mini Chinese noodle style cheese pizza."),
    MenuItem(id: 80, name: "Corn Cheese Pizza", price: 200, category: "Pizza AC", serialNumber: 80, desc: "Sweet corn and cheese pizza."),
    MenuItem(id: 81, name: "Baby Corn Cheese Pizza", price: 220, category: "Pizza AC", serialNumber: 81, desc: "Baby corn and cheese pizza."),
    MenuItem(id: 82, name: "Sp. Burger", price: 110, category: "Pizza AC", serialNumber: 82, desc: "Special house burger."),
    MenuItem(id: 83, name: "Veg Cheese Burger", price: 90, category: "Pizza AC", serialNumber: 83, desc: "Vegetable burger loaded with cheese."),
    MenuItem(id: 84, name: "Veg Burger", price: 70, category: "Pizza AC", serialNumber: 84, desc: "Classic vegetable burger."),
    MenuItem(id: 85, name: "Sp. Hot Dog", price: 110, category: "Pizza AC", serialNumber: 85, desc: "Special house hot dog."),
    MenuItem(id: 86, name: "Veg Cheese Hot Dog", price: 90, category: "Pizza AC", serialNumber: 86, desc: "Vegetable hot dog loaded with cheese."),
    MenuItem(id: 87, name: "Paneer Burger", price: 90, category: "Pizza AC", serialNumber: 87, desc: "Burger with paneer patty."),
    MenuItem(id: 88, name: "Paneer Hot Dog", price: 90, category: "Pizza AC", serialNumber: 88, desc: "Hot dog with paneer filling."),
    // Paneer Sp AC
    MenuItem(id: 89, name: "Paneer Lajavab", price: 220, category: "Paneer Sp AC", serialNumber: 89, desc: "Creamy delicious paneer dish."),
    MenuItem(id: 90, name: "Paneer Adrakhi", price: 220, category: "Paneer Sp AC", serialNumber: 90, desc: "Spiced ginger flavored paneer dish."),
    MenuItem(id: 91, name: "Paneer Zafrani", price: 230, category: "Paneer Sp AC", serialNumber: 91, desc: "Saffron flavored rich paneer curry."),
    MenuItem(id: 92, name: "Paneer Hazari", price: 220, category: "Paneer Sp AC", serialNumber: 92, desc: "Rich paneer curry with royal spices."),
    MenuItem(id: 93, name: "Paneer Balti", price: 220, category: "Paneer Sp AC", serialNumber: 93, desc: "Balti style spiced paneer curry."),
    MenuItem(id: 94, name: "Paneer Dahi", price: 230, category: "Paneer Sp AC", serialNumber: 94, desc: "Paneer cooked in a rich yogurt based gravy."),
    MenuItem(id: 95, name: "Paneer Rajarani", price: 230, category: "Paneer Sp AC", serialNumber: 95, desc: "Royal paneer dish with dual gravies."),
    MenuItem(id: 96, name: "Paneer Tandoor", price: 240, category: "Paneer Sp AC", serialNumber: 96, desc: "Tandoori grilled spiced paneer chunks."),
    MenuItem(id: 97, name: "Paneer Takatak", price: 230, category: "Paneer Sp AC", serialNumber: 97, desc: "Spicy and tangy paneer stir fry."),
    MenuItem(id: 98, name: "Paneer Musiri", price: 240, category: "Paneer Sp AC", serialNumber: 98, desc: "Special house recipe paneer dish."),
    MenuItem(id: 99, name: "Paneer Olani", price: 240, category: "Paneer Sp AC", serialNumber: 99, desc: "Paneer cooked with signature herbs."),
    MenuItem(id: 100, name: "Paneer Chaklani", price: 260, category: "Paneer Sp AC", serialNumber: 100, desc: "Rich paneer curry cooked with handpicked spices."),
    MenuItem(id: 101, name: "Paneer Dahisodi", price: 240, category: "Paneer Sp AC", serialNumber: 101, desc: "Tangy and rich curd flavored paneer curry."),

    // Kaju Sp AC
    MenuItem(id: 102, name: "Sp. Kaju Tavaa Masala", price: 250, category: "Kaju Sp AC", serialNumber: 102, desc: "Special tava style cashew curry."),
    MenuItem(id: 103, name: "Sp. Kaju Kofta", price: 250, category: "Kaju Sp AC", serialNumber: 103, desc: "Cashew dumplings in rich gravy."),
    MenuItem(id: 104, name: "Kaju Malai", price: 250, category: "Kaju Sp AC", serialNumber: 104, desc: "Cashews in rich creamy white gravy."),
    MenuItem(id: 105, name: "Kaju Chatpati", price: 250, category: "Kaju Sp AC", serialNumber: 105, desc: "Tangy and spicy cashew dry curry."),
    MenuItem(id: 106, name: "Kaju Balti", price: 250, category: "Kaju Sp AC", serialNumber: 106, desc: "Balti style cashew curry."),
    MenuItem(id: 107, name: "Kaju Handi", price: 250, category: "Kaju Sp AC", serialNumber: 107, desc: "Cashews slow cooked in a handi."),

    // Punjabi AC
    MenuItem(id: 108, name: "Bhindi Masala", price: 120, category: "Punjabi AC", serialNumber: 108, desc: "Spicy dry okra curry."),
    MenuItem(id: 109, name: "Punjabi Thali", price: 160, category: "Punjabi AC", serialNumber: 109, desc: "Traditional Punjabi meal with curries, roti, rice, and sweet."),
    MenuItem(id: 110, name: "Aahar Special", price: 170, category: "Punjabi AC", serialNumber: 110, desc: "Special house recipe vegetable curry."),
    MenuItem(id: 111, name: "Veg.Handi", price: 120, category: "Punjabi AC", serialNumber: 111, desc: "Mixed vegetables cooked in a handi gravy."),
    MenuItem(id: 112, name: "Veg.Kadai", price: 120, category: "Punjabi AC", serialNumber: 112, desc: "Mixed vegetables cooked in a kadai with bell peppers and spices."),
    MenuItem(id: 113, name: "Veg.Angara", price: 180, category: "Punjabi AC", serialNumber: 113, desc: "Spicy vegetable curry with a smoky flavor."),
    MenuItem(id: 114, name: "Veg.Tufani", price: 140, category: "Punjabi AC", serialNumber: 114, desc: "Spicy and tangy mixed vegetable dish."),
    MenuItem(id: 115, name: "Paneer Anguri", price: 220, category: "Punjabi AC", serialNumber: 115, desc: "Paneer balls in a rich cream gravy."),
    MenuItem(id: 116, name: "Cheese Anguri", price: 220, category: "Punjabi AC", serialNumber: 116, desc: "Cheese cubes cooked in rich gravy."),
    MenuItem(id: 117, name: "Cheese Butter Masala", price: 210, category: "Punjabi AC", serialNumber: 117, desc: "Melted cheese cubes in rich buttery tomato gravy."),
    MenuItem(id: 118, name: "Paneer Angara", price: 210, category: "Punjabi AC", serialNumber: 118, desc: "Smoky and spicy paneer curry."),
    MenuItem(id: 119, name: "Paneer Chatpati", price: 180, category: "Punjabi AC", serialNumber: 119, desc: "Tangy and spicy paneer dish."),
    MenuItem(id: 120, name: "Paneer Jodhpuri", price: 160, category: "Punjabi AC", serialNumber: 120, desc: "Paneer cooked Jodhpur style with unique spices."),
    MenuItem(id: 121, name: "Panner Badsahi", price: 170, category: "Punjabi AC", serialNumber: 121, desc: "Royal paneer curry cooked with dry fruits and cream."),
    MenuItem(id: 122, name: "Panner Kolhapuri", price: 160, category: "Punjabi AC", serialNumber: 122, desc: "Spicy paneer curry Kolhapuri style."),
    MenuItem(id: 123, name: "Paneer Kadai", price: 150, category: "Punjabi AC", serialNumber: 123, desc: "Paneer cooked with bell peppers and fresh ground spices."),
    MenuItem(id: 124, name: "Paneer Tawa", price: 190, category: "Punjabi AC", serialNumber: 124, desc: "Paneer tossed on tawa with thick spiced gravy."),
    MenuItem(id: 125, name: "Paneer Butter Masala", price: 150, category: "Punjabi AC", serialNumber: 125, desc: "Rich and creamy paneer curry in tomato butter sauce."),
    MenuItem(id: 126, name: "Paneer Tikka Masala", price: 150, category: "Punjabi AC", serialNumber: 126, desc: "Grilled paneer tikka chunks cooked in a spiced gravy."),
    MenuItem(id: 127, name: "Paneer Bhurji", price: 170, category: "Punjabi AC", serialNumber: 127, desc: "Scrambled cottage cheese cooked with onions, tomatoes, and spices."),
    MenuItem(id: 128, name: "Paneer Mutter", price: 150, category: "Punjabi AC", serialNumber: 128, desc: "Classic paneer and green peas curry."),
    MenuItem(id: 129, name: "Paneer Toofani", price: 160, category: "Punjabi AC", serialNumber: 129, desc: "Very spicy paneer curry cooked with red chillies."),
    MenuItem(id: 130, name: "Paneer Handi", price: 140, category: "Punjabi AC", serialNumber: 130, desc: "Paneer slow cooked in a handi with rich gravy."),
    MenuItem(id: 131, name: "Paneer Masala", price: 160, category: "Punjabi AC", serialNumber: 131, desc: "Spiced paneer curry cooked in onion tomato paste."),
    MenuItem(id: 132, name: "Paneer Palak", price: 150, category: "Punjabi AC", serialNumber: 132, desc: "Paneer cooked in a healthy spinach gravy."),
    MenuItem(id: 133, name: "Paneer Kurma", price: 160, category: "Punjabi AC", serialNumber: 133, desc: "Paneer cooked in a rich and creamy Mughlai style gravy."),
    MenuItem(id: 134, name: "Paneer Pasanda", price: 240, category: "Punjabi AC", serialNumber: 134, desc: "Rich paneer sandwiches stuffed with nuts and cooked in cream gravy."),
    MenuItem(id: 135, name: "Sahi Paneer", price: 160, category: "Punjabi AC", serialNumber: 135, desc: "Royal paneer curry in a sweet and creamy gravy."),
    MenuItem(id: 136, name: "Paneer Express", price: 240, category: "Punjabi AC", serialNumber: 136, desc: "Special fast-cooked rich paneer curry."),
    MenuItem(id: 137, name: "Aahar Special Kofta(Sweet)", price: 220, category: "Punjabi AC", serialNumber: 137, desc: "Sweet vegetable kofta in royal gravy."),
    MenuItem(id: 138, name: "Aahar Special Malai Kofta(Spicy)", price: 190, category: "Punjabi AC", serialNumber: 138, desc: "Spicy vegetable kofta in rich malai gravy."),
    MenuItem(id: 139, name: "Paneer Kofta", price: 200, category: "Punjabi AC", serialNumber: 139, desc: "Paneer dumplings cooked in spiced gravy."),
    MenuItem(id: 140, name: "Paneer Kaju", price: 180, category: "Punjabi AC", serialNumber: 140, desc: "Paneer and cashews cooked in a rich gravy."),
    MenuItem(id: 141, name: "Veg.Kofta", price: 160, category: "Punjabi AC", serialNumber: 141, desc: "Mixed vegetable dumplings in spiced curry."),
    MenuItem(id: 142, name: "Navratna Kurma", price: 170, category: "Punjabi AC", serialNumber: 142, desc: "Rich sweet curry cooked with nine varieties of veggies, fruits, and nuts."),
    MenuItem(id: 143, name: "Veg.Kurma", price: 140, category: "Punjabi AC", serialNumber: 143, desc: "Mixed vegetables cooked in a creamy coconut curry."),
    MenuItem(id: 144, name: "Kaju-Kari", price: 180, category: "Punjabi AC", serialNumber: 144, desc: "Cashews cooked in a rich, spiced gravy."),
    MenuItem(id: 145, name: "Kaju Masala", price: 180, category: "Punjabi AC", serialNumber: 145, desc: "Cashews cooked in a spicy onion-tomato masala."),
    MenuItem(id: 146, name: "Paneer Jvala", price: 210, category: "Punjabi AC", serialNumber: 146, desc: "Extremely spicy paneer curry with a fiery red gravy."),
    MenuItem(id: 147, name: "Paneer Pahadi", price: 180, category: "Punjabi AC", serialNumber: 147, desc: "Spiced paneer cooked in a green herb marinade."),
    MenuItem(id: 148, name: "Paneer Matka", price: 180, category: "Punjabi AC", serialNumber: 148, desc: "Paneer curry slow cooked in an earthen pot."),
    MenuItem(id: 149, name: "Paneer Sejali", price: 180, category: "Punjabi AC", serialNumber: 149, desc: "Traditional style spiced paneer curry."),
    MenuItem(id: 150, name: "Paneer Hungama", price: 200, category: "Punjabi AC", serialNumber: 150, desc: "Exotic and rich paneer curry with royal spices."),
    MenuItem(id: 151, name: "Paneer Patiyala", price: 190, category: "Punjabi AC", serialNumber: 151, desc: "Rich paneer wrapped in papad rolls and cooked in gravy."),
    MenuItem(id: 152, name: "Paneer Mirch Masala", price: 160, category: "Punjabi AC", serialNumber: 152, desc: "Spicy paneer cooked with green chillies and bell peppers."),
    MenuItem(id: 153, name: "Paneer Chana Masala", price: 160, category: "Punjabi AC", serialNumber: 153, desc: "Paneer and chickpeas cooked in a spicy tomato onion gravy."),
    MenuItem(id: 154, name: "Lollipop Masala", price: 160, category: "Punjabi AC", serialNumber: 154, desc: "Spiced vegetable lollipop bites cooked in a rich gravy."),
    MenuItem(id: 155, name: "Capsicum Masala", price: 150, category: "Punjabi AC", serialNumber: 155, desc: "Bell peppers cooked in a spiced peanut onion gravy."),
    MenuItem(id: 156, name: "Veg. Hariyali", price: 140, category: "Punjabi AC", serialNumber: 156, desc: "Mixed vegetables cooked in a green spinach and mint gravy."),
    MenuItem(id: 157, name: "Veg. Hydrabadi", price: 140, category: "Punjabi AC", serialNumber: 157, desc: "Mixed vegetables cooked in a rich"),
    MenuItem(id: 158, name: "Veg. Adraki", price: 120, category: "Punjabi AC", serialNumber: 158, desc: "Mixed vegetables flavored with fresh ginger and spices."),
    MenuItem(id: 159, name: "Veg. Amrutsari", price: 160, category: "Punjabi AC", serialNumber: 159, desc: "Sweet and mildly spiced mixed vegetable curry"),
    MenuItem(id: 160, name: "Veg. Dilli Darbar", price: 170, category: "Punjabi AC", serialNumber: 160, desc: "Royal mixed vegetables cooked Delhi style."),
    MenuItem(id: 161, name: "Veg. Sabnam Curry", price: 170, category: "Punjabi AC", serialNumber: 161, desc: "Sweet and rich mixed vegetable curry with cashews and cream."),
    MenuItem(id: 162, name: "Veg. Divani Handi", price: 160, category: "Punjabi AC", serialNumber: 162, desc: "Veggies slow cooked in a rich"),
    MenuItem(id: 163, name: "Veg. Sabnam Kofta", price: 160, category: "Punjabi AC", serialNumber: 163, desc: "Sweet vegetable dumplings in a rich"),
    MenuItem(id: 164, name: "Lajvab Kofta", price: 200, category: "Punjabi AC", serialNumber: 164, desc: "Deliciously spiced vegetable dumplings in a rich gravy."),
    MenuItem(id: 165, name: "Kaju Khoya", price: 180, category: "Punjabi AC", serialNumber: 165, desc: "Cashews and khoya cooked in a sweet"),
    MenuItem(id: 166, name: "Veg. Tiranga", price: 220, category: "Punjabi AC", serialNumber: 166, desc: "Three colored vegetable curries layered together."),
    MenuItem(id: 167, name: "Mashroom Masala", price: 180, category: "Punjabi AC", serialNumber: 167, desc: "Savory mushrooms cooked in a spiced tomato onion gravy."),
    MenuItem(id: 168, name: "Stuff Tometo", price: 140, category: "Punjabi AC", serialNumber: 168, desc: "Tomatoes stuffed with mashed potatoes and cottage cheese in gravy."),
    MenuItem(id: 169, name: "Dum Aloo", price: 140, category: "Punjabi AC", serialNumber: 169, desc: "Slow cooked baby potatoes in a spiced yogurt based gravy."),
    MenuItem(id: 170, name: "Dum Aloo Kashmiri", price: 150, category: "Punjabi AC", serialNumber: 170, desc: "Slow cooked potatoes in a sweet"),
    MenuItem(id: 171, name: "Jeera Aloo", price: 110, category: "Punjabi AC", serialNumber: 171, desc: "Baby potatoes tossed with cumin seeds and mild spices."),
    MenuItem(id: 172, name: "Tometo Batata", price: 120, category: "Punjabi AC", serialNumber: 172, desc: "Traditional potato and tomato curry."),
    MenuItem(id: 173, name: "Papad Roll Masala", price: 160, category: "Punjabi AC", serialNumber: 173, desc: "Papad rolls stuffed with spiced vegetables in gravy."),
    MenuItem(id: 174, name: "Bengan Masala", price: 120, category: "Punjabi AC", serialNumber: 174, desc: "Spiced eggplant curry cooked with tomato onion paste."),
    MenuItem(id: 175, name: "Bengan Bhatta", price: 130, category: "Punjabi AC", serialNumber: 175, desc: "Smoked eggplant mash cooked with green peas"),
    MenuItem(id: 176, name: "Dal Fry", price: 100, category: "Punjabi AC", serialNumber: 176, desc: "Yellow lentils cooked and tempered with cumin"),
    MenuItem(id: 177, name: "Butter Dal Fry", price: 130, category: "Punjabi AC", serialNumber: 177, desc: "Tempered yellow lentils cooked with extra butter."),
    MenuItem(id: 178, name: "Dal Tadka", price: 130, category: "Punjabi AC", serialNumber: 178, desc: "Yellow lentils tempered with red chillies"),
    MenuItem(id: 179, name: "Palak Mutter", price: 120, category: "Punjabi AC", serialNumber: 179, desc: "Green peas cooked in a spiced spinach gravy."),
    MenuItem(id: 180, name: "Aloo Palak", price: 120, category: "Punjabi AC", serialNumber: 180, desc: "Potatoes cooked in a spiced spinach gravy."),
    MenuItem(id: 181, name: "Chana Masala", price: 130, category: "Punjabi AC", serialNumber: 181, desc: "Chickpeas cooked in a tangy and spicy masala gravy."),
    MenuItem(id: 182, name: "Alu Gobi", price: 120, category: "Punjabi AC", serialNumber: 182, desc: "Potatoes and cauliflower florets cooked with dry spices."),
    MenuItem(id: 183, name: "Alu Mutter", price: 120, category: "Punjabi AC", serialNumber: 183, desc: "Potatoes and green peas cooked in a spiced tomato gravy."),
    MenuItem(id: 184, name: "Mix Veg.", price: 120, category: "Punjabi AC", serialNumber: 184, desc: "Assorted vegetables cooked in a spiced tomato onion gravy."),
    MenuItem(id: 185, name: "Veg. Kolhapuri", price: 140, category: "Punjabi AC", serialNumber: 185, desc: "Spicy mixed vegetables cooked Kolhapuri style."),
    MenuItem(id: 186, name: "Veg. Makhanwala", price: 150, category: "Punjabi AC", serialNumber: 186, desc: "Mixed vegetables cooked in a rich"),
    MenuItem(id: 187, name: "Veg. Jaypuri", price: 140, category: "Punjabi AC", serialNumber: 187, desc: "Mixed vegetables cooked Jaipur style with roasted papad on top."),
    MenuItem(id: 188, name: "Palak Masala", price: 120, category: "Punjabi AC", serialNumber: 188, desc: "Spiced spinach curry cooked with tomatoes and onions."),
    MenuItem(id: 189, name: "Bhindi Fry", price: 120, category: "Punjabi AC", serialNumber: 189, desc: "Crispy fried okra tossed with dry spices."),

    // Tandoori AC
    MenuItem(id: 190, name: "Tandoori Roti", price: 20, category: "Tandoori AC", serialNumber: 190, desc: "Clay oven baked flatbread."),
    MenuItem(id: 191, name: "Butter Roti", price: 25, category: "Tandoori AC", serialNumber: 191, desc: "Tandoori roti spread with butter."),
    MenuItem(id: 192, name: "Tava Amul Butter Roti", price: 25, category: "Tandoori AC", serialNumber: 192, desc: "Griddle cooked roti spread with Amul butter."),
    MenuItem(id: 193, name: "Amul Butter Roti", price: 30, category: "Tandoori AC", serialNumber: 193, desc: "Tandoori roti loaded with premium Amul butter."),
    MenuItem(id: 194, name: "Butter Parotha", price: 50, category: "Tandoori AC", serialNumber: 194, desc: "Multi-layered tandoori flatbread spread with butter."),
    MenuItem(id: 195, name: "Sada Parotha", price: 40, category: "Tandoori AC", serialNumber: 195, desc: "Classic multi-layered tandoori flatbread."),
    MenuItem(id: 196, name: "Butter Nan", price: 50, category: "Tandoori AC", serialNumber: 196, desc: "Soft leavened tandoori bread spread with butter."),
    MenuItem(id: 197, name: "Sada Nan", price: 40, category: "Tandoori AC", serialNumber: 197, desc: "Soft leavened plain tandoori bread."),
    MenuItem(id: 198, name: "Kashmiri Nan", price: 70, category: "Tandoori AC", serialNumber: 198, desc: "Sweet leavened bread stuffed with nuts and raisins."),
    MenuItem(id: 199, name: "Masala Parotha", price: 70, category: "Tandoori AC", serialNumber: 199, desc: "Tandoori flatbread stuffed with spiced potatoes and herbs."),
    MenuItem(id: 200, name: "Stuff Parotha", price: 70, category: "Tandoori AC", serialNumber: 200, desc: "Tandoori flatbread stuffed with mixed vegetables."),
    MenuItem(id: 201, name: "Masala Kulcha", price: 70, category: "Tandoori AC", serialNumber: 201, desc: "Leavened bread stuffed with spices and cooked in clay oven."),
    MenuItem(id: 202, name: "Sada Kulcha", price: 50, category: "Tandoori AC", serialNumber: 202, desc: "Plain leavened tandoori bread."),
    MenuItem(id: 203, name: "Tava Roti", price: 15, category: "Tandoori AC", serialNumber: 203, desc: "Griddle cooked plain whole wheat flatbread."),
    MenuItem(id: 204, name: "Tava Roti Butter", price: 20, category: "Tandoori AC", serialNumber: 204, desc: "Griddle cooked flatbread spread with butter."),
    MenuItem(id: 205, name: "Paneer Parotha", price: 80, category: "Tandoori AC", serialNumber: 205, desc: "Griddle cooked flatbread stuffed with spiced cottage cheese."),
    MenuItem(id: 206, name: "Paneer Nan", price: 80, category: "Tandoori AC", serialNumber: 206, desc: "Tandoori naan stuffed with spiced cottage cheese."),
    MenuItem(id: 207, name: "Onion Nan", price: 60, category: "Tandoori AC", serialNumber: 207, desc: "Tandoori naan topped with chopped onions and spices."),
    MenuItem(id: 208, name: "Cheese Nan", price: 90, category: "Tandoori AC", serialNumber: 208, desc: "Tandoori naan stuffed with melted cheese."),
    MenuItem(id: 209, name: "Garlic Nan", price: 70, category: "Tandoori AC", serialNumber: 209, desc: "Tandoori naan flavored with fresh minced garlic."),
    MenuItem(id: 210, name: "Garlic Chesses", price: 100, category: "Tandoori AC", serialNumber: 210, desc: "Naan topped with garlic and cheese."),

    // Papad AC
    MenuItem(id: 211, name: "Rosted Papad", price: 20, category: "Papad AC", serialNumber: 211, desc: "Crispy roasted lentil wafer."),
    MenuItem(id: 212, name: "Fry Papad", price: 30, category: "Papad AC", serialNumber: 212, desc: "Deep fried crispy lentil wafer."),
    MenuItem(id: 213, name: "Masala Papad", price: 40, category: "Papad AC", serialNumber: 213, desc: "Crispy papad topped with onions"),
    MenuItem(id: 214, name: "Butter Milk", price: 25, category: "Papad AC", serialNumber: 214, desc: "Chilled savory yogurt drink."),
    MenuItem(id: 215, name: "Green Salad", price: 80, category: "Papad AC", serialNumber: 215, desc: "Fresh sliced cucumber"),
    MenuItem(id: 216, name: "Finger Chips", price: 100, category: "Papad AC", serialNumber: 216, desc: "Crispy potato French fries."),

    // Soup AC
    MenuItem(id: 217, name: "Tomato Soup", price: 80, category: "Soup AC", serialNumber: 217, desc: "Classic hot tomato soup with croutons."),
    MenuItem(id: 218, name: "Hot & Sour Soup", price: 80, category: "Soup AC", serialNumber: 218, desc: "Spicy and tangy Chinese style soup."),
    MenuItem(id: 219, name: "Veg. Manchow Soup", price: 80, category: "Soup AC", serialNumber: 219, desc: "Spicy vegetable soup served with crispy noodles."),
    MenuItem(id: 220, name: "Sweet Corn Veg. Soup", price: 80, category: "Soup AC", serialNumber: 220, desc: "Creamy soup loaded with sweet corn and vegetables."),
    MenuItem(id: 221, name: "Sweet Corn Plain Soup", price: 80, category: "Soup AC", serialNumber: 221, desc: "Mild"),
    MenuItem(id: 222, name: "Mushroom Soup", price: 90, category: "Soup AC", serialNumber: 222, desc: "Creamy earthy mushroom soup."),
    MenuItem(id: 223, name: "Ministrone Soup", price: 80, category: "Soup AC", serialNumber: 223, desc: "Italian style tomato soup with vegetables and pasta."),
    MenuItem(id: 224, name: "Veg.Clear Soup", price: 70, category: "Soup AC", serialNumber: 224, desc: "Light and healthy vegetable broth."),
    MenuItem(id: 225, name: "Green Peas Soup", price: 70, category: "Soup AC", serialNumber: 225, desc: "Smooth green pea puree soup."),
    MenuItem(id: 226, name: "Veg Noodles Soup", price: 80, category: "Soup AC", serialNumber: 226, desc: "Clear soup with noodles and vegetables."),
    MenuItem(id: 227, name: "Royal Veg. Soup", price: 90, category: "Soup AC", serialNumber: 227, desc: "Special house recipe rich vegetable soup."),
    MenuItem(id: 228, name: "Cocktail Soup", price: 90, category: "Soup AC", serialNumber: 228, desc: "Unique sweet and sour mixed soup."),

    // Noodles AC
    MenuItem(id: 229, name: "Bombay Bhel", price: 150, category: "Noodles AC", serialNumber: 229, desc: "Crispy noodles tossed with veggies and tangy sauces."),
    MenuItem(id: 230, name: "Aaisi paisi Noodles", price: 170, category: "Noodles AC", serialNumber: 230, desc: "Special spiced Chinese noodles."),
    MenuItem(id: 231, name: "Hakka Noodles", price: 150, category: "Noodles AC", serialNumber: 231, desc: "Classic stir-fried vegetable noodles."),
    MenuItem(id: 232, name: "Singapuri Noodles", price: 160, category: "Noodles AC", serialNumber: 232, desc: "Stir-fried noodles with a hint of curry powder and spices."),
    MenuItem(id: 233, name: "Veg. Rice & Noodles", price: 150, category: "Noodles AC", serialNumber: 233, desc: "Combo of stir-fried rice and noodles."),
    MenuItem(id: 234, name: "Schwan Noodles", price: 150, category: "Noodles AC", serialNumber: 234, desc: "Spicy Schezwan sauce tossed noodles."),
    MenuItem(id: 235, name: "Fried Noodles", price: 170, category: "Noodles AC", serialNumber: 235, desc: "Crispy deep fried noodles with vegetable sauce."),
    MenuItem(id: 236, name: "Combination Noodles", price: 150, category: "Noodles AC", serialNumber: 236, desc: "Stir-fried noodles with multiple sauces."),
    MenuItem(id: 237, name: "Mashroom Noodles", price: 160, category: "Noodles AC", serialNumber: 237, desc: "Stir-fried noodles with savory mushrooms."),
    MenuItem(id: 238, name: "Tripple's Schzwan Noodles", price: 200, category: "Noodles AC", serialNumber: 238, desc: "Fried rice"),
    MenuItem(id: 239, name: "American Chopsy", price: 160, category: "Noodles AC", serialNumber: 239, desc: "Sweet and tangy tomato sauce over crispy noodles with veggies."),
    MenuItem(id: 240, name: "Mashroom Chopsy", price: 170, category: "Noodles AC", serialNumber: 240, desc: "Crispy noodles served with mushroom and vegetable sauce."),
    MenuItem(id: 241, name: "Chinese Bhel", price: 150, category: "Noodles AC", serialNumber: 241, desc: "Fried crispy noodles with onions"),
    MenuItem(id: 242, name: "Garlic Chawmin (liquid)", price: 160, category: "Noodles AC", serialNumber: 242, desc: "Chowmein cooked in garlic rich gravy."),
    MenuItem(id: 243, name: "Veg. Chawmin (Liquid)", price: 150, category: "Noodles AC", serialNumber: 243, desc: "Chowmein cooked in vegetable rich gravy."),
    MenuItem(id: 244, name: "Huanan Noodles", price: 200, category: "Noodles AC", serialNumber: 244, desc: "Special Hunan style hot and spicy noodles."),

    // Veg Food Gravy AC
    MenuItem(id: 245, name: "Paneer bullet", price: 220, category: "Veg Food Gravy AC", serialNumber: 245, desc: "Spicy bullet-shaped cottage cheese starters in gravy."),
    MenuItem(id: 246, name: "Paneer Schzwen Roll", price: 240, category: "Veg Food Gravy AC", serialNumber: 246, desc: "Paneer roll cooked in hot Schezwan sauce."),
    MenuItem(id: 247, name: "Veg. Krivsi", price: 200, category: "Veg Food Gravy AC", serialNumber: 247, desc: "Crispy fried mixed vegetables tossed in sweet and spicy sauce."),
    MenuItem(id: 248, name: "Mashroom Roll", price: 220, category: "Veg Food Gravy AC", serialNumber: 248, desc: "Sautéed mushrooms and onions rolled in flatbread."),
    MenuItem(id: 249, name: "Veg. Manchurian (Liquid)", price: 160, category: "Veg Food Gravy AC", serialNumber: 249, desc: "Vegetable dumplings cooked in Manchurian gravy."),
    MenuItem(id: 250, name: "Veg. Manchurian (Dry)", price: 160, category: "Veg Food Gravy AC", serialNumber: 250, desc: "Deep fried vegetable dumplings tossed in Manchurian sauce."),
    MenuItem(id: 251, name: "Mashroom Manchurian (Liquid)", price: 200, category: "Veg Food Gravy AC", serialNumber: 251, desc: "Mushrooms cooked in Manchurian gravy."),
    MenuItem(id: 252, name: "Baby Corn Manchurian (Dry)", price: 200, category: "Veg Food Gravy AC", serialNumber: 252, desc: "Crispy baby corn tossed in Manchurian sauce."),
    MenuItem(id: 253, name: "Baby Corn Manchurian (Liquid)", price: 200, category: "Veg Food Gravy AC", serialNumber: 253, desc: "Baby corn cooked in Manchurian gravy."),
    MenuItem(id: 254, name: "Baby Corn Chilli (Dry)", price: 200, category: "Veg Food Gravy AC", serialNumber: 254, desc: "Crispy baby corn tossed in a spicy chilli sauce."),
    MenuItem(id: 255, name: "Paneer Manchurian (Dry)", price: 200, category: "Veg Food Gravy AC", serialNumber: 255, desc: "Fried paneer chunks tossed in Manchurian sauce."),
    MenuItem(id: 256, name: "Paneer Manchurian (Liquid)", price: 200, category: "Veg Food Gravy AC", serialNumber: 256, desc: "Paneer chunks cooked in Manchurian gravy."),
    MenuItem(id: 257, name: "Paneer Chilli (Dry)", price: 200, category: "Veg Food Gravy AC", serialNumber: 257, desc: "Fried paneer chunks with capsicum and onions in chilli sauce."),
    MenuItem(id: 258, name: "Paneer Chilli (Liquid)", price: 200, category: "Veg Food Gravy AC", serialNumber: 258, desc: "Paneer chunks cooked in spicy chilli gravy."),
    MenuItem(id: 259, name: "Paneer Mamtal (Dry)", price: 250, category: "Veg Food Gravy AC", serialNumber: 259, desc: "Signature rich dry paneer starter."),
    MenuItem(id: 260, name: "Paneer '65 (Dry)", price: 200, category: "Veg Food Gravy AC", serialNumber: 260, desc: "Spicy"),
    MenuItem(id: 261, name: "Paneer '65 (Liquid)", price: 200, category: "Veg Food Gravy AC", serialNumber: 261, desc: "Spicy deep-fried paneer in yogurt chilli gravy."),
    MenuItem(id: 262, name: "Cocktail (Dry/Liquid)", price: 180, category: "Veg Food Gravy AC", serialNumber: 262, desc: "Mixed vegetables cooked in a cocktail sauce."),
    MenuItem(id: 263, name: "Veg. Chilli (Dry)", price: 170, category: "Veg Food Gravy AC", serialNumber: 263, desc: "Crispy fried vegetables tossed in chilli sauce."),
    MenuItem(id: 264, name: "Veg. Chilli (Liquid)", price: 170, category: "Veg Food Gravy AC", serialNumber: 264, desc: "Mixed vegetables cooked in spicy chilli gravy."),
    MenuItem(id: 265, name: "Veg. '65 (Dry)", price: 180, category: "Veg Food Gravy AC", serialNumber: 265, desc: "Spicy deep-fried mixed vegetables."),
    MenuItem(id: 266, name: "Veg. '65 (Liquid)", price: 180, category: "Veg Food Gravy AC", serialNumber: 266, desc: "Spicy deep-fried vegetables in rich gravy."),
    MenuItem(id: 267, name: "Potato Chilli", price: 180, category: "Veg Food Gravy AC", serialNumber: 267, desc: "Crispy potatoes tossed in hot chilli sauce."),
    MenuItem(id: 268, name: "Veg. Lollipop", price: 200, category: "Veg Food Gravy AC", serialNumber: 268, desc: "Spiced vegetable lollipop shaped starters."),

    // Rice Dish AC
    MenuItem(id: 269, name: "Huanan Rice", price: 200, category: "Rice Dish AC", serialNumber: 269, desc: "Spicy Hunan style stir-fried rice."),
    MenuItem(id: 270, name: "Hongkong Rice", price: 200, category: "Rice Dish AC", serialNumber: 270, desc: "Hong Kong style fried rice with vegetables and nuts."),
    MenuItem(id: 271, name: "Aahar Sp. Rice", price: 220, category: "Rice Dish AC", serialNumber: 271, desc: "Special house recipe vegetable fried rice."),
    MenuItem(id: 272, name: "Veg. Fried Rice", price: 150, category: "Rice Dish AC", serialNumber: 272, desc: "Classic Chinese style stir-fried vegetable rice."),
    MenuItem(id: 273, name: "Mix Veg. Fried Rice", price: 150, category: "Rice Dish AC", serialNumber: 273, desc: "Fried rice loaded with a mix of assorted veggies."),
    MenuItem(id: 274, name: "Veg. Ginger Fried Rice", price: 150, category: "Rice Dish AC", serialNumber: 274, desc: "Stir-fried rice flavored with fresh ginger."),
    MenuItem(id: 275, name: "Garlic Fried Rice", price: 170, category: "Rice Dish AC", serialNumber: 275, desc: "Stir-fried rice loaded with aromatic garlic."),
    MenuItem(id: 276, name: "Combination Rice", price: 160, category: "Rice Dish AC", serialNumber: 276, desc: "Combo of fried rice and noodles with sauce."),
    MenuItem(id: 277, name: "Mashroom Fried Rice", price: 190, category: "Rice Dish AC", serialNumber: 277, desc: "Stir-fried rice with savory mushrooms."),
    MenuItem(id: 278, name: "Schezwan Fried Rice", price: 160, category: "Rice Dish AC", serialNumber: 278, desc: "Fried rice tossed in spicy Schezwan sauce."),
    MenuItem(id: 279, name: "Tripple Schezwan Rice", price: 200, category: "Rice Dish AC", serialNumber: 279, desc: "Combo of noodles"),
    MenuItem(id: 280, name: "Singapoori Fried Rice", price: 160, category: "Rice Dish AC", serialNumber: 280, desc: "Yellow-hued fried rice with mild spices."),
    MenuItem(id: 281, name: "Chinese Veg. Pulao", price: 150, category: "Rice Dish AC", serialNumber: 281, desc: "Chinese style spiced vegetable rice."),
    MenuItem(id: 282, name: "Paneer Pulao", price: 200, category: "Rice Dish AC", serialNumber: 282, desc: "Fragrant basmati rice cooked with paneer chunks."),
    MenuItem(id: 283, name: "Cheese Pulao", price: 220, category: "Rice Dish AC", serialNumber: 283, desc: "Fragrant rice cooked with melted cheese cubes."),
    MenuItem(id: 284, name: "Punjabi Veg. Pulao", price: 160, category: "Rice Dish AC", serialNumber: 284, desc: "Punjabi style spiced vegetable pulao."),
    MenuItem(id: 285, name: "Veg. Kashmiri Pulao", price: 180, category: "Rice Dish AC", serialNumber: 285, desc: "Sweet pulao cooked with fruits"),
    MenuItem(id: 286, name: "Green Peas Pulao", price: 150, category: "Rice Dish AC", serialNumber: 286, desc: "Simple fragrant rice cooked with sweet green peas."),
    MenuItem(id: 287, name: "Veg. Biryani", price: 160, category: "Rice Dish AC", serialNumber: 287, desc: "Layered spiced vegetable and rice dish."),
    MenuItem(id: 288, name: "Hydrabadi Biryani", price: 160, category: "Rice Dish AC", serialNumber: 288, desc: "Spicy"),
    MenuItem(id: 289, name: "Jira Rice", price: 110, category: "Rice Dish AC", serialNumber: 289, desc: "Basmati rice tempered with cumin seeds."),
    MenuItem(id: 290, name: "Plain Rice", price: 90, category: "Rice Dish AC", serialNumber: 290, desc: "Steamed basmati rice."),
    MenuItem(id: 291, name: "Masala Rice", price: 160, category: "Rice Dish AC", serialNumber: 291, desc: "Spiced basmati rice with vegetables."),
    MenuItem(id: 292, name: "Half Jira Rice", price: 80, category: "Rice Dish AC", serialNumber: 292, desc: "Half portion of cumin-tempered rice."),
    MenuItem(id: 293, name: "Half Plain Rice", price: 70, category: "Rice Dish AC", serialNumber: 293, desc: "Half portion of steamed basmati rice."),
    MenuItem(id: 294, name: "Half Masala Rice", price: 110, category: "Rice Dish AC", serialNumber: 294, desc: "Half portion of spiced vegetable rice."),
    MenuItem(id: 295, name: "Veg.Rayta", price: 80, category: "Rice Dish AC", serialNumber: 295, desc: "Yogurt dip with cucumbers"),
    MenuItem(id: 296, name: "Kashmiri Rayta", price: 120, category: "Rice Dish AC", serialNumber: 296, desc: "Yogurt dip with mixed fruits and nuts."),
    MenuItem(id: 297, name: "Pineapple Rayta", price: 100, category: "Rice Dish AC", serialNumber: 297, desc: "Sweet yogurt dip loaded with pineapple chunks."),
    MenuItem(id: 298, name: "Bundi Rayta", price: 90, category: "Rice Dish AC", serialNumber: 298, desc: "Yogurt dip topped with crispy chickpea flour droplets."),

    // Sizzlers AC
    MenuItem(id: 299, name: "Veg. Sizzlers", price: 250, category: "Sizzlers AC", serialNumber: 299, desc: "Mixed veggies"),
    MenuItem(id: 300, name: "Mix Veg. Sizzlers", price: 250, category: "Sizzlers AC", serialNumber: 300, desc: "Assorted vegetables sizzler plate."),
    MenuItem(id: 301, name: "Combination Sizzlers", price: 250, category: "Sizzlers AC", serialNumber: 301, desc: "Combination of noodles"),
    MenuItem(id: 302, name: "Mix Grill Sizzlers", price: 250, category: "Sizzlers AC", serialNumber: 302, desc: "Tandoori grilled starters sizzler plate."),
    MenuItem(id: 303, name: "Chinese Sizzlers", price: 250, category: "Sizzlers AC", serialNumber: 303, desc: "Manchurian"),
    MenuItem(id: 304, name: "Garlic Ball (dry/liquid)", price: 160, category: "Sizzlers AC", serialNumber: 304, desc: "Spiced garlic dough balls served dry or in gravy."),
    MenuItem(id: 305, name: "Ginjer Ball (dry/liquid)", price: 160, category: "Sizzlers AC", serialNumber: 305, desc: "Spiced ginger dough balls served dry or in gravy."),
    MenuItem(id: 306, name: "Veg. Cheese Ball (dry)", price: 180, category: "Sizzlers AC", serialNumber: 306, desc: "Crispy fried cheese and vegetable balls."),
    MenuItem(id: 307, name: "Veg. Spring roll", price: 200, category: "Sizzlers AC", serialNumber: 307, desc: "Crispy fried rolls stuffed with spiced vegetables."),
    MenuItem(id: 308, name: "Hara Bhara Kabab", price: 200, category: "Sizzlers AC", serialNumber: 308, desc: "Pan-fried spiced spinach and potato patties."),
    MenuItem(id: 309, name: "Schzwan Ball (dry/liquid)", price: 170, category: "Sizzlers AC", serialNumber: 309, desc: "Spiced vegetable balls in Schezwan sauce."),

    // Cold Drinks AC
    MenuItem(id: 310, name: "Soft Drink (300 ml.)", price: 40, category: "Cold Drinks AC", serialNumber: 310, desc: "Chilled aerated soft drink 300 ml bottle."),
    MenuItem(id: 311, name: "Soft Drink (1.5 Lit.)", price: 90, category: "Cold Drinks AC", serialNumber: 311, desc: "Chilled aerated soft drink 1.5 L bottle."),
    MenuItem(id: 312, name: "Soft Drink (2 Lit.)", price: 110, category: "Cold Drinks AC", serialNumber: 312, desc: "Chilled aerated soft drink 2 L bottle."),
    MenuItem(id: 313, name: "Soda", price: 20, category: "Cold Drinks AC", serialNumber: 313, desc: "Chilled carbonated soda water."),
    MenuItem(id: 314, name: "Min. Water", price: 20, category: "Cold Drinks AC", serialNumber: 314, desc: "Chilled mineral drinking water."),
  ];

  final List<MenuItem> defaultMenu = newDefaultMenu;

  final List<TableModel> defaultTablesList = [
    TableModel(id: "A1", type: "table"),
    TableModel(id: "A2", type: "table"),
    TableModel(id: "A3", type: "table"),
    TableModel(id: "A4", type: "table"),
    TableModel(id: "A5", type: "table"),
    TableModel(id: "A6", type: "table"),
    TableModel(id: "B2", type: "table"),
    TableModel(id: "B3", type: "table"),
    TableModel(id: "B4", type: "table"),
    TableModel(id: "B5", type: "table"),
    TableModel(id: "C1", type: "table"),
    TableModel(id: "C2", type: "table"),
    TableModel(id: "C3", type: "table"),
    TableModel(id: "C4", type: "table"),
    TableModel(id: "C5", type: "table"),
    TableModel(id: "C6", type: "table"),
    TableModel(id: "D1", type: "table"),
    TableModel(id: "D",  type: "table"),
    TableModel(id: "D2", type: "table"),
    TableModel(id: "D3", type: "table"),
    TableModel(id: "D4", type: "table"),
    TableModel(id: "1B", type: "table"),
    TableModel(id: "PARCEL", type: "parcel"),
    TableModel(id: "PARCEL 2", type: "parcel"),
    TableModel(id: "PARCEL 3", type: "parcel"),
    TableModel(id: "PARCEL 4", type: "parcel"),
    TableModel(id: "PARCEL 5", type: "parcel")
  ];

  final List<CategoryModel> defaultCategories = newDefaultCategories;

  Timer? _licensePoller;
  Timer? _cloudSyncTimer;
  Timer? _cartSyncDebounce;
  bool _hasTenantDb = false;

  StreamSubscription? _tablesSubscription;
  StreamSubscription? _invoicesSubscription;
  StreamSubscription? _usersSubscription;
  StreamSubscription? _menuSubscription;
  StreamSubscription? _categoriesSubscription;
  StreamSubscription? _saasCentralDbSubscription;

  String parseUserAgent(String ua) {
    if (ua.contains('Android')) {
      try {
        final regExp = RegExp(r'Android\s+[^;]+;\s+([^)]+)');
        final match = regExp.firstMatch(ua);
        if (match != null && match.groupCount >= 1) {
          final model = match.group(1)!.split(';').first.trim();
          return "Android ($model)";
        }
      } catch (_) {}
      return "Android Device";
    }
    if (ua.contains('iPhone') || ua.contains('iPad') || ua.contains('iPod')) {
      if (ua.contains('iPhone')) return "iPhone";
      if (ua.contains('iPad')) return "iPad";
      return "iOS Device";
    }
    if (ua.contains('Windows')) {
      String browser = "Browser";
      if (ua.contains('Edg/')) browser = "Edge";
      else if (ua.contains('Chrome/')) browser = "Chrome";
      else if (ua.contains('Firefox/')) browser = "Firefox";
      else if (ua.contains('Safari/')) browser = "Safari";
      return "Windows ($browser)";
    }
    if (ua.contains('Macintosh')) {
      return "macOS Device";
    }
    if (ua.contains('Linux')) {
      return "Linux Device";
    }
    return "Web Terminal";
  }

  Future<void> loadDeviceName() async {
    if (kIsWeb) {
      try {
        final userAgent = js.context['navigator']['userAgent'] as String;
        cachedDeviceName = parseUserAgent(userAgent);
      } catch (e) {
        cachedDeviceName = "Web Browser (${defaultTargetPlatform.name.toUpperCase()})";
      }
      return;
    }
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        final brand = androidInfo.brand;
        final model = androidInfo.model;
        final brandCapitalized = brand.isNotEmpty 
            ? "${brand[0].toUpperCase()}${brand.substring(1)}" 
            : brand;
        cachedDeviceName = "$brandCapitalized $model";
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        cachedDeviceName = iosInfo.name;
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        cachedDeviceName = macInfo.computerName;
      } else if (Platform.isWindows) {
        final winInfo = await deviceInfo.windowsInfo;
        cachedDeviceName = winInfo.computerName;
      } else {
        cachedDeviceName = defaultTargetPlatform.name.toUpperCase();
      }
    } catch (e) {
      cachedDeviceName = defaultTargetPlatform.name.toUpperCase();
    }
  }

  String getDeviceName() {
    return cachedDeviceName;
  }

  AppState() {
    init();
  }

  Future<void> init() async {
    await LocalStorageHelper.init();
    await loadDeviceName();
    
    cloudInvoicesLimit = int.tryParse(LocalStorageHelper.getString('ahar_cloud_invoices_limit') ?? '100') ?? 100;
    
    // Check SaaS License Activation
    final savedKey = LocalStorageHelper.getString('ahar_license_key');

    if (savedKey == null || savedKey.isEmpty) {
      saasActivationRequired = true;
      saasLocked = false;
      saasTitle = "License Required";
    } else {
      saasActivationRequired = false;
      saasLocked = false;
      saasLicenseKey = savedKey;
      appId = int.tryParse(LocalStorageHelper.getString('ahar_app_id') ?? '104') ?? 104;

      // --- DYNAMIC DATABASE RE-INITIALIZATION ON STARTUP ---
      final dbConfigStr = LocalStorageHelper.getString('saas_tenant_db_config_$appId');
      if (dbConfigStr != null && dbConfigStr.isNotEmpty) {
        _hasTenantDb = true;
        try {
          final dbConfig = jsonDecode(dbConfigStr);
          TenantDbManager.initialize(Map<String, dynamic>.from(dbConfig)).then((_) {
            debugPrint('[DEBUG] Tenant database re-initialized on startup.');
          });
        } catch (e) {
          debugPrint('[DEBUG] Failed to parse or init tenant DB config on startup: $e');
        }
      } else {
        _hasTenantDb = false;
        debugPrint('[DEBUG] No tenant DB config found. Running in LOCAL-ONLY mode.');
      }
    }


    
    // Load store configuration
    storeName = LocalStorageHelper.getString('ahar_store_name') ?? "AAHAR SANDWICH & CHINESE";
    storeGstin = LocalStorageHelper.getString('ahar_store_gstin') ?? "24ACAPR9698D1Z8";
    parcelDeliveryCharge = double.tryParse(LocalStorageHelper.getString('ahar_parcel_delivery_charge') ?? '') ?? 40.0;
    isGstInclusive = LocalStorageHelper.getString('ahar_is_gst_inclusive') != 'false';
    showGstOnBills = LocalStorageHelper.getString('ahar_show_gst_on_bills') != 'false';
    allowDiscounts = LocalStorageHelper.getString('ahar_allow_discounts') != 'false';
    defaultGstRate = int.tryParse(LocalStorageHelper.getString('ahar_default_gst_rate') ?? '5') ?? 5;

    // Load printer connection status
    isPrinterConnected = LocalStorageHelper.getString('ahar_printer_connected') == 'true';
    connectedPrinterMac = LocalStorageHelper.getString('ahar_connected_printer_mac') ?? '';
    connectedPrinterName = LocalStorageHelper.getString('ahar_connected_printer_name') ?? '';
    selectedPrinterType = LocalStorageHelper.getString('ahar_selected_printer_type') ?? 'bluetooth';
    printerIpAddress = LocalStorageHelper.getString('ahar_printer_ip_address') ?? '192.168.1.100';

    if (isPrinterConnected && connectedPrinterMac.isNotEmpty && !kIsWeb) {
      _autoConnectPrinter();
    }

    // Load device configs
    terminalId = LocalStorageHelper.getString('ahar_terminal_id') ?? 'TERMINAL-01';
    isBarcodeScannerEnabled = LocalStorageHelper.getString('ahar_barcode_scanner') == 'true';
    isCashDrawerEnabled = LocalStorageHelper.getString('ahar_cash_drawer') == 'true';
    rollWidth = int.tryParse(LocalStorageHelper.getString('ahar_roll_width') ?? '2') ?? 2;
    invoiceCode = LocalStorageHelper.getString('ahar_invoice_code') ?? 'INV';
    playSound = LocalStorageHelper.getString('ahar_play_sound') != 'false';

    // Load account / cashier configs
    _cashierName = LocalStorageHelper.getString('ahar_cashier_name') ?? 'Himanshu';
    _cashierPin = LocalStorageHelper.getString('ahar_cashier_pin') ?? '1234';
    isRegisterShiftLocked = LocalStorageHelper.getString('ahar_shift_locked') != 'false';
    openingFloat = double.tryParse(LocalStorageHelper.getString('ahar_opening_float') ?? '500.0') ?? 500.0;

    // Load security recovery & log configs
    securityQuestion = LocalStorageHelper.getString('ahar_security_question') ?? 'What was the name of your first restaurant?';
    securityAnswer = LocalStorageHelper.getString('ahar_security_answer') ?? 'ahar';
    adminEmail = LocalStorageHelper.getString('ahar_admin_email') ?? 'admin@aharpos.com';
    lastLoginTime = LocalStorageHelper.getString('ahar_last_login_time') ?? '';
    _defaultParcelMode = LocalStorageHelper.getString('ahar_default_parcel_mode') ?? 'delivery';

    // Load users list
    final usersJson = LocalStorageHelper.getString('ahar_users');
    if (usersJson != null && usersJson.isNotEmpty) {
      try {
        final List list = jsonDecode(usersJson);
        users = list.map((item) => UserProfile.fromJson(item)).toList();
      } catch (e) {
        _loadDefaultUsers();
      }
    } else {
      _loadDefaultUsers();
    }

    // Set loggedInUser to the matching cashier profile
    if (users.isNotEmpty) {
      final match = users.where((u) => u.name == _cashierName).toList();
      if (match.isNotEmpty) {
        loggedInUser = match.first;
      } else {
        loggedInUser = users.first;
      }
    }

    // Load tables list
    final tablesJson = LocalStorageHelper.getString('ahar_tables');
    if (tablesJson != null) {
      try {
        final List list = jsonDecode(tablesJson);
        tables = list.map((item) => TableModel.fromJson(item)).toList();
      } catch (e) {
        tables = List.from(defaultTablesList);
      }
    } else {
      tables = List.from(defaultTablesList);
      saveTables();
    }

    final currentMenuVersion = 'v15';
    final savedMenuVersion = LocalStorageHelper.getString('ahar_menu_version');
    if (savedMenuVersion != currentMenuVersion) {
          // Reset categories to defaultCategories on menu version bump
          categories = List.from(newDefaultCategories);
          categories.sort((a, b) => a.serialNumber.compareTo(b.serialNumber));
          saveCategories();
      
          // Load menu catalog list
          final menuJson = LocalStorageHelper.getString('ahar_menu_items');
          if (menuJson != null) {
            try {
              final List list = jsonDecode(menuJson);
              menu = list.map((item) => MenuItem.fromJson(item)).toList();
            } catch (e) {
              menu = List.from(newDefaultMenu);
            }
          } else {
            menu = List.from(newDefaultMenu);
            saveMenu();
          }
          // Automatically migrate categories to match updated defaults, removing old categories
          final newCategoryNames = newDefaultCategories.map((c) => c.name).toSet();
          menu.removeWhere((item) => !newCategoryNames.contains(item.category));
          for (final defCat in newDefaultCategories) {
            menu.removeWhere((item) => item.category == defCat.name);
            menu.addAll(newDefaultMenu.where((item) => item.category == defCat.name));
          }
          menu.sort((a, b) => a.serialNumber.compareTo(b.serialNumber));
          cleanDuplicateMenuItems();
          saveMenu();
      LocalStorageHelper.setString('ahar_menu_version', currentMenuVersion);
      _didMigrateThisLaunch = true;
    } else {
      // Just load categories and menu normally without overwriting local custom changes with defaults
      final categoriesJson = LocalStorageHelper.getString('ahar_categories');
      if (categoriesJson != null) {
        try {
          final List list = jsonDecode(categoriesJson);
          categories = list.map((item) => CategoryModel.fromJson(item)).toList();
          if (categories.isEmpty) categories = List.from(newDefaultCategories);
        } catch (e) {
          categories = List.from(newDefaultCategories);
        }
      } else {
        categories = List.from(newDefaultCategories);
      }
      categories.sort((a, b) => a.serialNumber.compareTo(b.serialNumber));

      final menuJson = LocalStorageHelper.getString('ahar_menu_items');
      if (menuJson != null) {
        try {
          final List list = jsonDecode(menuJson);
          menu = list.map((item) => MenuItem.fromJson(item)).toList();
          if (menu.isEmpty) menu = List.from(newDefaultMenu);
        } catch (e) {
          menu = List.from(newDefaultMenu);
        }
      } else {
        menu = List.from(newDefaultMenu);
      }
      menu.sort((a, b) => a.serialNumber.compareTo(b.serialNumber));
      cleanDuplicateMenuItems();
    }

    // Load active carts
    final cartsJson = LocalStorageHelper.getString('ahar_active_carts');
    if (cartsJson != null) {
      try {
        final Map<String, dynamic> rawCarts = jsonDecode(cartsJson);
        activeCarts = rawCarts.map((key, value) {
          final List list = value;
          return MapEntry(key, list.map((item) => CartItem.fromJson(item)).toList());
        });
      } catch (e) {
        activeCarts = {};
      }
    }

    // Load table occupied times
    final occupiedTimesJson = LocalStorageHelper.getString('ahar_table_occupied_times');
    if (occupiedTimesJson != null) {
      try {
        final Map<String, dynamic> rawTimes = jsonDecode(occupiedTimesJson);
        tableOccupiedTimes = rawTimes.map((key, value) => MapEntry(key, value.toString()));
      } catch (e) {
        tableOccupiedTimes = {};
      }
    }

    // Load invoices
    final invoicesJson = LocalStorageHelper.getString('ahar_invoices');
    if (invoicesJson != null) {
      try {
        final List list = jsonDecode(invoicesJson);
        invoices = list.map((item) => InvoiceModel.fromJson(item)).toList();
        enforceSequentialInvoiceIds();
      } catch (e) {
        invoices = [];
      }
    }

    // Load navigation state
    activeView = LocalStorageHelper.getString('ahar_active_view') ?? 'home';
    currentCategory = LocalStorageHelper.getString('ahar_current_category') ?? 'SANDWICH';
    final savedTableId = LocalStorageHelper.getString('ahar_selected_table_id');
    selectedTableId = (savedTableId != null && savedTableId.isNotEmpty) ? savedTableId : null;
    if (selectedTableId != null) {
      draftCart = List.from(activeCarts[selectedTableId!]?.map((i) => CartItem(
        id: i.id,
        name: i.name,
        price: i.price,
        category: i.category,
        qty: i.qty,
        gstRate: i.gstRate,
        printedQty: i.printedQty,
      )) ?? []);
    }

    // Pre-population of busy tables and sample invoices has been removed to start with a clean state.

    // Initialize SaaS checking and setup realtime subscription to central_db
    _saasCentralDbSubscription = FirebaseFirestore.instance
        .collection('saas_data')
        .doc('central_db')
        .snapshots()
        .listen((snap) {
      if (snap.exists) {
        final dbJson = snap.data()?['dbJson'] as String?;
        if (dbJson != null && dbJson.isNotEmpty) {
          LocalStorageHelper.setString('saas_central_db', dbJson);
          try {
            final decoded = jsonDecode(dbJson);
            if (decoded is Map<String, dynamic>) {
              _hasFetchedCloudDb = true;
              checkSaaSStatus();
            }
          } catch (e) {
            debugPrint('Error decoding central_db update: $e');
          }
        }
      }
    });

    checkSaaSStatus();
    _licensePoller = Timer.periodic(const Duration(seconds: 60), (timer) {
      checkSaaSStatus();
    });

    // Try to fetch DB and settings from cloud immediately on startup
    fetchSaaSDatabaseFromCloud().then((_) {
      fetchSaaSGlobalSettingsFromCloud().then((_) {
        checkSaaSStatus();
        updateHeartbeatOnCloud();
        // After fetching cloud DB, check if a dbConfig was added for this key
        if (!_hasTenantDb && saasLicenseKey.isNotEmpty) {
          _checkAndUpgradeToCloudMode();
        }
      });
    });

    // Setup cloud sync timer (every 10 minutes to optimize Firestore daily read/write quota)
    _cloudSyncTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      fetchSaaSGlobalSettingsFromCloud();
      fetchSaaSDatabaseFromCloud(); // Keep local cache fresh for heartbeat
      updateHeartbeatOnCloud();
      // Periodically check if admin assigned a dbConfig to this license
      if (!_hasTenantDb && saasLicenseKey.isNotEmpty) {
        _checkAndUpgradeToCloudMode();
      }
    });

    // Try to sync with Firestore initial data on startup if license is active AND has a tenant DB
    if (saasLicenseKey.isNotEmpty && _hasTenantDb) {
      syncDataFromCloud().then((_) {
        startRealtimeSync();
      }).catchError((e) {
        debugPrint('[Firestore] Startup pull failed: $e');
        cloudStatus = 'offline';
        notifyListeners();
        // Register listeners anyway so we can sync when connection is restored!
        startRealtimeSync();
      });
    } else if (saasLicenseKey.isNotEmpty && !_hasTenantDb) {
      debugPrint('[LOCAL MODE] No tenant DB. App running fully offline with local data.');
      cloudStatus = 'local';
      notifyListeners();
    } else {
      cloudStatus = 'connected';
      notifyListeners();
    }
    _startInternetCheckTimer();
    notifyListeners();
  }

  @override
  void dispose() {
    _licensePoller?.cancel();
    _cloudSyncTimer?.cancel();
    _cartSyncDebounce?.cancel();
    _internetCheckTimer?.cancel();
    _tablesSubscription?.cancel();
    _invoicesSubscription?.cancel();
    _usersSubscription?.cancel();
    _menuSubscription?.cancel();
    _categoriesSubscription?.cancel();
    _saasCentralDbSubscription?.cancel();
    super.dispose();
  }

  Future<void> wipeTenantFirebaseData() async {
    try {
      debugPrint('[Firestore] Wiping old data from tenant Firebase...');
      final db = TenantDbManager.instance;
      final collections = ['menu_items', 'categories', 'invoices', 'tables', 'users'];
      for (var col in collections) {
        final snap = await db.collection(col).get();
        if (snap.docs.isNotEmpty) {
          final batch = db.batch();
          for (var doc in snap.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        }
      }
      debugPrint('[Firestore] Old data wiped successfully!');
    } catch (e) {
      debugPrint('[Firestore] Error wiping data: $e');
    }
  }

  void startRealtimeSync() {
    if (saasLicenseKey.isEmpty || !_hasTenantDb) return;
    
    final db = TenantDbManager.instance;
    
    // Listen to tables
    _tablesSubscription?.cancel();
    _tablesSubscription = db.collection('${saasLicenseKey}_tables').snapshots().listen((snap) {
      final List<TableModel> newTables = [];
      final Map<String, List<CartItem>> newCarts = {};
      final Map<String, String> newTimes = {};
      
      for (final doc in snap.docs) {
        final data = doc.data();
        final tableId = doc.id;
        
        newTables.add(TableModel(
          id: tableId,
          type: data['type'] ?? 'table',
        ));
        
        final occupyTime = data['occupyTime'] as String?;
        if (occupyTime != null && occupyTime.isNotEmpty) {
          newTimes[tableId] = occupyTime;
        }
        final itemsList = data['items'] as List?;
        if (itemsList != null && itemsList.isNotEmpty) {
          newCarts[tableId] = itemsList.map((i) => CartItem.fromJson(Map<String, dynamic>.from(i))).toList();
        }
      }
      
      if (newTables.isNotEmpty) {
        tables = newTables;
        activeCarts = newCarts;
        tableOccupiedTimes = newTimes;
        LocalStorageHelper.setString('ahar_tables', jsonEncode(tables.map((t) => t.toJson()).toList()));
        LocalStorageHelper.setString('ahar_active_carts', jsonEncode(activeCarts.map((k, v) => MapEntry(k, v.map((i) => i.toJson()).toList()))));
        LocalStorageHelper.setString('ahar_table_occupied_times', jsonEncode(tableOccupiedTimes));
        notifyListeners();
      }
    });

    // Listen to invoices
    _invoicesSubscription?.cancel();
    _invoicesSubscription = db.collection('${saasLicenseKey}_invoices').snapshots().listen((snap) {
      final List<InvoiceModel> newInvoices = snap.docs.map((d) => InvoiceModel.fromJson(d.data())).toList();
      if (newInvoices.isNotEmpty) {
        invoices = newInvoices;
        invoices.sort((a, b) => b.parsedDateTime.compareTo(a.parsedDateTime));
        LocalStorageHelper.setString('ahar_invoices', jsonEncode(invoices.map((i) => i.toJson()).toList()));
        notifyListeners();
      }
    });

    // Listen to users
    _usersSubscription?.cancel();
    _usersSubscription = db.collection('${saasLicenseKey}_users').snapshots().listen((snap) {
      final List<UserProfile> newUsers = snap.docs.map((d) => UserProfile.fromJson(d.data())).toList();
      if (newUsers.isNotEmpty) {
        users = newUsers;
        LocalStorageHelper.setString('ahar_users', jsonEncode(users.map((u) => u.toJson()).toList()));
        notifyListeners();
      }
    });

    // Listen to menu items
    _menuSubscription?.cancel();
    _menuSubscription = db.collection('${saasLicenseKey}_menu_items').snapshots().listen((snap) {
      final List<MenuItem> newMenu = snap.docs.map((d) => MenuItem.fromJson(d.data())).toList();
      if (newMenu.isNotEmpty) {
        menu = newMenu;
        menu.sort((a, b) => a.serialNumber.compareTo(b.serialNumber));
        LocalStorageHelper.setString('ahar_menu_items', jsonEncode(menu.map((m) => m.toJson()).toList()));
        notifyListeners();
      }
    });

    // Listen to categories
    _categoriesSubscription?.cancel();
    _categoriesSubscription = db.collection('${saasLicenseKey}_categories').snapshots().listen((snap) {
      final List<CategoryModel> newCategories = snap.docs.map((d) => CategoryModel.fromJson(d.data())).toList();
      if (newCategories.isNotEmpty) {
        categories = newCategories;
        categories.sort((a, b) => a.serialNumber.compareTo(b.serialNumber));
        LocalStorageHelper.setString('ahar_categories', jsonEncode(categories.map((c) => c.toJson()).toList()));
        notifyListeners();
      }
    });
  }

  /// Checks if the admin (Himanshu) has assigned a dbConfig to this license key.
  /// If yes, upgrades from local-only mode to cloud mode.
  Future<void> _checkAndUpgradeToCloudMode() async {
    try {
      final rawDb = LocalStorageHelper.getString('saas_central_db');
      if (rawDb == null) return;
      final dbObj = jsonDecode(rawDb);
      final List licensesList = dbObj['licenses'] ?? [];
      for (var l in licensesList) {
        if (l['key'].toString().trim().toUpperCase() == saasLicenseKey.trim().toUpperCase()) {
          if (l['dbConfig'] != null) {
            debugPrint('[UPGRADE] dbConfig found for this license! Upgrading to CLOUD mode...');
            final dbConfigStr = jsonEncode(l['dbConfig']);
            await LocalStorageHelper.setString('saas_tenant_db_config_$appId', dbConfigStr);
            await TenantDbManager.initialize(Map<String, dynamic>.from(l['dbConfig']));
            _hasTenantDb = true;
            await syncDataFromCloud();
            startRealtimeSync();
            debugPrint('[UPGRADE] Successfully upgraded to cloud mode!');
          }
          break;
        }
      }
    } catch (e) {
      debugPrint('[UPGRADE] Error checking for cloud upgrade: $e');
    }
  }

  Future<void> syncDataFromCloud() async {
    if (saasLicenseKey.isEmpty) return;
    if (!_hasTenantDb) {
      debugPrint('[LOCAL MODE] Skipping cloud sync — no tenant DB configured.');
      return;
    }
    cloudStatus = 'syncing';
    notifyListeners();
    try {
      if (LocalStorageHelper.getString('has_wiped_firebase_v4') != 'true') {
         await wipeTenantFirebaseData();
         LocalStorageHelper.setString('has_wiped_firebase_v4', 'true');
         // Force push the new local menu and categories to the clean firebase
         await FirestoreService.syncCategories(categories, saasLicenseKey);
         await FirestoreService.syncMenu(menu, saasLicenseKey);
         await FirestoreService.syncUsers(users, saasLicenseKey);
      }

      final cloudData = await FirestoreService.pullInitialData(saasLicenseKey);
      if (cloudData.isNotEmpty) {
        if (cloudData.containsKey('tables')) {
          tables = List<TableModel>.from(cloudData['tables']);
          LocalStorageHelper.setString('ahar_tables', jsonEncode(tables.map((t) => t.toJson()).toList()));
        }
        if (cloudData.containsKey('menu')) {
          if (_didMigrateThisLaunch) {
            await FirestoreService.syncMenu(menu, saasLicenseKey);
          } else {
            menu = List<MenuItem>.from(cloudData['menu']);
            cleanDuplicateMenuItems();
            LocalStorageHelper.setString('ahar_menu_items', jsonEncode(menu.map((m) => m.toJson()).toList()));
          }
        }
        if (cloudData.containsKey('categories')) {
          if (_didMigrateThisLaunch) {
            await FirestoreService.syncCategories(categories, saasLicenseKey);
          } else {
            categories = List<CategoryModel>.from(cloudData['categories']);
            LocalStorageHelper.setString('ahar_categories', jsonEncode(categories.map((c) => c.toJson()).toList()));
          }
        }
        if (cloudData.containsKey('users')) {
          if (_didMigrateThisLaunch) {
            await FirestoreService.syncUsers(users, saasLicenseKey);
          } else {
            users = List<UserProfile>.from(cloudData['users']);
            LocalStorageHelper.setString('ahar_users', jsonEncode(users.map((u) => u.toJson()).toList()));
          }
        }
        if (cloudData.containsKey('invoices')) {
          final cloudInvoices = List<InvoiceModel>.from(cloudData['invoices']);
          final Map<String, InvoiceModel> invoiceMap = {};
          for (final inv in cloudInvoices) {
            invoiceMap[inv.id] = inv;
          }
          for (final inv in invoices) {
            if (!invoiceMap.containsKey(inv.id)) {
              invoiceMap[inv.id] = inv;
            }
          }
          invoices = invoiceMap.values.toList();
          invoices.sort((a, b) => b.parsedDateTime.compareTo(a.parsedDateTime));
          LocalStorageHelper.setString('ahar_invoices', jsonEncode(invoices.map((i) => i.toJson()).toList()));
        }
        if (cloudData.containsKey('activeCarts')) {
          activeCarts = Map<String, List<CartItem>>.from(cloudData['activeCarts']);
          final rawMap = activeCarts.map((key, value) => MapEntry(key, value.map((i) => i.toJson()).toList()));
          LocalStorageHelper.setString('ahar_active_carts', jsonEncode(rawMap));
        }
        if (cloudData.containsKey('tableOccupiedTimes')) {
          tableOccupiedTimes = Map<String, String>.from(cloudData['tableOccupiedTimes']);
          LocalStorageHelper.setString('ahar_table_occupied_times', jsonEncode(tableOccupiedTimes));
        }
        cloudStatus = 'connected';
        invalidateCache();
        notifyListeners();
        debugPrint('[Firestore] Successfully synced data from cloud for license key $saasLicenseKey');
      } else {
        cloudStatus = 'connected';
        notifyListeners();
        debugPrint('[Firestore] Cloud is empty for this tenant! Pushing default app data up to cloud...');
        if (menu.isEmpty) menu = List.from(newDefaultMenu);
        if (categories.isEmpty) categories = List.from(newDefaultCategories);
        if (tables.isEmpty) tables = List.from(defaultTablesList);
        await FirestoreService.syncCategories(categories, saasLicenseKey);
        await FirestoreService.syncMenu(menu, saasLicenseKey);
        await FirestoreService.syncTables(tables, saasLicenseKey);
      }
    } catch (e) {
      debugPrint('[Firestore] Error syncing data from cloud: $e');
      cloudStatus = 'offline';
      notifyListeners();
    }
  }

  Future<void> pushLocalDataToCloud() async {
    if (saasLicenseKey.isEmpty) return;
    if (!_hasTenantDb) {
      debugPrint('[LOCAL MODE] Skipping cloud push — no tenant DB configured.');
      return;
    }
    if (_isPushingLocalData) return;
    _isPushingLocalData = true;
    cloudStatus = 'syncing';
    notifyListeners();
    try {
      await FirestoreService.syncTables(
        tables,
        saasLicenseKey,
        activeCarts: activeCarts,
        tableOccupiedTimes: tableOccupiedTimes,
      );
      await FirestoreService.syncMenu(menu, saasLicenseKey);
      await FirestoreService.syncCategories(categories, saasLicenseKey);
      await FirestoreService.syncUsers(users, saasLicenseKey);
      await FirestoreService.syncInvoices(invoices, saasLicenseKey);
      // Throttle diagnostic sync to once per 5 minutes to save bandwidth/quota
      final lastSync = LocalStorageHelper.getString('ahar_last_bt_sync');
      if (lastSync == null || DateTime.now().difference(DateTime.parse(lastSync)).inMinutes >= 5) {
        await FirestoreService.syncDiagnostics(btLogs, saasLicenseKey);
        LocalStorageHelper.setString('ahar_last_bt_sync', DateTime.now().toIso8601String());
      }
      cloudStatus = 'connected';
      notifyListeners();
      debugPrint('[Firestore] Successfully pushed all local data to cloud.');
    } catch (e) {
      debugPrint('[Firestore] Error pushing local data to cloud: $e');
      cloudStatus = 'offline';
      notifyListeners();
    } finally {
      _isPushingLocalData = false;
    }
  }

  Future<void> fetchSaaSGlobalSettingsFromCloud() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('saas_data').doc('global_settings').get().timeout(const Duration(seconds: 4));
      if (snap.exists) {
        final settingsJson = snap.data()?['settingsJson'] as String?;
        if (settingsJson != null && settingsJson.isNotEmpty) {
          await LocalStorageHelper.setString('saas_global_settings', settingsJson);
          debugPrint('[DEBUG] SaaS global settings fetched from cloud successfully.');
        }
      }
    } catch (e) {
      debugPrint('[DEBUG] Error fetching SaaS global settings from cloud: $e');
    }
  }

  // --- SaaS CLOUD DB SYNC METHODS ---

  Future<Map<String, dynamic>?> fetchSaaSDatabaseFromCloud() async {
    cloudStatus = 'syncing';
    notifyListeners();
    try {
      final snap = await FirebaseFirestore.instance.collection('saas_data').doc('central_db').get().timeout(const Duration(seconds: 4));
      if (snap.exists) {
        final dbJson = snap.data()?['dbJson'] as String?;
        if (dbJson != null && dbJson.isNotEmpty) {
          await LocalStorageHelper.setString('saas_central_db', dbJson);
          final decoded = jsonDecode(dbJson);
          if (decoded is Map<String, dynamic> &&
              decoded.containsKey('licenses') &&
              decoded.containsKey('customers') &&
              decoded.containsKey('applications')) {
            cloudStatus = 'connected';
            _hasFetchedCloudDb = true;
            notifyListeners();
            return decoded;
          }
        }
      } else {
        final Map<String, dynamic> defaultDbMap = {
          'customers': [
            {'id': 1, 'name': 'Rahul Sharma', 'contact': '+91 9876543210', 'appsOwned': 2},
            {'id': 2, 'name': 'Priya Singh', 'contact': '+91 8765432109', 'appsOwned': 1},
            {'id': 3, 'name': 'Amit Patel', 'contact': '+91 7654321098', 'appsOwned': 3}
          ],
          'applications': [
            {'id': 101, 'name': 'Restaurant POS System'},
            {'id': 102, 'name': 'Retail Inventory Pro'},
            {'id': 103, 'name': 'Hotel Manager Lite'},
            {'id': 104, 'name': 'Ahar Food App'}
          ],
          'licenses': [
            {'id': 1001, 'key': 'LIC-ABCD-1234-WXYZ', 'customerId': 1, 'appId': 101, 'rate': 1500, 'active': true, 'expiryDate': DateTime.now().add(const Duration(days: 15)).toIso8601String()},
            {'id': 1002, 'key': 'LIC-EFGH-5678-UVWX', 'customerId': 1, 'appId': 102, 'rate': 800, 'active': true, 'expiryDate': DateTime.now().add(const Duration(days: 25)).toIso8601String()},
            {'id': 1003, 'key': 'LIC-IJKL-9012-QRST', 'customerId': 2, 'appId': 101, 'rate': 1500, 'active': false, 'expiryDate': DateTime.now().subtract(const Duration(days: 2)).toIso8601String()},
            {'id': 1004, 'key': 'LIC-MNOP-3456-YZAB', 'customerId': 3, 'appId': 103, 'rate': 2500, 'active': true, 'expiryDate': DateTime.now().add(const Duration(days: 5)).toIso8601String()},
            {'id': 1005, 'key': 'LIC-AHAR-FOOD-2026', 'customerId': 1, 'appId': 104, 'rate': 1200, 'active': true, 'expiryDate': DateTime.now().add(const Duration(days: 30)).toIso8601String()}
          ],
          'activity': [],
          'pendingRenewals': []
        };
        await saveSaaSDatabaseToCloud(defaultDbMap);
        cloudStatus = 'connected';
        _hasFetchedCloudDb = true;
        notifyListeners();
        return defaultDbMap;
      }
    } catch (e) {
      debugPrint('[DEBUG] Error fetching central DB from Firestore: $e');
    }
    cloudStatus = 'offline';
    notifyListeners();
    return null;
  }

  Future<bool> saveSaaSDatabaseToCloud(Map<String, dynamic> dbObj) async {
    cloudStatus = 'syncing';
    notifyListeners();
    try {
      await FirebaseFirestore.instance.collection('saas_data').doc('central_db').set({
        'dbJson': jsonEncode(dbObj)
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 4));
      await LocalStorageHelper.setString('saas_central_db', jsonEncode(dbObj));
      cloudStatus = 'connected';
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[DEBUG] Error saving central DB to Firestore: $e');
    }
    cloudStatus = 'offline';
    notifyListeners();
    return false;
  }

  Future<void> updateHeartbeatOnCloud() async {
    if (saasActivationRequired || saasLicenseKey.isEmpty) return;
    if (!_hasTenantDb) {
      debugPrint('[LOCAL MODE] Skipping heartbeat — no tenant DB.');
      return;
    }

    try {
      // Use locally cached DB instead of fetching from cloud every time
      final rawDb = LocalStorageHelper.getString('saas_central_db');
      if (rawDb == null) return;
      final dbObj = jsonDecode(rawDb) as Map<String, dynamic>;

      final List licensesList = dbObj['licenses'] ?? [];
      int foundIdx = -1;
      for (int i = 0; i < licensesList.length; i++) {
        final l = licensesList[i];
        if (l is Map && l['key'].toString().trim().toUpperCase() == saasLicenseKey.trim().toUpperCase()) {
          foundIdx = i;
          break;
        }
      }

      if (foundIdx != -1) {
        final nowIso = DateTime.now().toIso8601String();
        licensesList[foundIdx]['lastSeen'] = nowIso;
        
        // Ensure current device is in pins with its deviceName
        final pins = licensesList[foundIdx]['pins'] != null ? Map<String, dynamic>.from(licensesList[foundIdx]['pins']) : {};
        final currentDevId = getOrCreateDeviceId();
        if (pins[currentDevId] != null && pins[currentDevId] is Map) {
          final devInfo = Map<String, dynamic>.from(pins[currentDevId] as Map);
          if (devInfo['deviceName'] == null) {
            devInfo['deviceName'] = getDeviceName();
            pins[currentDevId] = devInfo;
            licensesList[foundIdx]['pins'] = pins;
          }
        } else {
          pins[currentDevId] = {
            'pin': 'Not Set',
            'name': 'Unknown',
            'deviceName': getDeviceName(),
          };
          licensesList[foundIdx]['pins'] = pins;
        }
        
        // Update locally first for responsiveness, then async push
        await LocalStorageHelper.setString('saas_central_db', jsonEncode(dbObj));
        saveSaaSDatabaseToCloud(dbObj).then((success) {
           if (success) debugPrint('[DEBUG] Heartbeat updated on cloud successfully.');
        });
        
        cloudStatus = 'connected';
        final l = licensesList[foundIdx];
        final isActive = l['active'] ?? false;
        final expiry = l['expiryDate'] ?? DateTime.now().add(const Duration(days: 30)).toIso8601String();
        final rate = l['rate'] ?? 1200;
        final isRejected = l['paymentRejected'] == true;
        final cloudLimit = l['cloudInvoicesLimit'] ?? 100;
        if (cloudInvoicesLimit != cloudLimit) {
          updateCloudInvoicesLimit(cloudLimit);
        }
        
        String statusVal = isActive ? 'active' : 'paused';
        final List pendingRenewals = dbObj['pendingRenewals'] ?? [];
        final isPending = pendingRenewals.any((req) => req is Map && req['appId'] == appId);
        if (isPending) {
          statusVal = 'pending_verification';
        } else if (isRejected) {
          statusVal = 'rejected';
        }
        
        final licenseData = {
          'status': statusVal,
          'type': 'subscription',
          'expiryDate': expiry,
          'rate': rate,
          'paymentRejected': isRejected,
          'lastSeen': nowIso
        };
        await LocalStorageHelper.setString('saas_license_$appId', jsonEncode(licenseData));
        checkSaaSStatus();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[DEBUG] Error updating heartbeat on cloud: $e');
      cloudStatus = 'offline';
      notifyListeners();
    }
  }

  // --- SaaS LICENSE HANDLERS ---

  void checkSaaSStatus() {
    if (saasActivationRequired) return;

    final savedKey = LocalStorageHelper.getString('ahar_license_key');
    if (savedKey == null || savedKey.isEmpty) {
      saasActivationRequired = true;
      saasLocked = false;
      notifyListeners();
      return;
    }

    // Verify key still exists in central db
    var rawDb = LocalStorageHelper.getString('saas_central_db');
    bool needsReset = false;
    if (rawDb == null || rawDb.trim().isEmpty || rawDb == 'null') {
      needsReset = true;
    } else {
      try {
        final dbObj = jsonDecode(rawDb);
        if (dbObj is! Map || !dbObj.containsKey('licenses') || dbObj['licenses'] is! List) {
          needsReset = true;
        } else {
          final List licensesList = dbObj['licenses'];
          final uppercaseSavedKey = savedKey.trim().toUpperCase();
          final keyExists = licensesList.any((l) => l['key'].toString().trim().toUpperCase() == uppercaseSavedKey);
          
          final defaultKeys = ['LIC-ABCD-1234-WXYZ', 'LIC-EFGH-5678-UVWX', 'LIC-IJKL-9012-QRST', 'LIC-MNOP-3456-YZAB', 'LIC-AHAR-FOOD-2026', 'LIC-JQEL-CG2V-2ECX'];
          if (!keyExists && defaultKeys.contains(uppercaseSavedKey)) {
            needsReset = true;
          }
        }
      } catch (_) {
        needsReset = true;
      }
    }

    if (needsReset) {
      // Fallback local initialization in case of different origins/ports
      final defaultDb = {
        'customers': [
          {'id': 1, 'name': 'Rahul Sharma', 'contact': '+91 9876543210', 'appsOwned': 2},
          {'id': 2, 'name': 'Priya Singh', 'contact': '+91 8765432109', 'appsOwned': 1},
          {'id': 3, 'name': 'Amit Patel', 'contact': '+91 7654321098', 'appsOwned': 3}
        ],
        'applications': [
          {'id': 101, 'name': 'Restaurant POS System'},
          {'id': 102, 'name': 'Retail Inventory Pro'},
          {'id': 103, 'name': 'Hotel Manager Lite'},
          {'id': 104, 'name': 'Ahar Food App'}
        ],
        'licenses': [
          {'id': 1001, 'key': 'LIC-ABCD-1234-WXYZ', 'customerId': 1, 'appId': 101, 'rate': 1500, 'active': true, 'expiryDate': DateTime.now().add(const Duration(days: 15)).toIso8601String()},
          {'id': 1002, 'key': 'LIC-EFGH-5678-UVWX', 'customerId': 1, 'appId': 102, 'rate': 800, 'active': true, 'expiryDate': DateTime.now().add(const Duration(days: 25)).toIso8601String()},
          {'id': 1003, 'key': 'LIC-IJKL-9012-QRST', 'customerId': 2, 'appId': 101, 'rate': 1500, 'active': false, 'expiryDate': DateTime.now().subtract(const Duration(days: 2)).toIso8601String()},
          {'id': 1004, 'key': 'LIC-MNOP-3456-YZAB', 'customerId': 3, 'appId': 103, 'rate': 2500, 'active': true, 'expiryDate': DateTime.now().add(const Duration(days: 5)).toIso8601String()},
          {'id': 1005, 'key': 'LIC-AHAR-FOOD-2026', 'customerId': 1, 'appId': 104, 'rate': 1200, 'active': true, 'expiryDate': DateTime.now().add(const Duration(days: 30)).toIso8601String()},
          {
            'id': 1006, 
            'key': 'LIC-JQEL-CG2V-2ECX', 
            'customerId': 1, 
            'appId': 104, 
            'rate': 1200, 
            'active': true, 
            'expiryDate': DateTime.now().add(const Duration(days: 365)).toIso8601String(),
            'dbConfig': {
              'apiKey': 'AIzaSyC1FE1COnXA4iA0vArfj_nPLT9WejbRgoc',
              'authDomain': 'ahar-77377.firebaseapp.com',
              'projectId': 'ahar-77377',
              'storageBucket': 'ahar-77377.firebasestorage.app',
              'messagingSenderId': '420187507844',
              'appId': '1:420187507844:web:cd84759e03d1604b2c46d1'
            }
          }
        ],
        'activity': [],
        'pendingRenewals': []
      };
      rawDb = jsonEncode(defaultDb);
      LocalStorageHelper.setString('saas_central_db', rawDb);
    }

    if (rawDb != null) {
      try {
        final dbObj = jsonDecode(rawDb);
        final List licensesList = dbObj['licenses'] ?? [];
        
        Map<String, dynamic>? foundLicense;
        for (var l in licensesList) {
          if (l['key'].toString().trim().toUpperCase() == savedKey.trim().toUpperCase()) {
            foundLicense = l;
            break;
          }
        }
        
        if (foundLicense == null || (foundLicense['appId'] ?? 104) != 104) {
          if (_hasFetchedCloudDb) {
            deactivateApp();
          } else {
            debugPrint('[DEBUG] License key not found in local db cache on startup. Waiting for Firestore sync...');
          }
          return;
        }

        final List<dynamic> devicesList = foundLicense['devices'] != null
            ? List.from(foundLicense['devices'])
            : [];
        saasRegisteredDevices = devicesList.map((d) => d.toString()).toList();

        final cloudLimit = foundLicense['cloudInvoicesLimit'] ?? 100;
        if (cloudInvoicesLimit != cloudLimit) {
          updateCloudInvoicesLimit(cloudLimit);
        }

        // Verify device ID if cloud DB has been fetched
        if (_hasFetchedCloudDb) {
          final currentDevId = getOrCreateDeviceId();
          final List<dynamic> devices = foundLicense['devices'] != null
              ? List.from(foundLicense['devices'])
              : [];
          if (!devices.contains(currentDevId)) {
            debugPrint('[DEBUG] checkSaaSStatus: Device ID ($currentDevId) is not registered on cloud. Deactivating app.');
            deactivateApp();
            return;
          }
        }
      } catch (_) {}
    }

    final rawLicense = LocalStorageHelper.getString('saas_license_$appId');
    Map<String, dynamic> licenseData = {
      'status': 'active',
      'type': 'subscription',
      'expiryDate': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      'rate': 1200
    };

    if (rawLicense != null) {
      try {
        licenseData = jsonDecode(rawLicense);
      } catch (e) {
        debugPrint('JSON parse error saas_license: $e');
      }
    }

    // Heartbeat: update lastSeen timestamp to signal that the app is actively running
    licenseData['lastSeen'] = DateTime.now().toIso8601String();
    LocalStorageHelper.setString('saas_license_$appId', jsonEncode(licenseData));

    final newRate = licenseData['rate'] ?? 0;
    if (saasRate != newRate) {
      saasRate = newRate;
      notifyListeners();
    }

    // Load global settings overrides (QR image code URLs)
    final rawSettings = LocalStorageHelper.getString('saas_global_settings');
    if (rawSettings != null) {
      try {
        final settings = jsonDecode(rawSettings);
        saasQRCodeUrl = settings['paymentQRCodeUrl'] ?? '';
        if (saasQRCodeUrl.isEmpty) {
          saasQRCodeUrl = "https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=upi%3A%2F%2Fpay%3Fpa%3D9979711149%40ybl%26pn%3DRestroSaaS%26cu%3DINR";
        }
        saasAnnouncement = settings['announcement'] ?? 'Scan to Pay & Renew';
        saasSupportPhone = settings['supportPhone'] ?? '9979711149';
      } catch (_) {}
    }

    // Check status
    final String status = licenseData['status'] ?? 'active';

    if (status == 'pending_verification') {
      saasTitle = "Verification Pending";
      if (!saasLocked) {
        saasLocked = true;
        notifyListeners();
      }
      return;
    }

    if (status == 'rejected' || status == 'payment_rejected' || licenseData['paymentRejected'] == true) {
      saasTitle = "Payment Rejected";
      if (!saasLocked) {
        saasLocked = true;
        notifyListeners();
      }
      return;
    }

    if (status == 'paused') {
      saasTitle = "Service Suspended";
      if (!saasLocked) {
        saasLocked = true;
        notifyListeners();
      }
      return;
    }

    if (licenseData['type'] == 'subscription' && licenseData['expiryDate'] != null) {
      try {
        final expiry = DateTime.parse(licenseData['expiryDate']);
        if (DateTime.now().isAfter(expiry)) {
          saasTitle = "Subscription Expired";
          if (!saasLocked) {
            saasLocked = true;
            notifyListeners();
          }
          return;
        }
      } catch (_) {}
    }

    if (saasLocked) {
      saasLocked = false;
      notifyListeners();
    }
  }

  Future<bool> activateWithLicenseKey(String key, {String? ownerPin, String? ownerName}) async {
    licenseErrorMessage = '';
    debugPrint('[DEBUG] activateWithLicenseKey: entered key = "$key", pin = "$ownerPin", name = "$ownerName"');
    
    // Fetch latest DB from cloud first
    final dbObj = await fetchSaaSDatabaseFromCloud();
    var rawDb = LocalStorageHelper.getString('saas_central_db');
    debugPrint('[DEBUG] Loaded rawDb: ${rawDb != null ? "Length: ${rawDb.length}" : "Null"}');

    bool needsReset = false;
    if (rawDb == null || rawDb.trim().isEmpty || rawDb == 'null') {
      debugPrint('[DEBUG] rawDb is null/empty. Forcing reset to defaultDb.');
      needsReset = true;
    } else {
      try {
        final Map<String, dynamic> dbData = dbObj ?? jsonDecode(rawDb);
        if (!dbData.containsKey('licenses') || dbData['licenses'] is! List) {
          debugPrint('[DEBUG] rawDb is invalid/corrupted format. Forcing reset.');
          needsReset = true;
        } else {
          final List licensesList = dbData['licenses'];
          final uppercaseKey = key.trim().toUpperCase();
          final keyExists = licensesList.any((l) => l['key'].toString().trim().toUpperCase() == uppercaseKey);
          debugPrint('[DEBUG] Key "$uppercaseKey" exists in current rawDb: $keyExists');
          
          final defaultKeys = ['LIC-ABCD-1234-WXYZ', 'LIC-EFGH-5678-UVWX', 'LIC-IJKL-9012-QRST', 'LIC-MNOP-3456-YZAB', 'LIC-AHAR-FOOD-2026', 'LIC-JQEL-CG2V-2ECX'];
          if (!keyExists && defaultKeys.contains(uppercaseKey)) {
            debugPrint('[DEBUG] Key is a known default key but missing in current rawDb. Forcing reset.');
            needsReset = true;
          }
        }
      } catch (e) {
        debugPrint('[DEBUG] Exception parsing rawDb: $e. Forcing reset.');
        needsReset = true;
      }
    }

    if (needsReset) {
      debugPrint('[DEBUG] Performing fallback DB reset...');
      final defaultDb = {
        'customers': [
          {'id': 1, 'name': 'Rahul Sharma', 'contact': '+91 9876543210', 'appsOwned': 2},
          {'id': 2, 'name': 'Priya Singh', 'contact': '+91 8765432109', 'appsOwned': 1},
          {'id': 3, 'name': 'Amit Patel', 'contact': '+91 7654321098', 'appsOwned': 3}
        ],
        'applications': [
          {'id': 101, 'name': 'Restaurant POS System'},
          {'id': 102, 'name': 'Retail Inventory Pro'},
          {'id': 103, 'name': 'Hotel Manager Lite'},
          {'id': 104, 'name': 'Ahar Food App'}
        ],
        'licenses': [
          {'id': 1001, 'key': 'LIC-ABCD-1234-WXYZ', 'customerId': 1, 'appId': 101, 'rate': 1500, 'active': true, 'expiryDate': DateTime.now().add(const Duration(days: 15)).toIso8601String()},
          {'id': 1002, 'key': 'LIC-EFGH-5678-UVWX', 'customerId': 1, 'appId': 102, 'rate': 800, 'active': true, 'expiryDate': DateTime.now().add(const Duration(days: 25)).toIso8601String()},
          {'id': 1003, 'key': 'LIC-IJKL-9012-QRST', 'customerId': 2, 'appId': 101, 'rate': 1500, 'active': false, 'expiryDate': DateTime.now().subtract(const Duration(days: 2)).toIso8601String()},
          {'id': 1004, 'key': 'LIC-MNOP-3456-YZAB', 'customerId': 3, 'appId': 103, 'rate': 2500, 'active': true, 'expiryDate': DateTime.now().add(const Duration(days: 5)).toIso8601String()},
          {'id': 1005, 'key': 'LIC-AHAR-FOOD-2026', 'customerId': 1, 'appId': 104, 'rate': 1200, 'active': true, 'expiryDate': DateTime.now().add(const Duration(days: 30)).toIso8601String()},
          {
            'id': 1006, 
            'key': 'LIC-JQEL-CG2V-2ECX', 
            'customerId': 1, 
            'appId': 104, 
            'rate': 1200, 
            'active': true, 
            'expiryDate': DateTime.now().add(const Duration(days: 365)).toIso8601String(),
            'dbConfig': {
              'apiKey': 'AIzaSyC1FE1COnXA4iA0vArfj_nPLT9WejbRgoc',
              'authDomain': 'ahar-77377.firebaseapp.com',
              'projectId': 'ahar-77377',
              'storageBucket': 'ahar-77377.firebasestorage.app',
              'messagingSenderId': '420187507844',
              'appId': '1:420187507844:web:cd84759e03d1604b2c46d1'
            }
          }
        ],
        'activity': [],
        'pendingRenewals': []
      };
      rawDb = jsonEncode(defaultDb);
      LocalStorageHelper.setString('saas_central_db', rawDb);
    }

    if (rawDb == null) {
      debugPrint('[DEBUG] rawDb is null after reset block. Return false.');
      return false;
    }

    try {
      final dbObjDecoded = jsonDecode(rawDb);
      final List licensesList = dbObjDecoded['licenses'] ?? [];
      
      debugPrint('[DEBUG] Licenses inside DB:');
      for (var l in licensesList) {
        debugPrint(' - Key: "${l['key']}", appId: ${l['appId']}, active: ${l['active']}');
      }


      Map<String, dynamic>? foundLicense;
      for (var l in licensesList) {
        if (l['key'].toString().trim().toUpperCase() == key.trim().toUpperCase()) {
          foundLicense = l;
          break;
        }
      }

      if (foundLicense != null) {
        final targetAppId = foundLicense['appId'] ?? 104;
        debugPrint('[DEBUG] Found key matches license! targetAppId = $targetAppId');
        if (targetAppId != 104) {
          debugPrint('[DEBUG] Strict Security Block: targetAppId ($targetAppId) != 104. Rejecting!');
          licenseErrorMessage = 'Invalid App ID for this license.';
          return false;
        }

        // --- DEVICE VERIFICATION CHECK (MAX 2 DEVICES OR CUSTOM LIMIT) ---
        final currentDevId = getOrCreateDeviceId();
        final List<dynamic> devices = foundLicense['devices'] != null
            ? List.from(foundLicense['devices'])
            : [];
        final deviceLimit = foundLicense['deviceLimit'] ?? 2;
        
        bool dbChanged = false;
        if (!devices.contains(currentDevId)) {
          if (devices.length >= deviceLimit) {
            debugPrint('[DEBUG] Activation failed: Device limit reached.');
            licenseErrorMessage = 'This license key is already active on $deviceLimit other devices.\nPlease contact your administrator.';
            return false;
          }
          // Register the current device
          devices.add(currentDevId);
          foundLicense['devices'] = devices;
          dbChanged = true;
        }

        if (ownerPin != null && ownerPin.length == 4) {
          final ownerIdx = users.indexWhere((u) => u.role == 'owner');
          if (ownerIdx != -1) {
            final String nameToUse = ownerName != null && ownerName.isNotEmpty ? "$ownerName (Owner)" : users[ownerIdx].name;
            users[ownerIdx] = UserProfile(name: nameToUse, pin: ownerPin, role: users[ownerIdx].role);
            saveUsers();
            if (loggedInUser != null && loggedInUser!.role == 'owner') {
              loggedInUser = users[ownerIdx];
            }
          }
          
          final pins = foundLicense['pins'] != null ? Map<String, dynamic>.from(foundLicense['pins']) : {};
          final newPinObj = {
            'pin': ownerPin,
            'name': ownerName ?? '',
            'deviceName': getDeviceName(),
          };
          
          bool pinObjChanged = true;
          if (pins[currentDevId] != null && pins[currentDevId] is Map) {
            final existing = pins[currentDevId] as Map;
            if (existing['pin'] == ownerPin && existing['name'] == ownerName && existing['deviceName'] == getDeviceName()) {
              pinObjChanged = false;
            }
          }
          
          if (pinObjChanged) {
            pins[currentDevId] = newPinObj;
            foundLicense['pins'] = pins;
            dbChanged = true;
          }
        }

        if (dbChanged) {
          // Save the updated central DB back to Firestore (non-blocking for local-only mode)
          final saveSuccess = await saveSaaSDatabaseToCloud(dbObjDecoded);
          if (!saveSuccess) {
            debugPrint('[DEBUG] Failed to save database on cloud. Continuing with local activation.');
            // Save locally so device info is not lost
            LocalStorageHelper.setString('saas_central_db', jsonEncode(dbObjDecoded));
          }
        }
        appId = targetAppId;
        saasLicenseKey = key;
        saasActivationRequired = false;
        
        LocalStorageHelper.setString('ahar_license_key', key);
        LocalStorageHelper.setString('ahar_app_id', targetAppId.toString());

        // --- DYNAMIC DATABASE INITIALIZATION ---
        if (foundLicense['dbConfig'] != null) {
          final dbConfigStr = jsonEncode(foundLicense['dbConfig']);
          await LocalStorageHelper.setString('saas_tenant_db_config_$targetAppId', dbConfigStr);
          _hasTenantDb = true;
          try {
            await TenantDbManager.initialize(Map<String, dynamic>.from(foundLicense['dbConfig']));
            debugPrint('[DEBUG] Tenant database initialized from cloud config.');
          } catch (e) {
            debugPrint('[DEBUG] Failed to initialize tenant DB: $e');
          }
        } else {
          _hasTenantDb = false;
          debugPrint('[DEBUG] No dbConfig for this license. App will run in LOCAL-ONLY mode.');
        }

        // Sync local storage state
        final isActive = foundLicense['active'] ?? false;
        final expiry = foundLicense['expiryDate'] ?? DateTime.now().add(const Duration(days: 30)).toIso8601String();
        
        final licenseData = {
          'status': isActive ? 'active' : 'paused',
          'type': 'subscription',
          'expiryDate': expiry
        };
        LocalStorageHelper.setString('saas_license_$targetAppId', jsonEncode(licenseData));

        // Start heartbeat immediately on successful activation
        updateHeartbeatOnCloud();

        if (_hasTenantDb) {
          // Sync data from cloud for this license key (CLOUD MODE)
          await syncDataFromCloud();
          startRealtimeSync();
        } else {
          // LOCAL MODE: Load default menu data locally
          menu = List.from(newDefaultMenu);
          categories = List.from(newDefaultCategories);
          tables = List.from(defaultTablesList);
          saveMenu();
          saveCategories();
          saveTables();
          cloudStatus = 'local';
          debugPrint('[LOCAL MODE] App activated in local-only mode. Data stored on device.');
        }
        await fetchSaaSGlobalSettingsFromCloud();

        checkSaaSStatus();
        notifyListeners();
        debugPrint('[DEBUG] Activation successful!');
        return true;
      } else {
        debugPrint('[DEBUG] License key not found in db.');
      }
    } catch (e) {
      debugPrint('Error during activation: $e');
    }

    return false;
  }

  Future<bool> deactivateApp() async {
    final currentDevId = getOrCreateDeviceId();
    bool cloudRemoved = false;
    if (saasLicenseKey.isNotEmpty) {
      try {
        final dbObj = await fetchSaaSDatabaseFromCloud();
        if (dbObj != null) {
          final List licensesList = dbObj['licenses'] ?? [];
          int foundIdx = -1;
          for (int i = 0; i < licensesList.length; i++) {
            final l = licensesList[i];
            if (l is Map && l['key'].toString().trim().toUpperCase() == saasLicenseKey.trim().toUpperCase()) {
              foundIdx = i;
              break;
            }
          }

          if (foundIdx != -1) {
            final List devices = List.from(licensesList[foundIdx]['devices'] ?? []);
            if (devices.contains(currentDevId)) {
              devices.remove(currentDevId);
              licensesList[foundIdx]['devices'] = devices;
              await saveSaaSDatabaseToCloud(dbObj);
              debugPrint('[DEBUG] Device $currentDevId removed from cloud during deactivation.');
              cloudRemoved = true;
            }
          }
        }
      } catch (e) {
        debugPrint('[DEBUG] Error removing device from cloud during deactivation: $e');
      }
    }

    LocalStorageHelper.remove('ahar_license_key');
    LocalStorageHelper.remove('ahar_app_id');
    LocalStorageHelper.remove('saas_tenant_db_config_$appId');
    
    saasLicenseKey = "";
    saasActivationRequired = true;
    saasLocked = false;
    saasRegisteredDevices = [];
    _hasTenantDb = false;
    _tablesSubscription?.cancel();
    _invoicesSubscription?.cancel();
    _usersSubscription?.cancel();
    _menuSubscription?.cancel();
    _categoriesSubscription?.cancel();
    
    notifyListeners();
    return cloudRemoved;
  }


  Future<void> removeDeviceFromLicenseCloud(String deviceId) async {
    if (saasLicenseKey.isEmpty) return;
    try {
      final dbObj = await fetchSaaSDatabaseFromCloud();
      if (dbObj != null) {
        final List licensesList = dbObj['licenses'] ?? [];
        int foundIdx = -1;
        for (int i = 0; i < licensesList.length; i++) {
          final l = licensesList[i];
          if (l is Map && l['key'].toString().trim().toUpperCase() == saasLicenseKey.trim().toUpperCase()) {
            foundIdx = i;
            break;
          }
        }

        if (foundIdx != -1) {
          final List devices = List.from(licensesList[foundIdx]['devices'] ?? []);
          devices.remove(deviceId);
          licensesList[foundIdx]['devices'] = devices;
          
          final success = await saveSaaSDatabaseToCloud(dbObj);
          if (success) {
            debugPrint('[DEBUG] Device $deviceId removed successfully from cloud.');
            await LocalStorageHelper.setString('saas_central_db', jsonEncode(dbObj));
            checkSaaSStatus();
          }
        }
      }
    } catch (e) {
      debugPrint('[DEBUG] Error removing device from cloud: $e');
    }
  }

  Future<void> clearAllDevicesFromLicenseCloud() async {
    if (saasLicenseKey.isEmpty) return;
    try {
      final dbObj = await fetchSaaSDatabaseFromCloud();
      if (dbObj != null) {
        final List licensesList = dbObj['licenses'] ?? [];
        int foundIdx = -1;
        for (int i = 0; i < licensesList.length; i++) {
          final l = licensesList[i];
          if (l is Map && l['key'].toString().trim().toUpperCase() == saasLicenseKey.trim().toUpperCase()) {
            foundIdx = i;
            break;
          }
        }

        if (foundIdx != -1) {
          licensesList[foundIdx]['devices'] = [];
          
          final success = await saveSaaSDatabaseToCloud(dbObj);
          if (success) {
            debugPrint('[DEBUG] All registered devices cleared successfully from cloud.');
            await LocalStorageHelper.setString('saas_central_db', jsonEncode(dbObj));
            checkSaaSStatus();
          }
        }
      }
    } catch (e) {
      debugPrint('[DEBUG] Error clearing all devices from cloud: $e');
    }
  }

  Future<void> renewLicense() async {
    final savedKey = LocalStorageHelper.getString('ahar_license_key');
    if (savedKey != null && savedKey.isNotEmpty) {
      final dbObj = await fetchSaaSDatabaseFromCloud();
      if (dbObj != null) {
        try {
          final List licensesList = dbObj['licenses'] ?? [];
          
          int foundIdx = -1;
          for (int i = 0; i < licensesList.length; i++) {
            final l = licensesList[i];
            if (l is Map && l['key'].toString().trim().toUpperCase() == savedKey.trim().toUpperCase()) {
              foundIdx = i;
              break;
            }
          }

          if (foundIdx != -1) {
            final license = licensesList[foundIdx];
            final customerId = license['customerId'] ?? 1;
            final currentExpiry = license['expiryDate'] ?? DateTime.now().toIso8601String();
            
            // Clear paymentRejected flag from central DB
            license['paymentRejected'] = false;
            
            // Initialize pendingRenewals array in central DB if not exists
            if (dbObj['pendingRenewals'] == null) {
              dbObj['pendingRenewals'] = [];
            }
            final List pendingList = dbObj['pendingRenewals'];
            
            // Add if not already pending
            final alreadyPending = pendingList.any((req) => req is Map && req['appId'] == appId);
            if (!alreadyPending) {
              pendingList.add({
                'appId': appId,
                'licenseKey': savedKey,
                'rate': saasRate,
                'customerId': customerId,
                'storeName': storeName,
                'timestamp': DateTime.now().toIso8601String()
              });
            }
            
            // Log activity in central DB
            if (dbObj['activity'] == null) {
              dbObj['activity'] = [];
            }
            final List activityList = dbObj['activity'];
            activityList.insert(0, "Payment verification requested for License ${savedKey.split('-')[1]}...");
            if (activityList.length > 5) activityList.removeLast();

            // Save back to cloud and local storage
            await saveSaaSDatabaseToCloud(dbObj);
            
            // Sync the key for Ahar POS as pending_verification
            final licenseData = {
              'status': 'pending_verification',
              'type': 'subscription',
              'expiryDate': currentExpiry,
              'rate': saasRate,
              'paymentRejected': false
            };
            LocalStorageHelper.setString('saas_license_$appId', jsonEncode(licenseData));
          }
        } catch (e) {
          debugPrint('[DEBUG] Error renewing license: $e');
        }
      }
    }
    checkSaaSStatus();
  }

  // --- STORAGE WRITERS ---

  void saveStoreNameGstin() {
    LocalStorageHelper.setString('ahar_store_name', storeName);
    LocalStorageHelper.setString('ahar_store_gstin', storeGstin);
    LocalStorageHelper.setString('ahar_parcel_delivery_charge', parcelDeliveryCharge.toString());
    LocalStorageHelper.setString('ahar_is_gst_inclusive', isGstInclusive ? 'true' : 'false');
    LocalStorageHelper.setString('ahar_show_gst_on_bills', showGstOnBills ? 'true' : 'false');
    LocalStorageHelper.setString('ahar_allow_discounts', allowDiscounts ? 'true' : 'false');
    LocalStorageHelper.setString('ahar_default_gst_rate', defaultGstRate.toString());
  }

  void saveTables() async {
    LocalStorageHelper.setString('ahar_tables', jsonEncode(tables.map((t) => t.toJson()).toList()));
    cloudStatus = 'syncing';
    notifyListeners();
    try {
      await FirestoreService.syncTables(
        tables,
        saasLicenseKey,
        activeCarts: activeCarts,
        tableOccupiedTimes: tableOccupiedTimes,
      );
      cloudStatus = 'connected';
    } catch (_) {
      cloudStatus = 'offline';
    }
    notifyListeners();
  }

  void saveMenu() async {
    LocalStorageHelper.setString('ahar_menu_items', jsonEncode(menu.map((m) => m.toJson()).toList()));
    cloudStatus = 'syncing';
    notifyListeners();
    try {
      await FirestoreService.syncMenu(menu, saasLicenseKey);
      cloudStatus = 'connected';
    } catch (_) {
      cloudStatus = 'offline';
    }
    notifyListeners();
  }

  void saveCategories() async {
    LocalStorageHelper.setString('ahar_categories', jsonEncode(categories.map((c) => c.toJson()).toList()));
    cloudStatus = 'syncing';
    notifyListeners();
    try {
      await FirestoreService.syncCategories(categories, saasLicenseKey);
      cloudStatus = 'connected';
    } catch (_) {
      cloudStatus = 'offline';
    }
    notifyListeners();
  }

  void saveCarts() {
    final rawMap = activeCarts.map((key, value) => MapEntry(key, value.map((i) => i.toJson()).toList()));
    LocalStorageHelper.setString('ahar_active_carts', jsonEncode(rawMap));
    LocalStorageHelper.setString('ahar_table_occupied_times', jsonEncode(tableOccupiedTimes));
    
    // Debounced Firestore sync: waits 10s after last cart change to avoid excessive writes
    if (saasLicenseKey.isNotEmpty) {
      _cartSyncDebounce?.cancel();
      _cartSyncDebounce = Timer(const Duration(seconds: 30), () {
        FirestoreService.syncTables(
          tables,
          saasLicenseKey,
          activeCarts: activeCarts,
          tableOccupiedTimes: tableOccupiedTimes,
        ).catchError((_) {});
      });
    }
  }

  void saveInvoices() async {
    LocalStorageHelper.setString('ahar_invoices', jsonEncode(invoices.map((i) => i.toJson()).toList()));
    cloudStatus = 'syncing';
    notifyListeners();
    try {
      await FirestoreService.syncInvoices(invoices, saasLicenseKey);
      cloudStatus = 'connected';
    } catch (_) {
      cloudStatus = 'offline';
    }
    notifyListeners();
  }

  // --- POS BUSINESS ACTIONS ---

  void saveNavigationState() {
    LocalStorageHelper.setString('ahar_active_view', activeView);
    LocalStorageHelper.setString('ahar_current_category', currentCategory);
    if (selectedTableId != null && selectedTableId!.isNotEmpty) {
      LocalStorageHelper.setString('ahar_selected_table_id', selectedTableId!);
    } else {
      LocalStorageHelper.remove('ahar_selected_table_id');
    }
  }

  void navigateToView(String viewId) {
    if (activeView != viewId) {
      if (viewId == 'home') {
        viewHistory.clear();
      } else {
        if (viewHistory.isEmpty || viewHistory.last != activeView) {
          viewHistory.add(activeView);
        }
      }
      activeView = viewId;
      searchBarVisible = false;
      menuSearchQuery = '';
      saveNavigationState();
      notifyListeners();
    }
  }

  bool goBack() {
    if (viewHistory.isNotEmpty) {
      final prevView = viewHistory.last;
      if (prevView == 'home') {
        selectedTableId = null;
        draftCart.clear();
      }
      activeView = viewHistory.removeLast();
      searchBarVisible = false;
      menuSearchQuery = '';
      saveNavigationState();
      notifyListeners();
      return true;
    } else if (activeView != 'home') {
      selectedTableId = null;
      draftCart.clear();
      activeView = 'home';
      searchBarVisible = false;
      menuSearchQuery = '';
      saveNavigationState();
      notifyListeners();
      return true;
    }
    return false;
  }

  void selectTable(String tableId) {
    selectedTableId = tableId;
    currentCategory = 'SANDWICH';
    searchBarVisible = false;
    menuSearchQuery = '';
    
    // Copy the active cart to draftCart (deep copy)
    draftCart = List.from(activeCarts[tableId]?.map((i) => CartItem(
      id: i.id,
      name: i.name,
      price: i.price,
      category: i.category,
      qty: i.qty,
      gstRate: i.gstRate,
      printedQty: i.printedQty,
    )) ?? []);
    
    saveNavigationState();
    navigateToView('menu');
  }

  List<CartItem> get activeCart => selectedTableId != null ? draftCart : [];

  int get cartCount => activeCart.fold(0, (sum, item) => sum + item.qty);

  int get cartSubtotal {
    final discountRatio = 1.0 - (cartDiscountPercent / 100.0);
    if (!showGstOnBills) {
      return activeCart.fold(0, (sum, item) => sum + (item.price * item.qty * discountRatio).round());
    }
    if (isGstInclusive) {
      return activeCart.fold(0, (sum, item) {
        final totalItemPrice = (item.price * item.qty * discountRatio).round();
        final gstAmount = (totalItemPrice * item.gstRate / (100 + item.gstRate)).round();
        return sum + (totalItemPrice - gstAmount);
      });
    } else {
      return activeCart.fold(0, (sum, item) => sum + (item.price * item.qty * discountRatio).round());
    }
  }

  int get cartGst {
    if (!showGstOnBills) {
      return 0;
    }
    final discountRatio = 1.0 - (cartDiscountPercent / 100.0);
    if (isGstInclusive) {
      return activeCart.fold(0, (sum, item) {
        final totalItemPrice = (item.price * item.qty * discountRatio).round();
        return sum + (totalItemPrice * item.gstRate / (100 + item.gstRate)).round();
      });
    } else {
      return activeCart.fold(0, (sum, item) => sum + (item.price * item.qty * discountRatio * (item.gstRate / 100.0)).round());
    }
  }

  int get cartDelivery {
    if (cartSubtotal == 0) return 0;
    if (selectedTableId != null) {
      final table = tables.firstWhere((t) => t.id == selectedTableId, orElse: () => TableModel(id: '', type: ''));
      if (table.type == 'parcel') {
        return _defaultParcelMode == 'delivery' ? parcelDeliveryCharge.round() : 0;
      }
    }
    return 0; // tables (dine-in) default to 0 delivery/packaging charge
  }

  int get cartTotal => cartSubtotal + cartGst + cartDelivery;

  void addToCart(MenuItem item) {
    if (selectedTableId == null) return;
    playSystemSound();
    
    final existing = draftCart.where((i) => i.id == item.id).toList();

    if (existing.isNotEmpty) {
      existing.first.qty++;
    } else {
      draftCart.add(CartItem(
        id: item.id,
        name: item.name,
        price: item.price,
        category: item.category,
        qty: 1,
        gstRate: item.gstRate,
        printedQty: 0,
      ));
    }
    
    notifyListeners();
  }

  void updateQty(int itemId, int change) {
    if (selectedTableId == null) return;

    final items = draftCart.where((i) => i.id == itemId).toList();

    if (items.isNotEmpty) {
      final item = items.first;
      item.qty += change;
      if (item.qty <= 0) {
        draftCart.removeWhere((i) => i.id == itemId);
      }
    }

    notifyListeners();
  }

  void clearCart() {
    if (selectedTableId == null) return;
    draftCart.clear();
    notifyListeners();
  }

  List<CartItem> get newKOTItems {
    if (selectedTableId == null) return [];
    final List<CartItem> newItems = [];

    for (var item in draftCart) {
      final diffQty = item.qty - item.printedQty;
      if (diffQty > 0) {
        newItems.add(CartItem(
          id: item.id,
          name: item.name,
          price: item.price,
          category: item.category,
          qty: diffQty,
          gstRate: item.gstRate,
          printedQty: item.printedQty,
        ));
      }
    }
    return newItems;
  }

  void markKOTPrinted() {
    if (selectedTableId == null) return;
    for (var item in draftCart) {
      item.printedQty = item.qty;
    }
    activeCarts[selectedTableId!] = List.from(draftCart);
    if (!tableOccupiedTimes.containsKey(selectedTableId)) {
      tableOccupiedTimes[selectedTableId!] = DateTime.now().toIso8601String();
    }
    saveCarts();
    invalidateCache();
    notifyListeners();
  }

  void saveDraftToActive() {
    if (selectedTableId == null) return;
    if (draftCart.isEmpty) {
      activeCarts.remove(selectedTableId);
      tableOccupiedTimes.remove(selectedTableId);
    } else {
      activeCarts[selectedTableId!] = List.from(draftCart.map((i) => CartItem(
        id: i.id,
        name: i.name,
        price: i.price,
        category: i.category,
        qty: i.qty,
        gstRate: i.gstRate,
        printedQty: i.printedQty,
      )));
    }
    saveCarts();
    invalidateCache();
    notifyListeners();
  }

  void confirmOrder() {
    if (selectedTableId == null) return;
    saveDraftToActive();
    
    // Start occupancy timer if not already active
    if (!tableOccupiedTimes.containsKey(selectedTableId)) {
      tableOccupiedTimes[selectedTableId!] = DateTime.now().toIso8601String();
    }
    
    saveCarts();
    selectedTableId = null;
    draftCart.clear();
    activeView = 'home';
    viewHistory.clear();
    saveNavigationState();
    notifyListeners();
  }

  void cancelOrderDraft() {
    selectedTableId = null;
    draftCart.clear();
    activeView = 'home';
    viewHistory.clear();
    saveNavigationState();
    notifyListeners();
  }

  void discardDraftChanges() {
    if (selectedTableId == null) return;
    draftCart.removeWhere((item) => item.printedQty == 0);
    for (var item in draftCart) {
      item.qty = item.printedQty;
    }
    if (draftCart.isEmpty) {
      activeCarts.remove(selectedTableId);
      tableOccupiedTimes.remove(selectedTableId);
    } else {
      activeCarts[selectedTableId!] = List.from(draftCart);
    }
    saveCarts();
    selectedTableId = null;
    draftCart.clear();
    activeView = 'home';
    viewHistory.clear();
    saveNavigationState();
    notifyListeners();
  }

  void discardDraftForTable(String tableId) {
    final list = activeCarts[tableId] ?? [];
    list.removeWhere((item) => item.printedQty == 0);
    for (var item in list) {
      item.qty = item.printedQty;
    }
    if (list.isEmpty) {
      activeCarts.remove(tableId);
      tableOccupiedTimes.remove(tableId);
    } else {
      activeCarts[tableId] = list;
    }
    saveCarts();
    notifyListeners();
  }

  void selectCategory(String cat) {
    currentCategory = cat;
    saveNavigationState();
    notifyListeners();
  }

  void toggleMenuSearch() {
    searchBarVisible = !searchBarVisible;
    if (!searchBarVisible) {
      menuSearchQuery = '';
    }
    notifyListeners();
  }

  void updateMenuSearch(String text) {
    menuSearchQuery = text.trim().toLowerCase();
    notifyListeners();
  }

  // Finalizes table checkout and logs invoices
  String placeOrder() {
    if (selectedTableId == null || activeCart.isEmpty) return '';
    playSystemSound();

    final sub = cartSubtotal;
    final tax = cartGst;
    final del = cartDelivery;
    final tot = cartTotal;

    final tempInvId = "TEMP-${DateTime.now().millisecondsSinceEpoch}";
    final now = DateTime.now();
    final dateStr = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}, ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}";

    // Retrieve occupied check-in time
    String? checkInStr;
    final occupiedIso = tableOccupiedTimes[selectedTableId!];
    if (occupiedIso != null) {
      final occupiedDt = DateTime.tryParse(occupiedIso);
      if (occupiedDt != null) {
        final h = occupiedDt.hour.toString().padLeft(2, '0');
        final m = occupiedDt.minute.toString().padLeft(2, '0');
        final s = occupiedDt.second.toString().padLeft(2, '0');
        final ampm = occupiedDt.hour >= 12 ? 'PM' : 'AM';
        checkInStr = "${occupiedDt.day.toString().padLeft(2, '0')}/${occupiedDt.month.toString().padLeft(2, '0')}/${occupiedDt.year}, $h:$m:$s $ampm";
      }
    }

    final newInvoice = InvoiceModel(
      id: tempInvId,
      tableId: selectedTableId!,
      dateTime: dateStr,
      checkInTime: checkInStr ?? dateStr,
      items: List.from(activeCart),
      subtotal: sub,
      gst: tax,
      packaging: del,
      total: tot,
      originalTotal: tot,
      discountPercent: cartDiscountPercent,
    );

    invoices.insert(0, newInvoice);
    enforceSequentialInvoiceIds();

    final finalInvId = invoices.isNotEmpty ? invoices[0].id : tempInvId;

    cartDiscountPercent = 0.0;
    activeCarts.remove(selectedTableId);
    tableOccupiedTimes.remove(selectedTableId);
    saveCarts();

    // Store for print/receipt viewer
    if (invoices.isNotEmpty) {
      selectedReceiptInvoice = invoices[0];
    }

    selectedTableId = null;
    activeView = 'home';
    viewHistory.clear();
    saveNavigationState();
    invalidateCache();
    notifyListeners();

    return finalInvId;
  }

  void generateTableBill() {
    if (activeCart.isEmpty) return;
    placeOrder();
  }

  // --- CRUD CONFIGURATIONS ---

  void addTable(String name, String type) {
    if (tables.any((t) => t.id.toUpperCase() == name.toUpperCase())) return;
    tables.add(TableModel(id: name.toUpperCase(), type: type));
    saveTables();
    notifyListeners();
  }

  void deleteTable(String tableId) {
    tables.removeWhere((t) => t.id == tableId);
    activeCarts.remove(tableId);
    tableOccupiedTimes.remove(tableId);
    saveTables();
    saveCarts();
    notifyListeners();
  }

  void addCategory(String name, int serialNumber) {
    if (categories.any((c) => c.name.toUpperCase() == name.toUpperCase())) return;
    categories.add(CategoryModel(name: name, serialNumber: serialNumber));
    categories.sort((a, b) => a.serialNumber.compareTo(b.serialNumber));
    saveCategories();
    notifyListeners();
  }

  void deleteCategory(String name) {
    categories.removeWhere((c) => c.name == name);
    saveCategories();
    notifyListeners();
  }

  void addMenuItem({
    required String name,
    required int price,
    required String category,
    required int serialNumber,
    required bool isVeg,
    required int gstRate,
  }) {
    final nextId = menu.isEmpty ? 1 : menu.map((m) => m.id).reduce((a, b) => a > b ? a : b) + 1;
    menu.add(MenuItem(
      id: nextId,
      name: name,
      price: price,
      category: category,
      desc: "Custom gourmet dish added in settings.",
      serialNumber: serialNumber,
      isVeg: isVeg,
      gstRate: gstRate,
    ));
    menu.sort((a, b) => a.serialNumber.compareTo(b.serialNumber));
    saveMenu();
    notifyListeners();
  }

  void deleteMenuItem(int id) {
    menu.removeWhere((m) => m.id == id);
    saveMenu();
    notifyListeners();
  }

  void updateMenuItem({
    required int id,
    required String name,
    required int price,
    required String category,
    required int serialNumber,
    required bool isVeg,
    required int gstRate,
  }) {
    final idx = menu.indexWhere((m) => m.id == id);
    if (idx != -1) {
      menu[idx] = MenuItem(
        id: id,
        name: name,
        price: price,
        category: category,
        desc: menu[idx].desc,
        serialNumber: serialNumber,
        isVeg: isVeg,
        gstRate: gstRate,
      );
      menu.sort((a, b) => a.serialNumber.compareTo(b.serialNumber));
      saveMenu();
      notifyListeners();
    }
  }

  void toggleGstInclusive(bool value) {
    isGstInclusive = value;
    LocalStorageHelper.setString('ahar_is_gst_inclusive', value ? 'true' : 'false');
    notifyListeners();
  }

  void updateCartDiscount(double percent) {
    cartDiscountPercent = percent;
    notifyListeners();
  }

  void saveStoreSettings(String name, String gstin, double charge, bool gstInclusive, bool showGst, bool discountsAllowed, int defaultGst) {
    storeName = name;
    storeGstin = gstin;
    parcelDeliveryCharge = charge;
    isGstInclusive = gstInclusive;
    showGstOnBills = showGst;
    allowDiscounts = discountsAllowed;
    defaultGstRate = defaultGst;
    if (!allowDiscounts) {
      cartDiscountPercent = 0.0;
    }
    saveStoreNameGstin();
    notifyListeners();
  }

  Future<void> _autoConnectPrinter() async {
    if (kIsWeb || connectedPrinterMac.isEmpty) return;
    try {
      try {
        isBluetoothEnabled = await PrintBluetoothThermal.bluetoothEnabled;
      } catch (_) {
        isBluetoothEnabled = true;
      }
      try {
        await PrintBluetoothThermal.disconnect;
      } catch (_) {}
      final connected = await PrintBluetoothThermal.connect(macPrinterAddress: connectedPrinterMac);
      isPrinterConnected = connected;
      LocalStorageHelper.setString('ahar_printer_connected', connected ? 'true' : 'false');
      notifyListeners();
    } catch (e) {
      debugPrint("Auto connect to printer failed: $e");
      isPrinterConnected = false;
      LocalStorageHelper.setString('ahar_printer_connected', 'false');
      notifyListeners();
    }
  }

  Future<void> scanForPrinters() async {
    if (kIsWeb) return;
    addBtLog('SCAN', 'Scanning for paired Bluetooth devices...', 'APP_SIDE');
    isBtScanning = true;
    availablePrinters = [];
    notifyListeners();

    try {
      try {
        isBluetoothEnabled = await PrintBluetoothThermal.bluetoothEnabled;
      } catch (_) {
        isBluetoothEnabled = true;
      }
      if (!isBluetoothEnabled) {
        addBtLog('SCAN', 'Bluetooth is turned OFF on this device. Please enable Bluetooth from system settings.', 'MACHINE_SIDE');
      }
      final List<BluetoothInfo> list = await PrintBluetoothThermal.pairedBluetooths;
      availablePrinters = list;
      addBtLog('SCAN', 'Scan complete. Found ${list.length} paired device(s).', 'APP_SIDE');
    } catch (e) {
      addBtLog('SCAN', 'Failed to scan for Bluetooth devices.', 'MACHINE_SIDE', error: e.toString());
      debugPrint("Error scanning for Bluetooth printers: $e");
    } finally {
      isBtScanning = false;
      notifyListeners();
    }
  }

  Future<bool> connectToBluetoothPrinter(String macAddress, String name, {int maxRetries = 3}) async {
    if (kIsWeb) {
      isPrinterConnected = true;
      connectedPrinterMac = macAddress;
      connectedPrinterName = name;
      LocalStorageHelper.setString('ahar_printer_connected', 'true');
      LocalStorageHelper.setString('ahar_connected_printer_mac', macAddress);
      LocalStorageHelper.setString('ahar_connected_printer_name', name);
      addBtLog('CONNECT', 'Web mode: Simulated connection to $name ($macAddress).', 'APP_SIDE', mac: macAddress);
      notifyListeners();
      return true;
    }

    addBtLog('CONNECT', 'Attempting to connect to "$name" ($macAddress) with $maxRetries max retries...', 'APP_SIDE', mac: macAddress);
    isBtScanning = true;
    notifyListeners();

    try {
      try {
        isBluetoothEnabled = await PrintBluetoothThermal.bluetoothEnabled;
      } catch (_) {
        isBluetoothEnabled = true;
      }

      if (!isBluetoothEnabled) {
        addBtLog('CONNECT', 'FAILED: Bluetooth is OFF on this device. Cannot connect to printer.', 'MACHINE_SIDE', mac: macAddress);
      }

      // Retry loop for flaky BT connections (e.g. BPT-10077650)
      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        try {
          // Always cleanly disconnect before reconnecting
          try {
            await PrintBluetoothThermal.disconnect;
          } catch (_) {}

          // Small delay between disconnect and reconnect for BT stack stability
          if (attempt > 1) {
            addBtLog('RETRY', 'Retry attempt $attempt/$maxRetries after ${500 * attempt}ms delay...', 'APP_SIDE', mac: macAddress);
            await Future.delayed(Duration(milliseconds: 500 * attempt));
          }

          final bool connected = await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
          if (connected) {
            isPrinterConnected = true;
            connectedPrinterMac = macAddress;
            connectedPrinterName = name;
            LocalStorageHelper.setString('ahar_printer_connected', 'true');
            LocalStorageHelper.setString('ahar_connected_printer_mac', macAddress);
            LocalStorageHelper.setString('ahar_connected_printer_name', name);
            addBtLog('CONNECT', 'SUCCESS: Connected to "$name" ($macAddress) on attempt $attempt.', 'APP_SIDE', mac: macAddress);
            return true;
          }

          addBtLog('CONNECT', 'Attempt $attempt/$maxRetries failed. Printer did not accept connection. Check if printer is ON and in range.', 'MACHINE_SIDE', mac: macAddress);
        } catch (e) {
          addBtLog('ERROR', 'Attempt $attempt/$maxRetries threw error. Possibly printer is busy, out of range, or BT stack crashed.', 'MACHINE_SIDE', mac: macAddress, error: e.toString());
        }
      }

      // All retries failed
      addBtLog('CONNECT', 'FAILED: All $maxRetries connection attempts failed for "$name" ($macAddress). Printer may be OFF, out of range, or paired with another device.', 'MACHINE_SIDE', mac: macAddress);
      isPrinterConnected = false;
      LocalStorageHelper.setString('ahar_printer_connected', 'false');
      return false;
    } catch (e) {
      addBtLog('ERROR', 'Critical error during connection to "$name" ($macAddress). App-side Bluetooth stack error.', 'APP_SIDE', mac: macAddress, error: e.toString());
      isPrinterConnected = false;
      LocalStorageHelper.setString('ahar_printer_connected', 'false');
      return false;
    } finally {
      isBtScanning = false;
      notifyListeners();
    }
  }


  Future<void> disconnectFromBluetoothPrinter() async {
    addBtLog('DISCONNECT', 'User requested disconnect from "$connectedPrinterName" ($connectedPrinterMac).', 'APP_SIDE');
    isPrinterConnected = false;
    LocalStorageHelper.setString('ahar_printer_connected', 'false');
    notifyListeners();

    if (!kIsWeb) {
      try {
        await PrintBluetoothThermal.disconnect;
        addBtLog('DISCONNECT', 'Successfully disconnected from Bluetooth printer.', 'APP_SIDE');
      } catch (e) {
        addBtLog('ERROR', 'Error while disconnecting. BT stack may be in an unstable state.', 'APP_SIDE', error: e.toString());
        debugPrint("Error disconnecting from Bluetooth printer: $e");
      }
    }
  }

  Future<void> togglePrinterConnection(bool connected) async {
    addBtLog('TOGGLE', 'User toggled printer switch to ${connected ? 'ON' : 'OFF'}.', 'APP_SIDE');
    if (connected) {
      if (connectedPrinterMac.isNotEmpty) {
        // Await the connection so the toggle reflects the true result
        final success = await connectToBluetoothPrinter(connectedPrinterMac, connectedPrinterName);
        // If connection failed, ensure toggle stays OFF (not stuck)
        if (!success) {
          addBtLog('TOGGLE', 'Toggle ON failed: Could not connect. Toggle reset to OFF. Check if printer is ON and in range.', 'MACHINE_SIDE');
          isPrinterConnected = false;
          LocalStorageHelper.setString('ahar_printer_connected', 'false');
          notifyListeners();
        }
      } else {
        addBtLog('TOGGLE', 'No printer MAC saved. Please detect and select a printer first.', 'APP_SIDE');
        isPrinterConnected = true;
        LocalStorageHelper.setString('ahar_printer_connected', 'true');
        notifyListeners();
      }
    } else {
      disconnectFromBluetoothPrinter();
    }
  }

  /// Ensures BT printer is connected before printing.
  /// If disconnected, automatically tries to reconnect.
  /// Returns true if connected and ready to print.
  Future<bool> ensureBluetoothConnection() async {
    if (kIsWeb) return true;
    if (selectedPrinterType == 'wifi') return true;

    try {
      final bool isConnected = await PrintBluetoothThermal.connectionStatus;
      if (isConnected) {
        // Sync state in case it drifted
        if (!isPrinterConnected) {
          addBtLog('SYNC', 'Connection state synced: Hardware says connected, but app thought disconnected. State corrected.', 'APP_SIDE');
          isPrinterConnected = true;
          notifyListeners();
        }
        return true;
      }
    } catch (_) {
      addBtLog('ERROR', 'Could not check BT hardware connection status. BT stack may be unresponsive.', 'APP_SIDE');
    }

    // Not connected - try auto-reconnect if we have a saved MAC
    if (connectedPrinterMac.isNotEmpty) {
      addBtLog('AUTO_RECONNECT', 'Printer found disconnected before print. Auto-reconnecting to "$connectedPrinterName" ($connectedPrinterMac)...', 'MACHINE_SIDE');
      return await connectToBluetoothPrinter(connectedPrinterMac, connectedPrinterName, maxRetries: 3);
    }

    // No saved printer to reconnect to
    addBtLog('ERROR', 'No saved printer MAC address. Cannot auto-reconnect. Please select a printer from Detect Printer.', 'APP_SIDE');
    isPrinterConnected = false;
    notifyListeners();
    return false;
  }

  /// Syncs the in-memory isPrinterConnected state with actual BT hardware status.
  /// Call this periodically or before critical operations.
  Future<void> syncBluetoothConnectionState() async {
    if (kIsWeb || selectedPrinterType == 'wifi') return;

    try {
      final bool actuallyConnected = await PrintBluetoothThermal.connectionStatus;
      if (isPrinterConnected != actuallyConnected) {
        if (actuallyConnected) {
          addBtLog('SYNC', 'State mismatch detected: Printer is actually CONNECTED but app showed disconnected. Corrected.', 'APP_SIDE');
        } else {
          addBtLog('SYNC', 'State mismatch detected: Printer is actually DISCONNECTED but app showed connected. Printer may have gone out of range, turned OFF, or lost power.', 'MACHINE_SIDE');
        }
        isPrinterConnected = actuallyConnected;
        LocalStorageHelper.setString('ahar_printer_connected', actuallyConnected ? 'true' : 'false');
        notifyListeners();
      }
    } catch (e) {
      addBtLog('ERROR', 'Failed to sync BT connection state with hardware. BT adapter may be unresponsive.', 'APP_SIDE', error: e.toString());
      debugPrint('Error syncing BT state: $e');
    }
  }

  void setPrinterType(String type) {
    selectedPrinterType = type;
    LocalStorageHelper.setString('ahar_selected_printer_type', type);
    notifyListeners();
  }

  void setPrinterIpAddress(String ip) {
    printerIpAddress = ip;
    LocalStorageHelper.setString('ahar_printer_ip_address', ip);
    notifyListeners();
  }

  void setInvoiceFilter(String? filterType) {
    activeInvoiceFilter = filterType;
    notifyListeners();
  }

  void setCustomInvoiceFilter(DateTime start, DateTime end) {
    activeInvoiceFilter = 'custom';
    customFilterStartDate = start;
    customFilterEndDate = end;
    notifyListeners();
  }

  DateTime? parseInvoiceDate(String dateStr) {
    try {
      final parts = dateStr.split(', ');
      final dateParts = parts[0].split('/');
      final day = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final year = int.parse(dateParts[2]);

      final timeParts = parts[1].split(' ');
      final timeHMS = timeParts[0].split(':');
      var hour = int.parse(timeHMS[0]);
      final minute = int.parse(timeHMS[1]);
      final second = int.parse(timeHMS[2]);
      final ampm = timeParts[1].toUpperCase();

      if (ampm == 'PM' && hour < 12) {
        hour += 12;
      } else if (ampm == 'AM' && hour == 12) {
        hour = 0;
      }

      return DateTime(year, month, day, hour, minute, second);
    } catch (e) {
      debugPrint('Error parsing invoice date "$dateStr": $e');
      return null;
    }
  }

  List<InvoiceModel> get filteredInvoices {
    if (activeInvoiceFilter == null) return invoices;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1)).subtract(const Duration(microseconds: 1));

    switch (activeInvoiceFilter) {
      case 'today':
        return invoices.where((inv) {
          final date = inv.parsedDateTime;
          return date.isAfter(todayStart.subtract(const Duration(microseconds: 1))) && date.isBefore(todayEnd.add(const Duration(microseconds: 1)));
        }).toList();

      case 'yesterday':
        final yesterdayStart = todayStart.subtract(const Duration(days: 1));
        final yesterdayEnd = todayEnd.subtract(const Duration(days: 1));
        return invoices.where((inv) {
          final date = inv.parsedDateTime;
          return date.isAfter(yesterdayStart.subtract(const Duration(microseconds: 1))) && date.isBefore(yesterdayEnd.add(const Duration(microseconds: 1)));
        }).toList();

      case 'this_week':
        final weekday = now.weekday;
        final mondayStart = todayStart.subtract(Duration(days: weekday - 1));
        final sundayEnd = todayEnd.add(Duration(days: 7 - weekday));
        return invoices.where((inv) {
          final date = inv.parsedDateTime;
          return date.isAfter(mondayStart.subtract(const Duration(microseconds: 1))) && date.isBefore(sundayEnd.add(const Duration(microseconds: 1)));
        }).toList();

      case 'last_week':
        final weekday = now.weekday;
        final lastMondayStart = todayStart.subtract(Duration(days: weekday - 1 + 7));
        final lastSundayEnd = todayEnd.subtract(Duration(days: weekday));
        return invoices.where((inv) {
          final date = inv.parsedDateTime;
          return date.isAfter(lastMondayStart.subtract(const Duration(microseconds: 1))) && date.isBefore(lastSundayEnd.add(const Duration(microseconds: 1)));
        }).toList();

      case 'this_month':
        final monthStart = DateTime(now.year, now.month, 1);
        final monthEnd = DateTime(now.year, now.month + 1, 1).subtract(const Duration(microseconds: 1));
        return invoices.where((inv) {
          final date = inv.parsedDateTime;
          return date.isAfter(monthStart.subtract(const Duration(microseconds: 1))) && date.isBefore(monthEnd.add(const Duration(microseconds: 1)));
        }).toList();

      case 'last_month':
        final prevMonthYear = now.month == 1 ? now.year - 1 : now.year;
        final prevMonth = now.month == 1 ? 12 : now.month - 1;
        final lastMonthStart = DateTime(prevMonthYear, prevMonth, 1);
        final lastMonthEnd = DateTime(now.year, now.month, 1).subtract(const Duration(microseconds: 1));
        return invoices.where((inv) {
          final date = inv.parsedDateTime;
          return date.isAfter(lastMonthStart.subtract(const Duration(microseconds: 1))) && date.isBefore(lastMonthEnd.add(const Duration(microseconds: 1)));
        }).toList();

      case 'custom':
        if (customFilterStartDate == null || customFilterEndDate == null) return invoices;
        final start = DateTime(customFilterStartDate!.year, customFilterStartDate!.month, customFilterStartDate!.day);
        final end = DateTime(customFilterEndDate!.year, customFilterEndDate!.month, customFilterEndDate!.day, 23, 59, 59, 999);
        return invoices.where((inv) {
          final date = inv.parsedDateTime;
          return date.isAfter(start.subtract(const Duration(microseconds: 1))) && date.isBefore(end.add(const Duration(microseconds: 1)));
        }).toList();

      default:
        return invoices;
    }
  }

  void _rebuildReportCache() {
    if (_isCacheValid) return;
    
    final List<double> sales = List.filled(7, 0.0);
    final List<String> labels = List.filled(7, '');
    final now = DateTime.now();
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    
    for (int i = 0; i < 7; i++) {
      final targetDate = now.subtract(Duration(days: i));
      final targetDayStart = DateTime(targetDate.year, targetDate.month, targetDate.day);
      final targetDayEnd = targetDayStart.add(const Duration(days: 1)).subtract(const Duration(microseconds: 1));
      
      double daySum = 0.0;
      for (var inv in invoices) {
        final date = inv.parsedDateTime;
        if (date.isAfter(targetDayStart.subtract(const Duration(microseconds: 1))) && 
            date.isBefore(targetDayEnd.add(const Duration(microseconds: 1)))) {
          daySum += inv.total;
        }
      }
      sales[6 - i] = daySum;
      labels[6 - i] = weekdays[targetDate.weekday - 1];
    }
    _cachedLast7DaysSales = sales;
    _cachedLast7DaysLabels = labels;

    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1)).subtract(const Duration(microseconds: 1));
    double todaySum = 0.0;
    for (var inv in invoices) {
      final date = inv.parsedDateTime;
      if (date.isAfter(todayStart.subtract(const Duration(microseconds: 1))) && 
          date.isBefore(todayEnd.add(const Duration(microseconds: 1)))) {
        todaySum += inv.total;
      }
    }
    _cachedTodayCashSales = todaySum;

    final Map<int, int> counts = {};
    for (var item in menu) {
      counts[item.id] = 0;
    }
    for (var inv in invoices) {
      for (var item in inv.items) {
        if (counts.containsKey(item.id)) {
          counts[item.id] = counts[item.id]! + item.qty;
        }
      }
    }
    _cachedMenuPerformance = counts;

    _isCacheValid = true;
  }

  List<double> get last7DaysSales {
    _rebuildReportCache();
    return _cachedLast7DaysSales;
  }

  List<String> get last7DaysLabels {
    _rebuildReportCache();
    return _cachedLast7DaysLabels;
  }

  double get todayCashSales {
    _rebuildReportCache();
    return _cachedTodayCashSales;
  }

  Map<int, int> get menuPerformanceCounts {
    _rebuildReportCache();
    return _cachedMenuPerformance;
  }

  void updateTerminalSettings(String id, bool scanner, bool drawer) {
    terminalId = id;
    isBarcodeScannerEnabled = scanner;
    isCashDrawerEnabled = drawer;
    LocalStorageHelper.setString('ahar_terminal_id', id);
    LocalStorageHelper.setString('ahar_barcode_scanner', scanner ? 'true' : 'false');
    LocalStorageHelper.setString('ahar_cash_drawer', drawer ? 'true' : 'false');
    notifyListeners();
  }

  void setRollWidth(int width) {
    rollWidth = width;
    LocalStorageHelper.setString('ahar_roll_width', width.toString());
    notifyListeners();
  }

  void setInvoiceCode(String code) {
    invoiceCode = code;
    LocalStorageHelper.setString('ahar_invoice_code', code);
    notifyListeners();
  }

  void togglePlaySound(bool val) {
    playSound = val;
    LocalStorageHelper.setString('ahar_play_sound', val ? 'true' : 'false');
    notifyListeners();
    if (val) {
      playSystemSound();
    }
  }

  void playSystemSound() {
    if (playSound) {
      try {
        SystemSound.play(SystemSoundType.click);
      } catch (e) {
        debugPrint("Error playing system sound: $e");
      }
    }
  }

  void _loadDefaultUsers() {
    users = [
      UserProfile(name: "Himanshu (Owner)", pin: "1234", role: "owner"),
      UserProfile(name: "Rahul (Cashier 1)", pin: "2222", role: "cashier"),
      UserProfile(name: "Priya (Cashier 2)", pin: "3333", role: "cashier"),
      UserProfile(name: "Amit (Cashier 3)", pin: "4444", role: "cashier"),
    ];
    saveUsers();
  }

  void saveUsers() async {
    LocalStorageHelper.setString('ahar_users', jsonEncode(users.map((u) => u.toJson()).toList()));
    if (saasLicenseKey.isNotEmpty && _hasTenantDb) {
      cloudStatus = 'syncing';
      notifyListeners();
      try {
        await FirestoreService.syncUsers(users, saasLicenseKey);
        cloudStatus = 'connected';
      } catch (_) {
        cloudStatus = 'offline';
      }
      notifyListeners();
    }
  }

  void updateUsersList(List<UserProfile> newList) {
    users = newList;
    saveUsers();

    if (loggedInUser != null) {
      final index = users.indexWhere((u) => u.name == loggedInUser!.name);
      if (index != -1) {
        loggedInUser = users[index];
      }
    }
    notifyListeners();
  }

  void loginUser(UserProfile user) {
    loggedInUser = user;
    _cashierName = user.name;
    _cashierPin = user.pin;
    LocalStorageHelper.setString('ahar_cashier_name', user.name);
    LocalStorageHelper.setString('ahar_cashier_pin', user.pin);
    notifyListeners();
  }

  void logoutUser() {
    loggedInUser = null;
    toggleRegisterShiftLock(true);
    notifyListeners();
  }

  void updateCashierSettings(String name, String pin, double float) {
    _cashierName = name;
    _cashierPin = pin;
    openingFloat = float;
    LocalStorageHelper.setString('ahar_cashier_name', name);
    LocalStorageHelper.setString('ahar_cashier_pin', pin);
    LocalStorageHelper.setString('ahar_opening_float', float.toString());

    final idx = users.indexWhere((u) => u.name == name || (loggedInUser != null && u.name == loggedInUser!.name));
    if (idx != -1) {
      if (users[idx].role == 'owner' && (loggedInUser == null || loggedInUser!.role != 'owner')) {
        return; // Cashiers cannot change owner settings!
      }
      users[idx] = UserProfile(name: name, pin: pin, role: users[idx].role);
      saveUsers();
      loggedInUser = users[idx];
    }
    notifyListeners();
  }

  void updateSecuritySettings(String question, String answer) {
    securityQuestion = question;
    securityAnswer = answer;
    LocalStorageHelper.setString('ahar_security_question', question);
    LocalStorageHelper.setString('ahar_security_answer', answer);
    notifyListeners();
  }

  void updateLastLoginTime(String time) {
    lastLoginTime = time;
    LocalStorageHelper.setString('ahar_last_login_time', time);
    notifyListeners();
  }

  void toggleRegisterShiftLock(bool locked) {
    isRegisterShiftLocked = locked;
    LocalStorageHelper.setString('ahar_shift_locked', locked ? 'true' : 'false');
    notifyListeners();
  }

  void updateSaaSLicenseOverride(String status, String expiryDate) {
    final licenseData = {
      'status': status,
      'type': 'subscription',
      'expiryDate': expiryDate
    };
    LocalStorageHelper.setString('saas_license_$appId', jsonEncode(licenseData));
    checkSaaSStatus();
  }

  void updateAppId(int newId) {
    appId = newId;
    LocalStorageHelper.setString('ahar_app_id', newId.toString());
    checkSaaSStatus();
    notifyListeners();
  }

  String exportBackupJson() {
    final data = {
      'storeName': storeName,
      'storeGstin': storeGstin,
      'tables': tables.map((t) => t.toJson()).toList(),
      'menu': menu.map((m) => m.toJson()).toList(),
      'categories': categories.map((c) => c.toJson()).toList(),
      'invoices': invoices.map((i) => i.toJson()).toList(),
      'terminalId': terminalId,
      'isBarcodeScannerEnabled': isBarcodeScannerEnabled,
      'isCashDrawerEnabled': isCashDrawerEnabled,
      'cashierName': cashierName,
      'cashierPin': cashierPin,
      'openingFloat': openingFloat,
    };
    return jsonEncode(data);
  }

  bool importBackupJson(String jsonStr) {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonStr);
      if (data['storeName'] != null) storeName = data['storeName'];
      if (data['storeGstin'] != null) storeGstin = data['storeGstin'];
      
      if (data['tables'] != null) {
        final List list = data['tables'];
        tables = list.map((item) => TableModel.fromJson(item)).toList();
      }
      if (data['menu'] != null) {
        final List list = data['menu'];
        menu = list.map((item) => MenuItem.fromJson(item)).toList();
      }
      if (data['categories'] != null) {
        final List list = data['categories'];
        categories = list.map((item) => CategoryModel.fromJson(item)).toList();
      }
      if (data['invoices'] != null) {
        final List list = data['invoices'];
        invoices = list.map((item) => InvoiceModel.fromJson(item)).toList();
      }

      if (data['terminalId'] != null) terminalId = data['terminalId'];
      if (data['isBarcodeScannerEnabled'] != null) isBarcodeScannerEnabled = data['isBarcodeScannerEnabled'];
      if (data['isCashDrawerEnabled'] != null) isCashDrawerEnabled = data['isCashDrawerEnabled'];
      if (data['cashierName'] != null) cashierName = data['cashierName'];
      if (data['cashierPin'] != null) cashierPin = data['cashierPin'];
      if (data['openingFloat'] != null) openingFloat = data['openingFloat'];

      // Save everything to LocalStorage
      saveStoreNameGstin();
      saveTables();
      saveMenu();
      saveCategories();
      saveInvoices();
      
      LocalStorageHelper.setString('ahar_terminal_id', terminalId);
      LocalStorageHelper.setString('ahar_barcode_scanner', isBarcodeScannerEnabled ? 'true' : 'false');
      LocalStorageHelper.setString('ahar_cash_drawer', isCashDrawerEnabled ? 'true' : 'false');
      LocalStorageHelper.setString('ahar_cashier_name', cashierName);
      LocalStorageHelper.setString('ahar_cashier_pin', cashierPin);
      LocalStorageHelper.setString('ahar_opening_float', openingFloat.toString());

      invalidateCache();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error importing database backup: $e');
      return false;
    }
  }

  void resetSystemData() {
    LocalStorageHelper.remove('ahar_store_name');
    LocalStorageHelper.remove('ahar_store_gstin');
    LocalStorageHelper.remove('ahar_tables');
    LocalStorageHelper.remove('ahar_active_carts');
    LocalStorageHelper.remove('ahar_table_occupied_times');
    LocalStorageHelper.remove('ahar_invoices');
    LocalStorageHelper.remove('ahar_menu_items');
    LocalStorageHelper.remove('ahar_categories');
    LocalStorageHelper.remove('ahar_printer_connected');
    LocalStorageHelper.remove('ahar_connected_printer_mac');
    LocalStorageHelper.remove('ahar_connected_printer_name');
    LocalStorageHelper.remove('ahar_terminal_id');
    LocalStorageHelper.remove('ahar_barcode_scanner');
    LocalStorageHelper.remove('ahar_cash_drawer');
    LocalStorageHelper.remove('ahar_cashier_name');
    LocalStorageHelper.remove('ahar_cashier_pin');
    LocalStorageHelper.remove('ahar_shift_locked');
    LocalStorageHelper.remove('ahar_opening_float');
    
    storeName = "AAHAR SANDWICH & CHINESE";
    storeGstin = "24ACAPR9698D1Z8";
    tables = List.from(defaultTablesList);
    menu = List.from(defaultMenu);
    categories = List.from(defaultCategories);
    activeCarts = {};
    invoices = [];
    isPrinterConnected = false;
    connectedPrinterMac = '';
    connectedPrinterName = '';
    availablePrinters = [];
    activeInvoiceFilter = null;
    customFilterStartDate = null;
    customFilterEndDate = null;
    
    terminalId = 'TERMINAL-01';
    isBarcodeScannerEnabled = false;
    isCashDrawerEnabled = false;
    cashierName = 'Himanshu';
    cashierPin = '1234';
    isRegisterShiftLocked = false;
    openingFloat = 500.0;
    
    saveTables();
    saveMenu();
    saveCategories();
    tableOccupiedTimes = {};
    saveCarts();
    saveInvoices();
    
    selectedTableId = null;
    activeView = 'home';
    viewHistory.clear();
    saveNavigationState();
    invalidateCache();
    notifyListeners();
  }

  Future<void> resetMenuToDefaultsAndSync() async {
    menu = List.from(defaultMenu);
    saveMenu();
    notifyListeners();
  }

  Future<void> clearSalesReportsAndSync() async {
    invoices.clear();
    activeCarts.clear();
    tableOccupiedTimes.clear();
    saveInvoices();
    saveCarts();
    invalidateCache();

    if (saasLicenseKey.isNotEmpty) {
      try {
        // 1. Clear master DB invoices
        final collectionRef = FirebaseFirestore.instance
            .collection('licenses')
            .doc(saasLicenseKey)
            .collection('invoices');
        final snapshots = await collectionRef.get().timeout(const Duration(seconds: 4));
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in snapshots.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit().timeout(const Duration(seconds: 4));

        // 2. Clear tenant DB invoices
        try {
          final tenantDb = TenantDbManager.instance;
          final tenantInvoicesRef = tenantDb.collection('${saasLicenseKey}_invoices');
          final tenantSnapshots = await tenantInvoicesRef.get().timeout(const Duration(seconds: 4));
          final tenantBatch = tenantDb.batch();
          for (var doc in tenantSnapshots.docs) {
            tenantBatch.delete(doc.reference);
          }
          await tenantBatch.commit().timeout(const Duration(seconds: 4));
        } catch (tenantErr) {
          debugPrint('[Firestore] Error clearing tenant invoices: $tenantErr');
        }

        // Also update tables on Firestore to set occupied = false
        await FirestoreService.syncTables(tables, saasLicenseKey, activeCarts: {}, tableOccupiedTimes: {});
        debugPrint('[Firestore] Invoices and active carts cleared on cloud.');
      } catch (e) {
        debugPrint('[Firestore] Error clearing invoices on cloud: $e');
      }
    }
    notifyListeners();
  }

  /// Removes duplicate menu items by case-insensitive name comparison.
  /// Keeps the first occurrence and deletes duplicates from memory and Firestore.
  void cleanDuplicateMenuItems() {
    final Set<String> seenNames = {};
    final List<MenuItem> duplicates = [];

    final List<MenuItem> uniqueMenu = [];
    for (final item in menu) {
      final lowerName = item.name.trim().toLowerCase();
      if (seenNames.contains(lowerName)) {
        duplicates.add(item);
      } else {
        seenNames.add(lowerName);
        uniqueMenu.add(item);
      }
    }

    if (duplicates.isNotEmpty) {
      debugPrint('[Cleanup] Found ${duplicates.length} duplicate menu items:');
      for (final dup in duplicates) {
        debugPrint('  - Removing duplicate: "${dup.name}" (id: ${dup.id}, category: ${dup.category})');
        // Delete from Firestore cloud
        if (saasLicenseKey.isNotEmpty) {
          FirebaseFirestore.instance
              .collection('licenses')
              .doc(saasLicenseKey)
              .collection('menu_items')
              .doc(dup.id.toString())
              .delete()
              .catchError((e) {
            debugPrint('[Cleanup] Error deleting dup doc ${dup.id} from Firestore: $e');
          });
        }
      }
      menu = uniqueMenu;
      debugPrint('[Cleanup] Menu cleaned. ${menu.length} unique items remain.');
    }
  }

  void _startInternetCheckTimer() {
    _internetCheckTimer?.cancel();
    _runInternetCheck();
    _internetCheckTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _runInternetCheck();
    });
  }

  Future<void> _runInternetCheck() async {
    final connected = _isMockOffline ? false : await checkRealInternet();
    if (connected != hasRealInternet) {
      hasRealInternet = connected;
      if (!hasRealInternet) {
        if (_hasTenantDb) {
          cloudStatus = 'offline';
        }
        try {
          await FirebaseFirestore.instance.disableNetwork();
          if (_hasTenantDb) {
            await TenantDbManager.instance.disableNetwork();
          }
          debugPrint('[Firestore] Network disabled (offline mode).');
        } catch (e) {
          debugPrint('[Firestore] Error disabling network: $e');
        }
      } else {
        cloudStatus = 'connected';
        try {
          await FirebaseFirestore.instance.enableNetwork();
          if (_hasTenantDb) {
            await TenantDbManager.instance.enableNetwork();
          }
          debugPrint('[Firestore] Network enabled (online mode).');
        } catch (e) {
          debugPrint('[Firestore] Error enabling network: $e');
        }
        if (_hasTenantDb) {
          // Internet has been restored! Let's auto-sync and reconnect!
          startRealtimeSync();
          pushLocalDataToCloud();
        }
      }
      notifyListeners();
    }
  }

  Future<bool> checkRealInternet() async {
    if (kIsWeb) {
      try {
        final navigator = js.context['navigator'];
        if (navigator != null) {
          final bool? onLine = navigator['onLine'] as bool?;
          if (onLine != null) {
            return onLine;
          }
        }
      } catch (e) {
        debugPrint('Web connectivity check error: $e');
      }
      return true; // Fallback to true if navigator is null
    } else {
      try {
        final result = await InternetAddress.lookup('google.com')
            .timeout(const Duration(seconds: 4));
        return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } catch (_) {
        return false;
      }
    }
  }

  void toggleMockOffline() {
    _isMockOffline = !_isMockOffline;
    _runInternetCheck();
  }

  void updateCloudInvoicesLimit(int limit) {
    cloudInvoicesLimit = limit;
    LocalStorageHelper.setString('ahar_cloud_invoices_limit', limit.toString());
    if (invoices.length < cloudInvoicesLimit * 0.8) {
      shownCloudFullAlert = false;
    }
    notifyListeners();
  }

  void clearOldSyncedInvoices() {
    if (invoices.length > 2) {
      invoices = invoices.sublist(0, 2);
      saveInvoices();
    }
    shownCloudFullAlert = false;
    notifyListeners();
  }

  void enforceSequentialInvoiceIds() {
    if (invoices.isEmpty) return;

    // Sort invoices chronologically (oldest first).
    // In our list, they are normally stored newest first (index 0 is newest).
    // So we sort them descending by parsedDateTime so index 0 is newest.
    invoices.sort((a, b) => b.parsedDateTime.compareTo(a.parsedDateTime));

    int startOffset = 0;
    if (saasLicenseKey.trim().toUpperCase() == 'LIC-JQEL-CG2V-2ECX') {
      startOffset = 5427;
    }

    for (int i = 0; i < invoices.length; i++) {
      final seqNum = startOffset + invoices.length - i;
      final newId = "$invoiceCode-$seqNum";
      final inv = invoices[i];
      if (inv.id != newId) {
        invoices[i] = InvoiceModel(
          id: newId,
          tableId: inv.tableId,
          dateTime: inv.dateTime,
          checkInTime: inv.checkInTime,
          items: inv.items,
          subtotal: inv.subtotal,
          gst: inv.gst,
          packaging: inv.packaging,
          total: inv.total,
          originalTotal: inv.originalTotal ?? inv.total,
        );
      }
    }
    saveInvoices();
  }

  bool deleteInvoice(String id) {
    if (invoices.isEmpty) return false;
    // Index 0 in invoices is the newest (most recent) invoice
    if (invoices.first.id != id) {
      return false; // Can only delete the last invoice to maintain sequence integrity
    }
    invoices.removeAt(0);
    saveInvoices();
    notifyListeners();
    return true;
  }

  void updateInvoice(InvoiceModel updatedInvoice) {
    final idx = invoices.indexWhere((inv) => inv.id == updatedInvoice.id);
    if (idx != -1) {
      invoices[idx] = updatedInvoice;
      saveInvoices();
      invalidateCache();
      notifyListeners();
    }
  }

  void bulkAdjustInvoices(DateTime targetDate, int targetTotal) {
    final targetStart = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final targetEnd = targetStart.add(const Duration(days: 1)).subtract(const Duration(microseconds: 1));

    final targetInvoices = invoices.where((inv) {
      final date = inv.parsedDateTime;
      return date.isAfter(targetStart.subtract(const Duration(microseconds: 1))) &&
             date.isBefore(targetEnd.add(const Duration(microseconds: 1)));
    }).toList();

    if (targetInvoices.isEmpty) return;

    final currentTotal = targetInvoices.fold(0, (sum, inv) => sum + inv.total);
    if (currentTotal == 0 || targetTotal >= currentTotal) return;

    final double ratio = targetTotal / currentTotal;

    for (var inv in targetInvoices) {
      final targetInvTotal = (inv.total * ratio).round();

      final List<CartItem> adjustedItems = inv.items.map((item) => CartItem(
        id: item.id,
        name: item.name,
        price: item.price,
        category: item.category,
        qty: item.qty,
        gstRate: item.gstRate,
      )).toList();

      final discountRatio = 1.0 - (inv.discountPercent / 100.0);

      int subtotal = adjustedItems.fold(0, (sum, item) {
        if (!showGstOnBills) {
          return sum + (item.price * item.qty * discountRatio).round();
        }
        if (isGstInclusive) {
          final totalItemPrice = (item.price * item.qty * discountRatio).round();
          final gstAmount = (totalItemPrice * item.gstRate / (100 + item.gstRate)).round();
          return sum + (totalItemPrice - gstAmount);
        } else {
          return sum + (item.price * item.qty * discountRatio).round();
        }
      });
      int gst = adjustedItems.fold(0, (sum, item) {
        if (!showGstOnBills) {
          return 0;
        }
        if (isGstInclusive) {
          final totalItemPrice = (item.price * item.qty * discountRatio).round();
          return sum + (totalItemPrice * item.gstRate / (100 + item.gstRate)).round();
        } else {
          return sum + (item.price * item.qty * discountRatio * (item.gstRate / 100.0)).round();
        }
      });
      int total = isGstInclusive
          ? (showGstOnBills
              ? adjustedItems.fold(0, (sum, item) => sum + (item.price * item.qty * discountRatio).round())
              : subtotal) + inv.packaging
          : subtotal + gst + inv.packaging;

      bool reduced = true;
      while (total > targetInvTotal && reduced) {
        reduced = false;
        CartItem? itemToReduce;
        for (var item in adjustedItems) {
          if (item.qty > 1) {
            itemToReduce = item;
            break;
          }
        }

        if (itemToReduce == null && adjustedItems.isNotEmpty) {
          itemToReduce = adjustedItems.first;
        }

        if (itemToReduce != null) {
          if (itemToReduce.qty > 1) {
            itemToReduce.qty--;
            reduced = true;
          } else {
            adjustedItems.remove(itemToReduce);
            reduced = true;
          }
          subtotal = adjustedItems.isEmpty ? 0 : adjustedItems.fold(0, (sum, item) {
            if (!showGstOnBills) {
              return sum + (item.price * item.qty * discountRatio).round();
            }
            if (isGstInclusive) {
              final totalItemPrice = (item.price * item.qty * discountRatio).round();
              final gstAmount = (totalItemPrice * item.gstRate / (100 + item.gstRate)).round();
              return sum + (totalItemPrice - gstAmount);
            } else {
              return sum + (item.price * item.qty * discountRatio).round();
            }
          });
          gst = adjustedItems.isEmpty ? 0 : adjustedItems.fold(0, (sum, item) {
            if (!showGstOnBills) {
              return 0;
            }
            if (isGstInclusive) {
              final totalItemPrice = (item.price * item.qty * discountRatio).round();
              return sum + (totalItemPrice * item.gstRate / (100 + item.gstRate)).round();
            } else {
              return sum + (item.price * item.qty * discountRatio * (item.gstRate / 100.0)).round();
            }
          });
          final currentPackaging = adjustedItems.isEmpty ? 0 : inv.packaging;
          total = isGstInclusive
              ? (adjustedItems.isEmpty
                  ? 0
                  : (showGstOnBills
                      ? adjustedItems.fold(0, (sum, item) => sum + (item.price * item.qty * discountRatio).round())
                      : subtotal)) + currentPackaging
              : subtotal + gst + currentPackaging;
        }
      }

      final indexInMain = invoices.indexWhere((i) => i.id == inv.id);
      if (indexInMain != -1) {
        final origTot = invoices[indexInMain].originalTotal ?? invoices[indexInMain].total;
        invoices[indexInMain] = InvoiceModel(
          id: inv.id,
          tableId: inv.tableId,
          dateTime: inv.dateTime,
          checkInTime: inv.checkInTime,
          items: adjustedItems,
          subtotal: subtotal,
          gst: gst,
          packaging: adjustedItems.isEmpty ? 0 : inv.packaging,
          total: total,
          originalTotal: origTot,
          discountPercent: inv.discountPercent,
        );
      }
    }

    int newSum = targetInvoices.fold(0, (sum, inv) {
      final updatedInv = invoices.firstWhere((i) => i.id == inv.id);
      return sum + updatedInv.total;
    });

    if (newSum > targetTotal) {
      for (var inv in targetInvoices) {
        final indexInMain = invoices.indexWhere((i) => i.id == inv.id);
        if (indexInMain != -1) {
          final currentInv = invoices[indexInMain];
          if (currentInv.packaging > 0) {
            final diff = newSum - targetTotal;
            final deduct = currentInv.packaging > diff ? diff : currentInv.packaging;
            final newPackaging = currentInv.packaging - deduct;
            final newTotal = currentInv.subtotal + currentInv.gst + newPackaging;
            
            invoices[indexInMain] = InvoiceModel(
              id: currentInv.id,
              tableId: currentInv.tableId,
              dateTime: currentInv.dateTime,
              checkInTime: currentInv.checkInTime,
              items: currentInv.items,
              subtotal: currentInv.subtotal,
              gst: currentInv.gst,
              packaging: newPackaging,
              total: newTotal,
              originalTotal: currentInv.originalTotal ?? currentInv.total,
              discountPercent: currentInv.discountPercent,
            );
            newSum -= deduct;
            if (newSum <= targetTotal) break;
          }
        }
      }
    }

    if (newSum > targetTotal) {
      final updatedTargetInvoices = invoices.where((inv) {
        final date = inv.parsedDateTime;
        return date.isAfter(targetStart.subtract(const Duration(microseconds: 1))) &&
               date.isBefore(targetEnd.add(const Duration(microseconds: 1)));
      }).toList();

      updatedTargetInvoices.sort((a, b) => b.total.compareTo(a.total));

      for (var inv in updatedTargetInvoices) {
        final indexInMain = invoices.indexWhere((i) => i.id == inv.id);
        if (indexInMain != -1) {
          final currentInv = invoices[indexInMain];
          final List<CartItem> adjustedItems = List.from(currentInv.items);
          
          while (newSum > targetTotal && adjustedItems.isNotEmpty) {
            final activeInvoicesCount = updatedTargetInvoices.where((i) {
              final up = invoices.firstWhere((x) => x.id == i.id);
              return up.items.isNotEmpty;
            }).length;

            if (adjustedItems.length == 1 && activeInvoicesCount == 1) {
              final item = adjustedItems.first;
              final remainingTarget = targetTotal - (newSum - currentInv.total);
              
              int bestPrice = 0;
              for (int p = 0; p <= remainingTarget; p++) {
                final calculatedTotal = isGstInclusive
                    ? p + currentInv.packaging
                    : p + (p * item.gstRate / 100).round() + currentInv.packaging;
                if (calculatedTotal <= remainingTarget) {
                  bestPrice = p;
                } else {
                  break;
                }
              }

              adjustedItems[0] = CartItem(
                id: item.id,
                name: item.name,
                price: bestPrice,
                category: item.category,
                qty: 1,
                gstRate: item.gstRate,
              );

              final subtotal = (!showGstOnBills)
                  ? bestPrice
                  : (isGstInclusive
                      ? bestPrice - (bestPrice * item.gstRate / (100 + item.gstRate)).round()
                      : bestPrice);
              final gst = (!showGstOnBills)
                  ? 0
                  : (isGstInclusive
                      ? (bestPrice * item.gstRate / (100 + item.gstRate)).round()
                      : (bestPrice * (item.gstRate / 100.0)).round());
              final total = isGstInclusive ? bestPrice + currentInv.packaging : subtotal + gst + currentInv.packaging;
              
              final diff = currentInv.total - total;
              newSum -= diff;

              invoices[indexInMain] = InvoiceModel(
                id: currentInv.id,
                tableId: currentInv.tableId,
                dateTime: currentInv.dateTime,
                checkInTime: currentInv.checkInTime,
                items: adjustedItems,
                subtotal: subtotal,
                gst: gst,
                packaging: currentInv.packaging,
                total: total,
                originalTotal: currentInv.originalTotal ?? currentInv.total,
                discountPercent: currentInv.discountPercent,
              );
              break;
            } else {
              final itemToReduce = adjustedItems.first;
              adjustedItems.remove(itemToReduce);

              final subtotal = 0;
              final gst = 0;
              final total = 0;
              
              final diff = currentInv.total - total;
              newSum -= diff;

              invoices[indexInMain] = InvoiceModel(
                id: currentInv.id,
                tableId: currentInv.tableId,
                dateTime: currentInv.dateTime,
                checkInTime: currentInv.checkInTime,
                items: adjustedItems,
                subtotal: subtotal,
                gst: gst,
                packaging: 0,
                total: total,
                originalTotal: currentInv.originalTotal ?? currentInv.total,
                discountPercent: currentInv.discountPercent,
              );
            }
          }
          if (newSum <= targetTotal) break;
        }
      }
    }

    newSum = targetInvoices.fold(0, (sum, inv) {
      final updatedInv = invoices.firstWhere((i) => i.id == inv.id);
      return sum + updatedInv.total;
    });

    if (newSum < targetTotal) {
      final diff = targetTotal - newSum;
      final activeIndex = invoices.indexWhere((inv) {
        final date = inv.parsedDateTime;
        final isOnDate = date.isAfter(targetStart.subtract(const Duration(microseconds: 1))) &&
                         date.isBefore(targetEnd.add(const Duration(microseconds: 1)));
        return isOnDate && inv.items.isNotEmpty;
      });

      if (activeIndex != -1) {
        final inv = invoices[activeIndex];
        final newPackaging = inv.packaging + diff;
        final newTotal = inv.subtotal + inv.gst + newPackaging;

        invoices[activeIndex] = InvoiceModel(
          id: inv.id,
          tableId: inv.tableId,
          dateTime: inv.dateTime,
          checkInTime: inv.checkInTime,
          items: inv.items,
          subtotal: inv.subtotal,
          gst: inv.gst,
          packaging: newPackaging,
          total: newTotal,
          originalTotal: inv.originalTotal ?? inv.total,
        );
      } else {
        final firstIndex = invoices.indexWhere((inv) {
          final date = inv.parsedDateTime;
          return date.isAfter(targetStart.subtract(const Duration(microseconds: 1))) &&
                 date.isBefore(targetEnd.add(const Duration(microseconds: 1)));
        });

        if (firstIndex != -1) {
          final inv = invoices[firstIndex];
          final menuItem = menu.isNotEmpty ? menu.first : MenuItem(id: 1, name: "Toast Sandwich", price: 50, category: "SANDWICH");
          
          int bestPrice = 0;
          for (int p = 0; p <= targetTotal; p++) {
            final calculatedTotal = isGstInclusive
                ? p
                : p + (p * menuItem.gstRate / 100).round();
            if (calculatedTotal <= targetTotal) {
              bestPrice = p;
            } else {
              break;
            }
          }

          final calculatedTotal = isGstInclusive ? bestPrice : bestPrice + (bestPrice * menuItem.gstRate / 100).round();
          final remDiff = targetTotal - calculatedTotal;

          final CartItem item = CartItem(
            id: menuItem.id,
            name: menuItem.name,
            price: bestPrice,
            category: menuItem.category,
            qty: 1,
            gstRate: menuItem.gstRate,
          );

          invoices[firstIndex] = InvoiceModel(
            id: inv.id,
            tableId: inv.tableId,
            dateTime: inv.dateTime,
            checkInTime: inv.checkInTime,
            items: [item],
            subtotal: isGstInclusive
                ? bestPrice - (bestPrice * menuItem.gstRate / (100 + menuItem.gstRate)).round()
                : bestPrice,
            gst: isGstInclusive
                ? (bestPrice * menuItem.gstRate / (100 + menuItem.gstRate)).round()
                : (bestPrice * menuItem.gstRate / 100).round(),
            packaging: remDiff,
            total: targetTotal,
            originalTotal: inv.originalTotal ?? inv.total,
          );
        }
      }
    }

    // Remove any invoices on the target date that ended up empty or zero-total
    invoices.removeWhere((inv) {
      final date = inv.parsedDateTime;
      final isOnDate = date.isAfter(targetStart.subtract(const Duration(microseconds: 1))) &&
                       date.isBefore(targetEnd.add(const Duration(microseconds: 1)));
      return isOnDate && (inv.total <= 0 || inv.items.isEmpty);
    });

    enforceSequentialInvoiceIds();
    invalidateCache();
    notifyListeners();
  }
}