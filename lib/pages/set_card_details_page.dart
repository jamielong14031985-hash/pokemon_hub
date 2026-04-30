import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/card_ownership.dart';
import '../models/set_card_details_result.dart';
import '../models/tcg_card.dart';
import '../services/wishlist_service.dart';
import '../utils/auth_input_decoration.dart';
import '../utils/card_condition_helpers.dart';
import '../utils/ebay_sold_search.dart';
import '../widgets/custom_binder_sheets.dart';
import '../widgets/graded_prices_button.dart';
import '../widgets/price_lookup_card.dart';
import '../widgets/set_logo_widgets.dart';
import 'graded_prices_page.dart';

class SetCardDetailsPage extends StatefulWidget {
  const SetCardDetailsPage({
    super.key,
    required this.card,
    required this.ownership,
    this.readOnly = false,
    this.ownerLabel,
    this.navigationCards,
    this.navigationIndex,
  });

  final TcgCard card;
  final CardOwnership ownership;
  final bool readOnly;
  final String? ownerLabel;
  final List<TcgCard>? navigationCards;
  final int? navigationIndex;

  @override
  State<SetCardDetailsPage> createState() => _SetCardDetailsPageState();
}

class _SetCardDetailsPageState extends State<SetCardDetailsPage> {
  late bool normal;
  late bool reverseHolo;
  late bool holo;
  late int copies;
  late String condition;
  late String gradingCompany;
  late final TextEditingController _gradeController;
  late final TextEditingController _conditionNotesController;
  bool _setWishlistBusy = false;
  bool _cardDetailsActionsVisible = true;

  Future<void> _addToCustomBinder() async {
    await addCardToCustomBinderFlow(context, widget.card);
  }

  @override
  void initState() {
    super.initState();
    normal = widget.ownership.normal;
    reverseHolo = widget.ownership.reverseHolo;
    holo = widget.ownership.holo;
    copies = widget.ownership.effectiveCopies;
    condition = normaliseCardCondition(widget.ownership.condition);
    gradingCompany = widget.ownership.gradingCompany.trim();
    _gradeController = TextEditingController(text: formatCardGrade(widget.ownership.grade));
    _conditionNotesController = TextEditingController(text: widget.ownership.conditionNotes);
  }

  @override
  void dispose() {
    _gradeController.dispose();
    _conditionNotesController.dispose();
    super.dispose();
  }

  double? _currentGradeValue() {
    final raw = _gradeController.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    final value = double.tryParse(raw);
    if (value == null || !value.isFinite || value <= 0 || value > 10) return null;
    return value;
  }

  CardOwnership get _currentOwnership => CardOwnership(
        normal: normal,
        reverseHolo: reverseHolo,
        holo: holo,
        copies: copies,
        condition: condition,
        gradingCompany: gradingCompany,
        grade: _currentGradeValue(),
        conditionNotes: _conditionNotesController.text.trim(),
      );

  bool get _hasCardNavigation {
    final cards = widget.navigationCards;
    final index = widget.navigationIndex;
    return cards != null && cards.isNotEmpty && index != null;
  }

  int get _navigationTotal => widget.navigationCards?.length ?? 0;

  int get _navigationPosition => (widget.navigationIndex ?? 0) + 1;

  bool get _canSwipeToPrevious => _hasCardNavigation && (widget.navigationIndex ?? 0) > 0;

  bool get _canSwipeToNext =>
      _hasCardNavigation && (widget.navigationIndex ?? 0) < _navigationTotal - 1;

  void _finishDetails({int? nextIndex}) {
    if (_hasCardNavigation) {
      Navigator.of(context).pop(
        SetCardDetailsResult(
          cardId: widget.card.id,
          ownership: _currentOwnership,
          nextIndex: nextIndex,
        ),
      );
      return;
    }

    Navigator.of(context).pop(_currentOwnership);
  }

  void _handleCardDetailsSwipe(DragEndDetails details) {
    if (!_hasCardNavigation) return;

    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 220) return;

