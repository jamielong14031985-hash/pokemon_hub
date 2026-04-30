import 'package:flutter/material.dart';

import '../models/community_models.dart';
import 'trade_safety_guide_point.dart';
import 'trade_safety_status_chip.dart';

List<TradeSafetyChecklistItem> _communityTradeSafetyItems(CommunityPost post) {
  final hasClearListingDetails = post.isForSale
      ? post.hasPrice
      : post.isWanted || post.isSwap
          ? post.wantedTradeFor.trim().isNotEmpty
          : post.description.trim().length >= 18;

  return <TradeSafetyChecklistItem>[
    TradeSafetyChecklistItem(
      label: 'Clear photos',
      complete: post.hasImages,
      icon: Icons.photo_library_outlined,
      helper: 'Ask for front, back, and close-up photos before agreeing.',
    ),
    TradeSafetyChecklistItem(
      label: 'Condition added',
      complete: post.cardCondition.trim().isNotEmpty,
      icon: Icons.verified_outlined,
      helper: 'Confirm whitening, scratches, bends, dents, and print version.',
    ),
    TradeSafetyChecklistItem(
      label: 'Delivery agreed',
      complete: post.deliveryMethod.trim().isNotEmpty,
      icon: post.deliveryMethod == 'Meetup'
          ? Icons.handshake_outlined
          : Icons.local_shipping_outlined,
      helper: 'Use tracked postage or a safe public meetup spot.',
    ),
    TradeSafetyChecklistItem(
      label: 'General area',
      complete: post.locationText.trim().isNotEmpty,
      icon: Icons.place_outlined,
      helper: 'Use a town or public collection point, not a full home address.',
    ),
    TradeSafetyChecklistItem(
      label: 'Deal details',
      complete: hasClearListingDetails,
      icon: post.isForSale ? Icons.sell_outlined : Icons.swap_horiz_rounded,
      helper: 'Agree exact cards, value, postage, and timing in writing.',
    ),
  ];
}

int _communityTradeSafetyScore(CommunityPost post) {
  return _communityTradeSafetyItems(post).where((item) => item.complete).length;
}

String _communityTradeSafetyRating(CommunityPost post) {
  final score = _communityTradeSafetyScore(post);
  if (score >= 5) return 'Strong safety info';
  if (score >= 3) return 'Good safety info';
  return 'Needs more details';
}

Color _communityTradeSafetyColor(CommunityPost post) {
  final score = _communityTradeSafetyScore(post);
  if (score >= 5) return const Color(0xFF2C7A5B);
  if (score >= 3) return const Color(0xFFF0A83A);
  return const Color(0xFFE85D5D);
}

