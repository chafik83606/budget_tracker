import 'package:in_app_purchase/in_app_purchase.dart';

class PurchaseService {
  PurchaseService._internal();
  static final PurchaseService instance = PurchaseService._internal();

  static const String proProductId = 'budget_tracker_pro';
  final Set<String> _productIds = {proProductId};

  Future<bool> isAvailable() async {
    return await InAppPurchase.instance.isAvailable();
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
}
