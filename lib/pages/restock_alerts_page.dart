import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/restock_alert_service.dart';

class RestockAlertsPage extends StatelessWidget {
  const RestockAlertsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        title: const Text('Restock Alerts'),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<RestockAlert>>(
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              const _IntroCard(),
              const SizedBox(height: 16),
              if (alerts.isEmpty)
                const _EmptyAlertsCard()
              else
                ...alerts.map(
                  (alert) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _RestockAlertCard(alert: alert),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF102754),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Padding(
        padding: EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.notifications_active_outlined, color: Color(0xFFF7DE77)),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'When Pokémon card stock is posted by the PocketChase team, it appears here automatically. '
                'If notifications are enabled for your account, you will also get a push notification.',
                style: TextStyle(color: Color(0xFFD8E3FB), height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyAlertsCard extends StatelessWidget {
  const _EmptyAlertsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF102754),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Padding(
        padding: EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(Icons.inventory_2_outlined, color: Colors.white70, size: 42),
            SizedBox(height: 12),
            Text(
              'No restocks yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'New Pokémon card restocks will show here when they are posted.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFD8E3FB)),
            ),
          ],
        ),
      ),
    );
  }
}

class _RestockAlertCard extends StatelessWidget {
  const _RestockAlertCard({
    required this.alert,
  });

  final RestockAlert alert;

  @override
  Widget build(BuildContext context) {
    final createdAtText = _formatDate(alert.createdAt);
    final hasProductUrl = alert.productUrl.trim().isNotEmpty;
    final hasImageUrl = alert.imageUrl.trim().isNotEmpty;

    return Card(
      color: const Color(0xFF102754),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProductImage(imageUrl: hasImageUrl ? alert.imageUrl : null),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.shopName,
                    style: const TextStyle(
                      color: Color(0xFFF7DE77),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alert.productName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (alert.notes.trim().isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(
                      alert.notes,
                      style: const TextStyle(
                        color: Color(0xFFD8E3FB),
                        height: 1.3,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.circle,
                        color: Color(0xFF54D39A),
                        size: 10,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        alert.inStock ? 'In stock' : 'Stock update',
                        style: const TextStyle(
                          color: Color(0xFF54D39A),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (createdAtText.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            createdAtText,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (hasProductUrl) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: alert.productUrl),
                          );

                          if (!context.mounted) return;

                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              const SnackBar(
                                content: Text('Product link copied'),
                              ),
                            );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFF7DE77),
                          foregroundColor: Colors.black,
                        ),
                        icon: const Icon(Icons.link),
                        label: const Text('Copy link'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return '';

    final local = dateTime.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$day/$month $hour:$minute';
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({
    required this.imageUrl,
  });

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();

    if (url == null || url.isEmpty) {
      return Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFF0E2A5E),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(
          Icons.catching_pokemon,
          color: Colors.white70,
          size: 34,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.network(
        url,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 72,
          height: 72,
          color: const Color(0xFF0E2A5E),
          child: const Icon(
            Icons.catching_pokemon,
            color: Colors.white70,
            size: 34,
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
