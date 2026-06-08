import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import '../providers/budget_provider.dart';
import '../models/category.dart';
import '../services/export_service.dart';
import '../services/purchase_service.dart';
import '../services/lock_service.dart';
import 'recurring_transactions_screen.dart';
import 'import_data_screen.dart';
import 'scan_receipt_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  bool _isPurchasing = false;
  bool _lockEnabled = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _purchaseSubscription = InAppPurchase.instance.purchaseStream.listen(
      _onPurchaseUpdated,
      onError: (_) {},
    );
    _loadLockState();
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
                  onPurchase: () => _buyPro(provider),
                ),

              // ── APPARENCE ────────────────────────────────────────────────
              _SectionHeader(title: 'Apparence'),
              ListTile(
                leading: const Icon(Icons.dark_mode),
                title: const Text('Thème sombre'),
                subtitle: provider.isPro
                    ? null
                    : const Text('Version Pro requise'),
                trailing: Switch(
                  value: provider.isDarkTheme,
                  onChanged: provider.isPro
                      ? (v) => provider.setDarkTheme(v)
                      : null,
                ),
              ),

              // ── CATÉGORIES ────────────────────────────────────────────────
              _SectionHeader(title: 'Catégories'),
              if (!provider.isPro)
                ListTile(
                  leading: const Icon(Icons.category),
                  title: const Text('Gérer les catégories'),
                  subtitle: const Text('Version Pro requise'),
                  trailing: const Icon(Icons.lock, color: Colors.amber),
                  onTap: () => _showProRequired(context, provider),
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
                    : () => _showProRequired(context, provider),
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
                    : () => _showProRequired(context, provider),
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

              // ── WIDGET ───────────────────────────────────────────────────
              _SectionHeader(title: 'Widget'),
              ListTile(
                leading: const Icon(Icons.widgets),
                title: const Text('Widget écran d\'accueil'),
                subtitle: const Text(
                  'Ajoutez le widget depuis l\'écran d\'accueil Android '
                  '(appui long → Widgets → Budget Tracker)',
                ),
              ),

              // ── EXPORT ────────────────────────────────────────────────────
              _SectionHeader(title: 'Export'),
              ListTile(
                leading: const Icon(Icons.table_chart),
                title: const Text('Exporter en CSV'),
                subtitle: provider.isPro
                    ? null
                    : const Text('Version Pro requise'),
                trailing: provider.isPro
                    ? const Icon(Icons.chevron_right)
                    : const Icon(Icons.lock, color: Colors.amber),
                onTap: provider.isPro
                    ? () => _exportCsv(context, provider)
                    : () => _showProRequired(context, provider),
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
                    : () => _showProRequired(context, provider),
              ),

              // ── SAUVEGARDE ──────────────────────────────────────────────────
              _SectionHeader(title: 'Sauvegarde'),
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
                    : () => _showProRequired(context, provider),
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
                    : () => _showProRequired(context, provider),
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

  Future<void> _exportCsv(BuildContext context, BudgetProvider provider) async {
    try {
      await ExportService().exportCsv(
        provider.transactions,
        provider.categories,
      );
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

  Future<void> _backup(BuildContext context) async {
    try {
      await ExportService().backupData();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Sauvegarde effectuée')));
      }
    } catch (e) {
      if (context.mounted) _showError(context, 'Erreur lors de la sauvegarde');
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

  void _showProRequired(BuildContext context, BudgetProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fonctionnalité Pro'),
        content: const Text(
          'Cette fonctionnalité est disponible dans la version Pro à 4,99 €.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Plus tard'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _buyPro(provider);
            },
            child: const Text('Passer à Pro'),
          ),
        ],
      ),
    );
  }

  Future<void> _buyPro(BudgetProvider provider) async {
    if (_isPurchasing) return;
    setState(() {
      _isPurchasing = true;
    });

    try {
      if (!await PurchaseService.instance.isAvailable()) {
        if (kDebugMode) {
          await provider.setPro(true);
          _showMessage('Version Pro activée en mode test.');
          return;
        }
        throw Exception('Achat in-app non disponible sur cet appareil.');
      }

      final products = await PurchaseService.instance.fetchProducts();
      if (products.isEmpty) {
        if (kDebugMode) {
          await provider.setPro(true);
          _showMessage('Version Pro activée en mode test.');
          return;
        }
        throw Exception('Produit Pro non disponible pour le moment.');
      }

      await PurchaseService.instance.buyPro(products.first);
      if (!mounted) return;
      _showMessage('Achat lancé. Veuillez suivre les instructions.');
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      _showError(context, message);
    } finally {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
        });
      }
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
  const _UpgradeProCard({required this.provider, required this.onPurchase});

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
            const Text('✅ Sauvegarde chiffrée'),
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
