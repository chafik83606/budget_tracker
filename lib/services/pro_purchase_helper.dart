import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../providers/budget_provider.dart';
import 'purchase_service.dart';

class ProPurchaseHelper {
  static bool _isPurchasing = false;

  /// Ouvre directement l'écran d'achat Google Play (sans dialogue intermédiaire).
  static Future<void> requestUpgrade(
    BuildContext context,
    BudgetProvider provider,
  ) async {
    await buyPro(context, provider);
  }

  static Future<void> showProRequiredDialog(
    BuildContext context,
    BudgetProvider provider, {
    String? message,
  }) async {
    await requestUpgrade(context, provider);
  }

  static Future<void> buyPro(
    BuildContext context,
    BudgetProvider provider,
  ) async {
    if (_isPurchasing) return;
    _isPurchasing = true;

    try {
      if (!await PurchaseService.instance.isAvailable()) {
        if (kDebugMode) {
          await provider.setPro(true);
          _showSnackBar(context, 'Version Pro activée en mode test.');
          return;
        }
        throw Exception('Achat in-app non disponible sur cet appareil.');
      }

      final product = await PurchaseService.instance.getProProduct();
      if (product == null) {
        if (kDebugMode) {
          await provider.setPro(true);
          _showSnackBar(context, 'Version Pro activée en mode test.');
          return;
        }
        throw Exception('Produit Pro non disponible pour le moment.');
      }

      await PurchaseService.instance.buyPro(product);
    } catch (e) {
      if (context.mounted) {
        final message = e.toString().replaceFirst('Exception: ', '');
        _showSnackBar(context, message, isError: true);
      }
    } finally {
      _isPurchasing = false;
    }
  }

  static Future<void> restorePro(
    BuildContext context,
    BudgetProvider provider,
  ) async {
    try {
      if (!await PurchaseService.instance.isAvailable()) {
        throw Exception('Achats in-app non disponibles sur cet appareil.');
      }
      await PurchaseService.instance.restorePurchases();
      if (!context.mounted) return;
      if (provider.isPro) {
        _showSnackBar(context, 'Budget Tracker Pro restauré !');
      } else {
        _showSnackBar(
          context,
          'Restauration lancée. Patientez quelques secondes.',
        );
      }
    } catch (e) {
      if (context.mounted) {
        final message = e.toString().replaceFirst('Exception: ', '');
        _showSnackBar(context, message, isError: true);
      }
    }
  }

  static void _showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }
}
