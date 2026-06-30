import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/budget_provider.dart';
import '../models/category.dart';
import '../services/export_service.dart';
import '../services/auto_backup_service.dart';
import '../services/purchase_service.dart';
import '../services/pro_purchase_helper.dart';
import '../services/lock_service.dart';
import '../services/notification_service.dart';
import '../services/widget_pin_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/preferences_service.dart';
import '../l10n/app_strings.dart';
import 'recurring_transactions_screen.dart';
import 'import_data_screen.dart';
import 'scan_receipt_screen.dart';
import 'about_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  bool _lockEnabled = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  AutoBackupStatus? _autoBackupStatus;

  @override
  void initState() {
    super.initState();
    _purchaseSubscription = InAppPurchase.instance.purchaseStream.listen(
      _onPurchaseUpdated,
      onError: (_) {},
    );
    _loadLockState();
    _loadAutoBackupStatus();
  }

  Future<void> _loadAutoBackupStatus() async {
    final status = await AutoBackupService.instance.getStatus();
    if (mounted) {
      setState(() => _autoBackupStatus = status);
    }
  }

  Future<void> _loadLockState() async {
    final enabled = await LockService.instance.isLockEnabled();
    final bio = await LockService.instance.isBiometricEnabled();
    final available = await LockService.instance.canUseBiometric();
    if (mounted) {
      setState(() {
        _lockEnabled = enabled;
        _biometricEnabled = bio;
        _biometricAvailable = available;
      });
    }
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BudgetProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Réglages'), centerTitle: true),
          body: ListView(
            children: [
              // ── STATUT PRO ───────────────────────────────────────────────
              if (!provider.isPro)
                _UpgradeProCard(
                  provider: provider,
                  onPurchase: () =>
                      ProPurchaseHelper.buyPro(context, provider),
                  onRestore: () =>
                      ProPurchaseHelper.restorePro(context, provider),
                ),

              // ── APPARENCE ────────────────────────────────────────────────
              _SectionHeader(title: 'Apparence'),
              ListTile(
                leading: const Icon(Icons.dark_mode),
                title: const Text('Thème sombre'),
                trailing: Switch(
                  value: provider.isDarkTheme,
                  onChanged: (v) => provider.setDarkTheme(v),
                ),
              ),

              // ── COMPTES ────────────────────────────────────────────────────
              _SectionHeader(title: 'Comptes'),
              ...provider.accounts.map(
                (acc) => ListTile(
                  leading: Text(acc.icon, style: const TextStyle(fontSize: 22)),
                  title: Text(acc.name),
                  trailing: provider.currentAccountId == acc.id
                      ? Icon(Icons.check_circle, color: Colors.green.shade600)
                      : null,
                  onTap: () => provider.setCurrentAccount(acc.id!),
                ),
              ),

              // ── NOTIFICATIONS ──────────────────────────────────────────────
              _SectionHeader(title: 'Notifications'),
              ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: const Text('Alertes budget (80 % / 100 %)'),
                trailing: Switch(
                  value: provider.budgetAlertsEnabled,
                  onChanged: (v) async {
                    if (v) {
                      await NotificationService.instance.requestPermission();
                    }
                    await provider.setBudgetAlertsEnabled(v);
                  },
                ),
              ),

              // ── LANGUE ─────────────────────────────────────────────────────
              _SectionHeader(title: 'Langue'),
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('Langue de l\'application'),
                subtitle: const Text('Français, English, العربية'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _pickLanguage(context),
              ),

              // ── CATÉGORIES ────────────────────────────────────────────────
              _SectionHeader(title: 'Catégories'),
              if (!provider.isPro)
                ListTile(
                  leading: const Icon(Icons.category),
                  title: const Text('Gérer les catégories'),
                  subtitle: const Text('Version Pro requise'),
                  trailing: const Icon(Icons.lock, color: Colors.amber),
                  onTap: () =>
                      ProPurchaseHelper.requestUpgrade(context, provider),
                )
              else
                ListTile(
                  leading: const Icon(Icons.category),
                  title: const Text('Gérer les catégories'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CategoriesScreen()),
                  ),
                ),

              // ── FONCTIONNALITÉS ──────────────────────────────────────────
              _SectionHeader(title: 'Fonctionnalités'),
              ListTile(
                leading: const Icon(Icons.repeat),
                title: const Text('Transactions récurrentes'),
                subtitle: const Text('Loyer, abonnements, salaire…'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RecurringTransactionsScreen(),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.document_scanner),
                title: const Text('Scanner un ticket (OCR)'),
                subtitle: provider.isPro
                    ? const Text('Photo de caisse ou reçu')
                    : const Text('Version Pro requise'),
                trailing: provider.isPro
                    ? const Icon(Icons.chevron_right)
                    : const Icon(Icons.lock, color: Colors.amber),
                onTap: provider.isPro
                    ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ScanReceiptScreen(),
                        ),
                      )
                    : () => ProPurchaseHelper.requestUpgrade(context, provider),
              ),
              ListTile(
                leading: const Icon(Icons.upload_file),
                title: const Text('Importer CSV / PDF'),
                subtitle: provider.isPro
                    ? const Text('Relevé bancaire ou export')
                    : const Text('Version Pro requise'),
                trailing: provider.isPro
                    ? const Icon(Icons.chevron_right)
                    : const Icon(Icons.lock, color: Colors.amber),
                onTap: provider.isPro
                    ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ImportDataScreen(),
                        ),
                      )
                    : () => ProPurchaseHelper.requestUpgrade(context, provider),
              ),

              // ── SÉCURITÉ ─────────────────────────────────────────────────
              _SectionHeader(title: 'Sécurité'),
              ListTile(
                leading: const Icon(Icons.lock),
                title: const Text('Verrouillage par code PIN'),
                subtitle: Text(
                  _lockEnabled ? 'Activé' : 'Protégez vos données financières',
                ),
                trailing: Switch(
                  value: _lockEnabled,
                  onChanged: (v) async {
                    if (v) {
                      await _setupPin();
                    } else {
                      await _disablePin();
                    }
                    await _loadLockState();
                  },
                ),
              ),
              if (_lockEnabled && _biometricAvailable)
                ListTile(
                  leading: const Icon(Icons.fingerprint),
                  title: const Text('Déverrouillage biométrique'),
                  trailing: Switch(
                    value: _biometricEnabled,
                    onChanged: (v) async {
                      await LockService.instance.setBiometricEnabled(v);
                      setState(() => _biometricEnabled = v);
                    },
                  ),
                ),
              if (_lockEnabled)
                ListTile(
                  leading: const Icon(Icons.pin),
                  title: const Text('Modifier le code PIN'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _setupPin,
                ),

              // ── WIDGET (Android uniquement) ────────────────────────────────
              if (Platform.isAndroid) ...[
                _SectionHeader(title: 'Widget'),
                ListTile(
                  leading: const Icon(Icons.widgets),
                  title: const Text('Widget écran d\'accueil'),
                  subtitle: const Text(
                    'Ajoutez le widget sur votre écran d\'accueil',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _pinWidget(context),
                ),
              ],

              // ── EXPORT ────────────────────────────────────────────────────
              _SectionHeader(title: 'Export'),
              ListTile(
                leading: const Icon(Icons.table_chart),
                title: const Text('Exporter CSV (mois courant)'),
                subtitle: const Text('Gratuit — mois affiché'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _exportCurrentMonthCsv(context, provider),
              ),
              ListTile(
                leading: const Icon(Icons.table_view),
                title: const Text('Exporter CSV (historique complet)'),
                subtitle: provider.isPro
                    ? null
                    : const Text('Version Pro requise'),
                trailing: provider.isPro
                    ? const Icon(Icons.chevron_right)
                    : const Icon(Icons.lock, color: Colors.amber),
                onTap: provider.isPro
                    ? () => _exportAllCsv(context, provider)
                    : () => ProPurchaseHelper.requestUpgrade(context, provider),
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: const Text('Exporter en PDF'),
                subtitle: provider.isPro
                    ? null
                    : const Text('Version Pro requise'),
                trailing: provider.isPro
                    ? const Icon(Icons.chevron_right)
                    : const Icon(Icons.lock, color: Colors.amber),
                onTap: provider.isPro
                    ? () => _exportPdf(context, provider)
                    : () => ProPurchaseHelper.requestUpgrade(context, provider),
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(AppStrings.annualReport),
                subtitle: provider.isPro
                    ? Text('Année ${DateTime.now().year}')
                    : const Text('Version Pro requise'),
                trailing: provider.isPro
                    ? const Icon(Icons.chevron_right)
                    : const Icon(Icons.lock, color: Colors.amber),
                onTap: provider.isPro
                    ? () => _exportAnnualPdf(context, provider)
                    : () => ProPurchaseHelper.requestUpgrade(context, provider),
              ),
              ListTile(
                leading: const Icon(Icons.cloud_upload_outlined),
                title: Text(AppStrings.cloudSync),
                subtitle: const Text('Export chiffré via partage (Drive, iCloud…)'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _cloudSync(context),
              ),
              _SectionHeader(title: 'Sauvegarde'),
              ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('Sauvegarde automatique'),
                subtitle: Text(_autoBackupSubtitle()),
              ),
              if (_autoBackupStatus?.hasTodayFile ?? false)
                ListTile(
                  leading: const Icon(Icons.today),
                  title: const Text('Restaurer la sauvegarde d\'aujourd\'hui'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _restoreAutoBackup(context, provider, today: true),
                ),
              if (_autoBackupStatus?.hasYesterdayFile ?? false)
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('Restaurer la sauvegarde d\'hier'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _restoreAutoBackup(context, provider, today: false),
                ),
              ListTile(
                leading: const Icon(Icons.backup),
                title: const Text('Sauvegarder les données'),
                subtitle: provider.isPro
                    ? null
                    : const Text('Version Pro requise'),
                trailing: provider.isPro
                    ? const Icon(Icons.chevron_right)
                    : const Icon(Icons.lock, color: Colors.amber),
                onTap: provider.isPro
                    ? () => _backup(context)
                    : () => ProPurchaseHelper.requestUpgrade(context, provider),
              ),
              ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('Restaurer une sauvegarde'),
                subtitle: provider.isPro
                    ? null
                    : const Text('Version Pro requise'),
                trailing: provider.isPro
                    ? const Icon(Icons.chevron_right)
                    : const Icon(Icons.lock, color: Colors.amber),
                onTap: provider.isPro
                    ? () => _restore(context, provider)
                    : () => ProPurchaseHelper.requestUpgrade(context, provider),
              ),

              // ── INFORMATIONS ───────────────────────────────────────────────
              _SectionHeader(title: 'Informations'),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('À propos'),
                subtitle: const Text(
                  'Version, confidentialité, support',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                ),
              ),

              // ── DEBUG (dev uniquement) ─────────────────────────────────────
              if (kDebugMode) ...[
                _SectionHeader(title: 'Développement'),
                ListTile(
                  leading: Icon(
                    provider.isPro ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                  title: Text(
                    provider.isPro
                        ? 'Désactiver Pro (test)'
                        : 'Activer Pro (test)',
                  ),
                  onTap: () => provider.setPro(!provider.isPro),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _setupPin() async {
    final pinCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Code PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pinCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 8,
              decoration: const InputDecoration(
                labelText: 'Nouveau PIN (4-8 chiffres)',
              ),
            ),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 8,
              decoration: const InputDecoration(labelText: 'Confirmer le PIN'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (pinCtrl.text.length < 4) return;
              if (pinCtrl.text != confirmCtrl.text) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (ok != true || pinCtrl.text.length < 4) {
      return;
    }
    if (pinCtrl.text != confirmCtrl.text) {
      if (mounted) {
        _showError(context, 'Les codes PIN ne correspondent pas');
      }
      return;
    }

    await LockService.instance.setPin(pinCtrl.text);
    await _loadLockState();
    if (mounted) {
      _showMessage('Verrouillage par PIN activé');
    }
  }

  Future<void> _disablePin() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Désactiver le verrouillage'),
        content: const Text('Supprimer le code PIN ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Désactiver'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await LockService.instance.disableLock();
      await _loadLockState();
    }
  }

  Future<void> _exportCurrentMonthCsv(
    BuildContext context,
    BudgetProvider provider,
  ) async {
    try {
      await ExportService().exportCurrentMonthCsv(
        provider.transactions,
        provider.categories,
        provider.currentYear,
        provider.currentMonth,
      );
    } catch (e) {
      if (context.mounted) _showError(context, 'Erreur lors de l\'export CSV');
    }
  }

  Future<void> _exportAllCsv(
    BuildContext context,
    BudgetProvider provider,
  ) async {
    try {
      await ExportService().exportAllCsv(provider.categories);
    } catch (e) {
      if (context.mounted) _showError(context, 'Erreur lors de l\'export CSV');
    }
  }

  Future<void> _exportPdf(BuildContext context, BudgetProvider provider) async {
    try {
      await ExportService().exportPdf(
        provider.transactions,
        provider.categories,
        provider.currentYear,
        provider.currentMonth,
      );
    } catch (e) {
      if (context.mounted) _showError(context, 'Erreur lors de l\'export PDF');
    }
  }

  Future<void> _exportAnnualPdf(
    BuildContext context,
    BudgetProvider provider,
  ) async {
    try {
      await ExportService().exportAnnualPdf(
        DateTime.now().year,
        provider.categories,
      );
    } catch (e) {
      if (context.mounted) {
        _showError(context, 'Erreur lors du rapport annuel');
      }
    }
  }

  Future<void> _cloudSync(BuildContext context) async {
    try {
      await CloudSyncService.instance.exportToCloud();
    } catch (e) {
      if (context.mounted) _showError(context, 'Erreur sync cloud');
    }
  }

  Future<void> _pinWidget(BuildContext context) async {
    final ok = await WidgetPinService.instance.requestPinWidget();
    if (!context.mounted) return;
    _showMessage(
      ok
          ? 'Suivez les instructions pour épingler le widget'
          : 'Épinglage non disponible — ajoutez le widget manuellement',
    );
  }

  Future<void> _pickLanguage(BuildContext context) async {
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Choisir la langue'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'fr'),
            child: const Text('Français'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'en'),
            child: const Text('English'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'ar'),
            child: const Text('العربية'),
          ),
        ],
      ),
    );
    if (code == null || !context.mounted) return;
    await PreferencesService().setAppLocaleCode(code);
    AppStrings.setLocale(Locale(code));
    _showMessage('Langue mise à jour — redémarrez l\'app si nécessaire');
  }

  String _autoBackupSubtitle() {
    final status = _autoBackupStatus;
    if (status == null) {
      return '1 sauvegarde par jour (aujourd\'hui + hier, max. 2 fichiers)';
    }
    if (status.lastBackupDate != null) {
      final date = DateFormat('dd/MM/yyyy').format(status.lastBackupDate!);
      return 'Dernière : $date — 2 copies max., les anciennes sont écrasées';
    }
    return '1 sauvegarde par jour (aujourd\'hui + hier, max. 2 fichiers)';
  }

  Future<void> _restoreAutoBackup(
    BuildContext context,
    BudgetProvider provider, {
    required bool today,
  }) async {
    final label = today ? 'd\'aujourd\'hui' : 'd\'hier';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Restaurer la sauvegarde $label ?'),
        content: const Text(
          'Vos données actuelles seront remplacées par celles de la sauvegarde.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restaurer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final success = today
          ? await AutoBackupService.instance.restoreToday()
          : await AutoBackupService.instance.restoreYesterday();
      if (!context.mounted) return;
      if (success) {
        await provider.initialize();
        await _loadAutoBackupStatus();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sauvegarde $label restaurée')),
          );
        }
      } else {
        _showError(context, 'Sauvegarde introuvable');
      }
    } catch (e) {
      if (context.mounted) {
        _showError(context, 'Erreur lors de la restauration');
      }
    }
  }

  Future<void> _backup(BuildContext context) async {
    try {
      await ExportService().backupData();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Sauvegarde effectuée')));
      }
    } catch (e) {
      if (context.mounted) {
        _showError(
          context,
          'Sauvegarde annulée ou impossible. Choisissez « Enregistrer dans Fichiers ».',
        );
      }
    }
  }

  Future<void> _restore(BuildContext context, BudgetProvider provider) async {
    try {
      final success = await ExportService().restoreData();
      if (context.mounted) {
        if (success) {
          await provider.initialize();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Restauration réussie')),
            );
          }
        } else {
          _showError(context, 'Aucun fichier sélectionné');
        }
      }
    } catch (e) {
      if (context.mounted) {
        _showError(context, 'Erreur lors de la restauration');
      }
    }
  }

  void _showError(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _showMessage(String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
    if (!mounted) return;
    final provider = context.read<BudgetProvider>();

    for (final purchase in purchases) {
      if (purchase.productID != PurchaseService.proProductId) continue;

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await provider.setPro(true);
        if (mounted) {
          _showMessage('Budget Tracker Pro activé !');
        }
      } else if (purchase.status == PurchaseStatus.error) {
        if (mounted) {
          _showError(
            context,
            purchase.error?.message ?? 'Erreur lors de l\'achat.',
          );
        }
      }

      if (purchase.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(purchase);
      }
    }
  }
}