    if (velocity < 0 && _canSwipeToNext) {
      HapticFeedback.selectionClick();
      _finishDetails(nextIndex: (widget.navigationIndex ?? 0) + 1);
    } else if (velocity > 0 && _canSwipeToPrevious) {
      HapticFeedback.selectionClick();
      _finishDetails(nextIndex: (widget.navigationIndex ?? 0) - 1);
    }
  }

  void _toggleCardDetailsActionsPanel() {
    setState(() {
      _cardDetailsActionsVisible = !_cardDetailsActionsVisible;
    });
  }

  Future<void> _toggleWishlist(bool isInWishlist) async {
    final ownerUid = FirebaseAuth.instance.currentUser?.uid;
    if (ownerUid == null || _setWishlistBusy) return;

    setState(() {
      _setWishlistBusy = true;
    });

    try {
      if (isInWishlist) {
        await WishlistService.removeCard(ownerUid: ownerUid, cardId: widget.card.id);
      } else {
        await WishlistService.addCard(ownerUid: ownerUid, card: widget.card);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isInWishlist ? 'Removed from wishlist' : 'Added to wishlist')),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Could not update wishlist right now')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update wishlist right now')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _setWishlistBusy = false;
        });
      }
    }
  }

  Widget _buildConditionEditor() {
    return Card(
      color: const Color(0xFF102754),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Condition & Grading',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Track raw condition, grading company, grade number, and private notes for this saved card.',
              style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.35),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: kCardConditionOptions.contains(condition) ? condition : kDefaultCardCondition,
              dropdownColor: const Color(0xFF16366E),
              style: const TextStyle(color: Colors.white),
              decoration: authInputDecoration('Raw condition'),
              items: kCardConditionOptions
                  .map(
                    (option) => DropdownMenuItem<String>(
                      value: option,
                      child: Text(option),
                    ),
                  )
                  .toList(),
              onChanged: widget.readOnly
                  ? null
                  : (value) {
                      setState(() {
                        condition = value ?? kDefaultCardCondition;
                      });
                    },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: kGradingCompanyOptions.contains(gradingCompany) ? gradingCompany : 'Other',
              dropdownColor: const Color(0xFF16366E),
              style: const TextStyle(color: Colors.white),
              decoration: authInputDecoration('Grading company'),
              items: kGradingCompanyOptions
                  .map(
                    (option) => DropdownMenuItem<String>(
                      value: option,
                      child: Text(option.isEmpty ? 'Not graded' : option),
                    ),
                  )
                  .toList(),
              onChanged: widget.readOnly
                  ? null
                  : (value) {
                      setState(() {
                        gradingCompany = value ?? '';
                        if (gradingCompany.isEmpty) {
                          _gradeController.clear();
                        }
                      });
                    },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _gradeController,
              enabled: !widget.readOnly && gradingCompany.trim().isNotEmpty,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]')),
              ],
              style: const TextStyle(color: Colors.white),
              decoration: authInputDecoration('Grade number')
                  .copyWith(
                    hintText: gradingCompany.trim().isEmpty ? 'Choose a grading company first' : 'e.g. 9, 9.5 or 10',
                    hintStyle: const TextStyle(color: Colors.white38),
                    helperText: 'Grades are saved from 1 to 10.',
                    helperStyle: const TextStyle(color: Colors.white54),
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _conditionNotesController,
              enabled: !widget.readOnly,
              maxLines: 3,
              maxLength: 220,
              style: const TextStyle(color: Colors.white),
              decoration: authInputDecoration('Condition notes')
                  .copyWith(
                    hintText: 'e.g. small whitening on back corner',
                    hintStyle: const TextStyle(color: Colors.white38),
                    counterStyle: const TextStyle(color: Colors.white54),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;

    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        title: Text(card.name),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        bottom: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: _handleCardDetailsSwipe,
          child: Column(
            children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SetLogoTile(setId: card.setId, setName: card.setName, logoUrl: card.setLogoUrl),
                  if (card.largeImageUrl != null)
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFBECBE1), Color(0xFF879CC4)],
                        ),
                      ),
                      padding: const EdgeInsets.all(7),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Image.network(card.largeImageUrl!),
                      ),
                    ),
                  const SizedBox(height: 16),
                  PriceLookupCard(
                    card: card,
                    onOpenRawSold: () => openEbaySoldSearch(context: context, card: card),
                  ),
                  GradedPricesButton(
                    card: card,
                    onOpenGradedPrices: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => GradedPricesPage(card: card),
                        ),
                      );
                    },
                  ),
                  if (_hasCardNavigation) ...[
                    const SizedBox(height: 12),
                    Card(
                      color: const Color(0xFF102754),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Icon(
                              Icons.keyboard_arrow_left_rounded,
                              color: _canSwipeToPrevious ? const Color(0xFFF7DE77) : Colors.white24,
                            ),
                            Expanded(
                              child: Text(
                                'Swipe left or right to flow through cards ($_navigationPosition / $_navigationTotal).',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFFC8D4F0),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.keyboard_arrow_right_rounded,
                              color: _canSwipeToNext ? const Color(0xFFF7DE77) : Colors.white24,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (widget.readOnly && (widget.ownerLabel ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Card(
                      color: const Color(0xFF102754),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          widget.ownerLabel!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Card(
                    color: const Color(0xFF102754),
                    child: Column(
                      children: [
                        SwitchListTile(
                          value: normal,
                          onChanged: widget.readOnly ? null : (value) => setState(() => normal = value),
                          title: const Text('Normal', style: TextStyle(color: Colors.white)),
                        ),
                        const Divider(height: 1, color: Colors.white12),
                        SwitchListTile(
                          value: reverseHolo,
                          onChanged: widget.readOnly ? null : (value) => setState(() => reverseHolo = value),
                          title: const Text('Reverse Holo', style: TextStyle(color: Colors.white)),
                        ),
                        const Divider(height: 1, color: Colors.white12),
                        SwitchListTile(
                          value: holo,
                          onChanged: widget.readOnly ? null : (value) => setState(() => holo = value),
                          title: const Text('Holo', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    color: const Color(0xFF102754),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text(
                            'Copies in Set Pokédex',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: widget.readOnly
                                      ? null
                                      : copies > 0
                                          ? () {
                                              setState(() {
                                                copies--;
                                              });
                                            }
                                          : null,
                                  child: const Text('- Remove'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 72,
                                height: 48,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  '$copies',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton(
                                  onPressed: widget.readOnly
                                      ? null
                                      : () {
                                          setState(() {
                                            copies++;
                                          });
                                        },
                                  child: const Text('+ Add'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            widget.readOnly
                                ? '${widget.ownerLabel ?? 'Shared Pokédex'} is read-only in this view.'
                                : 'Cards with more than 1 saved copy get a shiny border in the set Pokédex.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildConditionEditor(),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: !_cardDetailsActionsVisible ? _toggleCardDetailsActionsPanel : null,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _cardDetailsActionsVisible
                    ? Container(
                        key: const ValueKey('card_details_actions_open'),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF041B4A),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.22),
                              blurRadius: 12,
                              offset: const Offset(0, -4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: _toggleCardDetailsActionsPanel,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(28, 2, 28, 10),
                                child: Container(
                                  width: 44,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.28),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                            ),
                            StreamBuilder<bool>(
                              stream: WishlistService.cardInWishlistStream(
                                FirebaseAuth.instance.currentUser?.uid ?? '',
                                card.id,
                              ),
                              builder: (context, snapshot) {
                                final isInWishlist = snapshot.data ?? false;
                                return SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: _setWishlistBusy ? null : () => _toggleWishlist(isInWishlist),
                                    icon: Icon(
                                      isInWishlist
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_outline_rounded,
                                    ),
                                    label: Text(
                                      isInWishlist ? 'Remove from Wishlist' : 'Add to Wishlist',
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _addToCustomBinder,
                                icon: const Icon(Icons.photo_album_outlined),
                                label: const Text('Add to Custom Binder'),
                              ),
                            ),
                            if (!widget.readOnly) ...[
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: () {
                                    _finishDetails();
                                  },
                                  child: const Text('Save Card to Set Pokédex'),
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              'Tap the handle to hide actions',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.42),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        key: const ValueKey('card_details_actions_closed'),
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF041B4A),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 10,
                              offset: const Offset(0, -3),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 52,
                              height: 5,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7DE77),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tap to show wishlist, binder and save actions',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.68),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}
