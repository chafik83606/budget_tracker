import 'package:flutter/material.dart';
import '../services/lock_service.dart';

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _pinController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initBiometric();
  }

  Future<void> _initBiometric() async {
    final available = await LockService.instance.canUseBiometric();
    final enabled = await LockService.instance.isBiometricEnabled();
    if (mounted) {
      setState(() {
        _biometricAvailable = available;
        _biometricEnabled = enabled;
      });
      if (available && enabled) {
        _tryBiometric();
      }
    }
  }

  Future<void> _tryBiometric() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final ok = await LockService.instance.authenticateWithBiometric();
    if (!mounted) return;
    if (ok) {
      LockService.instance.markUnlocked();
      widget.onUnlocked();
    } else {
      setState(() {
        _loading = false;
        _error = 'Authentification biométrique échouée';
      });
    }
  }

  Future<void> _submitPin() async {
    final pin = _pinController.text;
    if (pin.length < 4) {
      setState(() => _error = 'Le code PIN doit contenir au moins 4 chiffres');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final ok = await LockService.instance.verifyPin(pin);
    if (!mounted) return;

    if (ok) {
      LockService.instance.markUnlocked();
      widget.onUnlocked();
    } else {
      setState(() {
        _loading = false;
        _error = 'Code PIN incorrect';
        _pinController.clear();
      });
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              const Text(
                'Budget Tracker',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Entrez votre code PIN',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _pinController,
                obscureText: _obscure,
                keyboardType: TextInputType.number,
                maxLength: 8,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 8),
                decoration: InputDecoration(
                  counterText: '',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                onSubmitted: (_) => _submitPin(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _submitPin,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Déverrouiller'),
                ),
              ),
              if (_biometricAvailable && _biometricEnabled) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _tryBiometric,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Empreinte / Face ID'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
