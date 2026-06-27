import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'js_interface.dart' as js;
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:local_auth/local_auth.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app_state.dart';
import 'storage_helper.dart';
import 'package:url_launcher/url_launcher.dart';

// TODO: Put your actual Firebase credentials here to enable Web Firestore sync
const FirebaseOptions firebaseOptions = FirebaseOptions(
  apiKey: "YOUR_API_KEY_HERE", // Paste your real API Key from Firebase console
  authDomain: "control-panel-add47.firebaseapp.com",
  projectId: "control-panel-add47",
  storageBucket: "control-panel-add47.appspot.com",
  messagingSenderId: "YOUR_SENDER_ID_HERE", // Paste your Messaging Sender ID
  appId: "YOUR_APP_ID_HERE", // Paste your Web App ID
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorageHelper.init(); // Load local storage before the app starts to prevent race conditions and data loss!
  try {
    await Firebase.initializeApp(
      options: firebaseOptions,
    );
    debugPrint('[Firebase] Initialized successfully.');
  } catch (e) {
    debugPrint('[Firebase] Initialization failed (Local storage fallback is active): $e');
  }
  runApp(const AharPOSApp());
}

class AharPOSApp extends StatefulWidget {
  const AharPOSApp({super.key});

  @override
  State<AharPOSApp> createState() => _AharPOSAppState();
}

class _AharPOSAppState extends State<AharPOSApp> {
  late AppState _appState;

  @override
  void initState() {
    super.initState();
    _appState = AppState();
  }

  @override
  Widget build(BuildContext context) {
    return AppStateProvider(
      notifier: _appState,
      child: MaterialApp(
        title: 'Ahar OS - Premium Culinary POS',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF0A0C10),
          colorScheme: const ColorScheme.dark().copyWith(
            primary: const Color(0xFFFF6F24),
            secondary: const Color(0xFFE6550F),
            surface: const Color(0xFF12161B),
            background: const Color(0xFF0A0C10),
          ),
          textTheme: ThemeData.dark().textTheme.apply(
            fontFamily: 'Outfit',
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
            ),
          ),
        ),
        home: const AharSplashScreen(),
      ),
    );
  }
}

// --- APP STATE PROVIDER INHERITED WIDGET ---

class AppStateProvider extends InheritedNotifier<AppState> {
  const AppStateProvider({
    super.key,
    required super.notifier,
    required super.child,
  });

  static AppState of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppStateProvider>()!.notifier!;
  }
}

// --- SPLASH SCREEN WITH BRANDING ---

class AharSplashScreen extends StatefulWidget {
  const AharSplashScreen({super.key});

  @override
  State<AharSplashScreen> createState() => _AharSplashScreenState();
}

class _AharSplashScreenState extends State<AharSplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _isFinished = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeIn)),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.1, 0.8, curve: Curves.easeOutBack)),
    );

    _controller.forward();

    Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _isFinished = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isFinished) {
      return const MainLayoutScaffold();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF07090C),
      body: Stack(
        children: [
          // Background ambient lights
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6F24).withOpacity(0.03),
                    blurRadius: 100,
                    spreadRadius: 50,
                  )
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00AA4F).withOpacity(0.02),
                    blurRadius: 100,
                    spreadRadius: 50,
                  )
                ],
              ),
            ),
          ),

          
          // Center contents
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // App Logo
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0x0CFFFFFF),
                            border: Border.all(color: const Color(0xFFFF6F24).withOpacity(0.15), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF6F24).withOpacity(0.05),
                                blurRadius: 40,
                                spreadRadius: 5,
                              )
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.asset(
                              'assets/images/app_logo.png',
                              width: 120,
                              height: 120,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // App Name
                        const Text(
                          "AHAR OS",
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Premium Culinary POS & Management",
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 48),
                        // Loading Indicator
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6F24)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Bottom KS Solution branding
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "POWERED BY",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: Colors.white38,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.asset(
                          'assets/images/ks_logo.png',
                          height: 24,
                          width: 24,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 8),

                      const Text(
                        "KS SOLUTION",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: Color(0xFFF3AD0A), // Gold color from logo
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Empowering Future with AI Excellence",
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                      color: Color(0xFF0A74F3), // Light blue color from logo
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- CLOUD STATUS INDICATOR WIDGET ---

class CloudStatusIndicator extends StatelessWidget {
  const CloudStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);
    Color color;
    IconData icon;
    String tooltip;
    String textVal;

    if (!state.hasRealInternet) {
      color = const Color(0xFFEF4444); // Red
      icon = Icons.wifi_off_outlined;
      tooltip = 'No Real Internet Connection (Real Check)';
      textVal = 'NO INTERNET';
    } else {
      switch (state.cloudStatus) {
        case 'connected':
          color = const Color(0xFF00AA4F); // Green
          icon = Icons.cloud_done_outlined;
          tooltip = 'Cloud Connected';
          textVal = 'CONNECTED';
          break;
        case 'syncing':
          color = const Color(0xFF3B82F6); // Blue
          icon = Icons.cloud_sync_outlined;
          tooltip = 'Cloud Syncing...';
          textVal = 'SYNCING';
          break;
        case 'offline':
        default:
          color = const Color(0xFFEF4444); // Red
          icon = Icons.cloud_off_outlined;
          tooltip = 'Cloud Offline / Local Mode';
          textVal = 'OFFLINE';
          break;
      }
    }

    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.25), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _GlowingDot(color: color),
            const SizedBox(width: 6),
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 4),
            Text(
              textVal,
              style: TextStyle(
                color: color,
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowingDot extends StatefulWidget {
  final Color color;
  const _GlowingDot({required this.color});

  @override
  State<_GlowingDot> createState() => _GlowingDotState();
}

class _GlowingDotState extends State<_GlowingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.5),
                blurRadius: 1 + _controller.value * 6,
                spreadRadius: _controller.value * 1.5,
              )
            ],
          ),
        );
      },
    );
  }
}

// --- MAIN LAYOUT SCAFFOLD WITH VIEWS ROUTING ---

class MainLayoutScaffold extends StatefulWidget {

  const MainLayoutScaffold({super.key});

  @override
  State<MainLayoutScaffold> createState() => _MainLayoutScaffoldState();
}

