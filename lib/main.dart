import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:io' show Platform;
import 'package:home_widget/home_widget.dart';
import 'config/app_config.dart';
import 'l10n/app_strings.dart';
import 'providers/budget_provider.dart';
import 'screens/home_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/add_transaction_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/ad_service.dart';
import 'services/lock_service.dart';
import 'services/notification_service.dart';
import 'services/purchase_service.dart';
import 'services/preferences_service.dart';
import 'services/widget_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AdService.instance.initialize();
  await WidgetService.instance.initialize();
  await NotificationService.instance.initialize();
  await initializeDateFormatting('fr_FR', null);
  await initializeDateFormatting('en_US', null);
  await initializeDateFormatting('ar', null);

  final localeCode = await PreferencesService().getAppLocaleCode();
  AppStrings.setLocale(Locale(localeCode));

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
          locale: Locale(AppStrings.locale.name),
          supportedLocales: const [
            Locale('fr', 'FR'),
            Locale('en', 'US'),
            Locale('ar'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          debugShowCheckedModeBanner: false,
          themeMode: provider.isDarkTheme ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppConfig.seedColor,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppConfig.seedColor,
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
  bool _showOnboarding = false;
  bool _onboardingChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLock();
    _checkOnboarding();
    _initPurchases();
    if (Platform.isAndroid) {
      _checkWidgetLaunch();
      HomeWidget.widgetClicked.listen((uri) {
        if (uri?.host == 'add' && mounted) {
          _openAddFromWidget();
        }
      });
    }
  }

  Future<void> _checkOnboarding() async {
    final done = await PreferencesService().isOnboardingDone();
    if (mounted) {
      setState(() {
        _showOnboarding = !done;
        _onboardingChecked = true;
      });
    }
  }

  @override
  void dispose() {
    PurchaseService.instance.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initPurchases() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<BudgetProvider>();
      while (provider.isLoading && mounted) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      if (!mounted) return;

      PurchaseService.instance.listen((_) async {
        await provider.setPro(true);
      });

      if (!provider.isPro) {
        await PurchaseService.instance.restorePurchases();
        await PurchaseService.instance.warmUpProducts();
      }
    });
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
    if (!_onboardingChecked || _checkingLock) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_showOnboarding) {
      return OnboardingScreen(
        onComplete: () => setState(() => _showOnboarding = false),
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
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: AppStrings.home,
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart),
            label: AppStrings.stats,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: AppStrings.settings,
          ),
        ],
      ),
    );
  }
}
