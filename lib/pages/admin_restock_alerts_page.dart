import 'package:flutter/material.dart';

import '../services/restock_alert_service.dart';
import '../services/user_feature_flags_service.dart';

class AdminRestockAlertsPage extends StatelessWidget {
  const AdminRestockAlertsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        title: const Text('Post Restock Alert'),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateAlertDialog(context),
        icon: const Icon(Icons.add_alert),
        label: const Text('New alert'),
      ),
      body: StreamBuilder<bool>(
        stream: UserFeatureFlagsService.watchCurrentUserCanManageFeatureFlags(),
        builder: (context, permissionSnapshot) {
          if (permissionSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final canManage = permissionSnapshot.data == true;

          if (!canManage) {
            return const _NoPermissionMessage();
          }

          return StreamBuilder<List<RestockAlert>>(
            stream: RestockAlertService.watchLatestAlerts(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _ErrorMessage(error: snapshot.error.toString());
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final alerts = snapshot.data ?? const <RestockAlert>[];

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  const _IntroCard(),
                  const SizedBox(height: 16),
                  if (alerts.isEmpty)
                    const _EmptyAdminAlertsCard()
                  else
                    ...alerts.map(
                      (alert) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _AdminRestockAlertCard(alert: alert),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  static Future<void> _showCreateAlertDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _CreateRestockAlertDialog(),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF102754),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: const Padding(
        padding: EdgeInsets.all(18),
        child: Text(
          'Create one global restock alert. It will appear for every user who has Restock Alerts enabled. '
          'When the Cloud Function is deployed, it will also push a notification to those users automatically.',
          style: TextStyle(color: Color(0xFFD8E3FB), height: 1.35),
        ),
      ),
    );
  }
}

class _EmptyAdminAlertsCard extends StatelessWidget {
  const _EmptyAdminAlertsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF102754),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: const Padding(
        padding: EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(Icons.add_alert_outlined, color: Colors.white70, size: 42),
            SizedBox(height: 12),
            Text(
              'No alerts posted yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Tap New alert to post the first restock.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFD8E3FB)),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminRestockAlertCard extends StatelessWidget {
  const _AdminRestockAlertCard({
    required this.alert,
  });

  final RestockAlert alert;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF102754),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFF0E2A5E),
          child: Icon(Icons.storefront, color: Color(0xFFF7DE77)),
        ),
        title: Text(
          alert.productName,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          [
            alert.shopName,
            if (alert.notes.trim().isNotEmpty) alert.notes.trim(),
          ].join(' • '),
          style: const TextStyle(color: Color(0xFFD8E3FB)),
        ),
        trailing: IconButton(
          tooltip: 'Delete alert',
          icon: const Icon(Icons.delete_outline, color: Color(0xFFFFB3C7)),
          onPressed: () => _confirmDelete(context, alert.id),
        ),
      ),
    );
  }

  static Future<void> _confirmDelete(BuildContext context, String alertId) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete restock alert?'),
        content: const Text('This removes the alert from the global list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      await RestockAlertService.deleteAlert(alertId);
    } catch (error) {
      if (!context.mounted) return;
      _showSnackBar(context, error.toString());
    }
  }
}

class _CreateRestockAlertDialog extends StatefulWidget {
  const _CreateRestockAlertDialog();

  @override
  State<_CreateRestockAlertDialog> createState() => _CreateRestockAlertDialogState();
}

class _CreateRestockAlertDialogState extends State<_CreateRestockAlertDialog> {
  final TextEditingController _shopController = TextEditingController();
  final TextEditingController _productController = TextEditingController();
  final TextEditingController _productUrlController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _shopController.dispose();
    _productController.dispose();
    _productUrlController.dispose();
    _imageUrlController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New restock alert'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(
                controller: _shopController,
                label: 'Shop name',
                hint: 'Example: Pokemon Center UK',
              ),
              const SizedBox(height: 12),
              _field(
                controller: _productController,
                label: 'Product name',
                hint: 'Example: 151 Booster Bundle',
              ),
              const SizedBox(height: 12),
              _field(
                controller: _productUrlController,
                label: 'Product link',
                hint: 'Optional',
              ),
              const SizedBox(height: 12),
              _field(
                controller: _imageUrlController,
                label: 'Image link',
                hint: 'Optional',
              ),
              const SizedBox(height: 12),
              _field(
                controller: _notesController,
                label: 'Notes',
                hint: 'Optional: limited stock, preorder, etc.',
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.notifications_active_outlined),
          label: const Text('Post alert'),
        ),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      enabled: !_isSaving,
      maxLines: maxLines,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Future<void> _save() async {
    final shopName = _shopController.text.trim();
    final productName = _productController.text.trim();

    if (shopName.isEmpty || productName.isEmpty) {
      _showSnackBar(context, 'Add a shop name and product name.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      await RestockAlertService.createAlert(
        shopName: shopName,
        productName: productName,
        productUrl: _productUrlController.text.trim(),
        imageUrl: _imageUrlController.text.trim(),
        notes: _notesController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(context, error.toString());
      setState(() => _isSaving = false);
    }
  }
}

class _NoPermissionMessage extends StatelessWidget {
  const _NoPermissionMessage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Card(
        color: Color(0xFF102754),
        margin: EdgeInsets.all(16),
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text(
            'You do not have permission to post restock alerts.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({
    required this.error,
  });

  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        color: const Color(0xFF102754),
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(
            'Could not load restock alerts.\n\n$error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

void _showSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