class _MainLayoutScaffoldState extends State<MainLayoutScaffold> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);

    if (state.saasActivationRequired) {
      return const SaaSActivationScreen();
    }

    if (state.saasLocked) {
      return const SaaSUnlockScreen();
    }

    if (state.isRegisterShiftLocked) {
      return CashierLockOverlay(state: state);
    }

    if (state.isCloudAlmostFull && !state.shownCloudFullAlert && state.saasLicenseKey.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!state.shownCloudFullAlert) {
          state.setShownCloudFullAlert(true);
          _showCloudFullWarningDialog(context, state);
        }
      });
    }

    return PopScope(
      canPop: state.activeView == 'home' && state.viewHistory.isEmpty,
      onPopInvoked: (didPop) {
        if (didPop) return;
        state.goBack();
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawer: const SidebarDrawer(),
        body: Row(
          children: [
            // On desktop viewports (width > 1100), show persistent sidebar drawer
            if (MediaQuery.of(context).size.width > 1100)
              const SizedBox(
                width: 280,
                child: SidebarDrawer(isPersistent: true),
              ),
            
            Expanded(
              child: Stack(
                children: [
                  Column(
                    children: [
                      if (!state.hasRealInternet)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withOpacity(0.95),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.wifi_off, color: Colors.white, size: 16),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Real Internet Connection Lost: Sales will be saved locally and synced automatically when connection is restored.',
                                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (state.isCloudAlmostFull && !state.isCloudFull)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6F24).withOpacity(0.95),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.cloud_queue, color: Colors.white, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Cloud Storage Warning: Your cloud space is ${state.cloudUsagePercentage.toStringAsFixed(1)}% full (${state.invoices.length}/${state.cloudInvoicesLimit}). Please upgrade or clear old invoices.',
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (state.isCloudFull)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withOpacity(0.95),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.cloud_off, color: Colors.white, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Cloud Storage Full: Database sync is paused (${state.invoices.length}/${state.cloudInvoicesLimit}). Please clear space or contact admin.',
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: _buildActiveView(context, state),
                      ),
                    ],
                  ),
                  
                  // Show Invoice Receipt detail popup overlay if selected
                  if (state.selectedReceiptInvoice != null)
                    ReceiptPopupOverlay(invoice: state.selectedReceiptInvoice!),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveView(BuildContext context, AppState state) {
    switch (state.activeView) {
      case 'home':
        return SeatingGridView(scaffoldKey: _scaffoldKey);
      case 'menu':
        return MenuCatalogView(scaffoldKey: _scaffoldKey);
      case 'invoices':
        return InvoicesListView(scaffoldKey: _scaffoldKey);
      case 'search':
        return InvoicesSearchView(scaffoldKey: _scaffoldKey);
      case 'reports-revenue':
        return RevenueReportView(scaffoldKey: _scaffoldKey);
      case 'reports-menu':
        return MenuReportView(scaffoldKey: _scaffoldKey);
      case 'reports-accounts':
        return AccountsReportView(scaffoldKey: _scaffoldKey);
      case 'reports-tables':
        return TableReportView(scaffoldKey: _scaffoldKey);
      case 'settings-tables':
        return TableSettingsView(scaffoldKey: _scaffoldKey);
      case 'settings-menu':
        return MenuSettingsView(scaffoldKey: _scaffoldKey);
      case 'settings-categories':
        return CategorySettingsView(scaffoldKey: _scaffoldKey);
      case 'settings-store':
        return StoreSettingsView(scaffoldKey: _scaffoldKey);
      case 'settings-device':
        return DevicePlaceholderView(scaffoldKey: _scaffoldKey);
      case 'settings-account':
        return AccountPlaceholderView(scaffoldKey: _scaffoldKey);
      case 'settings-advance':
        return AdvancePlaceholderView(scaffoldKey: _scaffoldKey);
      case 'feedback':
        return FeedbackView(scaffoldKey: _scaffoldKey);
      case 'invoice-filter':
        return InvoiceFilterView(scaffoldKey: _scaffoldKey);
      case 'secret-ledger':
        return SecretLedgerView(scaffoldKey: _scaffoldKey);
      case 'bt-logs':
        return BluetoothLogsView(scaffoldKey: _scaffoldKey);
      default:
        return SeatingGridView(scaffoldKey: _scaffoldKey);
    }
  }
}

// --- SaaS LOCK SCREEN VIEW ---

class SaaSUnlockScreen extends StatelessWidget {
  const SaaSUnlockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: NetworkImage("https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&q=80&w=1000"),
            fit: BoxFit.cover,
            opacity: 0.1,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(32),
              constraints: const BoxConstraints(maxWidth: 420),
              decoration: BoxDecoration(
                color: const Color(0x7F191E28),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0x0CFFFFFF)),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 40, spreadRadius: 0)
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_open, size: 54, color: Color(0xFFFF6F24)),
                  const SizedBox(height: 20),
                  Text(
                    state.saasTitle,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    state.saasMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              "Store: ",
                              style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            Expanded(
                              child: Text(
                                state.storeName,
                                style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Text(
                              "License: ",
                              style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            Expanded(
                              child: Text(
                                state.saasLicenseKey,
                                style: const TextStyle(color: Color(0xFFFF6F24), fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    state.saasAnnouncement,
                    style: const TextStyle(color: Color(0xFFFF6F24), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0x0CFFFFFF)),
                    ),
                    child: state.saasQRCodeUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(state.saasQRCodeUrl, fit: BoxFit.cover),
                          )
                        : const Center(child: Icon(Icons.qr_code, size: 80, color: Colors.white30)),
                  ),
                  if (state.saasSupportPhone.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      "For fast verification, call us or WhatsApp screenshot:",
                      style: TextStyle(color: Colors.white60, fontSize: 11.5),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        InkWell(
                          onTap: () async {
                            final number = state.saasSupportPhone.replaceAll(' ', '');
                            final Uri url = Uri.parse('tel:$number');
                            try {
                              await launchUrl(url);
                            } catch (e) {
                              debugPrint("Error launching call intent: $e");
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.phone, size: 14, color: Colors.blueAccent),
                                const SizedBox(width: 6),
                                Text(
                                  "Call ${state.saasSupportPhone}",
                                  style: const TextStyle(fontSize: 12, color: Colors.blueAccent, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () async {
                            final cleanNumber = state.saasSupportPhone.replaceAll(RegExp(r'[\s\+\-]'), '');
                            final text = Uri.encodeComponent("Hi, I have requested payment verification for Ahar OS. License Key: ${state.saasLicenseKey}");
                            final Uri url = Uri.parse('https://wa.me/$cleanNumber?text=$text');
                            try {
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                            } catch (e) {
                              debugPrint("Error launching WhatsApp intent: $e");
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.message, size: 14, color: Colors.green),
                                SizedBox(width: 6),
                                Text(
                                  "WhatsApp Screenshot",
                                  style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: state.saasTitle == "Verification Pending"
                        ? null
                        : () {
                            state.renewLicense();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Payment verification requested!')),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6F24),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      state.saasTitle == "Verification Pending"
                          ? 'Verification Pending...'
                          : 'I Have Paid (Mock Verify)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SaaSActivationScreen extends StatefulWidget {
  const SaaSActivationScreen({super.key});

  @override
  State<SaaSActivationScreen> createState() => _SaaSActivationScreenState();
}

class _SaaSActivationScreenState extends State<SaaSActivationScreen> {
  final _keyController = TextEditingController();
  final _nameController = TextEditingController();
  final _pinController = TextEditingController();
  String _errorMessage = '';
  bool _isLoading = false;

  @override
  void dispose() {
    _keyController.dispose();
    _nameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: NetworkImage("https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&q=80&w=1000"),
            fit: BoxFit.cover,
            opacity: 0.1,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(32),
              constraints: const BoxConstraints(maxWidth: 420),
              decoration: BoxDecoration(
                color: const Color(0x7F191E28),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0x0CFFFFFF)),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 40, spreadRadius: 0)
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.vpn_key_outlined, size: 54, color: Color(0xFFFF6F24)),
                  const SizedBox(height: 20),
                  const Text(
                    "POS Activation Required",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Please enter your POS license key and configure the owner credentials to authorize this terminal.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _keyController,
                    decoration: InputDecoration(
                      labelText: 'License Key',
                      hintText: 'e.g. LIC-ABCD-1234-WXYZ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.key),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Set Owner Name',
                      hintText: 'e.g. Rahul Sharma',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _pinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: InputDecoration(
                      labelText: 'Set Owner Login PIN (4 Digits)',
                      hintText: 'e.g. 1234',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.lock_outline),
                      counterText: '',
                    ),
                  ),
                  if (_errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            final enteredKey = _keyController.text.trim();
                            final enteredName = _nameController.text.trim();
                            final enteredPin = _pinController.text.trim();
                            if (enteredKey.isEmpty) {
                              setState(() {
                                _errorMessage = 'License Key cannot be empty.';
                              });
                              return;
                            }
                            if (enteredName.isEmpty) {
                              setState(() {
                                _errorMessage = 'Owner Name cannot be empty.';
                              });
                              return;
                            }
                            if (enteredPin.isEmpty || enteredPin.length != 4 || int.tryParse(enteredPin) == null) {
                              setState(() {
                                _errorMessage = 'Please enter a valid 4-digit numeric PIN.';
                              });
                              return;
                            }

                            setState(() {
                              _isLoading = true;
                              _errorMessage = '';
                            });

                            // Simulate network activation delay
                            await Future.delayed(const Duration(milliseconds: 800));

                            final success = await state.activateWithLicenseKey(
                              enteredKey,
                              ownerPin: enteredPin,
                              ownerName: enteredName,
                            );
                            if (!success) {
                              setState(() {
                                _isLoading = false;
                                _errorMessage = state.licenseErrorMessage.isNotEmpty
                                    ? state.licenseErrorMessage
                                    : 'Invalid Activation License Key.\nPlease contact your administrator.';
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6F24),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text('Activate Device', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- SIDEBAR DRAWER VIEW ---

class SidebarDrawer extends StatelessWidget {
  final bool isPersistent;

  const SidebarDrawer({super.key, this.isPersistent = false});

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D1013),
        border: Border(right: BorderSide(color: Color(0x0CFFFFFF))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header branding (stretched and beautifully bordered)
          Container(
            padding: const EdgeInsets.fromLTRB(24, 52, 24, 24),
            decoration: const BoxDecoration(
              color: Color(0xFF12161B),
              border: Border(bottom: BorderSide(color: Color(0x0CFFFFFF))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.storeName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  state.storeGstin,
                  style: const TextStyle(
                    color: Color(0xFFFF6F24),
                    fontSize: 11.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                const CloudStatusIndicator(),
              ],
            ),
          ),
          
          // Navigation Lists
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _buildNavItem(context, state, 'home', Icons.home_outlined, 'Home'),
                _buildNavItem(context, state, 'invoices', Icons.description_outlined, 'Invoice'),
                _buildNavItem(context, state, 'search', Icons.search, 'Search'),
                
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
                  child: Text('REPORTS', style: TextStyle(fontSize: 10, color: Color(0xFF4B5563), fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                ),
                _buildNavItem(context, state, 'reports-revenue', Icons.show_chart, 'Revenue Report'),
                _buildNavItem(context, state, 'reports-menu', Icons.restaurant_menu, 'Menu Item Report'),
                _buildNavItem(context, state, 'reports-tables', Icons.table_bar, 'Table Performance'),
                _buildNavItem(context, state, 'reports-accounts', Icons.bar_chart, 'Accounts Report'),
                
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
                  child: Text('RESTAURANT SETTINGS', style: TextStyle(fontSize: 10, color: Color(0xFF4B5563), fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                ),
                _buildNavItem(context, state, 'settings-tables', Icons.table_chart_outlined, 'Table Settings'),
                _buildNavItem(context, state, 'settings-menu', Icons.fastfood_outlined, 'Menu Settings'),
                _buildNavItem(context, state, 'settings-categories', Icons.category_outlined, 'Category Settings'),
                
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
                  child: Text('APPLICATION SETTINGS', style: TextStyle(fontSize: 10, color: Color(0xFF4B5563), fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                ),
                _buildNavItem(context, state, 'settings-store', Icons.storefront, 'Store Settings'),
                _buildNavItem(context, state, 'settings-device', Icons.laptop_chromebook, 'Device Settings'),
                _buildNavItem(context, state, 'settings-account', Icons.account_circle_outlined, 'Account Settings'),
                _buildNavItem(context, state, 'settings-advance', Icons.settings_applications, 'Advance Settings'),
                
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
                  child: Text('FEEDBACK', style: TextStyle(fontSize: 10, color: Color(0xFF4B5563), fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                ),
                _buildNavItem(context, state, 'feedback', Icons.comment_outlined, 'Send Feedback'),

                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
                  child: Text('SESSION', style: TextStyle(fontSize: 10, color: Color(0xFF4B5563), fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: ListTile(
                      visualDensity: VisualDensity.compact,
                      leading: const Icon(Icons.logout, color: Color(0xFFEF4444), size: 20),
                      title: const Text(
                        'Logout Shift',
                        style: TextStyle(
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.w500,
                          fontSize: 13.5,
                        ),
                      ),
                      onTap: () {
                        if (!isPersistent) {
                          Navigator.pop(context);
                        }
                        state.logoutUser();
                      },
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
                  child: Text('SUPPORT', style: TextStyle(fontSize: 10, color: Color(0xFF4B5563), fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: ListTile(
                      visualDensity: VisualDensity.compact,
                      leading: const Icon(Icons.support_agent_outlined, color: Color(0xFF94A3B8), size: 20),
                      title: const Text(
                        'Get Support',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                          fontSize: 13.5,
                        ),
                      ),
                      onTap: () {
                        if (!isPersistent) {
                          Navigator.pop(context);
                        }
                        showDialog(
                          context: context,
                          builder: (context) => const SupportDialog(),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Branded Footer (filling the blank space at the bottom)
          Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: 16 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF0A0D10),
              border: Border(top: BorderSide(color: Color(0x0CFFFFFF))),
            ),
            child: Row(
              children: [
                // Glowing circular branding emblem
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0x19FF6F24),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0x33FF6F24), width: 1.5),
                  ),
                  child: const Icon(Icons.blur_on, color: Color(0xFFFF6F24), size: 18),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'POWERED BY',
                        style: TextStyle(
                          color: Color(0xFF4B5563),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'KS Solution',
                        style: TextStyle(
                          color: Color(0xFFF3AD0A),
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Text(
                  'v2.4.2',
                  style: TextStyle(
                    color: Color(0xFF4B5563),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getNavItemColor(String viewId) {
    switch (viewId) {
      case 'home':
      case 'menu':
        return const Color(0xFF3B82F6); // Blue
      case 'invoices':
        return const Color(0xFF10B981); // Emerald
      case 'search':
        return const Color(0xFF6366F1); // Indigo
      case 'reports-revenue':
        return const Color(0xFFEC4899); // Pink
      case 'reports-menu':
        return const Color(0xFFF59E0B); // Amber
      case 'reports-tables':
        return const Color(0xFF8B5CF6); // Violet
      case 'reports-accounts':
        return const Color(0xFF06B6D4); // Cyan
      case 'settings-tables':
        return const Color(0xFF14B8A6); // Teal
      case 'settings-menu':
        return const Color(0xFFF97316); // Sunset Orange
      case 'settings-categories':
        return const Color(0xFF8B5CF6); // Purple
      case 'settings-store':
        return const Color(0xFFD946EF); // Fuchsia
      case 'settings-device':
        return const Color(0xFF64748B); // Slate
      case 'settings-account':
        return const Color(0xFF84CC16); // Lime
      case 'settings-advance':
        return const Color(0xFFEF4444); // Red
      default:
        return const Color(0xFFFF6F24); // Orange fallback
    }
  }

  Widget _buildNavItem(BuildContext context, AppState state, String viewId, IconData icon, String title) {
    final isActive = state.activeView == viewId ||
        (viewId == 'home' && state.activeView == 'menu'); // highlight home if in menu view
    final activeColor = _getNavItemColor(viewId);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      decoration: BoxDecoration(
        gradient: isActive ? LinearGradient(
          colors: [
            activeColor.withOpacity(0.18),
            activeColor.withOpacity(0.06),
          ],
        ) : null,
        borderRadius: BorderRadius.circular(10),
        border: isActive ? Border.all(color: activeColor.withOpacity(0.25)) : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: ListTile(
          visualDensity: VisualDensity.compact,
          leading: Icon(icon, color: isActive ? activeColor : const Color(0xFF94A3B8), size: 20),
          title: Text(
            title,
            style: TextStyle(
              color: isActive ? activeColor : const Color(0xFF94A3B8),
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              fontSize: 13.5,
              letterSpacing: 0.3,
            ),
          ),
          onTap: () {
            state.navigateToView(viewId);
            if (!isPersistent) {
              Navigator.pop(context);
            }
          },
        ),
      ),
    );
  }
}

class SupportDialog extends StatelessWidget {
  const SupportDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);
    final licenseKey = state.saasLicenseKey.isNotEmpty ? state.saasLicenseKey : "Not Activated";
    final phone = state.saasSupportPhone.isNotEmpty ? state.saasSupportPhone : "9979711149";
    
    return Dialog(
      backgroundColor: const Color(0xFF12161B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.support_agent, color: Color(0xFFFF6F24), size: 28),
                    SizedBox(width: 10),
                    Text(
                      'Customer Support',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white60),
                ),
              ],
            ),
            const Divider(color: Colors.white12, height: 24),
            const Text(
              'For any issues, queries, or manual license activation/renewal, contact our support team:',
              style: TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.4),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('License Key:', style: TextStyle(color: Colors.white54, fontSize: 12.5)),
                      Text(
                        licenseKey,
                        style: const TextStyle(
                          color: Color(0xFFFF6F24),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Support Contact:', style: TextStyle(color: Colors.white54, fontSize: 12.5)),
                      Text(
                        phone,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final cleanNumber = phone.replaceAll(RegExp(r'[\s\+\-]'), '');
                      final Uri url = Uri.parse('tel:$cleanNumber');
                      try {
                        await launchUrl(url);
                      } catch (e) {
                        debugPrint("Error launching call intent: $e");
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.phone, size: 18),
                    label: const Text('Call Support', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final cleanNumber = phone.replaceAll(RegExp(r'[\s\+\-]'), '');
                      final text = Uri.encodeComponent("Hi Support, I need assistance with my Ahar OS. License Key: $licenseKey");
                      final Uri url = Uri.parse('https://wa.me/$cleanNumber?text=$text');
                      try {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      } catch (e) {
                        debugPrint("Error launching WhatsApp intent: $e");
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.message, size: 18),
                    label: const Text('WhatsApp', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
}

// --- VIEW: SEATING GRID LAYOUT VIEW ---

class SeatingGridView extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;

  const SeatingGridView({super.key, required this.scaffoldKey});

  @override
  State<SeatingGridView> createState() => _SeatingGridViewState();
}

class _SeatingGridViewState extends State<SeatingGridView> {
  int _tapCount = 0;
  DateTime? _lastTapTime;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Live update the occupied durations every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  String _getOccupiedDurationText(String tableId, AppState state) {
    final timeStr = state.tableOccupiedTimes[tableId];
    if (timeStr == null) return '';
    try {
      final time = DateTime.parse(timeStr);
      final diff = DateTime.now().difference(time);
      if (diff.inMinutes < 60) {
        return "${diff.inMinutes}m";
      } else {
        final hrs = diff.inHours;
        final mins = diff.inMinutes % 60;
        return "${hrs}h ${mins}m";
      }
    } catch (_) {
      return '';
    }
  }

  void _handleHeaderTap(BuildContext context, AppState state) {
    final now = DateTime.now();
    if (_lastTapTime == null || now.difference(_lastTapTime!) > const Duration(seconds: 2)) {
      _tapCount = 1;
    } else {
      _tapCount++;
    }
    _lastTapTime = now;
    if (_tapCount >= 6) {
      _tapCount = 0;
      _showPinDialog(context, state);
    }
  }

  void _showPinDialog(BuildContext context, AppState state) {
    final pinController = TextEditingController();
    String errorMsg = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF12161B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0x0CFFFFFF)),
              ),
              title: const Row(
                children: [
                  Icon(Icons.security, color: Color(0xFFFF6F24)),
                  SizedBox(width: 10),
                  Text('Manager Authorization', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Please enter the manager security PIN to access the audit panel.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: pinController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      decoration: InputDecoration(
                        labelText: 'Security PIN',
                        counterText: '',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.lock_outline),
                      ),
                    ),
                    if (errorMsg.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorMsg,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ]
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final entered = pinController.text.trim();
                    final isOwnerPin = state.users.any((u) => u.pin == entered && u.role == 'owner');
                    if (isOwnerPin) {
                      Navigator.pop(context);
                      state.navigateToView('secret-ledger');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Access Granted: Sales Optimizer Panel opened.'),
                          backgroundColor: Color(0xFF00AA4F),
                        ),
                      );
                    } else {
                      setDialogState(() {
                        errorMsg = 'Invalid Security PIN. Access Denied.';
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6F24),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Authorize'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF12161B),
        elevation: 0,
        leading: MediaQuery.of(context).size.width <= 1100
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => widget.scaffoldKey.currentState?.openDrawer(),
              )
            : null,
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _handleHeaderTap(context, state),
          child: const Text('Home', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ),
        centerTitle: false,
        actions: [
          const Center(child: CloudStatusIndicator()),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => _showAddTableDialog(context, state),
            child: const Text('Add +', style: TextStyle(color: Color(0xFFFF6F24), fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 1200,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 110,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.35,
            ),
            itemCount: state.tables.length,
            itemBuilder: (context, idx) {
              final table = state.tables[idx];
              final hasOrder = state.activeCarts[table.id]?.isNotEmpty ?? false;

              return InkWell(
                onTap: () => state.selectTable(table.id),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: hasOrder
                          ? [const Color(0xFF2C1619), const Color(0xFF150D0E)]
                          : [const Color(0xFF0F2C20), const Color(0xFF0A1510)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: hasOrder 
                          ? const Color(0xFFEF4444).withOpacity(0.8) 
                          : const Color(0xFF10B981).withOpacity(0.8),
                      width: hasOrder ? 2.0 : 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (hasOrder ? const Color(0xFFEF4444) : const Color(0xFF10B981)).withOpacity(hasOrder ? 0.15 : 0.08),
                        blurRadius: hasOrder ? 10 : 8,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          table.id,
                          style: TextStyle(
                            fontSize: 15, 
                            fontWeight: FontWeight.w900, 
                            color: Colors.white,
                            letterSpacing: 0.5,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.5),
                                offset: const Offset(0, 2),
                                blurRadius: 4,
                              )
                            ]
                          ),
                        ),
                        if (hasOrder) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3), width: 1),
                            ),
                            child: Text(
                              _getOccupiedDurationText(table.id, state),
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFFCA5A5),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showAddTableDialog(BuildContext context, AppState state) {
    final nameController = TextEditingController();
    String tableType = 'table';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF12161B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0x0CFFFFFF))),
              title: const Text('Add Table/Parcel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Table/Parcel Name',
                        hintText: 'e.g. Table E1, PARCEL 6',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: tableType,
                      dropdownColor: const Color(0xFF12161B),
                      decoration: InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'table', child: Text('Table')),
                        DropdownMenuItem(value: 'parcel', child: Text('Parcel')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => tableType = val);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isNotEmpty) {
                      state.addTable(name, tableType);
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6F24),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// --- VIEW: MENU CATALOG VIEW ---

class MenuCatalogView extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;

  const MenuCatalogView({super.key, required this.scaffoldKey});

  @override
  State<MenuCatalogView> createState() => _MenuCatalogViewState();
}

class _MenuCatalogViewState extends State<MenuCatalogView> {
  final GlobalKey<ScaffoldState> _innerScaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      key: _innerScaffoldKey,
      endDrawer: const SizedBox(
        width: 350,
        child: CartDrawer(),
      ),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12161B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => state.navigateToView('home'),
        ),
        title: Row(
          children: [
            if (state.selectedTableId != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ]
                ),
                child: Text(
                  state.selectedTableId!,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              const Text('/', style: TextStyle(color: Colors.white38, fontSize: 16)),
              const SizedBox(width: 8),
            ],
            const Text('Menu Catalog', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              state.searchBarVisible ? Icons.close : Icons.search,
              color: state.searchBarVisible ? const Color(0xFF3B82F6) : const Color(0xFF94A3B8),
            ),
            onPressed: () {
              if (state.searchBarVisible) {
                _searchController.clear();
                state.updateMenuSearch('');
              }
              state.toggleMenuSearch();
            },
            tooltip: 'Search Dishes',
          ),
          const Center(child: CloudStatusIndicator()),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              _innerScaffoldKey.currentState?.openEndDrawer();
            },
            child: const Text('Bill', style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          IconButton(
            icon: const Icon(Icons.shopping_bag, color: Color(0xFF94A3B8)),
            onPressed: () {
              _innerScaffoldKey.currentState?.openEndDrawer();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          // Left: Menu catalog list & bottom bar
          Expanded(
            child: Stack(
              children: [
                Column(
                  children: [
                    // Search bar overlay toggle
                    if (state.searchBarVisible)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        color: const Color(0xFF12161B),
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Search dishes...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 20),
                                    onPressed: () {
                                      _searchController.clear();
                                      state.updateMenuSearch('');
                                    },
                                  )
                                : null,
                            fillColor: const Color(0xFF1E293B),
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          ),
                          onChanged: (val) => state.updateMenuSearch(val),
                        ),
                      ),
                    _buildHorizontalCategoriesBar(context, state),
                    // Category name and counter
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            state.menuSearchQuery.isEmpty ? state.currentCategory : "Search Results",
                            style: const TextStyle(fontSize: 20, color: Color(0xFF94A3B8)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0x0CFFFFFF)),
                            ),
                            child: Text(
                              state.menuSearchQuery.isEmpty
                                  ? '${state.menu.where((i) => i.category == state.currentCategory).length} items'
                                  : '${state.menu.where((i) => i.name.toLowerCase().contains(state.menuSearchQuery) || i.desc.toLowerCase().contains(state.menuSearchQuery)).length} found',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Color(0x0CFFFFFF), indent: 24, endIndent: 24, height: 1),
                    
                    // Food vertical items
                    Expanded(
                      child: _buildMenuListing(context, state),
                    ),
                  ],
                ),
                
                // Floating category popover selector button
                Positioned(
                  bottom: state.cartCount > 0 ? (76 + bottomPadding) : (24 + bottomPadding),
                  right: 24,
                  child: FloatingActionButton.extended(
                    onPressed: () => _showCategoryPopup(context, state),
                    backgroundColor: const Color(0xFF202D3D),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30), side: const BorderSide(color: Color(0x14FFFFFF))),
                    icon: const Icon(Icons.restaurant, size: 16, color: Colors.white),
                    label: const Text('Menu', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
                
                // Dynamic golden bottom bar
                if (state.cartCount > 0)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: CartBottomActionBar(
                      itemCount: state.cartCount,
                      onInfoTap: () {
                        _innerScaffoldKey.currentState?.openEndDrawer();
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuListing(BuildContext context, AppState state) {
    var items = state.menu;
    if (state.menuSearchQuery.isEmpty) {
      items = items.where((i) => i.category == state.currentCategory).toList();
    } else {
      items = items.where((i) => i.name.toLowerCase().contains(state.menuSearchQuery) || i.desc.toLowerCase().contains(state.menuSearchQuery)).toList();
    }

    if (items.isEmpty) {
      return Center(
        child: Text(
          state.menuSearchQuery.isEmpty
              ? 'No dishes found under this category.'
              : 'No dishes found matching "${state.menuSearchQuery}".',
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 700;

    if (isDesktop) {
      return GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 260,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 1.25, // Taller cards to prevent text vertical overflow!
        ),
        itemCount: items.length,
        itemBuilder: (context, idx) {
          final item = items[idx];
          final cartItem = state.activeCart.where((i) => i.id == item.id).toList();
          final inCart = cartItem.isNotEmpty;

          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1E293B).withOpacity(0.65),
                  const Color(0xFF0F172A).withOpacity(0.85),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: item.isVeg 
                    ? const Color(0xFF10B981).withOpacity(0.35) 
                    : const Color(0xFFEF4444).withOpacity(0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (item.isVeg ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: item.isVeg ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Center(
                        child: CircleAvatar(
                          radius: 3,
                          backgroundColor: item.isVeg ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 14, 
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₹${item.price}',
                      style: const TextStyle(
                        fontSize: 15, 
                        color: Color(0xFFFF6F24), 
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    inCart
                        ? Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFFFF8540), Color(0xFFFF5200)]),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF6F24).withOpacity(0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove, size: 12, color: Colors.white),
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(4),
                                  onPressed: () => state.updateQty(item.id, -1),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: Text(
                                    '${cartItem.first.qty}', 
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add, size: 12, color: Colors.white),
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(4),
                                  onPressed: () => state.addToCart(item),
                                ),
                              ],
                            ),
                          )
                        : Container(
                            height: 30,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF8540), Color(0xFFFF5200)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF6F24).withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: () => state.addToCart(item),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                elevation: 0,
                              ),
                              child: const Text(
                                'ADD', 
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5, letterSpacing: 0.5),
                              ),
                            ),
                          ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      itemCount: items.length,
      itemBuilder: (context, idx) {
        final item = items[idx];
        final cartItem = state.activeCart.where((i) => i.id == item.id).toList();
        final inCart = cartItem.isNotEmpty;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1E293B).withOpacity(0.65),
                const Color(0xFF0F172A).withOpacity(0.85),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: item.isVeg 
                  ? const Color(0xFF10B981).withOpacity(0.35) 
                  : const Color(0xFFEF4444).withOpacity(0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (item.isVeg ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: item.isVeg ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: CircleAvatar(
                          radius: 4,
                          backgroundColor: item.isVeg ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name, 
                            style: const TextStyle(
                              fontSize: 14.5, 
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '₹${item.price}', 
                            style: const TextStyle(
                              fontSize: 14, 
                              color: Color(0xFFFF6F24), 
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              inCart
                  ? Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFF8540), Color(0xFFFF5200)]),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6F24).withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, size: 14, color: Colors.white),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                            onPressed: () => state.updateQty(item.id, -1),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '${cartItem.first.qty}', 
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: Colors.white),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, size: 14, color: Colors.white),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                            onPressed: () => state.addToCart(item),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF8540), Color(0xFFFF5200)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6F24).withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () => state.addToCart(item),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          elevation: 0,
                        ),
                        child: const Text(
                          'ADD', 
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5, letterSpacing: 0.5),
                        ),
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHorizontalCategoriesBar(BuildContext context, AppState state) {
    return Container(
      height: 52,
      margin: const EdgeInsets.only(top: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: state.categoriesList.length,
        itemBuilder: (context, idx) {
          final cat = state.categoriesList[idx];
          final isActive = state.currentCategory == cat && state.menuSearchQuery.isEmpty;
          final count = state.menu.where((m) => m.category == cat).length;

          return GestureDetector(
            onTap: () {
              state.selectCategory(cat);
              state.updateMenuSearch('');
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                gradient: isActive
                    ? const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
                      )
                    : null,
                color: isActive ? null : const Color(0xFF1E293B).withOpacity(0.4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive
                      ? const Color(0xFF06B6D4).withOpacity(0.5)
                      : const Color(0x0CFFFFFF),
                  width: 1.2,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: const Color(0xFF06B6D4).withOpacity(0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Text(
                    cat,
                    style: TextStyle(
                      color: isActive ? Colors.white : const Color(0xFF94A3B8),
                      fontSize: 12.5,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.black26 : Colors.white12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: isActive ? Colors.white : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showCategoryPopup(BuildContext context, AppState state) {
    showDialog(
      context: context,
      builder: (context) {
        return Align(
          alignment: Alignment.center,
          child: Container(
            margin: const EdgeInsets.all(24),
            width: 300,
            constraints: const BoxConstraints(maxHeight: 480),
            child: Material(
              color: const Color(0xFF10141A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0x0CFFFFFF))),
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                shrinkWrap: true,
                itemCount: state.categoriesList.length,
                itemBuilder: (context, idx) {
                  final cat = state.categoriesList[idx];
                  final count = state.menu.where((m) => m.category == cat).length;
                  final isActive = state.currentCategory == cat;

                  return Container(
                    decoration: BoxDecoration(
                      gradient: isActive ? LinearGradient(
                        colors: [
                          const Color(0xFFFF6F24).withOpacity(0.18),
                          const Color(0xFFE6550F).withOpacity(0.06),
                        ],
                      ) : null,
                      borderRadius: BorderRadius.circular(10),
                      border: isActive ? Border.all(color: const Color(0x2BFF6F24)) : null,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      child: ListTile(
                        title: Text(
                          cat,
                          style: TextStyle(
                            color: isActive ? const Color(0xFFFF6F24) : const Color(0xFF94A3B8),
                            fontSize: 13.5,
                            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: isActive ? const LinearGradient(colors: [Color(0xFFFF6F24), Color(0xFFE6550F)]) : null,
                            color: isActive ? null : Colors.white10,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isActive ? Colors.white : const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                        onTap: () {
                          state.selectCategory(cat);
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

// --- WIDGET: CART BOTTOM ACTION BAR ---

class CartBottomActionBar extends StatelessWidget {
  final int itemCount;
  final VoidCallback onInfoTap;

  const CartBottomActionBar({super.key, required this.itemCount, required this.onInfoTap});

  Widget _buildActionBarButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    bool highlight = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: highlight ? Colors.white.withOpacity(0.25) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              icon,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, -3),
          )
        ],
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 12,
        top: 8,
        bottom: 8 + bottomPadding,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.shopping_cart, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                '$itemCount ${itemCount == 1 ? "Item" : "Items"}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          Row(
            children: [
              _buildActionBarButton(
                icon: Icons.info_outline,
                tooltip: 'View Details',
                onPressed: onInfoTap,
              ),
              const SizedBox(width: 8),
              _buildActionBarButton(
                icon: Icons.search,
                tooltip: 'Search Menu',
                onPressed: () => state.toggleMenuSearch(),
              ),
              const SizedBox(width: 8),
              _buildActionBarButton(
                icon: Icons.print,
                tooltip: 'Print Receipt',
                onPressed: () => _printMonospacedReceipt(context, state),
              ),
              const SizedBox(width: 8),
              _buildActionBarButton(
                icon: Icons.check_circle_outline,
                tooltip: 'Generate Bill',
                onPressed: () {
                  state.generateTableBill();
                  if (state.isCloudAlmostFull && !state.shownCloudFullAlert) {
                    state.setShownCloudFullAlert(true);
                    _showCloudFullWarningDialog(context, state);
                  }
                },
                highlight: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _printMonospacedReceipt(BuildContext context, AppState state) async {
    if (state.activeCart.isEmpty) return;

    if (!state.isPrinterReady) {
      showPrinterErrorDialog(context, state.selectedPrinterType);
      return;
    }

    final sub = state.cartSubtotal;
    final tax = state.cartGst;
    final del = state.cartDelivery;
    final tot = state.cartTotal;

    final List<String> lines = [];
    lines.add("========================================");
    lines.add("       ${state.storeName}");
    if (state.storeGstin.isNotEmpty) {
      lines.add("        GSTIN: ${state.storeGstin}");
    }
    lines.add("========================================");
    final occupiedIso = state.tableOccupiedTimes[state.selectedTableId];
    String? checkInStr;
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

    final now = DateTime.now();
    final hStr = now.hour.toString().padLeft(2, '0');
    final mStr = now.minute.toString().padLeft(2, '0');
    final sStr = now.second.toString().padLeft(2, '0');
    final ampm = now.hour >= 12 ? 'PM' : 'AM';
    final nowStr = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}, $hStr:$mStr:$sStr $ampm";

    lines.add("Table/Parcel: ${state.selectedTableId ?? ''}");
    if (checkInStr != null) {
      lines.add("Check-In:  $checkInStr");
      lines.add("Check-Out: $nowStr");
    } else {
      lines.add("Date: $nowStr");
    }
    lines.add("========================================");
    lines.add("ITEMS:");
    
    for (var item in state.activeCart) {
      final nameStr = item.name.padRight(20, '.');
      final qtyStr = "${item.qty}x".padRight(5, ' ');
      final valStr = "₹${item.price * item.qty}".padLeft(7, ' ');
      lines.add("$nameStr$qtyStr$valStr");
    }
    
    lines.add("========================================");
    final rawItemTotal = state.activeCart.fold<int>(0, (sum, item) => sum + (item.price * item.qty));
    final discountPercent = state.cartDiscountPercent;
    final discountAmount = (rawItemTotal * discountPercent / 100).round();
    if (discountPercent > 0) {
      final label = "Discount (${discountPercent.toStringAsFixed(0)}%):";
      final labelPadded = label.padRight(19, ' ');
      lines.add("Items Total:       ${"₹$rawItemTotal".padLeft(21, ' ')}");
      lines.add("$labelPadded${"-₹$discountAmount".padLeft(21, ' ')}");
    }
    lines.add("Subtotal:          ${"₹$sub".padLeft(21, ' ')}");
    if (state.showGstOnBills && tax > 0) {
      lines.add("CGST:              ${"₹${(tax / 2.0).toStringAsFixed(2)}".padLeft(21, ' ')}");
      lines.add("SGST:              ${"₹${(tax / 2.0).toStringAsFixed(2)}".padLeft(21, ' ')}");
    }
    lines.add("Packaging:         ${"₹$del".padLeft(21, ' ')}");
    if (state.showGstOnBills && tax > 0) {
      lines.add("Tax Mode:          ${(state.isGstInclusive ? "Inclusive" : "Exclusive").padLeft(21, ' ')}");
    }
    lines.add("========================================");
    lines.add("GRAND TOTAL:       ${"₹$tot".padLeft(21, ' ')}");
    lines.add("========================================");
    lines.add("      Thank You! Please Visit Again");
    lines.add("========================================");

    final success = await executeReceiptPrint(lines.join('\n'), state);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to print receipt.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt printed successfully!')),
      );
    }
  }
}

// --- WIDGET: CART DRAWER (ORDER BASKET SIDEBAR) ---

class CartDrawer extends StatelessWidget {
  const CartDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);

    return Container(
      color: const Color(0xFF0F172A),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 20 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header drawer title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.shopping_bag, size: 20, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Order Basket', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => state.clearCart(),
                icon: const Icon(Icons.delete_outline, size: 14, color: Color(0xFFEF4444)),
                label: const Text('Clear', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0x19EF4444),
                  foregroundColor: const Color(0xFFEF4444),
                  elevation: 0,
                  side: const BorderSide(color: Color(0x33EF4444)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0x14FFFFFF), height: 1),
          const SizedBox(height: 16),
          
          // Cart item listings
          Expanded(
            child: state.activeCart.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_basket_outlined, size: 40, color: Colors.white24),
                        SizedBox(height: 12),
                        Text(
                          'Your basket is empty.\nAdd some delicious food!',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.4),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: state.activeCart.length,
                    itemBuilder: (context, idx) {
                      final item = state.activeCart[idx];
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x0CFFFFFF)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item.qty} x ₹${item.price} = ₹${item.qty * item.price}',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFFFF6F24), fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove, size: 14, color: Colors.white60),
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(4),
                                  onPressed: () => state.updateQty(item.id, -1),
                                ),
                                Text('${item.qty}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                IconButton(
                                  icon: const Icon(Icons.add, size: 14, color: Colors.white60),
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(4),
                                  onPressed: () => state.updateQty(item.id, 1),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          
          // Checkout Summary footer
          if (state.activeCart.isNotEmpty) ...[
            const Divider(color: Color(0x14FFFFFF), height: 1),
            const SizedBox(height: 16),
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('GST Inclusive Prices', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    Switch(
                      value: state.isGstInclusive,
                      activeColor: const Color(0xFFFF6F24),
                      onChanged: (val) {
                        state.toggleGstInclusive(val);
                      },
                    ),
                  ],
                ),
                if (state.allowDiscounts) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Discount (% Off)', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildDiscountButton(state, 0),
                              const SizedBox(width: 4),
                              _buildDiscountButton(state, 5),
                              const SizedBox(width: 4),
                              _buildDiscountButton(state, 10),
                              const SizedBox(width: 4),
                              _buildDiscountButton(state, 15),
                              const SizedBox(width: 4),
                              _buildDiscountCustomButton(context, state),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    final rawItemTotal = state.activeCart.fold<int>(0, (sum, item) => sum + (item.price * item.qty));
                    final discountAmount = (rawItemTotal * state.cartDiscountPercent / 100).round();
                    return Column(
                      children: [
                        _buildSummaryRow('Items Total', '₹$rawItemTotal'),
                        if (state.cartDiscountPercent > 0) ...[
                          const SizedBox(height: 8),
                          _buildSummaryRow('Discount (${state.cartDiscountPercent.toStringAsFixed(0)}%)', '-₹$discountAmount', isDiscount: true),
                        ],
                        const SizedBox(height: 8),
                        _buildSummaryRow('Subtotal', '₹${state.cartSubtotal}'),
                        if (state.showGstOnBills && state.cartGst > 0) ...[
                          const SizedBox(height: 8),
                          _buildSummaryRow('CGST', '₹${(state.cartGst / 2.0).toStringAsFixed(2)}'),
                          const SizedBox(height: 8),
                          _buildSummaryRow('SGST', '₹${(state.cartGst / 2.0).toStringAsFixed(2)}'),
                        ],
                        const SizedBox(height: 8),
                        _buildSummaryRow('Packaging & Delivery', '₹${state.cartDelivery}'),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(color: Color(0x14FFFFFF), height: 1),
                        ),
                        _buildSummaryRow('Grand Total', '₹${state.cartTotal}', isTotal: true),
                      ],
                    );
                  }
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      if (!state.isPrinterReady) {
                        showPrinterErrorDialog(context, state.selectedPrinterType);
                      } else {
                        final kotText = formatKOTText(
                          state.storeName,
                          state.selectedTableId ?? 'WALK-IN',
                          state.activeCart,
                        );
                        final success = await executeReceiptPrint(kotText, state);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(success ? 'KOT sent to kitchen printer!' : 'Failed to print KOT.')),
                        );
                      }
                    },
                    icon: const Icon(Icons.restaurant, size: 16),
                    label: const Text('Print KOT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF6F24),
                      side: const BorderSide(color: Color(0xFFFF6F24)),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final invId = state.placeOrder();
                      if (invId.isNotEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Order Billed successfully!\nInvoice: $invId')),
                        );
                        if (state.isCloudAlmostFull && !state.shownCloudFullAlert) {
                          state.setShownCloudFullAlert(true);
                          _showCloudFullWarningDialog(context, state);
                        }
                      }
                    },
                    icon: const Icon(Icons.check_circle, size: 16),
                    label: const Text('Checkout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6F24),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDiscountButton(AppState state, double pct) {
    final isSelected = state.cartDiscountPercent == pct;
    return InkWell(
      onTap: () => state.updateCartDiscount(pct),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF6F24) : const Color(0x0CFFFFFF),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? const Color(0xFFFF6F24) : const Color(0x1AFFFFFF)),
        ),
        child: Text(
          '${pct.toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _buildDiscountCustomButton(BuildContext context, AppState state) {
    final isCustom = state.cartDiscountPercent != 0 &&
        state.cartDiscountPercent != 5 &&
        state.cartDiscountPercent != 10 &&
        state.cartDiscountPercent != 15;

    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) {
            final controller = TextEditingController();
            return AlertDialog(
              backgroundColor: const Color(0xFF12161B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Enter Custom Discount (%)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              content: TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  hintText: 'e.g. 20',
                  suffixText: '%',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                ),
                TextButton(
                  onPressed: () {
                    final val = double.tryParse(controller.text) ?? 0.0;
                    if (val >= 0 && val <= 100) {
                      state.updateCartDiscount(val);
                    }
                    Navigator.pop(context);
                  },
                  child: const Text('Apply', style: TextStyle(color: Color(0xFFFF6F24), fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isCustom ? const Color(0xFFFF6F24) : const Color(0x0CFFFFFF),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isCustom ? const Color(0xFFFF6F24) : const Color(0x1AFFFFFF)),
        ),
        child: Text(
          isCustom ? '${state.cartDiscountPercent.toStringAsFixed(1)}%' : 'Custom',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isCustom ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false, bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isTotal ? Colors.white : (isDiscount ? const Color(0xFF00AA4F) : const Color(0xFF94A3B8)),
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            fontSize: isTotal ? 16 : 13.5,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isTotal ? const Color(0xFFFF6F24) : (isDiscount ? const Color(0xFF00AA4F) : Colors.white),
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            fontSize: isTotal ? 18 : 13.5,
          ),
        ),
      ],
    );
  }
}

// --- WIDGET: RECEIPT POPUP RECEIPT VIEWER ---

class ReceiptPopupOverlay extends StatelessWidget {
  final InvoiceModel invoice;

  const ReceiptPopupOverlay({super.key, required this.invoice});

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);

    final List<String> lines = [];
    lines.add("========================================");
    lines.add("       ${state.storeName}");
    if (state.storeGstin.isNotEmpty) {
      lines.add("        GSTIN: ${state.storeGstin}");
    }
    lines.add("========================================");
    lines.add("Invoice: ${invoice.id}");
    lines.add("Table: ${invoice.tableId}");
    if (invoice.checkInTime != null) {
      lines.add("Check-In:  ${invoice.checkInTime}");
      lines.add("Check-Out: ${invoice.dateTime}");
    } else {
      lines.add("Date: ${invoice.dateTime}");
    }
    lines.add("========================================");
    lines.add("ITEMS:");
    
    for (var item in invoice.items) {
      final nameStr = item.name.padRight(20, '.');
      final qtyStr = "${item.qty}x".padRight(5, ' ');
      final valStr = "₹${item.price * item.qty}".padLeft(7, ' ');
      lines.add("$nameStr$qtyStr$valStr");
    }
    
    lines.add("========================================");
    final rawItemTotal = invoice.items.fold<int>(0, (sum, item) => sum + (item.price * item.qty));
    final discountPercent = invoice.discountPercent;
    final discountAmount = (rawItemTotal * discountPercent / 100).round();
    if (discountPercent > 0) {
      final label = "Discount (${discountPercent.toStringAsFixed(0)}%):";
      final labelPadded = label.padRight(19, ' ');
      lines.add("Items Total:       ${"₹$rawItemTotal".padLeft(21, ' ')}");
      lines.add("$labelPadded${"-₹$discountAmount".padLeft(21, ' ')}");
    }
    lines.add("Subtotal:          ${"₹${invoice.subtotal}".padLeft(21, ' ')}");
    if (invoice.gst > 0) {
      lines.add("CGST:              ${"₹${(invoice.gst / 2.0).toStringAsFixed(2)}".padLeft(21, ' ')}");
      lines.add("SGST:              ${"₹${(invoice.gst / 2.0).toStringAsFixed(2)}".padLeft(21, ' ')}");
    }
    lines.add("Packaging:         ${"₹${invoice.packaging}".padLeft(21, ' ')}");
    lines.add("========================================");
    lines.add("GRAND TOTAL:       ${"₹${invoice.total}".padLeft(21, ' ')}");
    lines.add("========================================");
    lines.add("      Thank You! Please Visit Again");
    lines.add("========================================");

    final receiptText = lines.join('\n');

    return GestureDetector(
      onTap: () => state.selectedReceiptInvoice = null,
      child: Container(
        color: Colors.black54,
        child: Center(
          child: GestureDetector(
            onTap: () {}, // consume tap
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(20),
              constraints: const BoxConstraints(maxWidth: 440, maxHeight: 520),
              decoration: BoxDecoration(
                color: const Color(0xFF12161B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x0CFFFFFF)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Invoice Bill Receipt', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => state.selectedReceiptInvoice = null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        child: Center(
                          child: Text(
                            receiptText,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5, height: 1.4, color: Colors.black87, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            if (!state.isPrinterReady) {
                              showPrinterErrorDialog(context, state.selectedPrinterType);
                            } else {
                              final success = await executeReceiptPrint(receiptText, state);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(success ? 'Receipt sent to printer!' : 'Failed to print receipt.')),
                              );
                            }
                          },
                          icon: const Icon(Icons.print, size: 16),
                          label: const Text('Receipt', style: TextStyle(fontSize: 12.5)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFF6F24),
                            side: const BorderSide(color: Color(0xFFFF6F24)),
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            if (!state.isPrinterReady) {
                              showPrinterErrorDialog(context, state.selectedPrinterType);
                            } else {
                              final kotText = formatKOTText(
                                state.storeName,
                                invoice.tableId,
                                invoice.items,
                              );
                              final success = await executeReceiptPrint(kotText, state);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(success ? 'KOT sent to kitchen!' : 'Failed to print KOT.')),
                              );
                            }
                          },
                          icon: const Icon(Icons.restaurant, size: 16),
                          label: const Text('KOT', style: TextStyle(fontSize: 12.5)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white24),
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            state.selectedReceiptInvoice = null;
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6F24),
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                          ),
                          child: const Text('Close', style: TextStyle(fontSize: 12.5)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- VIEW: INVOICES LOG VIEW ---

class InvoicesListView extends StatelessWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;

  const InvoicesListView({super.key, required this.scaffoldKey});

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF12161B),
        leading: MediaQuery.of(context).size.width <= 1100
            ? IconButton(icon: const Icon(Icons.menu), onPressed: () => scaffoldKey.currentState?.openDrawer())
            : null,
        title: const Text('Invoices', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: Icon(
              Icons.filter_alt_outlined,
              color: state.activeInvoiceFilter != null ? const Color(0xFF10B981) : Colors.white,
            ),
            onPressed: () => state.navigateToView('invoice-filter'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          decoration: BoxDecoration(color: const Color(0x7F191E28), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0x0CFFFFFF))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Past Orders & Invoices',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (state.activeInvoiceFilter != null)
                      InputChip(
                        label: Text(
                          state.activeInvoiceFilter == 'custom'
                              ? 'Custom Range'
                              : state.activeInvoiceFilter!.toUpperCase().replaceAll('_', ' '),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        backgroundColor: const Color(0xFF10B981),
                        deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white),
                        onDeleted: () {
                          state.setInvoiceFilter(null);
                        },
                      ),
                  ],
                ),
              ),
              const Divider(color: Color(0x0CFFFFFF), height: 1),
              Expanded(
                child: state.filteredInvoices.isEmpty
                    ? const Center(child: Text('No past invoices found matching the filter.', style: TextStyle(color: Color(0xFF94A3B8))))
                    : ListView.builder(
                        itemCount: state.filteredInvoices.length,
                        itemBuilder: (context, idx) {
                          final inv = state.filteredInvoices[idx];
                          return ListTile(
                            title: Text(inv.id, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981), fontFamily: 'monospace')),
                            subtitle: Text('Table: ${inv.tableId} • ${inv.dateTime}', style: const TextStyle(color: Color(0xFF94A3B8))),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('₹${inv.total}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: () {
                                    state.selectedReceiptInvoice = inv;
                                  },
                                  icon: const Icon(Icons.receipt_long, color: Color(0xFF10B981)),
                                  tooltip: 'View Bill',
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- VIEW: SEARCH LOG VIEW ---

class InvoicesSearchView extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;

  const InvoicesSearchView({super.key, required this.scaffoldKey});

  @override
  State<InvoicesSearchView> createState() => _InvoicesSearchViewState();
}

class _InvoicesSearchViewState extends State<InvoicesSearchView> {
  final searchController = TextEditingController();
  List<InvoiceModel> results = [];
  bool searched = false;

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF12161B),
        leading: MediaQuery.of(context).size.width <= 1100
            ? IconButton(icon: const Icon(Icons.menu), onPressed: () => widget.scaffoldKey.currentState?.openDrawer())
            : null,
        title: const Text('Search Invoices', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: const Color(0x7F191E28), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0x0CFFFFFF))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Find Checkout Records', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            decoration: InputDecoration(
                              hintText: 'Enter invoice ID, Table name or amount...',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            final text = searchController.text.trim().toLowerCase();
                            if (text.isNotEmpty) {
                              setState(() {
                                results = state.invoices.where((inv) => inv.id.toLowerCase().contains(text) || inv.tableId.toLowerCase().contains(text) || inv.total.toString().contains(text)).toList();
                                searched = true;
                              });
                            }
                          },
                          icon: const Icon(Icons.search),
                          label: const Text('Search'),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: !searched
                    ? const Center(child: Text('Please enter search text.', style: TextStyle(color: Color(0xFF94A3B8))))
                    : results.isEmpty
                        ? const Center(child: Text('No matching invoices found.', style: TextStyle(color: Color(0xFFFF4444))))
                        : ListView.builder(
                            itemCount: results.length,
                            itemBuilder: (context, idx) {
                              final inv = results[idx];
                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0x0CFFFFFF)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${inv.id} (Table: ${inv.tableId})', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6366F1), fontFamily: 'monospace')),
                                        const SizedBox(height: 4),
                                        Text(inv.dateTime, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Text('₹${inv.total}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        const SizedBox(width: 16),
                                        ElevatedButton(
                                          onPressed: () => state.selectedReceiptInvoice = inv,
                                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
                                          child: const Text('Details'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- VIEW: REVENUE REPORT VIEW ---

class RevenueReportView extends StatelessWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;

  const RevenueReportView({super.key, required this.scaffoldKey});

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);
    final gross = state.invoices.fold(0, (sum, inv) => sum + inv.total);
    final count = state.invoices.length;
    final gstSum = state.invoices.fold(0, (sum, inv) => sum + inv.gst);

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month, 1);
    final yearStart = DateTime(now.year, 1, 1);

    int todaySales = 0;
    int todayOrders = 0;
    int monthSales = 0;
    int monthOrders = 0;
    int yearSales = 0;
    int yearOrders = 0;

    for (var inv in state.invoices) {
      final date = inv.parsedDateTime;
      if (date.isAfter(todayStart.subtract(const Duration(microseconds: 1)))) {
        todaySales += inv.total;
        todayOrders++;
      }
      if (date.isAfter(monthStart.subtract(const Duration(microseconds: 1)))) {
        monthSales += inv.total;
        monthOrders++;
      }
      if (date.isAfter(yearStart.subtract(const Duration(microseconds: 1)))) {
        yearSales += inv.total;
        yearOrders++;
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF12161B),
        leading: MediaQuery.of(context).size.width <= 1100
            ? IconButton(icon: const Icon(Icons.menu), onPressed: () => scaffoldKey.currentState?.openDrawer())
            : null,
        title: const Text('Revenue Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overall Summary Header
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Overall Account Ledger',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.9)),
              ),
            ),
            // Stat Cards Grid
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.of(context).size.width > 700 ? 3 : 1,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: MediaQuery.of(context).size.width > 700 ? 2.2 : 3.0,
              ),
              children: [
                _buildStatCard('Gross Revenue', '₹$gross', 'Total sales since deployment', valueColor: const Color(0xFF8B5CF6)),
                _buildStatCard('Orders Placed', '$count', 'Total successful checkouts', valueColor: const Color(0xFF06B6D4)),
                _buildStatCard('GST Collected', '₹$gstSum', 'Accumulated 5% GST tax', valueColor: const Color(0xFFEC4899)),
              ],
            ),
            const SizedBox(height: 24),

            // Period Breakdown Header
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Sales Breakdown by Period',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.9)),
              ),
            ),
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.of(context).size.width > 700 ? 3 : 1,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: MediaQuery.of(context).size.width > 700 ? 2.2 : 3.0,
              ),
              children: [
                _buildStatCard("Today's Sales", '₹$todaySales', '$todayOrders orders today', valueColor: const Color(0xFF10B981)),
                _buildStatCard("This Month's Sales", '₹$monthSales', '$monthOrders orders this month', valueColor: const Color(0xFFF59E0B)),
                _buildStatCard("This Year's Sales", '₹$yearSales', '$yearOrders orders this year', valueColor: const Color(0xFF3B82F6)),
              ],
            ),
            const SizedBox(height: 24),
            
            // Bar Chart Widget
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: const Color(0x7F191E28), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0x0CFFFFFF))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sales Summary Chart (Last 7 Days)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  Builder(
                    builder: (context) {
                      final last7Sales = state.last7DaysSales;
                      final last7Labels = state.last7DaysLabels;
                      
                      // Find the max value to scale the bars (max height 130 to allow room for the value text above the bar)
                      final maxSales = last7Sales.reduce((a, b) => a > b ? a : b);
                      final scale = maxSales > 0 ? 130.0 / maxSales : 0.0;
                      
                      return Container(
                        height: 180,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(7, (index) {
                            final val = last7Sales[index];
                            final label = last7Labels[index];
                            final height = val * scale;
                            
                            // Ensure a minimum height of 2 pixels if there are sales
                            final barHeight = height > 0 ? height.clamp(5.0, 130.0) : 2.0;
                            
                            return _ChartBar(
                              label: label,
                              height: barHeight,
                              value: val,
                            );
                          }),
                        ),
                      );
                    }
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, String desc, {Color valueColor = const Color(0xFFFF6F24)}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0x7F191E28), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0x0CFFFFFF))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: valueColor)),
          Text(desc, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }
}

class _ChartBar extends StatelessWidget {
  final String label;
  final double height;
  final double value;

  const _ChartBar({
    required this.label,
    required this.height,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (value > 0)
          Text(
            '₹${value.round()}',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
        const SizedBox(height: 4),
        Container(
          width: 38,
          height: height,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Color(0xFF6366F1), Color(0xFF3B82F6)],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
      ],
    );
  }
}

// --- VIEW: MENU performance REPORT VIEW ---

class MenuReportView extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;

  const MenuReportView({super.key, required this.scaffoldKey});

  @override
  State<MenuReportView> createState() => _MenuReportViewState();
}

