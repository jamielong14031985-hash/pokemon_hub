import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/business_profile.dart';
import '../models/business_review.dart';
import '../services/business_profile_service.dart';

class BusinessReviewsPage extends StatefulWidget {
  const BusinessReviewsPage({
    super.key,
    required this.profile,
  });

  final BusinessProfile profile;

  @override
  State<BusinessReviewsPage> createState() => _BusinessReviewsPageState();
}

class _BusinessReviewsPageState extends State<BusinessReviewsPage> {
  static const Color _backgroundColor = Color(0xFF041B4A);
  static const Color _cardColor = Color(0xFF102754);
  static const Color _fieldColor = Color(0xFF16366E);
  static const Color _borderColor = Color(0xFF3F5C96);
  static const Color _goldColor = Color(0xFFF7DE77);
  static const Color _softTextColor = Color(0xFFC8D4F0);

  final BusinessProfileService _service = BusinessProfileService();

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  bool get _isOwnBusiness {
    return _currentUid.isNotEmpty && _currentUid == widget.profile.ownerUid;
  }

  double _averageStars(List<BusinessReview> reviews) {
    if (reviews.isEmpty) return 0;
    final total = reviews.fold<int>(0, (sum, review) => sum + review.stars);
    return total / reviews.length;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  Future<void> _openReviewSheet({BusinessReview? existingReview}) async {
    if (_isOwnBusiness) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot review your own business.')),
      );
      return;
    }

    var selectedStars = existingReview?.stars ?? 5;
    final commentController = TextEditingController(
      text: existingReview?.comment ?? '',
    );

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: _cardColor,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (bottomSheetContext) {
        var saving = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> saveReview() async {
              final comment = commentController.text.trim();
              if (comment.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please write a short review.')),
                );
                return;
              }

              setModalState(() => saving = true);

              try {
                await _service.saveBusinessReview(
                  businessId: widget.profile.id,
                  businessName: widget.profile.businessName,
                  ownerUid: widget.profile.ownerUid,
                  stars: selectedStars,
                  comment: comment,
                );

                if (!bottomSheetContext.mounted) return;
                Navigator.of(bottomSheetContext).pop();

                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Review saved.')),
                );

                return;
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not save review: $error')),
                );