// ─── WIDGET UPGRADE PRO ───────────────────────────────────────────────────────

class _UpgradeProCard extends StatelessWidget {
  final BudgetProvider provider;
  final VoidCallback onPurchase;
  final VoidCallback onRestore;
  const _UpgradeProCard({
    required this.provider,
    required this.onPurchase,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      color: Colors.amber.shade100,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.workspace_premium,
                  color: Colors.amber,
                  size: 28,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Budget Tracker Pro',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '4,99 €',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('✅ Catégories personnalisables'),
            const Text('✅ Budget par catégorie'),
            const Text('✅ Scan OCR de tickets'),
            const Text('✅ Import CSV & PDF'),
            const Text('✅ Export CSV & PDF'),
            const Text('✅ Graphiques avancés'),
            const Text('✅ Historique illimité'),
            const Text('✅ Thème sombre'),
            const Text('✅ Sauvegarde automatique quotidienne'),
            const Text('✅ Sauvegarde chiffrée (export)'),
            const Text('✅ Sans publicités'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onPurchase,
                icon: const Icon(Icons.star),
                label: const Text('Passer à la version Pro'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: onRestore,
                child: const Text('Restaurer mon achat'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── ÉCRAN GESTION CATÉGORIES (PRO) ──────────────────────────────────────────

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BudgetProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Catégories')),
          body: ListView.builder(
            itemCount: provider.categories.length,
            itemBuilder: (context, index) {
              final cat = provider.categories[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: cat.color.withValues(alpha: 0.2),
                  child: Text(cat.icon),
                ),
                title: Text(cat.name),
                subtitle: cat.monthlyBudget != null
                    ? Text(
                        'Budget : ${cat.monthlyBudget!.toStringAsFixed(2)} €',
                      )
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _editCategory(context, cat, provider),
                    ),
                    if (!cat.isDefault)
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () =>
                            _deleteCategory(context, cat, provider),
                      ),
                  ],
                ),
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _addCategory(context, provider),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  void _addCategory(BuildContext context, BudgetProvider provider) {
    _showCategoryDialog(context, provider, null);
  }

  void _editCategory(
    BuildContext context,
    Category cat,
    BudgetProvider provider,
  ) {
    _showCategoryDialog(context, provider, cat);
  }

  Future<void> _deleteCategory(
    BuildContext context,
    Category cat,
    BudgetProvider provider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la catégorie'),
        content: Text('Supprimer "${cat.name}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) await provider.deleteCategory(cat.id!);
  }

  void _showCategoryDialog(
    BuildContext context,
    BudgetProvider provider,
    Category? existing,
  ) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final budgetCtrl = TextEditingController(
      text: existing?.monthlyBudget?.toStringAsFixed(2) ?? '',
    );
    String icon = existing?.icon ?? '📦';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: Text(existing == null ? 'Nouvelle catégorie' : 'Modifier'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nom'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: budgetCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Budget mensuel (€, optionnel)',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Icône : '),
                    GestureDetector(
                      onTap: () async {
                        // Sélection simple d'icône parmi une liste prédéfinie
                        const icons = [
                          '📦',
                          '🛒',
                          '🚗',
                          '🏠',
                          '🎮',
                          '💊',
                          '✈️',
                          '🎓',
                          '💼',
                          '🎵',
                          '🍕',
                          '💪',
                        ];
                        final selected = await showDialog<String>(
                          context: ctx,
                          builder: (c) => AlertDialog(
                            title: const Text('Choisir un icône'),
                            content: Wrap(
                              children: icons
                                  .map(
                                    (i) => GestureDetector(
                                      onTap: () => Navigator.pop(c, i),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Text(
                                          i,
                                          style: const TextStyle(fontSize: 28),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        );
                        if (selected != null) setState(() => icon = selected);
                      },
                      child: Text(icon, style: const TextStyle(fontSize: 28)),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () {
                  if (nameCtrl.text.isEmpty) return;
                  final budget = double.tryParse(
                    budgetCtrl.text.replaceAll(',', '.'),
                  );
                  final cat = Category(
                    id: existing?.id,
                    name: nameCtrl.text.trim(),
                    icon: icon,
                    color:
                        existing?.color ??
                        Colors.primaries[provider.categories.length %
                            Colors.primaries.length],
                    isDefault: existing?.isDefault ?? false,
                    monthlyBudget: budget,
                  );
                  if (existing == null) {
                    provider.addCategory(cat);
                  } else {
                    provider.updateCategory(cat);
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── SECTION HEADER ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