class _MenuReportViewState extends State<MenuReportView> {
  String _filter = 'all'; // 'daily', 'weekly', 'monthly', 'yearly', 'custom', 'all'
  DateTimeRange? _customDateRange;

  Future<void> _selectCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _customDateRange,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark().copyWith(
              primary: const Color(0xFFFF6F24),
              onPrimary: Colors.white,
              surface: const Color(0xFF12161B),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _filter = 'custom';
      });
    }
  }

  String _getDateRangeDescription() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);
    final yearStart = DateTime(now.year, 1, 1);

    if (_filter == 'daily') {
      return "Today: ${todayStart.day}/${todayStart.month}/${todayStart.year}";
    } else if (_filter == 'weekly') {
      return "This Week: ${weekStart.day}/${weekStart.month}/${weekStart.year} to ${now.day}/${now.month}/${now.year}";
    } else if (_filter == 'monthly') {
      return "This Month: ${monthStart.day}/${monthStart.month}/${monthStart.year} to ${now.day}/${now.month}/${now.year}";
    } else if (_filter == 'yearly') {
      return "This Year: ${yearStart.day}/${yearStart.month}/${yearStart.year} to ${now.day}/${now.month}/${now.year}";
    } else if (_filter == 'custom' && _customDateRange != null) {
      final start = _customDateRange!.start;
      final end = _customDateRange!.end;
      return "Custom: ${start.day}/${start.month}/${start.year} to ${end.day}/${end.month}/${end.year}";
    } else {
      return "All-time accumulated records";
    }
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white60,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          if (value == 'custom') {
            _selectCustomDateRange();
          } else {
            setState(() {
              _filter = value;
            });
          }
        }
      },
      selectedColor: const Color(0xFFFF6F24),
      backgroundColor: Colors.white.withOpacity(0.05),
      checkmarkColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);
    
    // Compute performanceCounts based on _filter
    final Map<int, int> performanceCounts = {};
    for (var item in state.menu) {
      performanceCounts[item.id] = 0;
    }

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);
    final yearStart = DateTime(now.year, 1, 1);

    int totalPeriodSales = 0;
    int totalPeriodQty = 0;

    for (var inv in state.invoices) {
      final date = inv.parsedDateTime;
      bool include = false;
      if (_filter == 'daily') {
        include = date.isAfter(todayStart.subtract(const Duration(microseconds: 1)));
      } else if (_filter == 'weekly') {
        include = date.isAfter(weekStart.subtract(const Duration(microseconds: 1)));
      } else if (_filter == 'monthly') {
        include = date.isAfter(monthStart.subtract(const Duration(microseconds: 1)));
      } else if (_filter == 'yearly') {
        include = date.isAfter(yearStart.subtract(const Duration(microseconds: 1)));
      } else if (_filter == 'custom') {
        if (_customDateRange != null) {
          final start = DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day);
          final end = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59, 999);
          include = date.isAfter(start.subtract(const Duration(microseconds: 1))) &&
                    date.isBefore(end.add(const Duration(microseconds: 1)));
        } else {
          include = false;
        }
      } else {
        include = true; // all time
      }

      if (include) {
        totalPeriodSales += inv.subtotal;
        for (var item in inv.items) {
          totalPeriodQty += item.qty;
          if (performanceCounts.containsKey(item.id)) {
            performanceCounts[item.id] = performanceCounts[item.id]! + item.qty;
          }
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF12161B),
        leading: MediaQuery.of(context).size.width <= 1100
            ? IconButton(icon: const Icon(Icons.menu), onPressed: () => widget.scaffoldKey.currentState?.openDrawer())
            : null,
        title: const Text('Menu Item Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          decoration: BoxDecoration(color: const Color(0x7F191E28), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0x0CFFFFFF))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Dish Sales Performance',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_filter == 'custom')
                          TextButton.icon(
                            onPressed: _selectCustomDateRange,
                            icon: const Icon(Icons.date_range, size: 14, color: Color(0xFFFF6F24)),
                            label: const Text('Change Range', style: TextStyle(fontSize: 12, color: Color(0xFFFF6F24))),
                            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getDateRangeDescription(),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('Daily (Today)', 'daily'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Weekly', 'weekly'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Monthly', 'monthly'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Yearly', 'yearly'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Custom Range', 'custom'),
                          const SizedBox(width: 8),
                          _buildFilterChip('All Time', 'all'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0x0CFFFFFF), height: 1),
              
              // Period Summary Banner
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFFFF6F24).withOpacity(0.12), const Color(0xFFE6550F).withOpacity(0.04)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFF6F24).withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('Total Items Sold', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        const SizedBox(height: 4),
                        Text('$totalPeriodQty Units', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                    Container(width: 1, height: 28, color: const Color(0x1AFFFFFF)),
                    Column(
                      children: [
                        const Text('Total Period Revenue', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        const SizedBox(height: 4),
                        Text('₹$totalPeriodSales', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFFF6F24))),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0x0CFFFFFF), height: 1),
              
              Expanded(
                child: ListView.builder(
                  itemCount: state.menu.length,
                  itemBuilder: (context, idx) {
                    final item = state.menu[idx];
                    final units = performanceCounts[item.id] ?? 0;

                    return ListTile(
                      title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
                            child: Text(item.category, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                          ),
                          const SizedBox(width: 12),
                          Text('Price: ₹${item.price}', style: const TextStyle(color: Color(0xFF94A3B8))),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('$units Units Sold', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('₹${units * item.price}', style: const TextStyle(color: Color(0xFFFF6F24), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- VIEW: ACCOUNTS LEDGER VIEW ---

class AccountsReportView extends StatelessWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;

  const AccountsReportView({super.key, required this.scaffoldKey});

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);
    final gross = state.invoices.fold(0, (sum, inv) => sum + inv.total);
    final gstSum = state.invoices.fold(0, (sum, inv) => sum + inv.gst);
    final delSum = state.invoices.fold(0, (sum, inv) => sum + inv.packaging);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF12161B),
        leading: MediaQuery.of(context).size.width <= 1100
            ? IconButton(icon: const Icon(Icons.menu), onPressed: () => scaffoldKey.currentState?.openDrawer())
            : null,
        title: const Text('Accounts Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: const Color(0x7F191E28), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0x0CFFFFFF))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Financial Accounts Statement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  _buildStatementRow('Cash Desk Ledger', '₹$gross', color: const Color(0xFF00AA4F)),
                  _buildStatementRow('Outstanding Receivables', '₹0', color: const Color(0xFFF59E0B)),
                  _buildStatementRow('Tax Liability (GST Account)', '₹$gstSum'),
                  _buildStatementRow('Direct Expense (Delivery Outflow)', '₹$delSum', color: const Color(0xFFFF4444)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatementRow(String label, String value, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x0CFFFFFF)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8)),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// --- VIEW: TABLE PERFORMANCE REPORT VIEW ---

class TableReportView extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  const TableReportView({super.key, required this.scaffoldKey});

  @override
  State<TableReportView> createState() => _TableReportViewState();
}

class _TableReportViewState extends State<TableReportView> {
  String _filter = 'all'; // 'daily', 'weekly', 'monthly', 'all', 'live'

  String _getLiveDurationText(String tableId, AppState state) {
    final timeStr = state.tableOccupiedTimes[tableId];
    if (timeStr == null) return '';
    try {
      final time = DateTime.parse(timeStr);
      final diff = DateTime.now().difference(time);
      if (diff.inMinutes < 60) {
        return "${diff.inMinutes}m";
      } else {
        final hrs = diff.inHours;
        final mins = diff.inMinutes % 60;
        return "${hrs}h ${mins}m";
      }
    } catch (_) {
      return '';
    }
  }

  String _getInvoiceDurationText(InvoiceModel inv) {
    if (inv.checkInTime == null) return '';
    try {
      final checkIn = parseInvoiceDateHelper(inv.checkInTime!);
      final checkOut = parseInvoiceDateHelper(inv.dateTime);
      if (checkIn == null || checkOut == null) return '';
      final diff = checkOut.difference(checkIn);
      if (diff.inSeconds < 0) return '0m';
      if (diff.inMinutes < 60) {
        return "${diff.inMinutes}m";
      } else {
        final hrs = diff.inHours;
        final mins = diff.inMinutes % 60;
        return "${hrs}h ${mins}m";
      }
    } catch (_) {
      return '';
    }
  }

  String _getDateRangeDescription() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    if (_filter == 'live') {
      return "Currently active tables and their live orders";
    } else if (_filter == 'daily') {
      return "Today: ${todayStart.day}/${todayStart.month}/${todayStart.year}";
    } else if (_filter == 'weekly') {
      return "This Week: ${weekStart.day}/${weekStart.month}/${weekStart.year} to ${now.day}/${now.month}/${now.year}";
    } else if (_filter == 'monthly') {
      return "This Month: ${monthStart.day}/${monthStart.month}/${monthStart.year} to ${now.day}/${now.month}/${now.year}";
    } else {
      return "All-time accumulated records";
    }
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white60,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() {
            _filter = value;
          });
        }
      },
      selectedColor: value == 'live' ? const Color(0xFFEF4444) : const Color(0xFF8B5CF6),
      backgroundColor: Colors.white.withOpacity(0.05),
      checkmarkColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    final List<InvoiceModel> periodInvoices = state.invoices.where((inv) {
      final date = inv.parsedDateTime;
      if (_filter == 'daily') {
        return date.isAfter(todayStart.subtract(const Duration(microseconds: 1)));
      } else if (_filter == 'weekly') {
        return date.isAfter(weekStart.subtract(const Duration(microseconds: 1)));
      } else if (_filter == 'monthly') {
        return date.isAfter(monthStart.subtract(const Duration(microseconds: 1)));
      }
      return true; // all time
    }).toList();

    final Map<String, int> tableOccupiedCount = {};
    final Map<String, int> tableRevenue = {};
    final Map<String, Map<String, int>> tableItemQuantities = {};
    final Map<String, List<InvoiceModel>> tableInvoices = {};

    for (var table in state.tables) {
      tableOccupiedCount[table.id] = 0;
      tableRevenue[table.id] = 0;
      tableItemQuantities[table.id] = {};
      tableInvoices[table.id] = [];
    }

    for (var inv in periodInvoices) {
      final tableId = inv.tableId;
      if (!tableOccupiedCount.containsKey(tableId)) {
        tableOccupiedCount[tableId] = 0;
        tableRevenue[tableId] = 0;
        tableItemQuantities[tableId] = {};
        tableInvoices[tableId] = [];
      }

      tableOccupiedCount[tableId] = tableOccupiedCount[tableId]! + 1;
      tableRevenue[tableId] = tableRevenue[tableId]! + inv.total;
      tableInvoices[tableId]!.add(inv);

      final itemMap = tableItemQuantities[tableId]!;
      for (var item in inv.items) {
        itemMap[item.name] = (itemMap[item.name] ?? 0) + item.qty;
      }
    }

    final displayTables = _filter == 'live'
        ? state.tables.where((t) => state.activeCarts[t.id]?.isNotEmpty ?? false).toList()
        : state.tables;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF12161B),
        leading: MediaQuery.of(context).size.width <= 1100
            ? IconButton(icon: const Icon(Icons.menu), onPressed: () => widget.scaffoldKey.currentState?.openDrawer())
            : null,
        title: const Text('Table Performance Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0x7F191E28),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x0CFFFFFF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Seating Performance & Revenue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      _getDateRangeDescription(),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('Live Performance', 'live'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Daily (Today)', 'daily'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Weekly', 'weekly'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Monthly', 'monthly'),
                          const SizedBox(width: 8),
                          _buildFilterChip('All Time', 'all'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0x0CFFFFFF), height: 1),

              Expanded(
                child: _filter == 'live' && displayTables.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.table_restaurant, size: 48, color: Colors.white24),
                            SizedBox(height: 12),
                            Text(
                              'No active orders on tables right now.',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: displayTables.length,
                        itemBuilder: (context, idx) {
                          final table = displayTables[idx];
                          final count = tableOccupiedCount[table.id] ?? 0;
                          final revenue = tableRevenue[table.id] ?? 0;
                          final avgValue = count > 0 ? (revenue / count).round() : 0;
                          final activeCartItems = state.activeCarts[table.id] ?? [];
                          final isLiveOccupied = activeCartItems.isNotEmpty;
                          final liveTotal = isLiveOccupied
                              ? activeCartItems.fold<double>(0, (sum, item) => sum + (item.price * item.qty))
                              : 0;
                          final liveDuration = _getLiveDurationText(table.id, state);

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            decoration: BoxDecoration(
                              color: isLiveOccupied
                                  ? const Color(0x0CFF4444)
                                  : const Color(0x05FFFFFF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isLiveOccupied
                                    ? const Color(0x22FF4444)
                                    : const Color(0x08FFFFFF),
                                width: 1.2,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              title: Row(
                                children: [
                                  Text(table.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  const SizedBox(width: 8),
                                  if (isLiveOccupied)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF4444),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.fiber_manual_record, color: Colors.white, size: 8),
                                          const SizedBox(width: 4),
                                          Text(
                                            'LIVE: ₹${liveTotal.round()}',
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 6),
                                  if (_filter == 'live') ...[
                                    Row(
                                      children: [
                                        const Icon(Icons.access_time, size: 12, color: Color(0xFFFF6F24)),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Active: $liveDuration',
                                          style: const TextStyle(color: Color(0xFFFF6F24), fontSize: 12, fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Live Items: ${activeCartItems.map((e) => "${e.name} x${e.qty}").join(", ")}',
                                      style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12, fontStyle: FontStyle.italic),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ] else ...[
                                    Text(
                                      'Occupied: $count times • Avg Bill: ₹$avgValue',
                                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                                    ),
                                    if (isLiveOccupied) ...[
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(Icons.access_time, size: 12, color: Color(0xFFFF6F24)),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Active: $liveDuration',
                                            style: const TextStyle(color: Color(0xFFFF6F24), fontSize: 12, fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Live Items: ${activeCartItems.map((e) => "${e.name} x${e.qty}").join(", ")}',
                                        style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12, fontStyle: FontStyle.italic),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _filter == 'live' ? 'Live Order Total' : 'Total Revenue',
                                    style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _filter == 'live' ? '₹${liveTotal.round()}' : '₹$revenue',
                                    style: TextStyle(
                                      color: _filter == 'live' ? const Color(0xFFFF4444) : const Color(0xFF8B5CF6),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () {
                                _showTableDetailDialog(
                                  context,
                                  table.id,
                                  count,
                                  revenue,
                                  tableItemQuantities[table.id] ?? {},
                                  tableInvoices[table.id] ?? [],
                                  activeCartItems,
                                  state.tableOccupiedTimes[table.id],
                                  isLiveMode: _filter == 'live',
                                );
                              },
                            ),
                          ),
                        );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTableDetailDialog(
    BuildContext context,
    String tableId,
    int occupiedCount,
    int totalRevenue,
    Map<String, int> itemsMap,
    List<InvoiceModel> invoices,
    List<CartItem> liveItems,
    String? occupiedTimeStr, {
    bool isLiveMode = false,
  }) {
    final state = AppStateProvider.of(context);
    final sortedItems = itemsMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    String liveDuration = '';
    String formattedOccupiedTime = '';
    if (occupiedTimeStr != null) {
      try {
        final occupiedDt = DateTime.parse(occupiedTimeStr);
        final h = occupiedDt.hour.toString().padLeft(2, '0');
        final m = occupiedDt.minute.toString().padLeft(2, '0');
        final ampm = occupiedDt.hour >= 12 ? 'PM' : 'AM';
        formattedOccupiedTime = "$h:$m $ampm";

        final diff = DateTime.now().difference(occupiedDt);
        if (diff.inMinutes < 60) {
          liveDuration = "${diff.inMinutes}m";
        } else {
          final hrs = diff.inHours;
          final mins = diff.inMinutes % 60;
          liveDuration = "${hrs}h ${mins}m";
        }
      } catch (_) {}
    }
    final double liveTotal = liveItems.fold<double>(0, (sum, item) => sum + (item.price * item.qty));

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF12161B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0x0CFFFFFF)),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.table_chart, color: Color(0xFF8B5CF6)),
                  const SizedBox(width: 10),
                  Text('Table $tableId Report', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white54, size: 20),
              )
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (liveItems.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0x11FF4444),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x22FF4444), width: 1.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.fiber_manual_record, color: Color(0xFFFF4444), size: 14),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'LIVE ACTIVE ORDER',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFFF4444), letterSpacing: 0.5),
                                  ),
                                ],
                              ),
                              if (liveDuration.isNotEmpty)
                                Text(
                                  'Time: $liveDuration ($formattedOccupiedTime)',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFFFF6F24), fontWeight: FontWeight.bold),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Column(
                            children: liveItems.map((item) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.name,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
                                      ),
                                    ),
                                    Text(
                                      '${item.qty} x ₹${item.price}',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      '₹${item.qty * item.price}',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 10),
                          const Divider(color: Color(0x22FF4444), height: 1),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Estimated Total', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70)),
                              Text(
                                '₹${liveTotal.round()}',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFFF4444)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (!isLiveMode) ...[
                    if (liveItems.isNotEmpty) const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              const Text('Occupied Count', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)), textAlign: TextAlign.center),
                              const SizedBox(height: 4),
                              Text('$occupiedCount times', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 24, color: const Color(0x1AFFFFFF)),
                        Expanded(
                          child: Column(
                            children: [
                              const Text('Total Revenue', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)), textAlign: TextAlign.center),
                              const SizedBox(height: 4),
                              Text('₹$totalRevenue', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)), textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 24, color: const Color(0x1AFFFFFF)),
                        Expanded(
                          child: Column(
                            children: [
                              const Text('Avg Order Value', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)), textAlign: TextAlign.center),
                              const SizedBox(height: 4),
                              Text('₹${occupiedCount > 0 ? (totalRevenue / occupiedCount).round() : 0}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Color(0x14FFFFFF)),
                    const SizedBox(height: 8),

                    Text(
                      'Items Ordered on this Table',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: const Color(0xFF22C55E), // Vibrant Green
                        shadows: [
                          Shadow(
                            offset: const Offset(1, 1),
                            color: Colors.black.withOpacity(0.9),
                            blurRadius: 2,
                          ),
                          Shadow(
                            offset: const Offset(2, 2),
                            color: const Color(0xFF22C55E).withOpacity(0.3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (sortedItems.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text('No items ordered yet.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5)),
                        ),
                      )
                    else
                      Column(
                        children: sortedItems.map((entry) {
                          final menuItem = state.menu.firstWhere(
                            (m) => m.name == entry.key,
                            orElse: () => MenuItem(id: 0, name: entry.key, price: 0, category: ''),
                          );
                          final price = menuItem.price;

                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.key,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFFACC15), // Highlighter Yellow
                                      shadows: [
                                        Shadow(
                                          color: Color(0x33FACC15),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Text(
                                  '${entry.value} x ₹$price',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  '₹${entry.value * price}',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 20),
                    const Divider(color: Color(0x14FFFFFF)),
                    const SizedBox(height: 8),

                    Text(
                      'Recent Bills & Sessions',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: const Color(0xFF22C55E), // Vibrant Green
                        shadows: [
                          Shadow(
                            offset: const Offset(1, 1),
                            color: Colors.black.withOpacity(0.9),
                            blurRadius: 2,
                          ),
                          Shadow(
                            offset: const Offset(2, 2),
                            color: const Color(0xFF22C55E).withOpacity(0.3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (invoices.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text('No completed bills.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5)),
                        ),
                      )
                    else
                      Theme(
                        data: Theme.of(context).copyWith(
                          dividerColor: Colors.transparent,
                          unselectedWidgetColor: Colors.white54,
                        ),
                        child: Column(
                          children: invoices.take(5).map((inv) {
                            final duration = _getInvoiceDurationText(inv);
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.02),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0x0CFFFFFF)),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                child: ExpansionTile(
                                  dense: true,
                                iconColor: const Color(0xFF8B5CF6),
                                tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                childrenPadding: const EdgeInsets.all(12).copyWith(top: 0),
                                title: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      inv.id,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Color(0xFF8B5CF6), fontSize: 13),
                                    ),
                                    Text(
                                      '₹${inv.total}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.white),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text('Checkout: ${inv.dateTime}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                    if (inv.checkInTime != null) ...[
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          const Icon(Icons.history_toggle_off, size: 11, color: Color(0xFF94A3B8)),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Duration: ${duration.isNotEmpty ? duration : "N/A"} (from ${inv.checkInTime!.split(', ').last})',
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                                children: [
                                  const Divider(color: Color(0x14FFFFFF), height: 16),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: inv.items.map((item) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 3),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item.name,
                                                style: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1)),
                                              ),
                                            ),
                                            Text(
                                              '${item.qty} x ₹${item.price}',
                                              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              '₹${item.qty * item.price}',
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: Colors.white60)),
            ),
          ],
        );
      },
    );
  }
}

// --- VIEW: TABLES SETTINGS VIEW ---

class TableSettingsView extends StatelessWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;

  const TableSettingsView({super.key, required this.scaffoldKey});

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF12161B),
        leading: MediaQuery.of(context).size.width <= 1100
            ? IconButton(icon: const Icon(Icons.menu), onPressed: () => scaffoldKey.currentState?.openDrawer())
            : null,
        title: const Text('Table Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          decoration: BoxDecoration(color: const Color(0x7F191E28), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0x0CFFFFFF))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Manage Seating Layout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const Divider(color: Color(0x0CFFFFFF), height: 1),
              Expanded(
                child: state.tables.isEmpty
                    ? const Center(child: Text('No tables configured in layout. Add tables on the Home dashboard.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5)))
                    : ListView.builder(
                        itemCount: state.tables.length,
                        itemBuilder: (context, idx) {
                    final table = state.tables[idx];
                    final hasOrder = state.activeCarts[table.id]?.isNotEmpty ?? false;

                    return ListTile(
                      title: Text(table.id, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(table.type.toUpperCase(), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: hasOrder ? const Color(0x19FF4444) : const Color(0x1900AA4F),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: hasOrder ? const Color(0x33FF4444) : const Color(0x3300AA4F)),
                            ),
                            child: Text(
                              hasOrder ? 'Occupied' : 'Vacant',
                              style: TextStyle(color: hasOrder ? const Color(0xFFFF4444) : const Color(0xFF00AA4F), fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 16),
                          OutlinedButton.icon(
                            onPressed: () {
                              state.deleteTable(table.id);
                            },
                            icon: const Icon(Icons.delete, size: 14),
                            label: const Text('Delete'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFFF4444),
                              side: const BorderSide(color: Color(0xFFFF4444)),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- VIEW: MENU SETTINGS VIEW ---

class MenuSettingsView extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;

  const MenuSettingsView({super.key, required this.scaffoldKey});

  @override
  State<MenuSettingsView> createState() => _MenuSettingsViewState();
}

class _MenuSettingsViewState extends State<MenuSettingsView> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);
    final filteredMenu = state.menu.where((item) {
      final query = _searchQuery.toLowerCase().trim();
      if (query.isEmpty) return true;
      return item.name.toLowerCase().contains(query) ||
             item.category.toLowerCase().contains(query) ||
             item.serialNumber.toString().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF12161B),
        leading: MediaQuery.of(context).size.width <= 1100
            ? IconButton(icon: const Icon(Icons.menu), onPressed: () => widget.scaffoldKey.currentState?.openDrawer())
            : null,
        title: const Text('Menu Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          decoration: BoxDecoration(color: const Color(0x7F191E28), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0x0CFFFFFF))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Menu List CRUD', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Reset & Sync Menu'),
                                content: const Text('This will reset your menu items to the rate card defaults and sync them to the cloud. Custom items will be overwritten. Do you want to proceed?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Reset & Sync', style: TextStyle(color: Color(0xFFF97316))),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              state.resetMenuToDefaultsAndSync();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Menu reset to defaults and synced successfully!')),
                              );
                            }
                          },
                          icon: const Icon(Icons.sync, size: 16),
                          label: const Text('Reset & Sync defaults', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E293B),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0x14FFFFFF))),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const NewItemScreen()),
                            );
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Item', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF97316),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: TextField(
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search items by name, category, or position...',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFFF97316)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white70),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0x0CFFFFFF),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0x1CFFFFFF)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFF97316)),
                    ),
                  ),
                ),
              ),
              const Divider(color: Color(0x0CFFFFFF), height: 1),
              Expanded(
                child: filteredMenu.isEmpty
                    ? const Center(child: Text('No menu items found. Add items using the button above or Reset to defaults.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5), textAlign: TextAlign.center))
                    : ListView.builder(
                        itemCount: filteredMenu.length,
                        itemBuilder: (context, idx) {
                    final item = filteredMenu[idx];
                    return ListTile(
                      leading: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: item.isVeg ? const Color(0xFF00AA4F) : const Color(0xFFEF4444),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: CircleAvatar(
                            radius: 4,
                            backgroundColor: item.isVeg ? const Color(0xFF00AA4F) : const Color(0xFFEF4444),
                          ),
                        ),
                      ),
                      title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        '₹${item.price} • ${item.category} • Position #${item.serialNumber}',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Color(0xFF3B82F6)),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditItemScreen(item: item),
                                ),
                              );
                            },
                            tooltip: 'Edit Item',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                            onPressed: () => state.deleteMenuItem(item.id),
                            tooltip: 'Delete Item',
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NewItemScreen()),
          );
        },
        backgroundColor: const Color(0xFFF97316),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add New Item', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class NewItemScreen extends StatefulWidget {
  const NewItemScreen({super.key});

  @override
  State<NewItemScreen> createState() => _NewItemScreenState();
}

