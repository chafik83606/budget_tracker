import 'package:flutter/material.dart';
import '../models/quick_template.dart';
import '../models/transaction.dart';
import '../providers/budget_provider.dart';
import '../services/pro_purchase_helper.dart';
import '../screens/add_transaction_screen.dart';
import '../screens/scan_receipt_screen.dart';

void showAddBottomSheet(BuildContext context, BudgetProvider provider) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ajouter',
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _AddShortcut(
                    icon: Icons.remove_circle_outline,
                    label: 'Dépense',
                    color: Colors.red.shade600,
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddTransactionScreen(
                            initialType: TransactionType.expense,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AddShortcut(
                    icon: Icons.add_circle_outline,
                    label: 'Revenu',
                    color: Colors.green.shade600,
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddTransactionScreen(
                            initialType: TransactionType.income,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AddShortcut(
                    icon: Icons.document_scanner_outlined,
                    label: 'Scan',
                    color: Colors.indigo,
                    locked: !provider.isPro,
                    onTap: () {
                      Navigator.pop(ctx);
                      if (provider.isPro) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ScanReceiptScreen(),
                          ),
                        );
                      } else {
                        ProPurchaseHelper.requestUpgrade(context, provider);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Modèles rapides',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: quickTemplates.map((tpl) {
                return ActionChip(
                  avatar: Text(tpl.icon),
                  label: Text(tpl.label),
                  backgroundColor: tpl.color.withValues(alpha: 0.12),
                  onPressed: () {
                    Navigator.pop(ctx);
                    final cat = provider.getCategoryByName(tpl.categoryName);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddTransactionScreen(
                          initialType: TransactionType.expense,
                          prefilledLabel: tpl.label,
                          prefilledCategoryId: cat?.id,
                          prefilledAmount: tpl.defaultAmount,
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Saisie manuelle complète'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddTransactionScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _AddShortcut extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool locked;

  const _AddShortcut({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.topRight,
                children: [
                  Icon(icon, color: color, size: 32),
                  if (locked)
                    Icon(Icons.lock, size: 14, color: Colors.amber.shade800),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: color,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
