import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:budget_tracker/main.dart' as app;
import 'package:budget_tracker/services/import_service.dart';
import 'package:budget_tracker/services/preferences_service.dart';
import 'package:budget_tracker/services/database_service.dart';
import 'package:budget_tracker/models/category.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Capture Play Store screenshots', (tester) async {
    await PreferencesService().setPro(true);

    final csv = await rootBundle.loadString(
      'play_store_assets/demo_statistiques.csv',
    );
    final rows = await ImportService().parseCsvContent(csv);
    await ImportService().importRows(rows);
    await _setCategoryBudgets();

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 6));
    await binding.convertFlutterSurfaceToImage();

    await _shot(binding, '01_home');

    await tester.tap(find.text('Statistiques'));
    await tester.pumpAndSettle(const Duration(seconds: 4));
    await _shot(binding, '02_stats');

    await tester.tap(find.text('Reglages'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await _shot(binding, '04_settings');

    await tester.tap(find.text('Catégories'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await _shot(binding, '03_categories');

    await tester.pageBack();
    await tester.pumpAndSettle(const Duration(seconds: 1));
  });
}

Future<void> _shot(
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  await binding.takeScreenshot(name);
}

Future<void> _setCategoryBudgets() async {
  final db = DatabaseService();
  final cats = await db.getCategories();
  final budgets = {
    'Logement': 800.0,
    'Alimentation': 350.0,
    'Transport': 150.0,
    'Loisirs': 120.0,
  };
  for (final cat in cats) {
    final budget = budgets[cat.name];
    if (budget != null) {
      await db.updateCategory(
        Category(
          id: cat.id,
          name: cat.name,
          icon: cat.icon,
          color: cat.color,
          isDefault: cat.isDefault,
          monthlyBudget: budget,
        ),
      );
    }
  }
}
