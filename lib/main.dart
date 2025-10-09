import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/logging.dart';
import 'package:local_auth/local_auth.dart';
import 'screens/dashboard_screen.dart';
import 'app/lifecycle_observer.dart';
import 'screens/market_screen.dart';
import 'screens/ai_strategies_screen.dart';
import 'screens/portfolio_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/order_history_screen.dart';
import 'services/market_data_service.dart';
import 'services/dio_binance_client.dart';
import 'src/core/trading_prefs.dart';
import 'services/price_rest_client.dart';
// if needed by clients
import 'l10n/strings.dart';
import 'dart:ui' as ui;
import 'ai/ai_locator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await TradingPrefs.load();
  final optIn = await prefs.getTelemetryOptIn();
  AppLogger.init(optInTelemetry: optIn);
  final obs = AppLifecycleObserver();
  WidgetsBinding.instance.addObserver(obs);
  
  // Initialize locale for L10n (EN/RO support)
  final locale = ui.PlatformDispatcher.instance.locale;
  L10n.setLocale(locale.languageCode);
  
  // 🤖 Initialize AI Pipeline (CRITICAL!)
  try {
    await AILocator.I.init();
    debugPrint('✅ AI Pipeline initialized in main()');
  } catch (e) {
    debugPrint('⚠️ AI Pipeline init failed (fallback will be used): $e');
  }
  
  runApp(const MyTradeMateApp());
}

class MyTradeMateApp extends StatefulWidget {
  const MyTradeMateApp({super.key});

  @override
  State<MyTradeMateApp> createState() => _MyTradeMateAppState();
}

class _MyTradeMateAppState extends State<MyTradeMateApp>
    with WidgetsBindingObserver {
  bool _lockCheckDone = false;
  MarketDataService? _marketData;
  DioBinanceClient? _dio;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _guardAtLaunch();
    _initServices();
  }

  Future<void> _guardAtLaunch() async {
    final sp = await SharedPreferences.getInstance();
    final requireBio = sp.getBool('security.biometric') ?? false;
    if (requireBio) {
      final auth = LocalAuthentication();
      try {
        final canCheck = await auth.canCheckBiometrics;
        if (canCheck) {
          await auth.authenticate(
            localizedReason: 'Unlock MyTradeMate',
            options: const AuthenticationOptions(biometricOnly: true),
          );
        }
      } catch (_) {
        // If biometrics are unavailable or not enrolled, continue to app
      }
    }
    if (mounted) setState(() => _lockCheckDone = true);
  }

  void _initServices() {
    // Create a single instance for the app lifecycle
    _dio = DioBinanceClient(env: TradeEnv.testnet);
    _marketData = MarketDataServiceImpl(
      env: TradeEnv.testnet,
      rest: DefaultPriceRestClient.fromClient(_dio!),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final md = _marketData;
    if (md == null) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      md.pause();
    } else if (state == AppLifecycleState.resumed) {
      md.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final md = _marketData;
    final app = MaterialApp(
      title: 'MyTradeMate',
      restorationScopeId: 'app',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
        textTheme: const TextTheme(
          titleLarge:
              TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          bodyMedium: TextStyle(color: Colors.white70),
        ),
        useMaterial3: true,
      ),
      home: _lockCheckDone
          ? const MainNavigator()
          : const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
    if (md == null) return app;
    return InheritedMarketData(service: md, child: app);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _marketData?.dispose();
    super.dispose();
  }
}

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    MarketScreen(),
    AIStrategiesScreen(),
    PortfolioScreen(),
    OrderHistoryScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Dashboard'),
          BottomNavigationBarItem(
              icon: Icon(Icons.show_chart), label: 'Market'),
          BottomNavigationBarItem(
              icon: Icon(Icons.psychology), label: 'AI Strategies'),
          BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet), label: 'Portfolio'),
          BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long), label: 'Orders'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.indigoAccent,
        unselectedItemColor: Colors.grey,
        backgroundColor: const Color(0xFF1A1A1A),
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
