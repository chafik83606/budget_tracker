import 'package:flutter/material.dart';

enum AppLocale { fr, en, ar }

class AppStrings {
  static AppLocale locale = AppLocale.fr;

  static void setLocale(Locale l) {
    switch (l.languageCode) {
      case 'en':
        locale = AppLocale.en;
      case 'ar':
        locale = AppLocale.ar;
      default:
        locale = AppLocale.fr;
    }
  }

  static String get home => _t('Accueil', 'Home', 'الرئيسية');
  static String get stats => _t('Statistiques', 'Statistics', 'الإحصائيات');
  static String get settings => _t('Réglages', 'Settings', 'الإعدادات');
  static String get add => _t('Ajouter', 'Add', 'إضافة');
  static String get expense => _t('Dépense', 'Expense', 'مصروف');
  static String get income => _t('Revenu', 'Income', 'دخل');
  static String get searchHint =>
      _t('Rechercher…', 'Search…', 'بحث…');
  static String get balanceMonth =>
      _t('Solde du mois', 'Monthly balance', 'رصيد الشهر');
  static String get incomes => _t('Revenus', 'Income', 'الدخل');
  static String get expenses => _t('Dépenses', 'Expenses', 'المصروفات');
  static String get undo => _t('Annuler', 'Undo', 'تراجع');
  static String get deleted =>
      _t('Transaction supprimée', 'Transaction deleted', 'تم حذف المعاملة');
  static String get duplicate =>
      _t('Dupliquer', 'Duplicate', 'نسخ');
  static String get vsLastMonth =>
      _t('vs mois dernier', 'vs last month', 'مقارنة بالشهر الماضي');
  static String get pullRefresh =>
      _t('Actualiser', 'Refresh', 'تحديث');
  static String get categoriesSummary =>
      _t('Budgets par catégorie', 'Category budgets', 'ميزانيات الفئات');
  static String get onboardingSkip => _t('Passer', 'Skip', 'تخطي');
  static String get onboardingNext => _t('Suivant', 'Next', 'التالي');
  static String get onboardingStart => _t('Commencer', 'Get started', 'ابدأ');
  static String get freeVsPro => _t('Gratuit vs Pro', 'Free vs Pro', 'مجاني مقابل برو');
  static String get pinWidget =>
      _t('Ajouter le widget', 'Pin widget', 'إضافة الودجت');
  static String get cloudSync =>
      _t('Sync cloud', 'Cloud sync', 'مزامنة سحابية');
  static String get tags => _t('Tags', 'Tags', 'وسوم');
  static String get annualReport =>
      _t('Rapport annuel PDF', 'Annual PDF report', 'تقرير سنوي PDF');

  static String _t(String fr, String en, String ar) {
    switch (locale) {
      case AppLocale.en:
        return en;
      case AppLocale.ar:
        return ar;
      case AppLocale.fr:
        return fr;
    }
  }
}
