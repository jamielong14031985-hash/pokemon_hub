import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'pro_status_service.dart';

enum ProPurchaseState {
  idle,
  loading,
  storeUnavailable,
  productNotFound,
  ready,
  purchasing,
  restoring,
  purchased,
  error,
}

class ProPurchaseService {
  ProPurchaseService._();

  static final ProPurchaseService instance = ProPurchaseService._();

  static const String proProductId = 'pocketchase_pro';

  final InAppPurchase _iap = InAppPurchase.instance;

  final ValueNotifier<ProPurchaseState> stateNotifier =
      ValueNotifier<ProPurchaseState>(ProPurchaseState.idle);
  final ValueNotifier<ProductDetails?> productNotifier =
      ValueNotifier<ProductDetails?>(null);
  final ValueNotifier<String?> messageNotifier = ValueNotifier<String?>(null);

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    _purchaseSub = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object error) {
        messageNotifier.value = 'Purchase update failed: $error';
        stateNotifier.value = ProPurchaseState.error;
      },
    );

    await loadProduct();
  }

  Future<void> dispose() async {
    await _purchaseSub?.cancel();
    _purchaseSub = null;
    _started = false;
  }

  Future<void> loadProduct() async {
    stateNotifier.value = ProPurchaseState.loading;
    messageNotifier.value = null;

    try {
      final available = await _iap.isAvailable();
      if (!available) {
        stateNotifier.value = ProPurchaseState.storeUnavailable;
        messageNotifier.value = 'The store is not available right now.';
        return;
      }

      final response = await _iap.queryProductDetails(
        <String>{proProductId},
      );

      if (response.error != null) {
        stateNotifier.value = ProPurchaseState.error;
        messageNotifier.value = response.error!.message;
        return;
      }

      if (response.productDetails.isEmpty) {
        stateNotifier.value = ProPurchaseState.productNotFound;
        messageNotifier.value =
            'PocketChase Pro is not available yet. Create the product in Google Play Console with ID $proProductId.';
        return;
      }

      productNotifier.value = response.productDetails.first;
      stateNotifier.value = ProStatusService.isProActive
          ? ProPurchaseState.purchased
          : ProPurchaseState.ready;
    } catch (error) {
      stateNotifier.value = ProPurchaseState.error;
      messageNotifier.value = 'Could not load PocketChase Pro: $error';
    }
  }

  Future<void> buyPro() async {
    final product = productNotifier.value;
    if (product == null) {
      await loadProduct();
      return;
    }

    stateNotifier.value = ProPurchaseState.purchasing;
    messageNotifier.value = null;

    try {
      final purchaseParam = PurchaseParam(productDetails: product);
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (error) {
      stateNotifier.value = ProPurchaseState.error;
      messageNotifier.value = 'Could not start purchase: $error';
    }
  }

  Future<void> restorePurchases() async {
    stateNotifier.value = ProPurchaseState.restoring;
    messageNotifier.value = null;

    try {
      await _iap.restorePurchases();
    } catch (error) {
      stateNotifier.value = ProPurchaseState.error;
      messageNotifier.value = 'Could not restore purchases: $error';
    }
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchases,
  ) async {
    for (final purchase in purchases) {
      if (purchase.productID != proProductId) {
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
        continue;
      }

      switch (purchase.status) {
        case PurchaseStatus.pending:
          stateNotifier.value = ProPurchaseState.purchasing;
          messageNotifier.value = 'Purchase pending...';
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await ProStatusService.setProActiveFromVerifiedPurchase(true);
          stateNotifier.value = ProPurchaseState.purchased;
          messageNotifier.value = 'PocketChase Pro is active. Ads are removed.';
          break;
        case PurchaseStatus.error:
          stateNotifier.value = ProPurchaseState.error;
          messageNotifier.value =
              purchase.error?.message ?? 'The purchase could not be completed.';
          break;
        case PurchaseStatus.canceled:
          stateNotifier.value = ProStatusService.isProActive
              ? ProPurchaseState.purchased
              : ProPurchaseState.ready;
          messageNotifier.value = 'Purchase cancelled.';
          break;
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }
}
