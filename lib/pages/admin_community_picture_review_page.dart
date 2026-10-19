import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/stored_image.dart';

class AdminCommunityPictureReviewPage extends StatefulWidget {
  const AdminCommunityPictureReviewPage({super.key});

  @override
  State<AdminCommunityPictureReviewPage> createState() =>
      _AdminCommunityPictureReviewPageState();
}

class _AdminCommunityPictureReviewPageState
    extends State<AdminCommunityPictureReviewPage> {
  static const _background = Color(0xFF041B4A);
  static const _card = Color(0xFF102754);
  static const _field = Color(0xFF16366E);
  static const _border = Color(0xFF3F5C96);
  static const _gold = Color(0xFFF7DE77);
  static const _softText = Color(0xFFC8D4F0);
  static const _success = Color(0xFF4ADE80);

  final Set<String> _busyPostIds = <String>{};

  List<String> _images(Map<String, dynamic> data) {
    final raw = data['imageRefs'] ??
        data['imageUrlList'] ??
        data['imageBase64List'];
    if (raw is! List) return const <String>[];
    return raw
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Future<void> _review(String postId, String status) async {
    if (_busyPostIds.contains(postId)) return;
    setState(() => _busyPostIds.add(postId));
    try {
      await FirebaseFirestore.instance
          .collection('community_posts')
          .doc(postId)
          .update(<String, dynamic>{
        'moderationStatus': status,
        'moderatedAtMs': DateTime.now().millisecondsSinceEpoch,
        'moderatedByUid': FirebaseAuth.instance.currentUser?.uid ?? '',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'approved'
                ? 'Post approved and now visible to the public.'
                : 'Post rejected and kept hidden.',
          ),
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Could not review this post.')),
      );
    } finally {
      if (mounted) setState(() => _busyPostIds.remove(postId));
    }
  }

  void _openImage(String imageRef) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 5,
              child: StoredImage(imageRef: imageRef, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text('Picture Post Reviews'),
        backgroundColor: _background,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('community_posts')
            .where('moderationStatus', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Could not load posts awaiting picture review.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _softText),
                ),
              ),
            );
          }

          final docs = [...?snapshot.data?.docs]
            ..sort((a, b) {
              final aTime =
                  (a.data()['moderationSubmittedAtMs'] as num?)?.toInt() ?? 0;
              final bTime =
                  (b.data()['moderationSubmittedAtMs'] as num?)?.toInt() ?? 0;
              return bTime.compareTo(aTime);
            });

          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No picture posts are waiting for approval.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _softText, fontSize: 16),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final images = _images(data);
              final busy = _busyPostIds.contains(doc.id);
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (data['title'] ?? 'Untitled post').toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${data['authorName'] ?? 'Trainer'} • ${data['postType'] ?? 'Post'}',
                      style: const TextStyle(
                        color: _gold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      (data['description'] ?? '').toString(),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _softText, height: 1.35),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 180,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: images.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, imageIndex) {
                          final imageRef = images[imageIndex];
                          return GestureDetector(
                            onTap: () => _openImage(imageRef),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                width: 180,
                                color: _field,
                                child: StoredImage(
                                  imageRef: imageRef,
                                  fit: BoxFit.cover,
                                  width: 180,
                                  height: 180,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed:
                                busy ? null : () => _review(doc.id, 'rejected'),
                            icon: const Icon(Icons.close),
                            label: const Text('Reject'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                              minimumSize: const Size.fromHeight(50),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed:
                                busy ? null : () => _review(doc.id, 'approved'),
                            icon: busy
                                ? const SizedBox(
                                    width: 17,
                                    height: 17,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.check),
                            label: const Text('Approve'),
                            style: FilledButton.styleFrom(
                              backgroundColor: _success,
                              foregroundColor: _background,
                              minimumSize: const Size.fromHeight(50),
                            ),
                          ),
                        ),
                      ],
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
}