class _NewItemScreenState extends State<NewItemScreen> {
  final _nameController = TextEditingController();
  final _serialController = TextEditingController();
  final _priceController = TextEditingController();
  final _customGstController = TextEditingController();
  bool _isCustomGst = false;
  String _categoryVal = 'SANDWICH';
  bool _isVeg = true;
  int _gstRate = 5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = AppStateProvider.of(context);
      setState(() {
        _gstRate = state.defaultGstRate;
        _isCustomGst = _gstRate != 0 && _gstRate != 5 && _gstRate != 12 && _gstRate != 18 && _gstRate != 28;
        if (_isCustomGst) {
          _customGstController.text = _gstRate.toString();
        }
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _serialController.dispose();
    _priceController.dispose();
    _customGstController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0C10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12161B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('New Item', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _saveItem,
            child: Row(
              children: const [
                Text('Save ', style: TextStyle(color: Color(0xFFFF6F24), fontWeight: FontWeight.bold, fontSize: 16)),
                Icon(Icons.save, color: Color(0xFFFF6F24), size: 20),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Item Name
                _buildField(
                  label: 'Item Name',
                  controller: _nameController,
                  hint: 'e.g. Cheese Toast Sandwich',
                  subtext: 'Name of the item as it appears in menu',
                ),
                const SizedBox(height: 24),

                // Serial Number
                _buildField(
                  label: 'Serial Number',
                  controller: _serialController,
                  hint: 'e.g. 10',
                  keyboardType: TextInputType.number,
                  subtext: 'Serial No determines the position of item',
                ),
                const SizedBox(height: 24),

                // Price
                _buildField(
                  label: 'Price',
                  controller: _priceController,
                  hint: 'e.g. 150',
                  keyboardType: TextInputType.number,
                  subtext: state.isGstInclusive
                      ? 'Price of the item is inclusive of GST'
                      : 'Price of the item is exclusive of GST (GST will be added on top)',
                ),
                const SizedBox(height: 24),

                // Category Dropdown
                const Text(
                  'Category',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFFFF6F24)),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _categoryVal,
                  dropdownColor: const Color(0xFF12161B),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0x33FFFFFF)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0x1AFFFFFF)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFFF6F24)),
                    ),
                  ),
                  items: state.categoriesList.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _categoryVal = val);
                    }
                  },
                ),
                const SizedBox(height: 28),

                // Vegetarian / Non Vegetarian Toggle Switch
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Vegetarian',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _isVeg ? const Color(0xFF00AA4F) : const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Switch(
                      value: !_isVeg,
                      onChanged: (val) {
                        setState(() {
                          _isVeg = !val;
                        });
                      },
                      activeColor: const Color(0xFFEF4444),
                      activeTrackColor: const Color(0x33EF4444),
                      inactiveThumbColor: const Color(0xFF00AA4F),
                      inactiveTrackColor: const Color(0x3300AA4F),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Non Vegetarian',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: !_isVeg ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // GST Rate Selection Section
                const Text(
                  'GST Rate',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFFFF6F24)),
                ),
                const SizedBox(height: 12),
                
                // GST Radio Row 1
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildGstRadio(0),
                    _buildGstRadio(5),
                    _buildGstRadio(12),
                  ],
                ),
                const SizedBox(height: 8),

                // GST Radio Row 2
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildGstRadio(18),
                    _buildGstRadio(28),
                    _buildCustomGstRadio(),
                  ],
                ),
                const SizedBox(height: 12),

                if (_isCustomGst) ...[
                  TextField(
                    controller: _customGstController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      labelText: 'Custom GST Rate (%)',
                      labelStyle: const TextStyle(color: Color(0xFFFF6F24)),
                      hintText: 'e.g. 15',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFFF6F24)),
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _gstRate = int.tryParse(val) ?? 0;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                // Italics help text
                Center(
                  child: Text(
                    'GST Tax Rate Slab is set to $_gstRate%',
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                  ),
                ),
                const SizedBox(height: 32),

                // Bottom Save Item Button
                ElevatedButton.icon(
                  onPressed: _saveItem,
                  icon: const Icon(Icons.save, size: 20),
                  label: const Text(
                    'Save Item',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                      side: const BorderSide(color: Color(0x1AFFFFFF)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomGstRadio() {
    final isSelected = _isCustomGst;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Custom',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: isSelected ? const Color(0xFFFF6F24) : const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(width: 4),
        Radio<bool>(
          value: true,
          groupValue: _isCustomGst ? true : null,
          activeColor: const Color(0xFFFF6F24),
          onChanged: (val) {
            if (val == true) {
              setState(() {
                _isCustomGst = true;
                _gstRate = int.tryParse(_customGstController.text) ?? 0;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildGstRadio(int rate) {
    final isSelected = !_isCustomGst && _gstRate == rate;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$rate%',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: isSelected ? const Color(0xFFFF6F24) : const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(width: 4),
        Radio<int>(
          value: rate,
          groupValue: _isCustomGst ? -1 : _gstRate,
          activeColor: const Color(0xFFFF6F24),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _isCustomGst = false;
                _gstRate = val;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required String subtext,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFFFF6F24)),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0x33FFFFFF)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0x1AFFFFFF)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFFF6F24)),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtext,
          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  void _saveItem() {
    final state = AppStateProvider.of(context);
    final name = _nameController.text.trim();
    final price = int.tryParse(_priceController.text) ?? 0;
    final serial = int.tryParse(_serialController.text) ?? 0;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an item name')),
      );
      return;
    }
    if (price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid price')),
      );
      return;
    }

    state.addMenuItem(
      name: name,
      price: price,
      category: _categoryVal,
      serialNumber: serial,
      isVeg: _isVeg,
      gstRate: _gstRate,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name created successfully!')),
    );
    Navigator.pop(context);
  }
}

class EditItemScreen extends StatefulWidget {
  final MenuItem item;
  const EditItemScreen({super.key, required this.item});

  @override
  State<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  final _nameController = TextEditingController();
  final _serialController = TextEditingController();
  final _priceController = TextEditingController();
  final _customGstController = TextEditingController();
  bool _isCustomGst = false;
  String _categoryVal = 'SANDWICH';
  bool _isVeg = true;
  int _gstRate = 5;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.item.name;
    _serialController.text = widget.item.serialNumber.toString();
    _priceController.text = widget.item.price.toString();
    _categoryVal = widget.item.category;
    _isVeg = widget.item.isVeg;
    _gstRate = widget.item.gstRate;
    _isCustomGst = _gstRate != 0 && _gstRate != 5 && _gstRate != 12 && _gstRate != 18 && _gstRate != 28;
    if (_isCustomGst) {
      _customGstController.text = _gstRate.toString();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _serialController.dispose();
    _priceController.dispose();
    _customGstController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0C10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12161B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Edit Item', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _saveItem,
            child: Row(
              children: const [
                Text('Save ', style: TextStyle(color: Color(0xFFFF6F24), fontWeight: FontWeight.bold, fontSize: 16)),
                Icon(Icons.save, color: Color(0xFFFF6F24), size: 20),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Item Name
                _buildField(
                  label: 'Item Name',
                  controller: _nameController,
                  hint: 'e.g. Cheese Toast Sandwich',
                  subtext: 'Name of the item as it appears in menu',
                ),
                const SizedBox(height: 24),

                // Serial Number
                _buildField(
                  label: 'Serial Number',
                  controller: _serialController,
                  hint: 'e.g. 10',
                  keyboardType: TextInputType.number,
                  subtext: 'Serial No determines the position of item',
                ),
                const SizedBox(height: 24),

                // Price
                _buildField(
                  label: 'Price',
                  controller: _priceController,
                  hint: 'e.g. 150',
                  keyboardType: TextInputType.number,
                  subtext: state.isGstInclusive
                      ? 'Price of the item is inclusive of GST'
                      : 'Price of the item is exclusive of GST (GST will be added on top)',
                ),
                const SizedBox(height: 24),

                // Category Dropdown
                const Text(
                  'Category',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFFFF6F24)),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _categoryVal,
                  dropdownColor: const Color(0xFF12161B),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0x33FFFFFF)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0x1AFFFFFF)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFFF6F24)),
                    ),
                  ),
                  items: state.categoriesList.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _categoryVal = val);
                    }
                  },
                ),
                const SizedBox(height: 28),

                // Vegetarian / Non Vegetarian Toggle Switch
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Vegetarian',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _isVeg ? const Color(0xFF00AA4F) : const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Switch(
                      value: !_isVeg,
                      onChanged: (val) {
                        setState(() {
                          _isVeg = !val;
                        });
                      },
                      activeColor: const Color(0xFFEF4444),
                      activeTrackColor: const Color(0x33EF4444),
                      inactiveThumbColor: const Color(0xFF00AA4F),
                      inactiveTrackColor: const Color(0x3300AA4F),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Non Vegetarian',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: !_isVeg ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // GST Rate Selection Section
                const Text(
                  'GST Rate',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFFFF6F24)),
                ),
                const SizedBox(height: 12),
                
                // GST Radio Row 1
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildGstRadio(0),
                    _buildGstRadio(5),
                    _buildGstRadio(12),
                  ],
                ),
                const SizedBox(height: 8),

                // GST Radio Row 2
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildGstRadio(18),
                    _buildGstRadio(28),
                    _buildCustomGstRadio(),
                  ],
                ),
                const SizedBox(height: 12),

                if (_isCustomGst) ...[
                  TextField(
                    controller: _customGstController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      labelText: 'Custom GST Rate (%)',
                      labelStyle: const TextStyle(color: Color(0xFFFF6F24)),
                      hintText: 'e.g. 15',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFFF6F24)),
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _gstRate = int.tryParse(val) ?? 0;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                // Italics help text
                Center(
                  child: Text(
                    'GST Tax Rate Slab is set to $_gstRate%',
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                  ),
                ),
                const SizedBox(height: 32),

                // Bottom Save Item Button
                ElevatedButton.icon(
                  onPressed: _saveItem,
                  icon: const Icon(Icons.save, size: 20),
                  label: const Text(
                    'Save Item',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                      side: const BorderSide(color: Color(0x1AFFFFFF)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomGstRadio() {
    final isSelected = _isCustomGst;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Custom',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: isSelected ? const Color(0xFFFF6F24) : const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(width: 4),
        Radio<bool>(
          value: true,
          groupValue: _isCustomGst ? true : null,
          activeColor: const Color(0xFFFF6F24),
          onChanged: (val) {
            if (val == true) {
              setState(() {
                _isCustomGst = true;
                _gstRate = int.tryParse(_customGstController.text) ?? 0;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildGstRadio(int rate) {
    final isSelected = !_isCustomGst && _gstRate == rate;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$rate%',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: isSelected ? const Color(0xFFFF6F24) : const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(width: 4),
        Radio<int>(
          value: rate,
          groupValue: _isCustomGst ? -1 : _gstRate,
          activeColor: const Color(0xFFFF6F24),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _isCustomGst = false;
                _gstRate = val;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required String subtext,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFFFF6F24)),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0x33FFFFFF)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0x1AFFFFFF)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFFF6F24)),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtext,
          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  void _saveItem() {
    final state = AppStateProvider.of(context);
    final name = _nameController.text.trim();
    final price = int.tryParse(_priceController.text) ?? 0;
    final serial = int.tryParse(_serialController.text) ?? 0;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an item name')),
      );
      return;
    }
    if (price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid price')),
      );
      return;
    }

    state.updateMenuItem(
      id: widget.item.id,
      name: name,
      price: price,
      category: _categoryVal,
      serialNumber: serial,
      isVeg: _isVeg,
      gstRate: _gstRate,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name updated successfully!')),
    );
    Navigator.pop(context);
  }
}

// --- VIEW: CATEGORY LISTING SETTINGS VIEW ---

class CategorySettingsView extends StatelessWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;

  const CategorySettingsView({super.key, required this.scaffoldKey});

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF12161B),
        leading: MediaQuery.of(context).size.width <= 1100
            ? IconButton(icon: const Icon(Icons.menu), onPressed: () => scaffoldKey.currentState?.openDrawer())
            : null,
        title: const Text('Category Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          decoration: BoxDecoration(color: const Color(0x7F191E28), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0x0CFFFFFF))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Supported Categories', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AddCategoryScreen()),
                        );
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Category', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0x0CFFFFFF), height: 1),
              Expanded(
                child: state.categories.isEmpty
                    ? const Center(child: Text('No categories found.', style: TextStyle(color: Color(0xFF94A3B8))))
                    : ListView.builder(
                        itemCount: state.categories.length,
                        itemBuilder: (context, idx) {
                          final cat = state.categories[idx];
                          final count = state.menu.where((m) => m.category == cat.name).length;

                          return ListTile(
                            title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Position #${cat.serialNumber}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0x198B5CF6),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0x338B5CF6)),
                                  ),
                                  child: Text('$count Items', style: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  onPressed: () => state.deleteCategory(cat.name),
                                  icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                                  tooltip: 'Delete Category',
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddCategoryScreen()),
          );
        },
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Category', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class AddCategoryScreen extends StatefulWidget {
  const AddCategoryScreen({super.key});

  @override
  State<AddCategoryScreen> createState() => _AddCategoryScreenState();
}

