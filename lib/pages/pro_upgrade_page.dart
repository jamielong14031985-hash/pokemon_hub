import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../services/pro_purchase_service.dart';
import '../services/pro_status_service.dart';

class ProUpgradePage extends StatefulWidget {
  const ProUpgradePage({super.key});

  @override
  State<ProUpgradePage> createState() => _ProUpgradePageState();
}

class _ProUpgradePageState extends State<ProUpgradePage> {
  final ProPurchaseService _purchaseService = ProPurchaseService.instance;

  @override
  void initState() {
    super.initState();
    _purchaseService.start();
  }

  bool _busy(ProPurchaseState state) {
    return state == ProPurchaseState.loading ||
        state == ProPurchaseState.purchasing ||
        state == ProPurchaseState.restoring;
  }

  String _buttonLabel({
    required ProPurchaseState state,
    required ProductDetails? product,
  }) {
    if (ProStatusService.isProActive || state == ProPurchaseState.purchased) {
      return 'PocketChase Pro Active';
    }

    if (state == ProPurchaseState.loading) return 'Loading Pro...';
    if (state == ProPurchaseState.purchasing) return 'Purchasing...';
    if (state == ProPurchaseState.restoring) return 'Restoring...';

    final price = product?.price.trim() ?? '';
    return price.isEmpty ? 'Remove Ads' : 'Remove Ads • $price';
  }

  String _statusText(ProPurchaseState state) {
    if (ProStatusService.isProActive || state == ProPurchaseState.purchased) {
      return 'Pro is active on this device. Banner ads are hidden.';
    }

    switch (state) {
      case ProPurchaseState.storeUnavailable:
        return 'The store is not available right now.';
      case ProPurchaseState.productNotFound:
        return 'PocketChase Pro has not been created in the store yet.';
      case ProPurchaseState.error:
        return 'Something went wrong while loading Pro.';
      case ProPurchaseState.loading:
        return 'Checking the store...';
      case ProPurchaseState.purchasing:
        return 'Waiting for the purchase to finish...';
      case ProPurchaseState.restoring:
        return 'Looking for previous purchases...';
      case ProPurchaseState.ready:
      case ProPurchaseState.idle:
      case ProPurchaseState.purchased:
        return 'Upgrade once to remove ads from PocketChase.';
    }
  }

  Widget _benefitTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E2A5E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFF7DE77), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFFC8D4F0),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF173A78),
            Color(0xFF102754),
            Color(0xFF071B43),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: const Color(0xFFF7DE77).withValues(alpha: 0.16),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFF7DE77).withValues(alpha: 0.36),
              ),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: Color(0xFFF7DE77),
              size: 40,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'PocketChase Pro',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Support PocketChase and remove banner ads from the app.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFC8D4F0),
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseCard() {
    return ValueListenableBuilder<ProPurchaseState>(
      valueListenable: _purchaseService.stateNotifier,
      builder: (context, state, _) {
        return ValueListenableBuilder<ProductDetails?>(
          valueListenable: _purchaseService.productNotifier,
          builder: (context, product, __) {
            final busy = _busy(state);
            final isPro =
                ProStatusService.isProActive || state == ProPurchaseState.purchased;
            final message = _purchaseService.messageNotifier.value;

            return Card(
              color: const Color(0xFF102754),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _statusText(state),
                      style: const TextStyle(
                        color: Color(0xFFD8E3FB),
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (message != null && message.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        message,
                        style: const TextStyle(
                          color: Color(0xFFFFF2B3),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed:
                          busy || isPro ? null : _purchaseService.buyPro,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF7DE77),
                        foregroundColor: Colors.black,
                        minimumSize: const Size.fromHeight(52),
                      ),
                      icon: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              isPro
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.workspace_premium_outlined,
                            ),
                      label: Text(
                        _buttonLabel(state: state, product: product),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed:
                          busy ? null : _purchaseService.restorePurchases,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF3F5C96)),
                        minimumSize: const Size.fromHeight(50),
                      ),
                      icon: const Icon(Icons.restore_rounded),
                      label: const Text(
                        'Restore Purchase',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        title: const Text('PocketChase Pro'),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 16),
            _benefitTile(
              icon: Icons.block_rounded,
              title: 'Remove banner ads',
              subtitle: 'Hide the banner ads from the main app tabs.',
            ),
            _benefitTile(
              icon: Icons.favorite_outline_rounded,
              title: 'Support PocketChase',
              subtitle: 'Help keep the app improving with one upgrade.',
            ),
            _benefitTile(
              icon: Icons.restore_rounded,
              title: 'Restore anytime',
              subtitle: 'Restore your Pro purchase on the same store account.',
            ),
            const SizedBox(height: 16),
            _buildPurchaseCard(),
            const SizedBox(height: 12),
            const Text(
              'You will not be charged in debug/test mode unless the product is fully configured and you use a real store purchase flow.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