Future<void> showTradeSafetyGuide(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF102754),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            18,
            20,
            MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7DE77).withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFF7DE77).withValues(alpha: 0.34),
                        ),
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: Color(0xFFF7DE77),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trade safety centre',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Quick checks before swaps, sales, and meetups.',
                            style: TextStyle(
                              color: Color(0xFFC8D4F0),
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const TradeSafetyGuidePoint(
                  icon: Icons.photo_camera_outlined,
                  title: 'Ask for proof photos',
                  body: 'Get clear front, back, corner, and username/date photos before sending payment or cards.',
                ),
                const TradeSafetyGuidePoint(
                  icon: Icons.local_shipping_outlined,
                  title: 'Use tracked delivery',
                  body: 'Share tracking numbers and keep postage receipts until both sides confirm the trade is complete.',
                ),
                const TradeSafetyGuidePoint(
                  icon: Icons.place_outlined,
                  title: 'Meet safely',
                  body: 'Meet in a busy public place. Do not share your full home address in public posts.',
                ),
                const TradeSafetyGuidePoint(
                  icon: Icons.payment_outlined,
                  title: 'Protect payment details',
                  body: 'Never share bank logins, one-time codes, passwords, or unnecessary personal details.',
                ),
                const TradeSafetyGuidePoint(
                  icon: Icons.description_outlined,
                  title: 'Keep an agreed record',
                  body: 'Confirm exact cards, condition, price or value, postage, and timing in messages before proceeding.',
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE85D5D).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE85D5D).withValues(alpha: 0.30)),
                  ),
                  child: const Text(
                    'PocketChase cannot verify users, payments, card authenticity, postage, or meetups. Walk away from anything that feels rushed, vague, or unsafe.',
                    style: TextStyle(
                      color: Color(0xFFFFD3D3),
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF7DE77),
                      foregroundColor: Colors.black,
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: const Text(
                      'Got it',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class TradeSafetyPanel extends StatefulWidget {
  const TradeSafetyPanel({
    super.key,
    this.post,
    this.compact = false,
    this.showGuideButton = true,
  });

  final CommunityPost? post;
  final bool compact;
  final bool showGuideButton;

  @override
  State<TradeSafetyPanel> createState() => _TradeSafetyPanelState();
}

class _TradeSafetyPanelState extends State<TradeSafetyPanel> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = !widget.compact;
  }

  @override
  void didUpdateWidget(covariant TradeSafetyPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.compact != widget.compact) {
      _expanded = !widget.compact;
    }
  }

  void _toggleExpanded() {
    if (!widget.compact) return;
    setState(() {
      _expanded = !_expanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final livePost = widget.post;
    final items = livePost == null
        ? const <TradeSafetyChecklistItem>[]
        : _communityTradeSafetyItems(livePost);
    final completed = livePost == null ? 0 : items.where((item) => item.complete).length;
    final total = items.isEmpty ? 5 : items.length;
    final rating = livePost == null ? 'Trade safety guide' : _communityTradeSafetyRating(livePost);
    final accent = livePost == null ? const Color(0xFFF7DE77) : _communityTradeSafetyColor(livePost);
    final visibleItems = widget.compact ? items.take(3).toList() : items;
    final summaryText = livePost == null
        ? 'Check the basics before any swap, sale, or meetup.'
        : '$rating • $completed/$total details added';

    if (widget.compact && !_expanded) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF0B214F),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.26)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _toggleExpanded,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, color: accent, size: 17),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Safety: $rating',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFC8D4F0),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (livePost != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '$completed/$total',
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.expand_more_rounded,
                    color: Color(0xFFC8D4F0),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0B214F),
        borderRadius: BorderRadius.circular(widget.compact ? 18 : 20),
        border: Border.all(color: accent.withValues(alpha: 0.34)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.compact ? _toggleExpanded : null,
          borderRadius: BorderRadius.circular(widget.compact ? 18 : 20),
          child: Padding(
            padding: EdgeInsets.all(widget.compact ? 12 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: widget.compact ? 34 : 40,
                      height: widget.compact ? 34 : 40,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                        border: Border.all(color: accent.withValues(alpha: 0.30)),
                      ),
                      child: Icon(
                        Icons.shield_outlined,
                        color: accent,
                        size: widget.compact ? 18 : 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Trade safety',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            summaryText,
                            maxLines: widget.compact && !_expanded ? 2 : null,
                            overflow: widget.compact && !_expanded
                                ? TextOverflow.ellipsis
                                : TextOverflow.visible,
                            style: const TextStyle(
                              color: Color(0xFFC8D4F0),
                              fontSize: 12,
                              height: 1.25,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (livePost != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: accent.withValues(alpha: 0.32)),
                        ),
                        child: Text(
                          '$completed/$total',
                          style: TextStyle(
                            color: accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    if (widget.compact) ...[
                      const SizedBox(width: 6),
                      Icon(
                        _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        color: const Color(0xFFC8D4F0),
                        size: 22,
                      ),
                    ],
                  ],
                ),
                if (!widget.compact || _expanded) ...[
                  if (visibleItems.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: visibleItems.map((item) {
                        return TradeSafetyStatusChip(item: item);
                      }).toList(),
                    ),
                  ],
                  if (!widget.compact) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Safety reminders: ask for proof photos, use tracked postage, meet in public, and keep a clear record of what both sides agreed.',
                      style: TextStyle(
                        color: Color(0xFFAFC0E6),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (widget.showGuideButton) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => showTradeSafetyGuide(context),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFFFF2B3),
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.info_outline, size: 17),
                        label: Text(
                          widget.compact ? 'Open safety guide' : 'View safety guide',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ] else if (widget.compact) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Tap to expand',
                    style: TextStyle(
                      color: accent.withValues(alpha: 0.95),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