class _AddCategoryScreenState extends State<AddCategoryScreen> {
  final _nameController = TextEditingController();
  final _serialController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0C10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12161B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Add Category', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _saveCategory,
            child: Row(
              children: const [
                Text('Save ', style: TextStyle(color: Color(0xFFFF6F24), fontWeight: FontWeight.bold, fontSize: 16)),
                Icon(Icons.save, color: Color(0xFFFF6F24), size: 20),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Name
                _buildField(
                  label: 'Category Name',
                  controller: _nameController,
                  hint: 'e.g. SANDWICH',
                  subtext: 'Category is a placeholder for Menu items',
                ),
                const SizedBox(height: 24),

                // Serial Number
                _buildField(
                  label: 'Serial Number',
                  controller: _serialController,
                  hint: 'e.g. 1',
                  keyboardType: TextInputType.number,
                  subtext: 'Serial No determines the position of Category',
                ),
                const SizedBox(height: 32),

                // Bottom Save Button
                ElevatedButton.icon(
                  onPressed: _saveCategory,
                  icon: const Icon(Icons.save, size: 20),
                  label: const Text(
                    'Save Category',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                      side: const BorderSide(color: Color(0x1AFFFFFF)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required String subtext,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFFFF6F24)),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0x33FFFFFF)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0x1AFFFFFF)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFFF6F24)),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtext,
          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  void _saveCategory() {
    final state = AppStateProvider.of(context);
    final name = _nameController.text.trim();
    final serial = int.tryParse(_serialController.text) ?? 0;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a category name')),
      );
      return;
    }

    state.addCategory(name, serial);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name category created successfully!')),
    );
    Navigator.pop(context);
  }
}

// --- VIEW: STORE SETTINGS VIEW ---

class StoreSettingsView extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;

  const StoreSettingsView({super.key, required this.scaffoldKey});

  @override
  State<StoreSettingsView> createState() => _StoreSettingsViewState();
}

class _StoreSettingsViewState extends State<StoreSettingsView> {
  final nameController = TextEditingController();
  final gstinController = TextEditingController();
  final deliveryController = TextEditingController();
  final defaultGstController = TextEditingController();
  bool _showGst = true;
  bool _allowDiscounts = true;

  @override
  void initState() {
    super.initState();
    // Schedule controller pre-populates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = AppStateProvider.of(context);
      nameController.text = state.storeName;
      gstinController.text = state.storeGstin;
      deliveryController.text = state.parcelDeliveryCharge.toString();
      defaultGstController.text = state.defaultGstRate.toString();
      setState(() {
        _showGst = state.showGstOnBills;
        _allowDiscounts = state.allowDiscounts;
      });
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    gstinController.dispose();
    deliveryController.dispose();
    defaultGstController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF12161B),
        leading: MediaQuery.of(context).size.width <= 1100
            ? IconButton(icon: const Icon(Icons.menu), onPressed: () => widget.scaffoldKey.currentState?.openDrawer())
            : null,
        title: const Text('Store Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: const Color(0x7F191E28), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0x0CFFFFFF))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Configure Store Branding', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text(
                    'Change the restaurant display name and billing GSTIN license printed on drawer and receipts.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8), height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(labelText: 'Restaurant Display Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: gstinController,
                    decoration: InputDecoration(labelText: 'GSTIN / Business Registration', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: deliveryController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Parcel / Delivery Charge (₹)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Default Parcel Mode', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: state.defaultParcelMode,
                    dropdownColor: const Color(0xFF12161B),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: [
                      const DropdownMenuItem(value: 'pickup', child: Text('Pickup (No delivery charge)')),
                      DropdownMenuItem(value: 'delivery', child: Text('Delivery (₹${state.parcelDeliveryCharge.round()} delivery charge)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        state.setDefaultParcelMode(val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Show/Calculate GST on Bills', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70)),
                      Switch(
                        value: _showGst,
                        activeColor: const Color(0xFFD946EF),
                        onChanged: (val) {
                          setState(() {
                            _showGst = val;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Allow Bill Discounts', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70)),
                      Switch(
                        value: _allowDiscounts,
                        activeColor: const Color(0xFFD946EF),
                        onChanged: (val) {
                          setState(() {
                            _allowDiscounts = val;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_showGst) ...[
                    const Text('Default GST Rate (%)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: defaultGstController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Default GST Rate (%)',
                        hintText: 'e.g. 5',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Default GST Calculation Mode', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<bool>(
                      value: state.isGstInclusive,
                      dropdownColor: const Color(0xFF12161B),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: const [
                        DropdownMenuItem(value: true, child: Text('Tax Inclusive (GST included in Price)')),
                        DropdownMenuItem(value: false, child: Text('Tax Exclusive (Add GST on top of Price)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          state.toggleGstInclusive(val);
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      final name = nameController.text.trim();
                      final gstin = gstinController.text.trim();
                      final charge = double.tryParse(deliveryController.text.trim()) ?? 40.0;
                      final defaultGst = int.tryParse(defaultGstController.text.trim()) ?? 5;
                      if (name.isNotEmpty) {
                        state.saveStoreSettings(name, gstin, charge, state.isGstInclusive, _showGst, _allowDiscounts, defaultGst);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Branding details saved successfully!')));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter restaurant display name.')));
                      }
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD946EF),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- PLACEHOLDERS ---

class DevicePlaceholderView extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  const DevicePlaceholderView({super.key, required this.scaffoldKey});

  @override
  State<DevicePlaceholderView> createState() => _DevicePlaceholderViewState();
}

class _DevicePlaceholderViewState extends State<DevicePlaceholderView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = AppStateProvider.of(context);
      if (!kIsWeb) {
        _requestBluetoothPermissions(state);
      }
    });
  }

  Future<void> _requestBluetoothPermissions(AppState state) async {
    if (kIsWeb) return;
    try {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      if (statuses[Permission.bluetoothConnect] == PermissionStatus.granted || 
          statuses[Permission.bluetoothScan] == PermissionStatus.granted) {
        state.scanForPrinters();
      } else {
        state.scanForPrinters();
      }
    } catch (e) {
      debugPrint("Error requesting Bluetooth permissions: $e");
      state.scanForPrinters();
    }
  }

  void _printTestPage(BuildContext context, AppState state) async {
    final List<String> lines = [];
    lines.add("========================================");
    lines.add("       ${state.storeName}");
    if (state.selectedPrinterType == 'wifi') {
      lines.add("        TEST WI-FI PRINT");
      lines.add("========================================");
      lines.add("Printer IP: ${state.printerIpAddress}");
    } else {
      lines.add("        TEST BLUETOOTH PRINT");
      lines.add("========================================");
      lines.add("Printer: ${state.connectedPrinterName.isEmpty ? 'BlueTooth Printer' : state.connectedPrinterName}");
      lines.add("MAC: ${state.connectedPrinterMac}");
    }
    lines.add("Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}");
    lines.add("========================================");
    lines.add("Status: WORKING");
    lines.add("========================================");
    final success = await executeReceiptPrint(lines.join('\n'), state);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? 'Test page printed!' : 'Failed to print test page.')),
    );
  }

  void _showDetectPrinterDialog(AppState state) {
    _requestBluetoothPermissions(state);
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF12161B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Select Printer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  if (state.isBtScanning)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF6F24)),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                      onPressed: () async {
                        await _requestBluetoothPermissions(state);
                        setDialogState(() {});
                      },
                    ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: !state.isBluetoothEnabled
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bluetooth_disabled, color: Colors.redAccent, size: 40),
                            const SizedBox(height: 12),
                            const Text('Bluetooth is turned off', style: TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            const Text('Please enable Bluetooth in your device settings.', style: TextStyle(color: Colors.white60, fontSize: 12)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () async {
                                await _requestBluetoothPermissions(state);
                                setDialogState(() {});
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF6F24),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Retry Scan'),
                            )
                          ],
                        )
                      : state.availablePrinters.isEmpty
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.bluetooth_disabled, color: Colors.white24, size: 40),
                                const SizedBox(height: 12),
                                const Text('No paired printers found', style: TextStyle(color: Colors.white60, fontSize: 13)),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: () async {
                                    await _requestBluetoothPermissions(state);
                                    setDialogState(() {});
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF6F24),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Scan Devices'),
                                ),
                              ],
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: state.availablePrinters.length,
                              itemBuilder: (context, idx) {
                                final printer = state.availablePrinters[idx];
                                final isCurrent = state.connectedPrinterMac == printer.macAdress;
                                return Container(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isCurrent ? const Color(0x1AFFFFFF) : Colors.black12,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isCurrent ? const Color(0xFFFF6F24) : Colors.white10,
                                    ),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    child: ListTile(
                                      dense: true,
                                      leading: const Icon(Icons.print, color: Colors.white60, size: 18),
                                      title: Text(
                                        printer.name.isNotEmpty ? printer.name : 'Unknown Device',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Text(printer.macAdress, style: const TextStyle(fontSize: 11, color: Colors.white38)),
                                      trailing: isCurrent
                                          ? const Icon(Icons.check_circle, color: Color(0xFF00AA4F), size: 18)
                                          : null,
                                      onTap: () async {
                                        Navigator.pop(context);
                                        bool success = await state.connectToBluetoothPrinter(printer.macAdress, printer.name);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(success
                                                  ? 'Connected to ${printer.name}!'
                                                  : 'Failed to connect to ${printer.name}.'),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPrinterIpDialog(BuildContext context, AppState state) {
    final controller = TextEditingController(text: state.printerIpAddress);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF12161B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Printer IP Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'e.g. 192.168.1.100',
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF6F24))),
            ),
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () {
                final ip = controller.text.trim();
                if (ip.isNotEmpty) {
                  state.setPrinterIpAddress(ip);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Printer IP Address updated to $ip')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6F24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showInvoiceCodeDialog(AppState state) {
    final controller = TextEditingController(text: state.invoiceCode);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF12161B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Change Invoice Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: TextField(
            controller: controller,
            maxLength: 6,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Invoice Prefix',
              hintText: 'e.g. INV, BILL, TX',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () {
                final val = controller.text.trim().toUpperCase();
                if (val.isNotEmpty) {
                  state.setInvoiceCode(val);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Invoice Code prefix updated to $val')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6F24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x7F191E28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x0CFFFFFF)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Icon(icon, color: const Color(0xFFFF6F24), size: 24),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
          ),
          subtitle: subtitle != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.3),
                  ),
                )
              : null,
          trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right, color: Colors.white30, size: 20) : null),
          onTap: onTap,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF12161B),
        leading: MediaQuery.of(context).size.width <= 1100
            ? IconButton(icon: const Icon(Icons.menu), onPressed: () => widget.scaffoldKey.currentState?.openDrawer())
            : null,
        title: const Text('Device Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSettingCard(
                  icon: Icons.settings_input_component,
                  title: 'Printer Connection Type',
                  subtitle: state.selectedPrinterType == 'wifi' ? 'Wi-Fi / Local Network' : 'Bluetooth (BT)',
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          backgroundColor: const Color(0xFF12161B),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          title: const Text('Printer Connection Type', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              RadioListTile<String>(
                                title: const Text('Bluetooth (BT)', style: TextStyle(color: Colors.white)),
                                value: 'bluetooth',
                                groupValue: state.selectedPrinterType,
                                activeColor: const Color(0xFFFF6F24),
                                onChanged: (val) {
                                  if (val != null) {
                                    state.setPrinterType(val);
                                    Navigator.pop(context);
                                  }
                                },
                              ),
                              RadioListTile<String>(
                                title: const Text('Wi-Fi / Network', style: TextStyle(color: Colors.white)),
                                value: 'wifi',
                                groupValue: state.selectedPrinterType,
                                activeColor: const Color(0xFFFF6F24),
                                onChanged: (val) {
                                  if (val != null) {
                                    state.setPrinterType(val);
                                    Navigator.pop(context);
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      }
                    );
                  }
                ),
                if (state.selectedPrinterType == 'wifi') ...[
                  _buildSettingCard(
                    icon: Icons.lan,
                    title: 'Printer IP Address',
                    subtitle: state.printerIpAddress.isEmpty ? 'Tap to configure IP address' : 'IP: ${state.printerIpAddress}',
                    onTap: () => _showPrinterIpDialog(context, state),
                  ),
                ] else ...[
                  _buildSettingCard(
                    icon: Icons.print,
                    title: 'Printer Name',
                    subtitle: "'${state.connectedPrinterName.isEmpty ? 'BlueTooth Printer' : state.connectedPrinterName}' is set as default printer for this device",
                  ),
                  _buildSettingCard(
                    icon: Icons.bluetooth,
                    title: 'Is Printer Connected',
                    trailing: Switch(
                      value: state.isPrinterConnected,
                      activeColor: const Color(0xFFFF6F24),
                      onChanged: (val) async {
                        await state.togglePrinterConnection(val);
                        if (context.mounted) {
                          if (val && !state.isPrinterConnected) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Could not connect to printer. Please turn ON the printer and reconnect from Detect Printer.')),
                            );
                          }
                        }
                      },
                    ),
                  ),
                  _buildSettingCard(
                    icon: Icons.lan,
                    title: 'Connect Printer',
                    subtitle: "Click on this button to connect with '${state.connectedPrinterName.isEmpty ? 'BlueTooth Printer' : state.connectedPrinterName}'",
                    onTap: () async {
                      if (state.connectedPrinterMac.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select/detect a printer first.')),
                        );
                        return;
                      }
                      bool success = await state.connectToBluetoothPrinter(state.connectedPrinterMac, state.connectedPrinterName);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(success ? 'Connected successfully!' : 'Failed to connect.')),
                        );
                      }
                    },
                  ),
                  _buildSettingCard(
                    icon: Icons.wifi,
                    title: 'Detect Printer',
                    subtitle: 'Select a printer from the list of already paired bluetooth devices',
                    onTap: () => _showDetectPrinterDialog(state),
                  ),
                ],
                _buildSettingCard(
                  icon: Icons.receipt_long,
                  title: 'Roll Width - ${state.rollWidth} Inches',
                  subtitle: 'Click to change Roll Width to ${state.rollWidth == 2 ? 3 : 2} Inches',
                  onTap: () {
                    final nextWidth = state.rollWidth == 2 ? 3 : 2;
                    state.setRollWidth(nextWidth);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Roll Width changed to $nextWidth Inches')),
                    );
                  },
                ),
                _buildSettingCard(
                  icon: Icons.play_arrow,
                  title: 'Test Print',
                  onTap: () {
                    if (!state.isPrinterReady) {
                      showPrinterErrorDialog(context, state.selectedPrinterType);
                    } else {
                      _printTestPage(context, state);
                    }
                  },
                ),
                _buildSettingCard(
                  icon: Icons.bug_report,
                  title: 'Bluetooth Diagnostic Logs',
                  subtitle: '${state.btLogs.length} events recorded — Tap to view connection history & troubleshoot',
                  onTap: () => state.navigateToView('bt-logs'),
                ),
                _buildSettingCard(
                  icon: Icons.description_outlined,
                  title: 'Invoice Code - ${state.invoiceCode}',
                  subtitle: 'Change Invoice Code for this device.',
                  onTap: () => _showInvoiceCodeDialog(state),
                ),
                _buildSettingCard(
                  icon: Icons.volume_up,
                  title: 'Play Sound - ${state.playSound ? 'On' : 'Off'}',
                  onTap: () {
                    state.togglePlaySound(!state.playSound);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Sound feedback turned ${state.playSound ? 'ON' : 'OFF'}')),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- SECURITY OTP VERIFICATION DIALOG ---

Future<bool> showOtpVerificationDialog(BuildContext context, String adminEmail) async {
  final otpCode = (100000 + math.Random().nextInt(900000)).toString();
  final otpController = TextEditingController();
  bool obscureOtp = true;
  
  debugPrint('[OTP] Generated OTP: $otpCode sent to $adminEmail');
  
  final verified = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF12161B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Row(
              children: [
                Icon(Icons.shield_outlined, color: Color(0xFFFF6F24)),
                SizedBox(width: 8),
                Text(
                  'Security Verification',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A 6-digit verification code has been sent to the Admin email:',
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    adminEmail,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFFFF6F24)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    obscureText: obscureOtp,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: 'Enter 6-Digit OTP',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureOtp ? Icons.visibility : Icons.visibility_off,
                          color: Colors.white60,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            obscureOtp = !obscureOtp;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6F24).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFF6F24).withOpacity(0.15)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 14, color: Color(0xFFFF6F24)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'For testing, use code: $otpCode',
                            style: const TextStyle(fontSize: 11, color: Color(0xFFFF6F24), fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
              ),
              ElevatedButton(
                onPressed: () {
                  final entered = otpController.text.trim();
                  if (entered == otpCode) {
                    Navigator.pop(context, true);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invalid OTP code. Please try again.')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6F24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Verify'),
              ),
            ],
          );
        },
      );
    },
  );
  return verified ?? false;
}

class AccountPlaceholderView extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  const AccountPlaceholderView({super.key, required this.scaffoldKey});

  @override
  State<AccountPlaceholderView> createState() => _AccountPlaceholderViewState();
}

