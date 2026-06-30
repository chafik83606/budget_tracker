import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/category.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return false;
  }

  Future<void> checkBudgetAlerts({
    required List<Category> categories,
    required Map<int, double> expensesByCategory,
    required int year,
    required int month,
  }) async {
    if (!_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final monthKey = '$year-${month.toString().padLeft(2, '0')}';

    for (final cat in categories) {
      if (cat.id == null || cat.monthlyBudget == null) continue;
      final budget = cat.monthlyBudget!;
      if (budget <= 0) continue;
      final spent = expensesByCategory[cat.id!] ?? 0;
      final ratio = spent / budget;

      for (final threshold in [0.8, 1.0]) {
        if (ratio < threshold) continue;
        final alertKey = 'budget_alert_${cat.id}_${monthKey}_$threshold';
        if (prefs.getBool(alertKey) == true) continue;
        await prefs.setBool(alertKey, true);

        final pct = (threshold * 100).round();
        final title = threshold >= 1.0
            ? 'Budget dépassé — ${cat.name}'
            : 'Budget à $pct % — ${cat.name}';
        final body = threshold >= 1.0
            ? 'Vous avez dépassé le budget de ${cat.name} (${spent.toStringAsFixed(0)} € / ${budget.toStringAsFixed(0)} €).'
            : 'Attention : ${spent.toStringAsFixed(0)} € sur ${budget.toStringAsFixed(0)} € pour ${cat.name}.';

        await _plugin.show(
          cat.id! * 10 + (threshold == 1.0 ? 1 : 0),
          title,
          body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'budget_alerts',
              'Alertes budget',
              channelDescription: 'Notifications quand un budget est proche ou dépassé',
              importance: Importance.defaultImportance,
            ),
            iOS: DarwinNotificationDetails(),
          ),
        );
      }
    }
  }
}
