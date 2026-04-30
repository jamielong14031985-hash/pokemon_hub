import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/app_user_profile.dart';
import '../services/community_rating_service.dart';

class CommunityRatingSheet extends StatefulWidget {
  const CommunityRatingSheet({
    super.key,
    required this.currentProfile,
    required this.sellerId,
    required this.sellerName,
    this.sourcePostId = '',
    this.sourcePostTitle = '',
  });

  final AppUserProfile currentProfile;
  final String sellerId;
  final String sellerName;
  final String sourcePostId;
  final String sourcePostTitle;

  @override
  State<CommunityRatingSheet> createState() => _CommunityRatingSheetState();
}

class _CommunityRatingSheetState extends State<CommunityRatingSheet> {
  final TextEditingController _commentController = TextEditingController();
  int _selectedStars = 5;
  bool _loading = true;
  bool _saving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadExistingRating();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingRating() async {
    try {
      final existing = await CommunityRatingService.fetchRating(
        sellerId: widget.sellerId,
        raterId: widget.currentProfile.uid,
      );
      if (!mounted) return;
      if (existing != null) {
        _selectedStars = existing.normalizedStars;
        _commentController.text = existing.comment;
      }
    } catch (_) {
      if (!mounted) return;
      _errorText = 'Could not load your previous rating. You can still save a new one.';
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveRating() async {
    if (_saving) return;
    final sellerId = widget.sellerId.trim();
    final currentUid = widget.currentProfile.uid.trim();
    if (sellerId.isEmpty || currentUid.isEmpty) {
      setState(() => _errorText = 'Could not find the seller details.');
      return;
    }
    if (sellerId == currentUid) {
      setState(() => _errorText = 'You cannot rate yourself.');
      return;
    }

    setState(() {
      _saving = true;
      _errorText = null;
    });

    try {
      await CommunityRatingService.submitRating(
        sellerId: sellerId,
        sellerName: widget.sellerName,
        raterId: currentUid,
        raterName: widget.currentProfile.displayName,
        stars: _selectedStars,
        comment: _commentController.text,
        sourcePostId: widget.sourcePostId,
        sourcePostTitle: widget.sourcePostTitle,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorText = error.message ?? 'Could not save rating.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorText = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  Widget _buildEditableStars() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final value = index + 1;
        final selected = value <= _selectedStars;
        return IconButton(
          onPressed: _saving ? null : () => setState(() => _selectedStars = value),
          icon: Icon(
            selected ? Icons.star_rounded : Icons.star_border_rounded,
            color: const Color(0xFFF7DE77),
            size: 36,
          ),
          tooltip: '$value star${value == 1 ? '' : 's'}',
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 18,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: _loading
            ? const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Icon(
                      Icons.verified_user_outlined,
                      color: Color(0xFFF7DE77),
                      size: 42,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Rate ${widget.sellerName.trim().isEmpty ? 'this seller' : widget.sellerName.trim()}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Leave an honest rating after a sale, swap, trade, or helpful community interaction.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFC8D4F0),
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildEditableStars(),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _commentController,
                      enabled: !_saving,
                      minLines: 3,
                      maxLines: 5,
                      maxLength: 180,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Comment (optional)',
                        hintText: 'Example: Fast delivery and card arrived safely.',
                        labelStyle: const TextStyle(color: Color(0xFFC8D4F0)),
                        hintStyle: const TextStyle(color: Colors.white38),
                        counterStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF0B214F),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    if (_errorText != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _errorText!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _saving ? null : _saveRating,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: const Color(0xFFF7DE77),
                        foregroundColor: Colors.black,
                      ),
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _saving ? 'Saving...' : 'Save rating',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF3F5C96)),
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