class _AccountPlaceholderViewState extends State<AccountPlaceholderView> {
  final nameController = TextEditingController();
  final pinController = TextEditingController();
  final floatController = TextEditingController();
  final questionController = TextEditingController();
  final answerController = TextEditingController();
  final adminEmailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = AppStateProvider.of(context);
      nameController.text = state.cashierName;
      pinController.text = state.cashierPin;
      floatController.text = state.openingFloat.toString();
      questionController.text = state.securityQuestion;
      answerController.text = state.securityAnswer;
      adminEmailController.text = state.adminEmail;
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    pinController.dispose();
    floatController.dispose();
    questionController.dispose();
    answerController.dispose();
    adminEmailController.dispose();
    super.dispose();
  }

  void _showEditUserDialog(UserProfile user, AppState state) {
    final editNameController = TextEditingController(text: user.name);
    final editPinController = TextEditingController(text: user.pin);
    String editRole = user.role;
    bool obscurePin = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF12161B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Row(
                children: [
                  Icon(
                    user.role == 'owner' ? Icons.admin_panel_settings : Icons.person,
                    color: const Color(0xFFFF6F24),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Edit ${user.name}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: editNameController,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: editPinController,
                      obscureText: obscurePin,
                      maxLength: 4,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'PIN (4 digits)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePin ? Icons.visibility : Icons.visibility_off,
                            color: Colors.white60,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              obscurePin = !obscurePin;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: editRole,
                      dropdownColor: const Color(0xFF12161B),
                      decoration: InputDecoration(
                        labelText: 'Role',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'owner', child: Text('Owner')),
                        DropdownMenuItem(value: 'cashier', child: Text('Cashier')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            editRole = val;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = editNameController.text.trim();
                    final pin = editPinController.text.trim();
                    if (name.isNotEmpty && pin.length == 4) {
                      final verified = await showOtpVerificationDialog(context, state.adminEmail);
                      if (verified) {
                        final updatedUsers = state.users.map((u) {
                          if (u.name == user.name) {
                            return UserProfile(name: name, pin: pin, role: editRole);
                          }
                          return u;
                        }).toList();
                        
                        state.updateUsersList(updatedUsers);
                        
                        // If the owner just edited their own active profile
                        if (user.name == state.cashierName) {
                          final matchedUser = updatedUsers.firstWhere((u) => u.name == name);
                          state.loginUser(matchedUser);
                          nameController.text = name;
                          pinController.text = pin;
                        }
                        
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Updated profile for $name successfully!')),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid name and a 4-digit PIN.')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6F24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<Widget> _buildProfileSettingsForm(BuildContext context, AppState state, double sales, double expected) {
    return [
      const Center(
        child: Column(
          children: [
            Icon(Icons.account_circle, size: 54, color: Color(0xFFFF6F24)),
            SizedBox(height: 16),
            Text('Cashier Profile & Shift Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      const SizedBox(height: 24),
      
      TextField(
        controller: nameController,
        readOnly: state.cashierRole != 'owner',
        decoration: InputDecoration(
          labelText: 'Cashier Name',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          helperText: state.cashierRole != 'owner' ? 'Cashier name can only be edited by the Owner' : null,
        ),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: pinController,
        obscureText: true,
        maxLength: 4,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: 'Register PIN Lock (4 digits)',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: floatController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'Opening Cash Float (₹)',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      const SizedBox(height: 24),
      const Divider(color: Colors.white12, height: 1),
      const SizedBox(height: 16),
      const Text(
        'Security & Account Recovery',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFFFF6F24)),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: ['What was the name of your first restaurant?', 'What is your mother\'s maiden name?', 'What was the name of your first pet?', 'What is your favorite food?'].contains(questionController.text)
            ? questionController.text
            : 'What was the name of your first restaurant?',
        dropdownColor: const Color(0xFF12161B),
        decoration: InputDecoration(
          labelText: 'Security Question',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        items: const [
          DropdownMenuItem(value: 'What was the name of your first restaurant?', child: Text('First Restaurant Name', style: TextStyle(fontSize: 13.5))),
          DropdownMenuItem(value: 'What is your mother\'s maiden name?', child: Text('Mother\'s Maiden Name', style: TextStyle(fontSize: 13.5))),
          DropdownMenuItem(value: 'What was the name of your first pet?', child: Text('First Pet Name', style: TextStyle(fontSize: 13.5))),
          DropdownMenuItem(value: 'What is your favorite food?', child: Text('Favorite Food', style: TextStyle(fontSize: 13.5))),
        ],
        onChanged: (val) {
          if (val != null) {
            setState(() {
              questionController.text = val;
            });
          }
        },
      ),
      const SizedBox(height: 16),
      TextField(
        controller: answerController,
        decoration: InputDecoration(
          labelText: 'Security Answer',
          hintText: 'Answer for PIN recovery',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      if (state.cashierRole == 'owner') ...[
        const SizedBox(height: 16),
        TextField(
          controller: adminEmailController,
          decoration: InputDecoration(
            labelText: 'Admin Linked Email (OTP Destination)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: const Icon(Icons.email, color: Color(0xFFFF6F24)),
          ),
        ),
      ],
      const SizedBox(height: 24),

      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x0CFFFFFF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Shift Financial Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFFFF6F24))),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Opening Cash Float:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                Text('₹${state.openingFloat.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Cash Sales Today:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                Text('₹${sales.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
            const Divider(color: Colors.white10, height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Expected Cash in Safe:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text('₹${expected.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF00AA4F))),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),

      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final pin = pinController.text.trim();
                final float = double.tryParse(floatController.text.trim()) ?? 500.0;
                final question = questionController.text.trim();
                final answer = answerController.text.trim();
                if (name.isNotEmpty && pin.length == 4 && question.isNotEmpty && answer.isNotEmpty) {
                  final verified = await showOtpVerificationDialog(context, state.adminEmail);
                  if (verified) {
                    state.updateCashierSettings(name, pin, float);
                    state.updateSecuritySettings(question, answer);
                    if (state.cashierRole == 'owner') {
                      final newEmail = adminEmailController.text.trim();
                      if (newEmail.isNotEmpty) {
                        state.updateAdminEmail(newEmail);
                      }
                    }
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings updated successfully!')));
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter valid name, 4-digit PIN, and recovery question/answer.')));
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFF6F24),
                side: const BorderSide(color: Color(0xFFFF6F24)),
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Update Settings'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                state.toggleRegisterShiftLock(true);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('POS Register Shift Locked!')));
              },
              icon: const Icon(Icons.lock),
              label: const Text('Lock Shift'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6F24),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildOwnerManagementConsole(BuildContext context, AppState state) {
    return [
      const Center(
        child: Column(
          children: [
            Icon(Icons.supervised_user_circle, size: 54, color: Color(0xFFFF6F24)),
            SizedBox(height: 16),
            Text('Owner Control Panel', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text(
              'Manage cashier PINs, roles & permissions',
              style: TextStyle(fontSize: 12, color: Colors.white60),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      ...state.users.map((user) {
        final isCurrentUser = user.name == state.cashierName;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCurrentUser ? const Color(0xFFFF6F24).withOpacity(0.3) : Colors.white10,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: user.role == 'owner'
                    ? const Color(0xFFFF6F24).withOpacity(0.15)
                    : Colors.white10,
                child: Icon(
                  user.role == 'owner' ? Icons.admin_panel_settings : Icons.person,
                  color: user.role == 'owner' ? const Color(0xFFFF6F24) : Colors.white70,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: user.role == 'owner'
                                ? const Color(0xFFFF6F24).withOpacity(0.2)
                                : Colors.white10,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            user.role.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: user.role == 'owner'
                                  ? const Color(0xFFFF6F24)
                                  : Colors.white60,
                            ),
                          ),
                        ),
                        if (isCurrentUser) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'LOGGED IN',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.greenAccent,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'PIN: ${user.pin}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFFFF6F24),
                    ),
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () => _showEditUserDialog(user, state),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white24),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit, size: 12, color: Colors.white70),
                          SizedBox(width: 4),
                          Text('Edit', style: TextStyle(fontSize: 11, color: Colors.white70)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);
    final sales = state.todayCashSales;
    final expected = state.openingFloat + sales;
    final isOwner = state.cashierRole == 'owner';
    final double maxW = isOwner ? 960 : 480;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF12161B),
        leading: MediaQuery.of(context).size.width <= 1100
            ? IconButton(icon: const Icon(Icons.menu), onPressed: () => widget.scaffoldKey.currentState?.openDrawer())
            : null,
        title: const Text('Account Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          constraints: BoxConstraints(maxWidth: maxW),
          decoration: BoxDecoration(color: const Color(0x7F191E28), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0x0CFFFFFF))),
          child: SingleChildScrollView(
            child: isOwner && MediaQuery.of(context).size.width > 900
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _buildProfileSettingsForm(context, state, sales, expected),
                        ),
                      ),
                      const SizedBox(width: 32),
                      Container(
                        width: 1,
                        height: 520,
                        color: Colors.white12,
                      ),
                      const SizedBox(width: 32),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _buildOwnerManagementConsole(context, state),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ..._buildProfileSettingsForm(context, state, sales, expected),
                      if (isOwner) ...[
                        const SizedBox(height: 32),
                        const Divider(color: Colors.white12),
                        const SizedBox(height: 24),
                        ..._buildOwnerManagementConsole(context, state),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class AdvancePlaceholderView extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  const AdvancePlaceholderView({super.key, required this.scaffoldKey});

  @override
  State<AdvancePlaceholderView> createState() => _AdvancePlaceholderViewState();
}

class _AdvancePlaceholderViewState extends State<AdvancePlaceholderView> {
  String saasStatus = 'active';
  final expiryController = TextEditingController();
  final appIdController = TextEditingController();

  bool isDeveloperMode = false;
  int _devTapCount = 0;
  DateTime? _lastDevTapTime;

  void _promptDeveloperPassword(BuildContext context, VoidCallback onSuccess) {
    final passwordController = TextEditingController();
    String errorMsg = '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF12161B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0x0CFFFFFF)),
              ),
              title: const Row(
                children: [
                  Icon(Icons.developer_mode, color: Color(0xFFFF6F24)),
                  SizedBox(width: 8),
                  Text('Developer Authorization', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Please enter the developer password to authorize this action.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Developer Password',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.lock_outline),
                      ),
                    ),
                    if (errorMsg.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorMsg,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ]
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final entered = passwordController.text.trim();
                    if (entered == 'ahar2026') {
                      Navigator.pop(context);
                      onSuccess();
                    } else {
                      setDialogState(() {
                        errorMsg = 'Incorrect Password. Access Denied.';
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6F24),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Authorize'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = AppStateProvider.of(context);
      appIdController.text = state.appId.toString();
      final rawLicense = LocalStorageHelper.getString('saas_license_${state.appId}');
      if (rawLicense != null) {
        try {
          final data = jsonDecode(rawLicense);
          setState(() {
            saasStatus = data['status'] ?? 'active';
            expiryController.text = data['expiryDate'] ?? '';
          });
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    expiryController.dispose();
    appIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF12161B),
        leading: MediaQuery.of(context).size.width <= 1100
            ? IconButton(icon: const Icon(Icons.menu), onPressed: () => widget.scaffoldKey.currentState?.openDrawer())
            : null,
        title: const Text('Advance Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          constraints: const BoxConstraints(maxWidth: 500),
          decoration: BoxDecoration(color: const Color(0x7F191E28), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0x0CFFFFFF))),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Column(
                    children: [
                      Icon(Icons.tune, size: 54, color: Color(0xFFFF6F24)),
                      SizedBox(height: 16),
                      Text('System Command Center', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                const Text('Database Local Cache Statistics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0x0CFFFFFF))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn('Tables', '${state.tables.length}'),
                      _buildStatColumn('Menu', '${state.menu.length}'),
                      _buildStatColumn('Invoices', '${state.invoices.length}'),
                      _buildStatColumn('Categories', '${state.categories.length}'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                const Text('Cloud Storage Capacity Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x0CFFFFFF)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Cloud Invoices Limit', style: TextStyle(fontWeight: FontWeight.w600)),
                          DropdownButton<int>(
                            value: state.cloudInvoicesLimit,
                            dropdownColor: const Color(0xFF12161B),
                            items: [3, 5, 10, 50, 100, 500, 1000].map((int val) {
                              return DropdownMenuItem<int>(
                                value: val,
                                child: Text('$val Invoices'),
                              );
                            }).toList(),
                            onChanged: (newVal) {
                              if (newVal != null) {
                                state.updateCloudInvoicesLimit(newVal);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Usage: ${state.invoices.length} / ${state.cloudInvoicesLimit} Invoices',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          ),
                          Text(
                            '${state.cloudUsagePercentage.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: state.isCloudFull
                                  ? Colors.redAccent
                                  : (state.isCloudAlmostFull ? Colors.orangeAccent : const Color(0xFF00AA4F)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: state.cloudUsagePercentage / 100.0,
                          backgroundColor: Colors.white12,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            state.isCloudFull
                                ? Colors.redAccent
                                : (state.isCloudAlmostFull ? Colors.orangeAccent : const Color(0xFF00AA4F)),
                          ),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                state.clearOldSyncedInvoices();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Cleared old synced invoices to free up space!')),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFFF6F24)),
                                foregroundColor: const Color(0xFFFF6F24),
                              ),
                              child: const Text('Free Up Space', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                state.toggleMockOffline();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      state.isMockOffline
                                          ? 'Mock Offline Mode Activated'
                                          : 'Mock Offline Mode Deactivated (Real Check Active)',
                                    ),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: state.isMockOffline ? Colors.redAccent : const Color(0xFF94A3B8),
                                ),
                                foregroundColor: state.isMockOffline ? Colors.redAccent : const Color(0xFF94A3B8),
                              ),
                              child: Text(
                                state.isMockOffline ? 'Disable Mock Offline' : 'Enable Mock Offline',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                const Text('Local Database Backup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final verified = await showOtpVerificationDialog(context, state.adminEmail);
                          if (verified) {
                            final json = state.exportBackupJson();
                            Clipboard.setData(ClipboardData(text: json));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Database backup JSON copied to Clipboard!')));
                          }
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('Export JSON'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFF6F24),
                          side: const BorderSide(color: Color(0xFFFF6F24)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final verified = await showOtpVerificationDialog(context, state.adminEmail);
                          if (verified) {
                            _showImportDialog(context, state);
                          }
                        },
                        icon: const Icon(Icons.paste),
                        label: const Text('Import JSON'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFF6F24),
                          side: const BorderSide(color: Color(0xFFFF6F24)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                GestureDetector(
                  onTap: () {
                    final now = DateTime.now();
                    if (_lastDevTapTime == null || now.difference(_lastDevTapTime!) > const Duration(seconds: 2)) {
                      _devTapCount = 1;
                    } else {
                      _devTapCount++;
                    }
                    _lastDevTapTime = now;
                    if (_devTapCount >= 6) {
                      _devTapCount = 0;
                      _promptDeveloperPassword(context, () {
                        setState(() {
                          isDeveloperMode = true;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Developer Mode Activated! Override controls unlocked.')),
                        );
                      });
                    }
                  },
                  child: const Text('SaaS Tenant Configuration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0x0CFFFFFF))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Licensed Tenant ID: ${state.appId}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text('Active License Key: ${state.saasLicenseKey}', style: const TextStyle(fontFamily: 'monospace', color: Color(0xFFFF6F24), fontSize: 13)),
                      const SizedBox(height: 6),
                      Text('SaaS Status: ${saasStatus.toUpperCase()}', style: TextStyle(fontWeight: FontWeight.w600, color: saasStatus == 'active' ? Colors.greenAccent : Colors.redAccent)),
                      const SizedBox(height: 6),
                      Text('SaaS Expiry Date: ${expiryController.text.isNotEmpty ? expiryController.text : "N/A"}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      const Text('Registered Terminals/Devices:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white70)),
                      const SizedBox(height: 6),
                      if (state.saasRegisteredDevices.isEmpty)
                        const Text('No devices registered.', style: TextStyle(fontSize: 12, color: Colors.white38))
                      else
                        ...state.saasRegisteredDevices.map((devId) {
                          final isThisDevice = devId == state.getOrCreateDeviceId();
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        devId,
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 11,
                                          color: isThisDevice ? const Color(0xFFFF6F24) : Colors.white70,
                                          fontWeight: isThisDevice ? FontWeight.bold : FontWeight.normal,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (isThisDevice)
                                        const Text(
                                          '(This POS Terminal)',
                                          style: TextStyle(fontSize: 9, color: Color(0xFFFF6F24), fontWeight: FontWeight.bold),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                  onPressed: () {
                                    _promptDeveloperPassword(context, () {
                                      showDialog(
                                        context: context,
                                        builder: (confirmCtx) {
                                          return AlertDialog(
                                            backgroundColor: const Color(0xFF12161B),
                                            title: const Text('Unregister Device'),
                                            content: Text('Are you sure you want to remove device ID $devId from this license?'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(confirmCtx), child: const Text('Cancel')),
                                              ElevatedButton(
                                                onPressed: () async {
                                                  Navigator.pop(confirmCtx);
                                                  BuildContext? loadingCtx;
                                                  showDialog(
                                                    context: context,
                                                    barrierDismissible: false,
                                                    builder: (lCtx) {
                                                      loadingCtx = lCtx;
                                                      return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6F24)));
                                                    },
                                                  );
                                                  try {
                                                    await state.removeDeviceFromLicenseCloud(devId);
                                                  } catch (e) {
                                                    debugPrint('Error unregistering device: $e');
                                                  } finally {
                                                    if (loadingCtx != null && loadingCtx!.mounted) {
                                                      Navigator.pop(loadingCtx!);
                                                    }
                                                  }
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('Device unregistered successfully.')),
                                                    );
                                                  }
                                                },
                                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4444)),
                                                child: const Text('Remove'),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          _promptDeveloperPassword(context, () {
                            showDialog(
                              context: context,
                              builder: (confirmCtx) {
                                return AlertDialog(
                                  backgroundColor: const Color(0xFF12161B),
                                  title: const Text('Clear All Devices'),
                                  content: const Text('Are you sure you want to clear ALL registered devices under this license key? This will allow registering new terminals/devices.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(confirmCtx), child: const Text('Cancel')),
                                    ElevatedButton(
                                      onPressed: () async {
                                        Navigator.pop(confirmCtx);
                                        BuildContext? loadingCtx;
                                        showDialog(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (lCtx) {
                                            loadingCtx = lCtx;
                                            return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6F24)));
                                          },
                                        );
                                        try {
                                          await state.clearAllDevicesFromLicenseCloud();
                                        } catch (e) {
                                          debugPrint('Error clearing device registrations: $e');
                                        } finally {
                                          if (loadingCtx != null && loadingCtx!.mounted) {
                                            Navigator.pop(loadingCtx!);
                                          }
                                        }
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('All device registrations cleared successfully.')),
                                          );
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4444)),
                                      child: const Text('Clear All'),
                                    ),
                                  ],
                                );
                              },
                            );
                          });
                        },
                        icon: const Icon(Icons.phonelink_erase, size: 16),
                        label: const Text('Reset All Terminals/Devices', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          minimumSize: const Size.fromHeight(36),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          _promptDeveloperPassword(context, () {
                            showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  backgroundColor: const Color(0xFF12161B),
                                  title: const Text('Unlink Terminal'),
                                  content: const Text('Are you sure you want to deactivate and unlink this POS terminal? This will log you out of SaaS command synchronization.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                    ElevatedButton(
                                      onPressed: () async {
                                        Navigator.pop(context);
                                        BuildContext? loadingCtx;
                                        showDialog(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (lCtx) {
                                            loadingCtx = lCtx;
                                            return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6F24)));
                                          },
                                        );
                                        
                                        bool cloudRemoved = false;
                                        try {
                                          cloudRemoved = await state.deactivateApp();
                                        } catch (e) {
                                          debugPrint('Error unlinking POS: $e');
                                        } finally {
                                          if (loadingCtx != null && loadingCtx!.mounted) {
                                            Navigator.pop(loadingCtx!);
                                          }
                                        }
                                        
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(cloudRemoved 
                                                  ? 'POS terminal unlinked and deactivated successfully.'
                                                  : 'POS terminal deactivated locally (could not update cloud registry).'),
                                            ),
                                          );
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFFF4444),
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Unlink'),
                                    ),
                                  ],
                                );
                              },
                            );
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF4444),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(40),
                        ),
                        child: const Text('Deactivate & Unlink POS'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                if (isDeveloperMode) ...[
                  const Text('SaaS License Override', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0x0CFFFFFF))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          value: saasStatus,
                          dropdownColor: const Color(0xFF12161B),
                          decoration: const InputDecoration(labelText: 'SaaS Status'),
                          items: const [
                            DropdownMenuItem(value: 'active', child: Text('Active')),
                            DropdownMenuItem(value: 'paused', child: Text('Paused (Suspended)')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => saasStatus = val);
                          },
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: expiryController,
                          decoration: const InputDecoration(
                            labelText: 'SaaS Expiry Date (ISO 8601)',
                            hintText: 'e.g. 2026-07-10T14:02:19.000',
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            final dateStr = expiryController.text.trim();
                            if (dateStr.isNotEmpty) {
                              state.updateSaaSLicenseOverride(saasStatus, dateStr);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SaaS Licensing state updated successfully!')));
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6F24),
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(40),
                          ),
                          child: const Text('Apply SaaS Commands'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                ElevatedButton.icon(
                  onPressed: () {
                    _promptDeveloperPassword(context, () {
                      showDialog(
                        context: context,
                        builder: (confirmCtx) {
                          return AlertDialog(
                            backgroundColor: const Color(0xFF12161B),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0x0CFFFFFF))),
                            title: const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.amber),
                                SizedBox(width: 8),
                                Text('Zero Out Sales Reports', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                            content: const Text('WARNING: This will permanently delete all completed invoices and sales reports both locally and from the cloud database. Tables and menu prices will NOT be affected. Proceed?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(confirmCtx), child: const Text('Cancel', style: TextStyle(color: Colors.white70))),
                              ElevatedButton(
                                onPressed: () async {
                                  Navigator.pop(confirmCtx);
                                  BuildContext? loadingCtx;
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (lCtx) {
                                      loadingCtx = lCtx;
                                      return PopScope(
                                        canPop: false,
                                        child: AlertDialog(
                                          backgroundColor: const Color(0xFF1E293B),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          content: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              CircularProgressIndicator(color: Color(0xFFFF6F24)),
                                              SizedBox(width: 20),
                                              Expanded(
                                                child: Text(
                                                  "Clearing sales reports... please wait",
                                                  style: TextStyle(color: Colors.white, fontSize: 16),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                  bool success = false;
                                  try {
                                    await state.clearSalesReportsAndSync();
                                    success = true;
                                  } catch (e) {
                                    debugPrint('Error clearing reports: $e');
                                  } finally {
                                    if (loadingCtx != null && loadingCtx!.mounted) {
                                      Navigator.pop(loadingCtx!);
                                    }
                                  }
                                  if (success && context.mounted) {
                                    showDialog(
                                      context: context,
                                      builder: (alertCtx) => AlertDialog(
                                        backgroundColor: const Color(0xFF1E293B),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        title: const Row(
                                          children: [
                                            Icon(Icons.check_circle, color: Colors.green),
                                            SizedBox(width: 8),
                                            Text("Success", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                        content: const Text("All sales invoices and reports cleared successfully.", style: TextStyle(color: Colors.white70)),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(alertCtx),
                                            child: const Text("OK", style: TextStyle(color: Color(0xFFFF6F24), fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    );
                                  } else if (!success && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Failed to clear sales reports. Please check your connection and try again.')),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF6F24),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Clear Reports'),
                              ),
                            ],
                          );
                        },
                      );
                    });
                  },
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Zero Out Sales Reports', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9F24),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    _promptDeveloperPassword(context, () {
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            backgroundColor: const Color(0xFF12161B),
                            title: const Text('Factory Reset System'),
                            content: const Text('WARNING: This will clear all transactions, cashier pins, tables, and settings. Proceed?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                              ElevatedButton(
                                onPressed: () {
                                  state.resetSystemData();
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('System factory reset completed.')));
                                  widget.scaffoldKey.currentState?.closeDrawer();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF4444),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Reset'),
                              ),
                            ],
                          );
                        },
                      );
                    });
                  },
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('Clear Cache & Database Reset'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4444),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFFF6F24))),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
      ],
    );
  }

  void _showImportDialog(BuildContext context, AppState state) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF12161B),
          title: const Text('Import Database Backup'),
          content: TextField(
            controller: textController,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: 'Paste backup JSON string here...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final jsonStr = textController.text.trim();
                if (jsonStr.isNotEmpty) {
                  final ok = state.importBackupJson(jsonStr);
                  Navigator.pop(context);
                  if (ok) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Database backup restored successfully!')));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to restore backup. Invalid JSON format.')));
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6F24),
                foregroundColor: Colors.white,
              ),
              child: const Text('Import'),
            ),
          ],
        );
      },
    );
  }
}

// --- VIEW: SEND FEEDBACK VIEW ---

class FeedbackView extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;

  const FeedbackView({super.key, required this.scaffoldKey});

  @override
  State<FeedbackView> createState() => _FeedbackViewState();
}

class _FeedbackViewState extends State<FeedbackView> {
  final subjectController = TextEditingController();
  final messageController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF12161B),
        leading: MediaQuery.of(context).size.width <= 1100
            ? IconButton(icon: const Icon(Icons.menu), onPressed: () => widget.scaffoldKey.currentState?.openDrawer())
            : null,
        title: const Text('Send Feedback', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: const Color(0x7F191E28), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0x0CFFFFFF))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Customer Experience Feedback', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text(
                    'We would love to hear your thoughts or bugs discovered in this premium POS software.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8), height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: subjectController,
                    decoration: InputDecoration(labelText: 'Subject', hintText: 'e.g. Printer issue, Billing error', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: messageController,
                    maxLines: 4,
                    decoration: InputDecoration(labelText: 'Details', hintText: 'Explain the feedback details...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      final sub = subjectController.text.trim();
                      final msg = messageController.text.trim();
                      if (sub.isNotEmpty && msg.isNotEmpty) {
                        subjectController.clear();
                        messageController.clear();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thank you! Your feedback has been logged.')));
                      }
                    },
                    icon: const Icon(Icons.send),
                    label: const Text('Submit Feedback', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6F24), minimumSize: const Size.fromHeight(48)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CashierLockOverlay extends StatefulWidget {
  final AppState state;
  const CashierLockOverlay({super.key, required this.state});

  @override
  State<CashierLockOverlay> createState() => _CashierLockOverlayState();
}

class _CashierLockOverlayState extends State<CashierLockOverlay> {
  UserProfile? _selectedUser;
  String _enteredPin = '';
  String _errorMessage = '';
  String _currentView = 'login'; // login, forgot_options, verify_license, verify_question, reset_pin

  int _failedAttempts = 0;
  int _lockoutRemaining = 0;
  Timer? _cooldownTimer;

  final _licenseController = TextEditingController();
  final _answerController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final LocalAuthentication auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    if (widget.state.users.isNotEmpty) {
      _selectedUser = widget.state.users.firstWhere(
        (u) => u.name == widget.state.cashierName,
        orElse: () => widget.state.users.first,
      );
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _licenseController.dispose();
    _answerController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  void _onKeypadTap(String value) {
    if (_lockoutRemaining > 0) return;

    setState(() {
      _errorMessage = '';
      if (value == 'clear') {
        _enteredPin = '';
      } else if (value == 'backspace') {
        if (_enteredPin.isNotEmpty) {
          _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        }
      } else {
        if (_enteredPin.length < 4) {
          _enteredPin += value;
        }

        if (_enteredPin.length == 4) {
          _verifyPin();
        }
      }
    });
  }

  void _verifyPin() {
    if (_selectedUser == null) return;

    if (_enteredPin == _selectedUser!.pin) {
      widget.state.loginUser(_selectedUser!);
      widget.state.updateLastLoginTime(DateTime.now().toString().split('.')[0]);
      widget.state.toggleRegisterShiftLock(false);
      setState(() {
        _enteredPin = '';
        _failedAttempts = 0;
      });
    } else {
      setState(() {
        _failedAttempts++;
        _enteredPin = '';
        if (_failedAttempts >= 5) {
          _errorMessage = 'Too many failed attempts. Device locked.';
          _startLockout();
        } else {
          _errorMessage = 'Invalid PIN code. Attempt $_failedAttempts of 5.';
        }
      });
    }
  }

  void _startLockout() {
    setState(() {
      _lockoutRemaining = 30;
    });
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_lockoutRemaining > 1) {
        setState(() {
          _lockoutRemaining--;
        });
      } else {
        _cooldownTimer?.cancel();
        setState(() {
          _lockoutRemaining = 0;
          _failedAttempts = 0;
          _errorMessage = '';
        });
      }
    });
  }

  void _handleLicenseRecovery() {
    final enteredKey = _licenseController.text.trim().toUpperCase();
    final activeKey = widget.state.saasLicenseKey.trim().toUpperCase();

    if (enteredKey == activeKey && activeKey.isNotEmpty) {
      setState(() {
        _errorMessage = '';
        _currentView = 'reset_pin';
      });
    } else {
      setState(() {
        _errorMessage = 'Invalid active License Key. Recovery rejected.';
      });
    }
  }

  void _handleQuestionRecovery() {
    final enteredAns = _answerController.text.trim().toLowerCase();
    final activeAns = widget.state.securityAnswer.trim().toLowerCase();

    if (enteredAns == activeAns && activeAns.isNotEmpty) {
      setState(() {
        _errorMessage = '';
        _currentView = 'reset_pin';
      });
    } else {
      setState(() {
        _errorMessage = 'Incorrect answer. Recovery rejected.';
      });
    }
  }

  void _handlePinReset() {
    if (_selectedUser == null) return;
    final newPin = _newPinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (newPin.length != 4 || int.tryParse(newPin) == null) {
      setState(() {
        _errorMessage = 'PIN must be exactly 4 digits.';
      });
      return;
    }

    if (newPin != confirmPin) {
      setState(() {
        _errorMessage = 'PIN codes do not match.';
      });
      return;
    }

    // Save settings for selected user
    widget.state.updateCashierSettings(_selectedUser!.name, newPin, widget.state.openingFloat);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('PIN successfully reset for ${_selectedUser!.name}! Login with your new PIN.')),
    );

    setState(() {
      _currentView = 'login';
      _licenseController.clear();
      _answerController.clear();
      _newPinController.clear();
      _confirmPinController.clear();
      _errorMessage = '';
      _enteredPin = '';
    });
  }

  void _simulateBiometric() {
    if (_lockoutRemaining > 0) return;
    
    // Animate biometric success
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF12161B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 300),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.fingerprint, size: 60, color: Color(0xFFFF6F24)),
                SizedBox(height: 16),
                Text('Verifying Biometrics...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 20),
                CircularProgressIndicator(color: Color(0xFFFF6F24)),
                SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );

    Future.delayed(const Duration(milliseconds: 1200), () {
      Navigator.pop(context);
      if (_selectedUser != null) {
        widget.state.loginUser(_selectedUser!);
      }
      widget.state.updateLastLoginTime(DateTime.now().toString().split('.')[0]);
      widget.state.toggleRegisterShiftLock(false);
      setState(() {
        _enteredPin = '';
        _failedAttempts = 0;
        _errorMessage = '';
      });
    });
  }

  Future<void> _authenticateWithBiometrics() async {
    if (_lockoutRemaining > 0) return;

    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await auth.isDeviceSupported();

      if (canAuthenticate) {
        final bool didAuthenticate = await auth.authenticate(
          localizedReason: 'Scan fingerprint to unlock Ahar OS terminal',
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: true,
          ),
        );

        if (didAuthenticate) {
          if (_selectedUser != null) {
            widget.state.loginUser(_selectedUser!);
          }
          widget.state.updateLastLoginTime(DateTime.now().toString().split('.')[0]);
          widget.state.toggleRegisterShiftLock(false);
          setState(() {
            _enteredPin = '';
            _failedAttempts = 0;
            _errorMessage = '';
          });
        }
      } else {
        // Fallback to simulation/mock dialog if biometrics not available/supported (e.g. on web or emulator)
        _simulateBiometric();
      }
    } catch (e) {
      // Fallback on error
      _simulateBiometric();
    }
  }

  Widget _buildKeypadButton(String content, {bool isAction = false, IconData? icon, VoidCallback? onTap}) {
    final isDisabled = _lockoutRemaining > 0;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: InkWell(
          onTap: isDisabled ? null : (onTap ?? () => _onKeypadTap(content)),
          borderRadius: BorderRadius.circular(40),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isAction ? Colors.white.withOpacity(0.02) : Colors.white.withOpacity(0.04),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Center(
              child: icon != null
                  ? Icon(icon, color: Colors.white, size: 24)
                  : Text(
                      content,
                      style: TextStyle(
                        fontSize: isAction ? 14 : 26,
                        fontWeight: FontWeight.bold,
                        color: isAction ? const Color(0xFFFF6F24) : Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.lock_open_rounded, size: 48, color: Color(0xFFFF6F24)),
        const SizedBox(height: 12),
        const Text(
          'Register Locked',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<UserProfile>(
          value: _selectedUser,
          dropdownColor: const Color(0xFF12161B),
          decoration: InputDecoration(
            labelText: 'Select Profile',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.person_outline, color: Color(0xFFFF6F24)),
          ),
          items: widget.state.users.map((UserProfile user) {
            final icon = user.role == 'owner' ? Icons.security : Icons.account_circle;
            return DropdownMenuItem<UserProfile>(
              value: user,
              child: Row(
                children: [
                  Icon(icon, size: 18, color: const Color(0xFFFF6F24)),
                  const SizedBox(width: 10),
                  Text(user.name, style: const TextStyle(fontSize: 14)),
                ],
              ),
            );
          }).toList(),
          onChanged: (UserProfile? val) {
            if (val != null) {
              setState(() {
                _selectedUser = val;
                _enteredPin = '';
                _errorMessage = '';
              });
            }
          },
        ),
        const SizedBox(height: 24),
        // PIN dot indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            bool isEntered = index < _enteredPin.length;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 12),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isEntered ? const Color(0xFFFF6F24) : Colors.transparent,
                border: Border.all(
                  color: isEntered ? const Color(0xFFFF6F24) : Colors.white24,
                  width: 2,
                ),
                boxShadow: isEntered
                    ? [BoxShadow(color: const Color(0xFFFF6F24).withOpacity(0.4), blurRadius: 8, spreadRadius: 1)]
                    : [],
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        if (_errorMessage.isNotEmpty)
          Text(
            _errorMessage,
            style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.w600),
          ),
        if (_lockoutRemaining > 0)
          Text(
            'Cooldown: $_lockoutRemaining seconds',
            style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12, fontWeight: FontWeight.w600),
          ),
        const SizedBox(height: 24),
        // Keypad grid
        Column(
          children: [
            Row(children: [_buildKeypadButton('1'), _buildKeypadButton('2'), _buildKeypadButton('3')]),
            Row(children: [_buildKeypadButton('4'), _buildKeypadButton('5'), _buildKeypadButton('6')]),
            Row(children: [_buildKeypadButton('7'), _buildKeypadButton('8'), _buildKeypadButton('9')]),
            Row(
              children: [
                _buildKeypadButton(
                  'Forgot',
                  isAction: true,
                  onTap: () => setState(() {
                    _currentView = 'forgot_options';
                    _errorMessage = '';
                  }),
                ),
                _buildKeypadButton('0'),
                _buildKeypadButton('', icon: Icons.backspace_outlined, onTap: () => _onKeypadTap('backspace')),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: _authenticateWithBiometrics,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.fingerprint, color: Colors.white54, size: 20),
              SizedBox(width: 8),
              Text('Quick Unlock (Biometrics)', style: TextStyle(color: Colors.white54, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildForgotOptionsView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.security, size: 48, color: Color(0xFFFF6F24)),
        const SizedBox(height: 16),
        const Text(
          'Recovery Options',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Select a method to reset your terminal cashier PIN code securely.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => setState(() => _currentView = 'verify_license'),
          icon: const Icon(Icons.vpn_key_outlined, size: 18),
          label: const Text('Verify Owner License Key'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E293B),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        if (_selectedUser?.role != 'owner') ...[
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => setState(() => _currentView = 'verify_question'),
            icon: const Icon(Icons.help_outline, size: 18),
            label: const Text('Answer Security Question'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
        const SizedBox(height: 20),
        TextButton(
          onPressed: () => setState(() {
            _currentView = 'login';
            _errorMessage = '';
          }),
          child: const Text('Back to Login', style: TextStyle(color: Color(0xFFFF6F24))),
        ),
      ],
    );
  }

  Widget _buildVerifyLicenseView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.vpn_key, size: 48, color: Color(0xFFFF6F24)),
        const SizedBox(height: 16),
        const Text('Owner License Reset', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
          'Verify your active POS License Key to unlock recovery settings.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _licenseController,
          decoration: InputDecoration(
            labelText: 'SaaS License Key',
            hintText: 'e.g. LIC-ABCD-1234-WXYZ',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            prefixIcon: const Icon(Icons.key, size: 20),
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        if (_errorMessage.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(_errorMessage, style: const TextStyle(color: Colors.redAccent, fontSize: 12.5)),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() {
                  _currentView = 'forgot_options';
                  _errorMessage = '';
                }),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _handleLicenseRecovery,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6F24),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Verify'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVerifyQuestionView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.help, size: 48, color: Color(0xFFFF6F24)),
        const SizedBox(height: 16),
        const Text('Security Verification', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          widget.state.securityQuestion,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _answerController,
          decoration: InputDecoration(
            labelText: 'Security Answer',
            hintText: 'Case insensitive',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            prefixIcon: const Icon(Icons.question_answer_outlined, size: 20),
          ),
        ),
        if (_errorMessage.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(_errorMessage, style: const TextStyle(color: Colors.redAccent, fontSize: 12.5)),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() {
                  _currentView = 'forgot_options';
                  _errorMessage = '';
                }),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _handleQuestionRecovery,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6F24),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Verify'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResetPinView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.lock_reset, size: 48, color: Color(0xFFFF6F24)),
        const SizedBox(height: 16),
        const Text('Set New Login PIN', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          _selectedUser == null ? 'Set new 4-digit PIN code.' : 'Set new 4-digit PIN for ${_selectedUser!.name}.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _newPinController,
          obscureText: true,
          maxLength: 4,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'New PIN (4 digits)',
            counterText: '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            prefixIcon: const Icon(Icons.lock_outline, size: 20),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirmPinController,
          obscureText: true,
          maxLength: 4,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Confirm New PIN',
            counterText: '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            prefixIcon: const Icon(Icons.lock_outline, size: 20),
          ),
        ),
        if (_errorMessage.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(_errorMessage, style: const TextStyle(color: Colors.redAccent, fontSize: 12.5)),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() {
                  _currentView = 'login';
                  _errorMessage = '';
                }),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _handlePinReset,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6F24),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Reset PIN'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget activeWidget;
    switch (_currentView) {
      case 'forgot_options':
        activeWidget = _buildForgotOptionsView();
        break;
      case 'verify_license':
        activeWidget = _buildVerifyLicenseView();
        break;
      case 'verify_question':
        activeWidget = _buildVerifyQuestionView();
        break;
      case 'reset_pin':
        activeWidget = _buildResetPinView();
        break;
      case 'login':
      default:
        activeWidget = _buildLoginView();
        break;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A), // Slate 900
              Color(0xFF030712), // Gray 950
              Color(0xFF1E293B), // Slate 800
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                  margin: const EdgeInsets.all(24),
                  constraints: const BoxConstraints(maxWidth: 380),
                  decoration: BoxDecoration(
                    color: const Color(0x7F111827), // Transparent gray
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 40,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: KeyedSubtree(
                      key: ValueKey(_currentView),
                      child: activeWidget,
                    ),
                  ),
                ),
                // Security Badge footer info
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_user_outlined, size: 14, color: Colors.white54),
                      const SizedBox(width: 8),
                      Text(
                        widget.state.lastLoginTime.isEmpty
                            ? 'AES-256 Encrypted Session'
                            : 'Last Login: ${widget.state.lastLoginTime}',
                        style: const TextStyle(color: Colors.white54, fontSize: 11.5, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- PRINTING UTILITIES ---

void showPrinterErrorDialog(BuildContext context, String printerType) {
  final isWifi = printerType == 'wifi';
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: const Color(0xFFE2E8F0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const Icon(Icons.print, color: Color(0xFF334155), size: 26),
                const SizedBox(width: 10),
                const Text(
                  "Couldn't Connect",
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              "Hi Aahar!",
              style: TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              isWifi
                  ? "We couldn't connect to your Wi-Fi/Network Printer."
                  : "We couldn't connect to your Bluetooth Printer.",
              style: const TextStyle(
                color: Color(0xFF475569),
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              isWifi
                  ? "Please check that your printer is powered on and connected to the same network with the correct IP address."
                  : "Please make sure it is switched on before retrying.",
              style: const TextStyle(
                color: Color(0xFF475569),
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const Text(
              "Thank You!",
              style: TextStyle(
                color: Color(0xFF475569),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "OK",
              style: TextStyle(
                color: Color(0xFFFF6F24),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      );
    },
  );
}

String formatKOTText(String storeName, String tableId, List<dynamic> items) {
  final List<String> lines = [];
  lines.add("========================================");
  lines.add("             KITCHEN ORDER              ");
  lines.add("                 (KOT)                  ");
  lines.add("========================================");
  lines.add("Store: $storeName");
  lines.add("Table/Type: $tableId");
  final now = DateTime.now();
  final dateStr = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}, ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}";
  lines.add("Date: $dateStr");
  lines.add("========================================");
  lines.add("QTY   ITEMS");
  lines.add("----------------------------------------");
  for (var item in items) {
    lines.add("${item.qty.toString().padRight(5, ' ')} ${item.name}");
  }
  lines.add("========================================");
  return lines.join('\n');
}

Future<bool> executeReceiptPrint(String invoiceText, AppState state) async {
  if (kIsWeb) {
    try {
      final printWindow = js.context.callMethod('open', ['', '_blank']);
      if (printWindow != null) {
        final doc = printWindow['document'];
        doc.callMethod('write', [
          '<html><head><title>Print Bill</title><style>body{font-family:monospace;white-space:pre;padding:20px;font-size:14px;color:black;}</style></head><body>' +
          invoiceText.replaceAll('\n', '<br>') +
          '</body></html>'
        ]);
        doc.callMethod('close');
        printWindow.callMethod('focus');
        printWindow.callMethod('print');
        printWindow.callMethod('close');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Print helper error: $e');
      return false;
    }
  } else {
    if (state.selectedPrinterType == 'wifi') {
      try {
        final socket = await Socket.connect(state.printerIpAddress, 9100, timeout: const Duration(seconds: 5));
        
        // Replace Rupee symbol with Rs. for standard character set compatibility
        String printableText = invoiceText.replaceAll('₹', 'Rs.');
        
        // ESC/POS Commands:
        // Initialize printer: ESC @ (27, 64)
        socket.add([27, 64]);
        
        // Print text
        socket.write(printableText);
        
        // Print and feed paper (ESC d 4: 27, 100, 4)
        socket.add([27, 100, 4]);
        
        // Paper cut command: GS V 66 0 (29, 86, 66, 0)
        socket.add([29, 86, 66, 0]);
        
        await socket.flush();
        await socket.close();
        
        debugPrint('Real Wi-Fi Print Success');
        return true;
      } catch (e) {
        debugPrint('Real Wi-Fi Print Error: $e');
        return false;
      }
    } else {
      // Replace Rupee symbol with Rs. for standard character set compatibility
      String printableText = invoiceText.replaceAll('₹', 'Rs.');
      
      state.addBtLog('PRINT', 'Print command received. Preparing to send data to Bluetooth printer...', 'APP_SIDE');
      
      // Try printing with auto-reconnect (up to 2 attempts: 1 original + 1 retry after reconnect)
      for (int printAttempt = 1; printAttempt <= 2; printAttempt++) {
        try {
          // Check actual BT connection status
          bool isConnected = false;
          try {
            isConnected = await PrintBluetoothThermal.connectionStatus;
          } catch (_) {
            state.addBtLog('ERROR', 'Could not check BT connection status before print. BT hardware may be unresponsive.', 'APP_SIDE');
          }

          // If not connected, try auto-reconnect
          if (!isConnected) {
            state.addBtLog('PRINT', 'Printer not connected at print time (attempt $printAttempt). Triggering auto-reconnect...', 'MACHINE_SIDE');
            final reconnected = await state.ensureBluetoothConnection();
            if (!reconnected) {
              state.addBtLog('PRINT', 'Auto-reconnect failed on print attempt $printAttempt. Printer may be OFF, out of range, or battery dead.', 'MACHINE_SIDE');
              if (printAttempt < 2) {
                await Future.delayed(const Duration(milliseconds: 800));
                continue; // Try once more
              }
              state.addBtLog('PRINT', 'FAILED: Could not print. All reconnection attempts exhausted. Please check printer hardware.', 'MACHINE_SIDE');
              return false;
            }
            state.addBtLog('PRINT', 'Reconnected successfully. Resuming print...', 'APP_SIDE');
            // Give the BT stack a moment to stabilize after reconnect
            await Future.delayed(const Duration(milliseconds: 300));
          }

          // ESC/POS Commands:
          // 1. ESC @ (Initialize printer: 27, 64)
          await PrintBluetoothThermal.writeBytes([27, 64]);
          
          // 2. Print main text using writeString for robust character encoding and buffer safety
          final bool result = await PrintBluetoothThermal.writeString(
            printText: PrintTextSize(
              size: 1,
              text: printableText,
            ),
          );
          
          // 3. Print and feed paper (ESC d 4: 27, 100, 4) to roll paper out for tearing
          await PrintBluetoothThermal.writeBytes([27, 100, 4]);

          if (result) {
            // Sync state: printing succeeded, so we are definitely connected
            state.isPrinterConnected = true;
            state.addBtLog('PRINT', 'SUCCESS: Print job completed successfully on attempt $printAttempt.', 'APP_SIDE');
            return true;
          } else {
            state.addBtLog('PRINT', 'Print data was sent but printer returned failure on attempt $printAttempt. Printer may have disconnected mid-transfer or is out of paper.', 'MACHINE_SIDE');
            // writeString failed - likely a silent disconnect, retry after reconnect
            if (printAttempt < 2) {
              state.isPrinterConnected = false;
              state.addBtLog('PRINT', 'Printer returned failure, will retry after reconnect...', 'MACHINE_SIDE');
              await Future.delayed(const Duration(milliseconds: 500));
              continue;
            }
            state.addBtLog('PRINT', 'FAILED: Print could not be completed after all attempts. Check printer paper/power.', 'MACHINE_SIDE');
            return false;
          }
        } catch (e) {
          state.addBtLog('ERROR', 'Bluetooth print error on attempt $printAttempt. Printer may have disconnected abruptly during data transfer.', 'MACHINE_SIDE', error: e.toString());
          // On error, mark as disconnected and retry
          state.isPrinterConnected = false;
          state.addBtLog('PRINT', 'Marking printer as disconnected after error, will retry...', 'MACHINE_SIDE');
          if (printAttempt < 2) {
            await Future.delayed(const Duration(milliseconds: 500));
            continue;
          }
          state.addBtLog('PRINT', 'FAILED: Print aborted due to repeated errors. Check if printer turned OFF during print.', 'MACHINE_SIDE');
          return false;
        }
      }
      return false;
    }
  }
}

// --- BLUETOOTH DIAGNOSTIC LOGS VIEW ---

class BluetoothLogsView extends StatelessWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  const BluetoothLogsView({super.key, required this.scaffoldKey});

  IconData _eventIcon(String event) {
    switch (event) {
      case 'CONNECT': return Icons.bluetooth_connected;
      case 'DISCONNECT': return Icons.bluetooth_disabled;
      case 'PRINT': return Icons.print;
      case 'SCAN': return Icons.bluetooth_searching;
      case 'ERROR': return Icons.error_outline;
      case 'TOGGLE': return Icons.toggle_on;
      case 'RETRY': return Icons.refresh;
      case 'AUTO_RECONNECT': return Icons.autorenew;
      case 'SYNC': return Icons.sync;
      default: return Icons.info_outline;
    }
  }

  Color _eventColor(String event) {
    switch (event) {
      case 'CONNECT': return const Color(0xFF4ADE80);      // green
      case 'DISCONNECT': return const Color(0xFFF87171);    // red
      case 'PRINT': return const Color(0xFF60A5FA);         // blue
      case 'SCAN': return const Color(0xFFA78BFA);          // purple
      case 'ERROR': return const Color(0xFFF97316);         // orange
      case 'TOGGLE': return const Color(0xFF38BDF8);        // sky
      case 'RETRY': return const Color(0xFFFBBF24);         // yellow
      case 'AUTO_RECONNECT': return const Color(0xFFFBBF24);// yellow
      case 'SYNC': return const Color(0xFF2DD4BF);          // teal
      default: return Colors.white60;
    }
  }

  Color _diagnosisColor(String diagnosis) {
    switch (diagnosis) {
      case 'APP_SIDE': return const Color(0xFF60A5FA);      // blue
      case 'MACHINE_SIDE': return const Color(0xFFF87171);  // red
      default: return Colors.white38;
    }
  }

  String _diagnosisLabel(String diagnosis) {
    switch (diagnosis) {
      case 'APP_SIDE': return '📱 APP SIDE';
      case 'MACHINE_SIDE': return '🖨️ MACHINE SIDE';
      default: return '❓ UNKNOWN';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);
    final logs = state.btLogs;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF12161B),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => state.navigateToView('settings-device'),
        ),
        title: const Row(
          children: [
            Icon(Icons.bug_report, color: Color(0xFFFF6F24), size: 22),
            SizedBox(width: 10),
            Text('BT Diagnostic Logs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        actions: [
          if (logs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Color(0xFFF87171)),
              tooltip: 'Clear All Logs',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF12161B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Text('Clear All Logs?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    content: const Text('This will permanently delete all Bluetooth diagnostic logs.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          state.clearBtLogs();
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF87171),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Clear', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Status Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFF0D1117),
              border: Border(bottom: BorderSide(color: Color(0xFF1E293B), width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: state.isPrinterConnected ? const Color(0xFF4ADE80) : const Color(0xFFF87171),
                        boxShadow: [
                          BoxShadow(
                            color: (state.isPrinterConnected ? const Color(0xFF4ADE80) : const Color(0xFFF87171)).withValues(alpha: 0.5),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      state.isPrinterConnected ? 'CONNECTED' : 'DISCONNECTED',
                      style: TextStyle(
                        color: state.isPrinterConnected ? const Color(0xFF4ADE80) : const Color(0xFFF87171),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${logs.length} events',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  state.connectedPrinterName.isEmpty ? 'No printer selected' : '${state.connectedPrinterName} (${state.connectedPrinterMac})',
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
                const SizedBox(height: 12),
                // Legend
                const Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    _LegendChip(color: Color(0xFF60A5FA), label: '📱 APP SIDE'),
                    _LegendChip(color: Color(0xFFF87171), label: '🖨️ MACHINE SIDE'),
                  ],
                ),
                const Divider(color: Color(0xFF1E293B), height: 24),
                // Cloud Sync Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'License Key: ${state.saasLicenseKey}',
                            style: const TextStyle(color: Color(0xFFFF6F24), fontSize: 11.5, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Device ID: ${state.getOrCreateDeviceId()}',
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.cloud_upload, size: 16, color: Colors.white),
                      label: const Text('Backup Data', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Uploading local database backup to cloud...')),
                        );
                        await state.pushLocalDataToCloud();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Backup complete! Data saved to Firestore.')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Color(0xFFFF6F24), width: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Log List
          Expanded(
            child: logs.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long, size: 56, color: Color(0xFF334155)),
                        SizedBox(height: 16),
                        Text('No logs yet', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16, fontWeight: FontWeight.w500)),
                        SizedBox(height: 6),
                        Text('Bluetooth events will appear here as\nthey happen (connect, print, errors, etc.)',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.4),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      final evColor = _eventColor(log.event);
                      final diagColor = _diagnosisColor(log.diagnosis);

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111827),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: log.event == 'ERROR' ? const Color(0x33F97316) : const Color(0x0CFFFFFF),
                            width: log.event == 'ERROR' ? 1.2 : 0.8,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header row: event icon + event name + timestamp
                            Row(
                              children: [
                                Icon(_eventIcon(log.event), color: evColor, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  log.event,
                                  style: TextStyle(
                                    color: evColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${log.formattedTime}  ${log.formattedDate}',
                                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontFamily: 'monospace'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Message
                            Text(
                              log.message,
                              style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                            ),
                            const SizedBox(height: 8),
                            // Diagnosis badge + MAC
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: diagColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: diagColor.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    _diagnosisLabel(log.diagnosis),
                                    style: TextStyle(color: diagColor, fontSize: 10.5, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if (log.macAddress != null && log.macAddress!.isNotEmpty) ...[
                                  const SizedBox(width: 10),
                                  Text(
                                    log.macAddress!,
                                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 10.5, fontFamily: 'monospace'),
                                  ),
                                ],
                              ],
                            ),
                            // Error details (if present)
                            if (log.errorDetail != null && log.errorDetail!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0x1AF97316),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0x33F97316)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.code, size: 14, color: Color(0xFFF97316)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        log.errorDetail!,
                                        style: const TextStyle(
                                          color: Color(0xFFFBBF24),
                                          fontSize: 11,
                                          fontFamily: 'monospace',
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendChip({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// --- DATE RANGE HELPERS ---

String formatFilterDate(DateTime date) {
  final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return "${date.day}-${months[date.month - 1]}";
}

String formatFilterDayName(DateTime date) {
  final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return weekdays[date.weekday - 1];
}

String getThisWeekRange() {
  final now = DateTime.now();
  final monday = now.subtract(Duration(days: now.weekday - 1));
  final sunday = monday.add(const Duration(days: 6));
  return "${formatFilterDate(monday)} to ${formatFilterDate(sunday)}";
}

String getLastWeekRange() {
  final now = DateTime.now();
  final monday = now.subtract(Duration(days: now.weekday - 1 + 7));
  final sunday = monday.add(const Duration(days: 6));
  return "${formatFilterDate(monday)} to ${formatFilterDate(sunday)}";
}

String getThisMonthRange() {
  final now = DateTime.now();
  final first = DateTime(now.year, now.month, 1);
  final last = DateTime(now.year, now.month + 1, 0);
  return "${formatFilterDate(first)} to ${formatFilterDate(last)}";
}

String getLastMonthRange() {
  final now = DateTime.now();
  final prevMonthYear = now.month == 1 ? now.year - 1 : now.year;
  final prevMonth = now.month == 1 ? 12 : now.month - 1;
  final first = DateTime(prevMonthYear, prevMonth, 1);
  final last = DateTime(prevMonthYear, prevMonth + 1, 0);
  return "${formatFilterDate(first)} to ${formatFilterDate(last)}";
}

// --- VIEW: INVOICE FILTER VIEW ---

class InvoiceFilterView extends StatelessWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;

  const InvoiceFilterView({super.key, required this.scaffoldKey});

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF12161B),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => state.navigateToView('invoices'),
        ),
        title: const Text('Invoice Filter', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          TextButton(
            onPressed: () {
              state.setInvoiceFilter(null);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Filters reset successfully.')),
              );
              state.navigateToView('invoices');
            },
            child: const Text('Reset', style: TextStyle(color: Color(0xFFFF6F24), fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Filter History - Preset Filters.')),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildFilterItem(
            context: context,
            state: state,
            filterKey: 'today',
            title: 'Today',
            subtitle: 'View sales report for ${formatFilterDate(now)} @${formatFilterDayName(now)}',
            icon: Icons.timer_outlined,
          ),
          _buildFilterItem(
            context: context,
            state: state,
            filterKey: 'yesterday',
            title: 'Yesterday',
            subtitle: 'View sales report for ${formatFilterDate(now.subtract(const Duration(days: 1)))} @${formatFilterDayName(now.subtract(const Duration(days: 1)))}',
            icon: Icons.access_time,
          ),
          _buildFilterItem(
            context: context,
            state: state,
            filterKey: 'this_week',
            title: 'This Week',
            subtitle: 'View sales report for ${getThisWeekRange()}',
            icon: Icons.calendar_today_outlined,
          ),
          _buildFilterItem(
            context: context,
            state: state,
            filterKey: 'last_week',
            title: 'Last Week',
            subtitle: 'View sales report for ${getLastWeekRange()}',
            icon: Icons.calendar_month_outlined,
          ),
          _buildFilterItem(
            context: context,
            state: state,
            filterKey: 'this_month',
            title: 'This Month',
            subtitle: 'View sales report for ${getThisMonthRange()}',
            icon: Icons.calendar_view_month,
          ),
          _buildFilterItem(
            context: context,
            state: state,
            filterKey: 'last_month',
            title: 'Last Month',
            subtitle: 'View sales report for ${getLastMonthRange()}',
            icon: Icons.calendar_today,
          ),
          _buildFilterItem(
            context: context,
            state: state,
            filterKey: 'custom',
            title: 'Custom Date Range',
            subtitle: state.activeInvoiceFilter == 'custom' && state.customFilterStartDate != null && state.customFilterEndDate != null
                ? 'Selected: ${formatFilterDate(state.customFilterStartDate!)} to ${formatFilterDate(state.customFilterEndDate!)}'
                : 'View invoices from a particular date range of your choice',
            icon: Icons.date_range_outlined,
            onTap: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                initialDateRange: state.customFilterStartDate != null && state.customFilterEndDate != null
                    ? DateTimeRange(start: state.customFilterStartDate!, end: state.customFilterEndDate!)
                    : null,
                builder: (context, child) {
                  return Theme(
                    data: ThemeData.dark().copyWith(
                      colorScheme: const ColorScheme.dark().copyWith(
                        primary: const Color(0xFFFF6F24),
                        onPrimary: Colors.white,
                        surface: const Color(0xFF12161B),
                        onSurface: Colors.white,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                state.setCustomInvoiceFilter(picked.start, picked.end);
                state.navigateToView('invoices');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterItem({
    required BuildContext context,
    required AppState state,
    required String filterKey,
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    final isActive = state.activeInvoiceFilter == filterKey;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? const Color(0x14FF6F24) : const Color(0x7F191E28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? const Color(0xFFFF6F24) : const Color(0x0CFFFFFF),
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isActive ? const Color(0x1AFF6F24) : Colors.white10,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: isActive ? const Color(0xFFFF6F24) : Colors.white70, size: 24),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isActive ? const Color(0xFFFF6F24) : Colors.white,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              subtitle,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8), height: 1.3),
            ),
          ),
          trailing: const Icon(Icons.chevron_right, color: Color(0xFFFF6F24)),
          onTap: onTap ?? () {
            state.setInvoiceFilter(filterKey);
            state.navigateToView('invoices');
          },
        ),
      ),
    );
  }
}

void _showCloudFullWarningDialog(BuildContext context, AppState state) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: const Color(0xFF12161B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cloud_queue, color: Color(0xFFFF6F24), size: 28),
            SizedBox(width: 12),
            Text(
              'Cloud Storage Alert',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your cloud database storage is ${state.cloudUsagePercentage.toStringAsFixed(1)}% full.',
              style: const TextStyle(fontSize: 14.5, color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Currently using ${state.invoices.length} out of ${state.cloudInvoicesLimit} maximum allowed invoices. Please upgrade your storage capacity plan or clear old invoices to prevent sync errors.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), height: 1.4),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: state.cloudUsagePercentage / 100.0,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(
                  state.isCloudFull ? Colors.redAccent : Colors.orangeAccent,
                ),
                minHeight: 6,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Dismiss', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              state.navigateToView('settings-advance');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6F24),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Manage Storage', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      );
    },
  );
}

// --- VIEW: SECRET LEDGER / AUDIT ADJUSTMENT PANEL ---

class SecretLedgerView extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;

  const SecretLedgerView({super.key, required this.scaffoldKey});

  @override
  State<SecretLedgerView> createState() => _SecretLedgerViewState();
}

class _SecretLedgerViewState extends State<SecretLedgerView> {
  String _filter = 'daily'; // 'daily', 'yesterday', 'custom'
  DateTime _selectedDate = DateTime.now();
  DateTime _customDate = DateTime.now();
  final _targetTotalController = TextEditingController();

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _filter == 'custom' ? _customDate : DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark().copyWith(
              primary: const Color(0xFFFF6F24),
              onPrimary: Colors.white,
              surface: const Color(0xFF12161B),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _filter = 'custom';
        _customDate = picked;
        _selectedDate = picked;
      });
    }
  }

  List<InvoiceModel> _getInvoicesForDate(List<InvoiceModel> allInvoices, DateTime date) {
    final targetStart = DateTime(date.year, date.month, date.day);
    final targetEnd = targetStart.add(const Duration(days: 1)).subtract(const Duration(microseconds: 1));
    return allInvoices.where((inv) {
      final invDate = inv.parsedDateTime;
      return invDate.isAfter(targetStart.subtract(const Duration(microseconds: 1))) &&
             invDate.isBefore(targetEnd.add(const Duration(microseconds: 1)));
    }).toList();
  }

  Widget _buildFilterTab(String label, String value) {
    final isSelected = _filter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _filter = value;
            if (value == 'daily') {
              _selectedDate = DateTime.now();
            } else if (value == 'yesterday') {
              _selectedDate = DateTime.now().subtract(const Duration(days: 1));
            } else if (value == 'custom') {
              _selectedDate = _customDate;
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0x19FF6F24) : const Color(0x7F191E28),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFFFF6F24) : const Color(0x0CFFFFFF),
              width: 1.2,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFFFF6F24) : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);
    final dayInvoices = _getInvoicesForDate(state.invoices, _selectedDate);
    final dayTotal = dayInvoices.fold(0, (sum, inv) => sum + inv.total);
    final dayOriginalTotal = dayInvoices.fold(0, (sum, inv) => sum + (inv.originalTotal ?? inv.total));
    final dayDifference = dayOriginalTotal - dayTotal;
    final dateStr = "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}";

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF12161B),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => state.navigateToView('home'),
        ),
        title: const Text('Sales Optimizer Panel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter Tabs Row
            Row(
              children: [
                _buildFilterTab('Daily (Today)', 'daily'),
                const SizedBox(width: 8),
                _buildFilterTab('Yesterday', 'yesterday'),
                const SizedBox(width: 8),
                _buildFilterTab('Custom Date', 'custom'),
              ],
            ),
            const SizedBox(height: 16),

            // Date Picker Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0x7F191E28),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0x0CFFFFFF)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _filter == 'daily'
                            ? 'Today\'s Sales'
                            : _filter == 'yesterday'
                                ? 'Yesterday\'s Sales'
                                : 'Custom Date Sales',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 6),
                      Text(dateStr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                  if (_filter == 'custom')
                    ElevatedButton.icon(
                      onPressed: () => _selectDate(context),
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: const Text('Select Date'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0x19FF6F24),
                        foregroundColor: const Color(0xFFFF6F24),
                        side: const BorderSide(color: Color(0x33FF6F24)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Bulk Adjustment Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0x7F191E28),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0x0CFFFFFF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Bulk Adjustment & Auto-Scaling', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            const Text('Total Invoices', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                            const SizedBox(height: 4),
                            Text('${dayInvoices.length} Bills', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 24, color: const Color(0x1AFFFFFF)),
                      Expanded(
                        child: Column(
                          children: [
                            const Text('Original Sales', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                            const SizedBox(height: 4),
                            Text('₹$dayOriginalTotal', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70)),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 24, color: const Color(0x1AFFFFFF)),
                      Expanded(
                        child: Column(
                          children: [
                            const Text('Display Sales', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                            const SizedBox(height: 4),
                            Text('₹$dayTotal', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFFF6F24))),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 24, color: const Color(0x1AFFFFFF)),
                      Expanded(
                        child: Column(
                          children: [
                            const Text('Difference', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                            const SizedBox(height: 4),
                            Text('₹$dayDifference', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Color(0x0CFFFFFF)),
                  const SizedBox(height: 16),
                  const Text('Target Display Amount (₹)', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _targetTotalController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'e.g. 15000',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            fillColor: const Color(0x0CFFFFFF),
                            filled: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () {
                          final entered = int.tryParse(_targetTotalController.text.trim());
                          if (entered == null || entered <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a valid target amount.')),
                            );
                            return;
                          }
                          if (entered >= dayTotal) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Target total must be less than the current total to scale down.')),
                            );
                            return;
                          }
                          state.bulkAdjustInvoices(_selectedDate, entered);
                          _targetTotalController.clear();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Bulk Adjustment Complete. Target scaled to ₹$entered.'),
                              backgroundColor: const Color(0xFF00AA4F),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6F24),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Scale Sales', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Zero Out Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0x7F191E28),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0x0CFFFFFF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Factory Reset Sales Ledger', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Text(
                    'Clear all invoices and sales data to prepare a fresh APK for a client. Menu rate list prices will remain unchanged.',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (confirmCtx) {
                          return AlertDialog(
                            backgroundColor: const Color(0xFF12161B),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0x0CFFFFFF))),
                            title: const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.amber),
                                SizedBox(width: 8),
                                Text('Zero Out Sales Reports', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                            content: const Text('WARNING: This will permanently delete all completed invoices and sales reports both locally and from the cloud database. Tables and menu prices will NOT be affected. Proceed?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(confirmCtx), child: const Text('Cancel', style: TextStyle(color: Colors.white70))),
                              ElevatedButton(
                                onPressed: () async {
                                  Navigator.pop(confirmCtx);
                                  BuildContext? loadingCtx;
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (lCtx) {
                                      loadingCtx = lCtx;
                                      return PopScope(
                                        canPop: false,
                                        child: AlertDialog(
                                          backgroundColor: const Color(0xFF1E293B),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          content: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              CircularProgressIndicator(color: Color(0xFFFF6F24)),
                                              SizedBox(width: 20),
                                              Expanded(
                                                child: Text(
                                                  "Clearing sales reports... please wait",
                                                  style: TextStyle(color: Colors.white, fontSize: 16),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                  bool success = false;
                                  try {
                                    await state.clearSalesReportsAndSync();
                                    success = true;
                                  } catch (e) {
                                    debugPrint('Error clearing reports: $e');
                                  } finally {
                                    if (loadingCtx != null && loadingCtx!.mounted) {
                                      Navigator.pop(loadingCtx!);
                                    }
                                  }
                                  if (success && context.mounted) {
                                    showDialog(
                                      context: context,
                                      builder: (alertCtx) => AlertDialog(
                                        backgroundColor: const Color(0xFF1E293B),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        title: const Row(
                                          children: [
                                            Icon(Icons.check_circle, color: Colors.green),
                                            SizedBox(width: 8),
                                            Text("Success", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                        content: const Text("All sales invoices and reports cleared successfully.", style: TextStyle(color: Colors.white70)),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(alertCtx),
                                            child: const Text("OK", style: TextStyle(color: Color(0xFFFF6F24), fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    );
                                  } else if (!success && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Failed to clear sales reports. Please check your connection and try again.')),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF6F24),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Clear Reports'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    icon: const Icon(Icons.delete_sweep_outlined),
                    label: const Text('Zero Out Sales Reports', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF4444),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Invoices List Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Individual Bill Editor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('${dayInvoices.length} Invoices Available', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              ],
            ),
            const SizedBox(height: 12),

            dayInvoices.isEmpty
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: const Color(0x7F191E28),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0x0CFFFFFF)),
                    ),
                    child: const Center(
                      child: Text('No invoices found for this date.', style: TextStyle(color: Color(0xFF94A3B8))),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: dayInvoices.length,
                    itemBuilder: (context, idx) {
                      final inv = dayInvoices[idx];
                      final itemsSummary = inv.items.map((i) => "${i.name} (x${i.qty})").join(", ");

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0x7F191E28),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0x0CFFFFFF)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        inv.id,
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF6F24), fontFamily: 'monospace', fontSize: 14),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white10,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          inv.tableId,
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    itemsSummary,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(inv.dateTime, style: const TextStyle(fontSize: 10, color: Color(0xFF4B5563))),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (inv.originalTotal != null && inv.originalTotal != inv.total) ...[
                                      Text(
                                        '₹${inv.originalTotal}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.white38,
                                          decoration: TextDecoration.lineThrough,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    Text(
                                      '₹${inv.total}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Color(0xFFFF6F24),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: () => _showManualEditDialog(context, state, inv),
                                  icon: const Icon(Icons.edit, size: 14),
                                  label: const Text('Edit'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFFF6F24),
                                    side: const BorderSide(color: Color(0xFFFF6F24)),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  void _showManualEditDialog(BuildContext context, AppState state, InvoiceModel invoice) {
    showDialog(
      context: context,
      builder: (context) {
        return SecretInvoiceEditDialog(state: state, invoice: invoice);
      },
    );
  }
}

// --- WIDGET: SECRET INVOICE MANUAL EDIT DIALOG ---

class SecretInvoiceEditDialog extends StatefulWidget {
  final AppState state;
  final InvoiceModel invoice;

  const SecretInvoiceEditDialog({super.key, required this.state, required this.invoice});

  @override
  State<SecretInvoiceEditDialog> createState() => _SecretInvoiceEditDialogState();
}

class _SecretInvoiceEditDialogState extends State<SecretInvoiceEditDialog> {
  late List<CartItem> _items;
  late int _packaging;
  late double _discountPercent;
  final _scaleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _items = widget.invoice.items.map((i) => CartItem(
      id: i.id,
      name: i.name,
      price: i.price,
      category: i.category,
      qty: i.qty,
      gstRate: i.gstRate,
    )).toList();
    _packaging = widget.invoice.packaging;
    _discountPercent = widget.invoice.discountPercent;
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  int get _subtotal {
    final discountRatio = 1.0 - (_discountPercent / 100.0);
    if (widget.state.isGstInclusive) {
      return _items.fold(0, (sum, item) {
        final totalItemPrice = (item.price * item.qty * discountRatio).round();
        final gstAmount = (totalItemPrice * item.gstRate / (100 + item.gstRate)).round();
        return sum + (totalItemPrice - gstAmount);
      });
    } else {
      return _items.fold(0, (sum, item) => sum + (item.price * item.qty * discountRatio).round());
    }
  }

  int get _gst {
    final discountRatio = 1.0 - (_discountPercent / 100.0);
    if (widget.state.isGstInclusive) {
      return _items.fold(0, (sum, item) {
        final totalItemPrice = (item.price * item.qty * discountRatio).round();
        return sum + (totalItemPrice * item.gstRate / (100 + item.gstRate)).round();
      });
    } else {
      return _items.fold(0, (sum, item) => sum + (item.price * item.qty * discountRatio * (item.gstRate / 100.0)).round());
    }
  }

  int get _total => _subtotal + _gst + _packaging;

  void _smartScaleInvoice(int targetTotal) {
    if (targetTotal <= 0) return;

    final targetSubtotalGst = targetTotal - _packaging;
    if (targetSubtotalGst <= 0) return;

    final List<CartItem> origItems = widget.invoice.items;
    List<CartItem> adjusted = origItems.map((item) => CartItem(
      id: item.id,
      name: item.name,
      price: item.price,
      category: item.category,
      qty: item.qty,
      gstRate: item.gstRate,
    )).toList();

    final isInclusive = widget.state.isGstInclusive;
    final discountRatio = 1.0 - (_discountPercent / 100.0);

    int currentSubtotal = adjusted.fold(0, (sum, item) {
      if (isInclusive) {
        final totalItemPrice = (item.price * item.qty * discountRatio).round();
        final gstAmount = (totalItemPrice * item.gstRate / (100 + item.gstRate)).round();
        return sum + (totalItemPrice - gstAmount);
      } else {
        return sum + (item.price * item.qty * discountRatio).round();
      }
    });

    int currentGst = adjusted.fold(0, (sum, item) {
      if (isInclusive) {
        final totalItemPrice = (item.price * item.qty * discountRatio).round();
        return sum + (totalItemPrice * item.gstRate / (100 + item.gstRate)).round();
      } else {
        return sum + (item.price * item.qty * discountRatio * (item.gstRate / 100.0)).round();
      }
    });

    int currentTotal = currentSubtotal + currentGst;

    if (currentTotal <= 0) return;

    double ratio = targetSubtotalGst / currentTotal;

    for (var item in adjusted) {
      item.qty = (item.qty * ratio).round();
      if (item.qty < 0) item.qty = 0;
    }

    adjusted.removeWhere((item) => item.qty == 0);

    currentSubtotal = adjusted.fold(0, (sum, item) {
      if (isInclusive) {
        final totalItemPrice = (item.price * item.qty * discountRatio).round();
        final gstAmount = (totalItemPrice * item.gstRate / (100 + item.gstRate)).round();
        return sum + (totalItemPrice - gstAmount);
      } else {
        return sum + (item.price * item.qty * discountRatio).round();
      }
    });

    currentGst = adjusted.fold(0, (sum, item) {
      if (isInclusive) {
        final totalItemPrice = (item.price * item.qty * discountRatio).round();
        return sum + (totalItemPrice * item.gstRate / (100 + item.gstRate)).round();
      } else {
        return sum + (item.price * item.qty * discountRatio * (item.gstRate / 100.0)).round();
      }
    });

    currentTotal = currentSubtotal + currentGst;

    bool reduced = true;
    while (currentTotal > targetSubtotalGst && reduced) {
      reduced = false;
      CartItem? itemToReduce;
      for (var item in adjusted) {
        if (item.qty > 1) {
          itemToReduce = item;
          break;
        }
      }

      if (itemToReduce == null && adjusted.isNotEmpty) {
        itemToReduce = adjusted.first;
      }

      if (itemToReduce != null) {
        if (itemToReduce.qty > 1) {
          itemToReduce.qty--;
          reduced = true;
        } else {
          adjusted.remove(itemToReduce);
          reduced = true;
        }
        currentSubtotal = adjusted.isEmpty
            ? 0
            : adjusted.fold(0, (sum, item) {
                if (isInclusive) {
                  final totalItemPrice = (item.price * item.qty * discountRatio).round();
                  final gstAmount = (totalItemPrice * item.gstRate / (100 + item.gstRate)).round();
                  return sum + (totalItemPrice - gstAmount);
                } else {
                  return sum + (item.price * item.qty * discountRatio).round();
                }
              });
        currentGst = adjusted.isEmpty
            ? 0
            : adjusted.fold(0, (sum, item) {
                if (isInclusive) {
                  final totalItemPrice = (item.price * item.qty * discountRatio).round();
                  return sum + (totalItemPrice * item.gstRate / (100 + item.gstRate)).round();
                } else {
                  return sum + (item.price * item.qty * discountRatio * (item.gstRate / 100.0)).round();
                }
              });
        currentTotal = currentSubtotal + currentGst;
      }
    }

    if (adjusted.isNotEmpty && currentTotal != targetSubtotalGst) {
      final item = adjusted.first;
      int otherSubtotal = adjusted.skip(1).fold(0, (sum, i) {
        if (isInclusive) {
          final totalItemPrice = (i.price * i.qty * discountRatio).round();
          final gstAmount = (totalItemPrice * i.gstRate / (100 + i.gstRate)).round();
          return sum + (totalItemPrice - gstAmount);
        } else {
          return sum + (i.price * i.qty * discountRatio).round();
        }
      });
      int otherGst = adjusted.skip(1).fold(0, (sum, i) {
        if (isInclusive) {
          final totalItemPrice = (i.price * i.qty * discountRatio).round();
          return sum + (totalItemPrice * i.gstRate / (100 + i.gstRate)).round();
        } else {
          return sum + (i.price * i.qty * discountRatio * (i.gstRate / 100.0)).round();
        }
      });
      int otherTotal = otherSubtotal + otherGst;

      int targetForThisItem = targetSubtotalGst - otherTotal;
      if (targetForThisItem > 0) {
        int bestPrice = 0;
        for (int p = 0; p <= targetForThisItem; p++) {
          final discountedPrice = (p * item.qty * discountRatio).round();
          final calcTotal = isInclusive
              ? discountedPrice
              : discountedPrice + (discountedPrice * item.gstRate / 100.0).round();
          if (calcTotal <= targetForThisItem) {
            bestPrice = p;
          } else {
            break;
          }
        }
        if (bestPrice > 0) {
          adjusted[0] = CartItem(
            id: item.id,
            name: item.name,
            price: bestPrice,
            category: item.category,
            qty: item.qty,
            gstRate: item.gstRate,
          );
        }
      }
    }

    setState(() {
      _items = adjusted;
    });
  }

  void _updateItemQty(int itemId, int change) {
    setState(() {
      final index = _items.indexWhere((i) => i.id == itemId);
      if (index != -1) {
        _items[index].qty += change;
        if (_items[index].qty <= 0) {
          _items.removeAt(index);
        }
      }
    });
  }

  void _addItemToInvoice(MenuItem menuItem) {
    setState(() {
      final existingIndex = _items.indexWhere((i) => i.id == menuItem.id);
      if (existingIndex != -1) {
        _items[existingIndex].qty++;
      } else {
        _items.add(CartItem(
          id: menuItem.id,
          name: menuItem.name,
          price: menuItem.price,
          category: menuItem.category,
          qty: 1,
          gstRate: menuItem.gstRate,
        ));
      }
    });
  }

  void _showAddItemSelector() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF12161B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0x0CFFFFFF))),
          title: const Text('Add Item to Invoice', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SizedBox(
            width: 300,
            height: 400,
            child: ListView.builder(
              itemCount: widget.state.menu.length,
              itemBuilder: (context, idx) {
                final item = widget.state.menu[idx];
                return ListTile(
                  title: Text(item.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  subtitle: Text('₹${item.price}', style: const TextStyle(fontSize: 12, color: Color(0xFFFF6F24))),
                  trailing: const Icon(Icons.add_circle_outline, color: Color(0xFFFF6F24)),
                  onTap: () {
                    _addItemToInvoice(item);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF12161B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0x0CFFFFFF)),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long, color: Color(0xFFFF6F24)),
              const SizedBox(width: 10),
              Text('Edit Invoice ${widget.invoice.id}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white54, size: 20),
          )
        ],
      ),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Smart Scale Bill (₹)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _scaleController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Enter target amount (e.g. 80)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        fillColor: const Color(0x0CFFFFFF),
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final val = int.tryParse(_scaleController.text.trim());
                      if (val != null && val > 0) {
                        _smartScaleInvoice(val);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6F24),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    child: const Text('Scale', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0x14FFFFFF)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Invoice Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  TextButton.icon(
                    onPressed: _showAddItemSelector,
                    icon: const Icon(Icons.add, size: 14, color: Color(0xFFFF6F24)),
                    label: const Text('Add Dish', style: TextStyle(color: Color(0xFFFF6F24), fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              _items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('No items. Please add an item or delete the invoice.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5)),
                      ),
                    )
                  : Column(
                      children: _items.map((item) {
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withOpacity(0.04)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white)),
                                    const SizedBox(height: 2),
                                    Text('₹${item.price} each', style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove, size: 14, color: Colors.white60),
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(4),
                                    onPressed: () => _updateItemQty(item.id, -1),
                                  ),
                                  Text('${item.qty}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5)),
                                  IconButton(
                                    icon: const Icon(Icons.add, size: 14, color: Colors.white60),
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(4),
                                    onPressed: () => _updateItemQty(item.id, 1),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(4),
                                    onPressed: () => _updateItemQty(item.id, -item.qty),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
              
              const SizedBox(height: 16),
              const Divider(color: Color(0x14FFFFFF)),
              const SizedBox(height: 12),
              
              const Text('Packaging / Delivery Charge (₹)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Packaging charges...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  fillColor: const Color(0x0CFFFFFF),
                  filled: true,
                ),
                controller: TextEditingController(text: '$_packaging')..selection = TextSelection.fromPosition(TextPosition(offset: '$_packaging'.length)),
                onChanged: (val) {
                  final parsed = int.tryParse(val.trim());
                  if (parsed != null && parsed >= 0) {
                    setState(() {
                      _packaging = parsed;
                    });
                  }
                },
              ),
              
              const SizedBox(height: 16),
              const Text('Discount Percentage (%)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: 'Discount percentage...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  fillColor: const Color(0x0CFFFFFF),
                  filled: true,
                ),
                controller: TextEditingController(text: '$_discountPercent')..selection = TextSelection.fromPosition(TextPosition(offset: '$_discountPercent'.length)),
                onChanged: (val) {
                  final parsed = double.tryParse(val.trim());
                  if (parsed != null && parsed >= 0 && parsed <= 100) {
                    setState(() {
                      _discountPercent = parsed;
                    });
                  }
                },
              ),
              
              const SizedBox(height: 16),
              const Divider(color: Color(0x14FFFFFF)),
              const SizedBox(height: 12),
              
              if (_discountPercent > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Items Total', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                    Text('₹${_items.fold<int>(0, (sum, item) => sum + (item.price * item.qty))}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Discount (${_discountPercent.toStringAsFixed(0)}%)', style: const TextStyle(color: Color(0xFF10B981), fontSize: 13)),
                    Text('-₹${(_items.fold<int>(0, (sum, item) => sum + (item.price * item.qty)) * _discountPercent / 100).round()}', style: const TextStyle(color: Color(0xFF10B981), fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subtotal', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                  Text('₹$_subtotal', style: const TextStyle(color: Colors.white, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 6),
              if (widget.state.showGstOnBills && _gst > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('CGST', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                    Text('₹${(_gst / 2.0).toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('SGST', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                    Text('₹${(_gst / 2.0).toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Packaging & Delivery', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                  Text('₹$_packaging', style: const TextStyle(color: Colors.white, fontSize: 13)),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(color: Color(0x14FFFFFF)),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Grand Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                  Text('₹$_total', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFFFF6F24))),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: () {
                if (widget.state.invoices.isNotEmpty && widget.state.invoices.first.id != widget.invoice.id) {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: const Color(0xFF12161B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Color(0x0CFFFFFF)),
                      ),
                      title: const Text('Delete Blocked', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.amber)),
                      content: const Text(
                        'You can only delete the most recent bill (the last one generated) to prevent gaps in billing numbers.',
                        style: TextStyle(fontSize: 13),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('OK', style: TextStyle(color: Color(0xFFFF6F24))),
                        ),
                      ],
                    ),
                  );
                  return;
                }

                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF12161B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0x0CFFFFFF)),
                    ),
                    title: const Text('Delete Invoice', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.redAccent)),
                    content: Text('Are you sure you want to delete Invoice ${widget.invoice.id}? This will permanently delete this record and reset the sequence number count.', style: const TextStyle(fontSize: 13)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx); // pop confirmation
                          Navigator.pop(context); // pop edit dialog
                          final success = widget.state.deleteInvoice(widget.invoice.id);
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Invoice ${widget.invoice.id} deleted successfully.'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Error: Could not delete invoice.'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
              label: const Text('Delete Bill', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _items.isEmpty
                      ? null
                      : () {
                          final updatedInv = InvoiceModel(
                            id: widget.invoice.id,
                            tableId: widget.invoice.tableId,
                            dateTime: widget.invoice.dateTime,
                            items: _items,
                            subtotal: _subtotal,
                            gst: _gst,
                            packaging: _packaging,
                            total: _total,
                            originalTotal: widget.invoice.originalTotal ?? widget.invoice.total,
                            discountPercent: _discountPercent,
                          );
                          widget.state.updateInvoice(updatedInv);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Invoice ${widget.invoice.id} updated manually.'),
                              backgroundColor: const Color(0xFF00AA4F),
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6F24),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Save Changes'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