                if (context.mounted) {
                  setModalState(() => saving = false);
                }
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 8,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        existingReview == null ? 'Write a review' : 'Edit review',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.profile.businessName.trim().isEmpty
                            ? 'Business profile'
                            : widget.profile.businessName.trim(),
                        style: const TextStyle(
                          color: _softTextColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _fieldColor,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: _borderColor),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (index) {
                            final starNumber = index + 1;
                            final selected = starNumber <= selectedStars;

                            return IconButton(
                              tooltip:
                                  '$starNumber star${starNumber == 1 ? '' : 's'}',
                              icon: Icon(
                                selected
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: _goldColor,
                                size: 38,
                              ),
                              onPressed: saving
                                  ? null
                                  : () {
                                      setModalState(() {
                                        selectedStars = starNumber;
                                      });
                                    },
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: commentController,
                        enabled: !saving,
                        minLines: 4,
                        maxLines: 6,
                        maxLength: 500,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: _goldColor,
                        decoration: InputDecoration(
                          labelText: 'Review',
                          hintText: 'Share your experience with this business',
                          labelStyle: const TextStyle(color: _softTextColor),
                          hintStyle: const TextStyle(color: Color(0xFFAFC0E6)),
                          filled: true,
                          fillColor: _fieldColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(color: _borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(color: _borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: _goldColor,
                              width: 1.6,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _goldColor,
                          foregroundColor: _backgroundColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _backgroundColor,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          saving ? 'Saving...' : 'Save review',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        onPressed: saving ? null : saveReview,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    commentController.dispose();
  }

  Future<void> _openReplySheet(BusinessReview review) async {
    if (!_isOwnBusiness) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only the business owner can reply.')),
      );
      return;
    }

    final replyController = TextEditingController(text: review.businessReply);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: _cardColor,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (bottomSheetContext) {
        var saving = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> saveReply() async {
              final reply = replyController.text.trim();
              if (reply.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please write a reply.')),
                );
                return;
              }

              setModalState(() => saving = true);

              try {
                await _service.saveBusinessReviewReply(
                  businessId: widget.profile.id,
                  reviewId: review.id,
                  reply: reply,
                );

                if (!bottomSheetContext.mounted) return;
                Navigator.of(bottomSheetContext).pop();

                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Reply saved.')),
                );

                return;
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not save reply: $error')),
                );

                if (context.mounted) {
                  setModalState(() => saving = false);
                }
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 8,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        review.hasBusinessReply ? 'Edit reply' : 'Reply to review',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        review.displayReviewerName,
                        style: const TextStyle(
                          color: _softTextColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _fieldColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _borderColor),
                        ),
                        child: Text(
                          review.comment.trim(),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _softTextColor,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: replyController,
                        enabled: !saving,
                        minLines: 4,
                        maxLines: 6,
                        maxLength: 500,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: _goldColor,
                        decoration: InputDecoration(
                          labelText: 'Business reply',
                          hintText: 'Thank the customer or respond professionally',
                          labelStyle: const TextStyle(color: _softTextColor),
                          hintStyle: const TextStyle(color: Color(0xFFAFC0E6)),
                          filled: true,
                          fillColor: _fieldColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(color: _borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(color: _borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: _goldColor,
                              width: 1.6,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _goldColor,
                          foregroundColor: _backgroundColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _backgroundColor,
                                ),
                              )
                            : const Icon(Icons.reply_outlined),
                        label: Text(
                          saving ? 'Saving...' : 'Save reply',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        onPressed: saving ? null : saveReply,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    replyController.dispose();
  }

  Future<void> _deleteReply(BusinessReview review) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _cardColor,
          title: const Text(
            'Delete reply?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: const Text(
            'This will remove the business reply from this review.',
            style: TextStyle(color: _softTextColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await _service.deleteBusinessReviewReply(
        businessId: widget.profile.id,
        reviewId: review.id,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reply deleted.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete reply: $error')),
      );
    }
  }

  Future<void> _deleteReview(BusinessReview review) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _cardColor,
          title: const Text(
            'Delete review?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: const Text(
            'This will remove your review from this business.',
            style: TextStyle(color: _softTextColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await _service.deleteBusinessReview(
        businessId: widget.profile.id,
        reviewId: review.id,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review deleted.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete review: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.profile.businessName.trim().isEmpty
        ? 'Business reviews'
        : widget.profile.businessName.trim();

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Reviews & ratings'),
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<List<BusinessReview>>(
        stream: _service.watchBusinessReviews(widget.profile.id),
        builder: (context, snapshot) {
          final reviews = snapshot.data ?? const <BusinessReview>[];
          final average = _averageStars(reviews);
          final reviewCount = reviews.length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              _HeaderCard(
                businessName: title,
                average: average,
                reviewCount: reviewCount,
              ),
              const SizedBox(height: 14),
              if (_isOwnBusiness)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _fieldColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _borderColor),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: _goldColor,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'You can reply to customer reviews from this page. You cannot review your own business.',
                          style: TextStyle(
                            color: _softTextColor,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                StreamBuilder<BusinessReview?>(
                  stream: _service.watchMyBusinessReview(widget.profile.id),
                  builder: (context, myReviewSnapshot) {
                    final myReview = myReviewSnapshot.data;

                    return FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _goldColor,
                        foregroundColor: _backgroundColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      icon: Icon(
                        myReview == null
                            ? Icons.rate_review_outlined
                            : Icons.edit_outlined,
                      ),
                      label: Text(
                        myReview == null ? 'Write a review' : 'Edit my review',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      onPressed: () => _openReviewSheet(existingReview: myReview),
                    );
                  },
                ),
              const SizedBox(height: 18),
              const Text(
                'Customer reviews',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: _goldColor),
                  ),
                )
              else if (reviews.isEmpty)
                const _NoReviewsCard()
              else
                ...reviews.map(
                  (review) => _ReviewCard(
                    review: review,
                    currentUid: _currentUid,
                    isOwnBusiness: _isOwnBusiness,
                    formattedDate: _formatDate(review.displayDate),
                    formattedReplyDate:
                        _formatDate(review.businessReplyDisplayDate),
                    onEdit: () => _openReviewSheet(existingReview: review),
                    onDelete: () => _deleteReview(review),
                    onReply: () => _openReplySheet(review),
                    onDeleteReply: () => _deleteReply(review),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.businessName,
    required this.average,
    required this.reviewCount,
  });

  final String businessName;
  final double average;
  final int reviewCount;

  static const Color _cardColor = _BusinessReviewsPageState._cardColor;
  static const Color _fieldColor = _BusinessReviewsPageState._fieldColor;
  static const Color _borderColor = _BusinessReviewsPageState._borderColor;
  static const Color _goldColor = _BusinessReviewsPageState._goldColor;
  static const Color _softTextColor = _BusinessReviewsPageState._softTextColor;

  @override
  Widget build(BuildContext context) {
    final hasReviews = reviewCount > 0;
    final averageText = hasReviews ? average.toStringAsFixed(1) : 'New';
    final subtitle = hasReviews
        ? '$reviewCount review${reviewCount == 1 ? '' : 's'} from customers'
        : 'No reviews yet — be the first to leave feedback';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _fieldColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _borderColor),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: _goldColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      businessName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _softTextColor,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatChip(
                icon: Icons.star_rounded,
                label: 'Average rating',
                value: averageText,
              ),
              _StatChip(
                icon: Icons.rate_review_outlined,
                label: 'Reviews',
                value: '$reviewCount',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ...List.generate(5, (index) {
                final isFilled = hasReviews && index < average.round();
                return Padding(
                  padding: EdgeInsets.only(right: index == 4 ? 0 : 2),
                  child: Icon(
                    isFilled
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: _goldColor,
                    size: 22,
                  ),
                );
              }),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hasReviews
                      ? 'Rated by the PocketChase community'
                      : 'This business is waiting for its first review',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _softTextColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _BusinessReviewsPageState._fieldColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _BusinessReviewsPageState._borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: _BusinessReviewsPageState._goldColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: _BusinessReviewsPageState._softTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.review,
    required this.currentUid,
    required this.isOwnBusiness,
    required this.formattedDate,
    required this.formattedReplyDate,
    required this.onEdit,
    required this.onDelete,
    required this.onReply,
    required this.onDeleteReply,
  });

  final BusinessReview review;
  final String currentUid;
  final bool isOwnBusiness;
  final String formattedDate;
  final String formattedReplyDate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onReply;
  final VoidCallback onDeleteReply;

  @override
  Widget build(BuildContext context) {
    final canManageReview =
        currentUid.isNotEmpty && review.reviewerUid == currentUid;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _BusinessReviewsPageState._cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _BusinessReviewsPageState._borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _BusinessReviewsPageState._fieldColor,
                child: Text(
                  review.displayReviewerName.isEmpty
                      ? '?'
                      : review.displayReviewerName.characters.first.toUpperCase(),
                  style: const TextStyle(
                    color: _BusinessReviewsPageState._goldColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.displayReviewerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          return Icon(
                            index < review.stars
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: _BusinessReviewsPageState._goldColor,
                            size: 19,
                          );
                        }),
                        if (formattedDate.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              formattedDate,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _BusinessReviewsPageState._softTextColor,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (review.comment.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              review.comment.trim(),
              style: const TextStyle(
                color: _BusinessReviewsPageState._softTextColor,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (review.hasBusinessReply) ...[
            const SizedBox(height: 14),
            _BusinessReplyBox(
              reply: review.businessReply.trim(),
              formattedDate: formattedReplyDate,
            ),
          ],
          if (canManageReview || isOwnBusiness) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (canManageReview) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(
                        color: _BusinessReviewsPageState._borderColor,
                      ),
                    ),
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                  ),
                ],
                if (isOwnBusiness)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _BusinessReviewsPageState._goldColor,
                      side: const BorderSide(
                        color: _BusinessReviewsPageState._goldColor,
                      ),
                    ),
                    onPressed: onReply,
                    icon: const Icon(Icons.reply_outlined),
                    label: Text(
                      review.hasBusinessReply ? 'Edit reply' : 'Reply',
                    ),
                  ),
                if (isOwnBusiness && review.hasBusinessReply)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                    onPressed: onDeleteReply,
                    icon: const Icon(Icons.delete_sweep_outlined),
                    label: const Text('Delete reply'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BusinessReplyBox extends StatelessWidget {
  const _BusinessReplyBox({
    required this.reply,
    required this.formattedDate,
  });

  final String reply;
  final String formattedDate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _BusinessReviewsPageState._fieldColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _BusinessReviewsPageState._goldColor.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.storefront_outlined,
                color: _BusinessReviewsPageState._goldColor,
                size: 19,
              ),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'Business reply',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (formattedDate.isNotEmpty)
                Text(
                  formattedDate,
                  style: const TextStyle(
                    color: _BusinessReviewsPageState._softTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            reply,
            style: const TextStyle(
              color: _BusinessReviewsPageState._softTextColor,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoReviewsCard extends StatelessWidget {
  const _NoReviewsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      decoration: BoxDecoration(
        color: _BusinessReviewsPageState._cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _BusinessReviewsPageState._borderColor),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.reviews_outlined,
            color: _BusinessReviewsPageState._goldColor,
            size: 44,
          ),
          SizedBox(height: 12),
          Text(
            'No reviews yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'When customers leave feedback, their reviews and ratings will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _BusinessReviewsPageState._softTextColor,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
