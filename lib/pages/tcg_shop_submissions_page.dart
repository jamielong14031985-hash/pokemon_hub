import 'package:flutter/material.dart';

import '../models/tcg_shop.dart';
import '../services/tcg_shop_service.dart';

class TcgShopSubmissionsPage extends StatefulWidget {
  const TcgShopSubmissionsPage({super.key});

  @override
  State<TcgShopSubmissionsPage> createState() => _TcgShopSubmissionsPageState();
}

class _TcgShopSubmissionsPageState extends State<TcgShopSubmissionsPage> {
  final TcgShopService _shopService = TcgShopService();
  final Set<String> _busyIds = <String>{};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TCG Shop Submissions'),
      ),
      body: StreamBuilder<List<TcgShop>>(
        stream: _shopService.watchPendingSubmissions(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load submissions.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final submissions = snapshot.data ?? const <TcgShop>[];

          if (submissions.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No pending TCG shop submissions.'),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: submissions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final shop = submissions[index];
              final busy = _busyIds.contains(shop.id);

              return Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (shop.hasImage)
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          shop.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              child: const Center(
                                child: Icon(Icons.broken_image_outlined, size: 42),
                              ),
                            );
                          },
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shop.name.isEmpty ? 'Unnamed shop' : shop.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 6),
                          if (shop.singleLineAddress.isNotEmpty)
                            Text(shop.singleLineAddress),
                          const SizedBox(height: 6),
                          Text(
                            'Location: ${shop.lat.toStringAsFixed(6)}, ${shop.lng.toStringAsFixed(6)}',
                          ),
                          if (shop.website.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text('Website: ${shop.website}'),
                          ],
                          if (shop.phone.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text('Phone: ${shop.phone}'),
                          ],
                          if (shop.games.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: shop.games
                                  .map((game) => Chip(label: Text(_label(game))))
                                  .toList(),
                            ),
                          ],
                          if (shop.services.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: shop.services
                                  .map(
                                    (service) => Chip(label: Text(_label(service))),
                                  )
                                  .toList(),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  icon: busy
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.check_circle_outline),
                                  label: const Text('Approve'),
                                  onPressed: busy
                                      ? null
                                      : () => _approveSubmission(shop.id),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.cancel_outlined),
                                  label: const Text('Reject'),
                                  onPressed: busy
                                      ? null
                                      : () => _rejectSubmission(shop.id),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _label(String value) {
    return value
        .split(' ')
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  Future<void> _approveSubmission(String submissionId) async {
    await _runAction(
      submissionId: submissionId,
      action: () => _shopService.approveSubmission(submissionId),
      successMessage: 'Shop approved and added to the public map.',
    );
  }

  Future<void> _rejectSubmission(String submissionId) async {
    await _runAction(
      submissionId: submissionId,
      action: () => _shopService.rejectSubmission(submissionId),
      successMessage: 'Submission rejected.',
    );
  }

  Future<void> _runAction({
    required String submissionId,
    required Future<void> Function() action,
    required String successMessage,
  }) async {
    setState(() => _busyIds.add(submissionId));

    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(submissionId));
      }
    }
  }
}
