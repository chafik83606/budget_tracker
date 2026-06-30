import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../l10n/app_strings.dart';
import '../services/preferences_service.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await PreferencesService().setOnboardingDone(true);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: Text(AppStrings.onboardingSkip),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _OnboardingPage(
                    icon: Icons.add_circle_outline,
                    color: AppConfig.seedColor,
                    title: 'Ajoutez vos dépenses',
                    body:
                        'Saisissez une dépense ou un revenu en quelques secondes. '
                        'Utilisez les modèles rapides : Courses, Essence, Restaurant.',
                  ),
                  _OnboardingPage(
                    icon: Icons.account_balance_wallet_outlined,
                    color: Colors.blue,
                    title: 'Suivez votre solde',
                    body:
                        'Visualisez votre solde mensuel, vos budgets par catégorie '
                        'et votre objectif d\'épargne en un coup d\'œil.',
                  ),
                  _FreeProPage(onStart: _finish),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                3,
                (i) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _page == i
                        ? AppConfig.seedColor
                        : Colors.grey.shade400,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: () {
                  if (_page < 2) {
                    _controller.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  } else {
                    _finish();
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppConfig.seedColor,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(
                  _page < 2
                      ? AppStrings.onboardingNext
                      : AppStrings.onboardingStart,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _OnboardingPage({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 96, color: color),
          const SizedBox(height: 32),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _FreeProPage extends StatelessWidget {
  final VoidCallback onStart;

  const _FreeProPage({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            AppStrings.freeVsPro,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          _CompareRow(free: 'Suivi dépenses / revenus', pro: true),
          _CompareRow(free: 'Graphique camembert', pro: true),
          _CompareRow(free: 'Export CSV du mois', pro: true),
          _CompareRow(free: 'Thème sombre', pro: true),
          _CompareRow(free: 'Scan OCR & import PDF', pro: false),
          _CompareRow(free: 'Export PDF & historique complet', pro: false),
          _CompareRow(free: 'Sans publicités', pro: false),
          const SizedBox(height: 16),
          Text(
            'Pro : achat unique 4,99 €',
            style: TextStyle(
              color: AppConfig.seedColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  final String free;
  final bool pro;

  const _CompareRow({required this.free, required this.pro});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            size: 18,
            color: Colors.green.shade600,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(free, style: const TextStyle(fontSize: 14))),
          if (pro)
            const Icon(Icons.check, size: 18, color: Colors.green)
          else
            Icon(Icons.star, size: 18, color: Colors.amber.shade700),
        ],
      ),
    );
  }
}
