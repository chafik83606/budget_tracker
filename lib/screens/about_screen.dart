import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../providers/budget_provider.dart';
import '../services/pro_purchase_helper.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  PackageInfo? _info;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _info = info);
    });
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible d\'ouvrir $url')),
        );
      }
    }
  }

  Future<void> _openSupportEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: AppConfig.supportEmail,
      queryParameters: {
        'subject': 'Budget Tracker — Support',
      },
    );
    if (!await launchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Contact : ${AppConfig.supportEmail}'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<BudgetProvider>();
    final version = _info?.version ?? '…';
    final build = _info?.buildNumber ?? '…';

    return Scaffold(
      appBar: AppBar(title: const Text('À propos'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          const SizedBox(height: 8),
          Icon(Icons.account_balance_wallet, size: 64, color: AppConfig.seedColor),
          const SizedBox(height: 16),
          Text(
            AppConfig.appDisplayName,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Version $version ($build)',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (provider.isPro) ...[
            const SizedBox(height: 8),
            Center(
              child: Chip(
                avatar: Icon(Icons.star, size: 18, color: Colors.amber.shade700),
                label: const Text('Édition Pro'),
                backgroundColor: Colors.amber.shade50,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'Budget Tracker vous aide à suivre vos dépenses et revenus, '
            'visualiser vos budgets par catégorie et atteindre vos objectifs '
            'd\'épargne. Vos données restent sur votre appareil.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          _InfoBlock(
            title: 'Version gratuite',
            items: const [
              'Suivi des transactions et soldes',
              'Statistiques du mois en cours',
              'Export CSV du mois courant',
              'Objectif d\'épargne et alertes budget',
            ],
          ),
          const SizedBox(height: 12),
          _InfoBlock(
            title: 'Version Pro',
            items: const [
              'Import CSV et PDF',
              'Export complet, PDF et rapport annuel',
              'Scanner de tickets (OCR)',
              'Catégories personnalisées, sans publicité',
            ],
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Liens'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Politique de confidentialité'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _openUrl(AppConfig.privacyPolicyUrl),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.mail_outline),
            title: const Text('Contacter le support'),
            subtitle: Text(AppConfig.supportEmail),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openSupportEmail,
          ),
          if (!provider.isPro)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.restore),
              title: const Text('Restaurer les achats'),
              subtitle: const Text('Récupérer Budget Tracker Pro'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => ProPurchaseHelper.restorePro(context, provider),
            ),
          const SizedBox(height: 24),
          Text(
            '© ${DateTime.now().year} ${AppConfig.publisherName}',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Données financières stockées localement sur votre appareil.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.5,
          ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
