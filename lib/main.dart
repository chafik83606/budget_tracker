import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:io' show Platform;
import 'package:home_widget/home_widget.dart';
import 'providers/budget_provider.dart';
import 'screens/home_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/add_transaction_screen.dart';
import 'screens/lock_screen.dart';
import 'services/ad_service.dart';
import 'services/lock_service.dart';
import 'services/widget_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AdService.instance.initialize();
  await WidgetService.instance.initialize();
  await initializeDateFormatting('fr_FR', null);
  runApp(
    ChangeNotifierProvider(
      create: (_) => BudgetProvider()..initialize(),
      child: const BudgetTrackerApp(),
    ),
  );
}

class BudgetTrackerApp extends StatelessWidget {
  const BudgetTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BudgetProvider>(
      builder: (context, provider, _) {
        return MaterialApp(
          title: 'Budget Tracker',
          debugShowCheckedModeBanner: false,
          themeMode: (provider.isPro && provider.isDarkTheme)
              ? ThemeMode.dark
              : ThemeMode.light,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.indigo,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.indigo,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          home: const AppShell(),
        );
      },
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  bool _locked = false;
  bool _checkingLock = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLock();
    if (Platform.isAndroid) {
      _checkWidgetLaunch();
      HomeWidget.widgetClicked.listen((uri) {
        if (uri?.host == 'add' && mounted) {
          _openAddFromWidget();
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      LockService.instance.markLocked();
    } else if (state == AppLifecycleState.resumed) {
      _checkLock();
    }
  }

  Future<void> _checkLock() async {
    final shouldLock = await LockService.instance.shouldShowLock();
    if (mounted) {
      setState(() {
        _locked = shouldLock;
        _checkingLock = false;
      });
    }
  }

  Future<void> _checkWidgetLaunch() async {
    final action = await HomeWidget.getWidgetData<String>('launch_action');
    if (action == 'add') {
      await HomeWidget.saveWidgetData<String>('launch_action', '');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openAddFromWidget();
      });
    }
  }

  void _openAddFromWidget() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
    );
  }

  void _onUnlocked() {
    setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingLock) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_locked) {
      return LockScreen(onUnlocked: _onUnlocked);
    }

    return const MainNavigation();
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    StatsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Statistiques',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Reglages',
          ),
        ],
      ),
    );
  }
}
