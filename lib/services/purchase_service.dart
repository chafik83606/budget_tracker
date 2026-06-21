import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

class PurchaseService {
  PurchaseService._internal();
  static final PurchaseService instance = PurchaseService._internal();

  static const String proProductId = 'budget_tracker_pro';
  final Set<String> _productIds = {proProductId};

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  Future<bool> isAvailable() async {
    return InAppPurchase.instance.isAvailable();
  }

  Future<List<ProductDetails>> fetchProducts() async {
    final response = await InAppPurchase.instance.queryProductDetails(
      _productIds,
    );
    if (response.error != null) {
      throw Exception(response.error!.message);
    }
    return response.productDetails;
  }

  Future<void> buyPro(ProductDetails productDetails) async {
    final purchaseParam = PurchaseParam(productDetails: productDetails);
    await InAppPurchase.instance.buyNonConsumable(purchaseParam: purchaseParam);
  }

  void listen(void Function(PurchaseDetails purchase) onProUnlocked) {
    _subscription?.cancel();
    _subscription = InAppPurchase.instance.purchaseStream.listen((purchases) {
      for (final purchase in purchases) {
        if (purchase.productID != proProductId) continue;

        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          onProUnlocked(purchase);
        }

        if (purchase.pendingCompletePurchase) {
          InAppPurchase.instance.completePurchase(purchase);
        }
      }
    });
  }

  Future<void> restorePurchases() async {
    if (!await isAvailable()) return;
    await InAppPurchase.instance.restorePurchases();
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
