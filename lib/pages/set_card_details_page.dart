import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/card_ownership.dart';
import '../models/set_card_details_result.dart';
import '../models/tcg_card.dart';
import '../services/local_pokedex_store.dart';
import '../services/pokedex_sync_service.dart';
import '../services/wishlist_service.dart';
import '../services/external_card_price_service.dart';
import '../utils/auth_input_decoration.dart';
import '../utils/card_condition_helpers.dart';
import '../utils/ebay_sold_search.dart';
import '../utils/master_set_slot_helpers.dart';
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
    this.initialSlotKind = MasterSetSlotKind.normal,
    this.readOnly = false,
    this.ownerLabel,
    this.navigationCards,
    this.navigationSlotKinds,
    this.navigationIndex,
  });

  final TcgCard card;
  final CardOwnership ownership;
  final MasterSetSlotKind initialSlotKind;
  final bool readOnly;
  final String? ownerLabel;
  final List<TcgCard>? navigationCards;
  final List<MasterSetSlotKind>? navigationSlotKinds;
  final int? navigationIndex;

  @override
  State<SetCardDetailsPage> createState() => _SetCardDetailsPageState();
}

class _SetCardDetailsPageState extends State<SetCardDetailsPage> {
  late int normalCopies;
  late int reverseHoloCopies;
  late int holoCopies;
  late MasterSetSlotKind selectedSlotKind;
  late String condition;
  late String gradingCompany;
  late final TextEditingController _gradeController;
  late final TextEditingController _conditionNotesController;
  bool _setWishlistBusy = false;
  bool _cardDetailsActionsVisible = true;
  bool _savingOwnership = false;
  bool _refreshingPrice = false;
  late TcgCard _pricedCard;

  Future<void> _addToCustomBinder() async {
    await addCardToCustomBinderFlow(context, widget.card);
  }

  @override
  void initState() {
    super.initState();
    _pricedCard = widget.card;
    normalCopies = widget.ownership.normalCount;
    reverseHoloCopies = widget.ownership.reverseHoloCount;
    holoCopies = widget.ownership.holoCount;
    selectedSlotKind = _initialSelectedSlotKind();
    condition = normaliseCardCondition(widget.ownership.condition);
    gradingCompany = widget.ownership.gradingCompany.trim();
    _gradeController = TextEditingController(text: formatCardGrade(widget.ownership.grade));
    _conditionNotesController = TextEditingController(text: widget.ownership.conditionNotes);
    _refreshExternalPriceIfMissing();
  }


  Future<void> _refreshExternalPriceIfMissing() async {
    // Do not call JustTCG automatically when a card screen opens.
    // The JustTCG free tier is rate limited, so external pricing is now
    // checked only when the user presses Refresh Raw Price.
    return;
  }

  Future<void> _refreshExternalPrice({bool showMessageWhenMissing = true}) async {
    if (_refreshingPrice) return;

    setState(() {
      _refreshingPrice = true;
    });

    try {
      final enrichedCard = await ExternalCardPriceService.enrichCardWithExternalPrice(
        _pricedCard,
        rethrowErrors: showMessageWhenMissing,
      );
      if (!mounted) return;
      setState(() {
        _pricedCard = enrichedCard;
      });
      if (showMessageWhenMissing) {
        final hasPrice = (enrichedCard.marketPrice ?? 0) > 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hasPrice
                  ? 'Raw price updated from ${enrichedCard.marketPriceSource}'
                  : 'No raw price found from JustTCG yet',
            ),
          ),
        );
      }
    } catch (error) {
      if (showMessageWhenMissing && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ExternalCardPriceService.friendlyErrorMessage(error))),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _refreshingPrice = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _gradeController.dispose();
    _conditionNotesController.dispose();
    super.dispose();
  }

  MasterSetSlotKind _initialSelectedSlotKind() {
    final navigationIndex = widget.navigationIndex;
    final navigationSlotKinds = widget.navigationSlotKinds;
    if (navigationIndex != null &&
        navigationSlotKinds != null &&
        navigationIndex >= 0 &&
        navigationIndex < navigationSlotKinds.length) {
      return navigationSlotKinds[navigationIndex];
    }
    return widget.initialSlotKind;
  }

  double? _currentGradeValue() {
    final raw = _gradeController.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    final value = double.tryParse(raw);
    if (value == null || !value.isFinite || value <= 0 || value > 10) return null;
    return value;
  }

  int get _totalCopies => normalCopies + reverseHoloCopies + holoCopies;

  CardOwnership get _currentOwnership => CardOwnership(
        normal: normalCopies > 0,
        reverseHolo: reverseHoloCopies > 0,
        holo: holoCopies > 0,
        copies: _totalCopies,
        normalCopies: normalCopies,
        reverseHoloCopies: reverseHoloCopies,
        holoCopies: holoCopies,
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

  String _labelForKind(MasterSetSlotKind kind) {
    switch (kind) {
      case MasterSetSlotKind.normal:
        return 'Normal';
      case MasterSetSlotKind.reverseHolo:
        return 'Reverse Holo';
      case MasterSetSlotKind.holo:
        return 'Holo';
    }
  }

  int _countForKind(MasterSetSlotKind kind) {
    switch (kind) {
      case MasterSetSlotKind.normal:
        return normalCopies;
      case MasterSetSlotKind.reverseHolo:
        return reverseHoloCopies;
      case MasterSetSlotKind.holo:
        return holoCopies;
    }
  }

  void _setCountForKind(MasterSetSlotKind kind, int count) {
    final safeCount = count < 0 ? 0 : count;
    switch (kind) {
      case MasterSetSlotKind.normal:
        normalCopies = safeCount;
        break;
      case MasterSetSlotKind.reverseHolo:
        reverseHoloCopies = safeCount;
        break;
      case MasterSetSlotKind.holo:
        holoCopies = safeCount;
        break;
    }
  }

  Future<void> _saveCurrentOwnershipNow(String message) async {
    if (widget.readOnly || _savingOwnership) return;

    setState(() {
      _savingOwnership = true;
    });

    try {
      final ownershipByCardId = await PokedexSyncService.loadCurrentUserSetOwnership(widget.card.setId);
      ownershipByCardId[widget.card.id] = _currentOwnership;
      await LocalPokedexStore.saveSetOwnershipMap(widget.card.setId, ownershipByCardId);
      await PokedexSyncService.syncCurrentSetForCurrentUser(widget.card.setId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save card: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingOwnership = false;
        });
      }
    }
  }

  Future<void> _addSelectedCard() async {
    if (widget.readOnly || _savingOwnership) return;

    setState(() {
      _setCountForKind(selectedSlotKind, _countForKind(selectedSlotKind) + 1);
    });

    final selectedCount = _countForKind(selectedSlotKind);
    await _saveCurrentOwnershipNow(
      selectedCount == 1
          ? '${_labelForKind(selectedSlotKind)} card added'
          : '${_labelForKind(selectedSlotKind)} now x$selectedCount',
    );
  }

  Future<void> _removeSelectedCard() async {
    if (widget.readOnly || _savingOwnership || _countForKind(selectedSlotKind) <= 0) return;

    setState(() {
      _setCountForKind(selectedSlotKind, _countForKind(selectedSlotKind) - 1);
    });

    await _saveCurrentOwnershipNow('${_labelForKind(selectedSlotKind)} count updated');
  }

  void _finishDetails({int? nextIndex}) {
    if (_hasCardNavigation) {
      Navigator.of(context).pop(
        SetCardDetailsResult(
          cardId: widget.card.id,
          ownership: _currentOwnership,
          selectedSlotKind: selectedSlotKind,
          nextIndex: nextIndex,
        ),
      );
      return;
    }

    Navigator.of(context).pop(_currentOwnership);
  }

  void _handleBackRequested(bool didPop) {
    if (didPop) return;
    _finishDetails();
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

  Widget _buildVariantRow(MasterSetSlotKind kind) {
    final selected = selectedSlotKind == kind;
    final count = _countForKind(kind);

    return InkWell(
      onTap: widget.readOnly
          ? null
          : () {
              setState(() {
                selectedSlotKind = kind;
              });
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: selected ? const Color(0xFFF7DE77) : Colors.white54,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _labelForKind(kind),
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: count > 0
                    ? const Color(0xFFF7DE77)
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'x$count',
                style: TextStyle(
                  color: count > 0 ? Colors.black : Colors.white70,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVariantSelector() {
    return Card(
      color: const Color(0xFF102754),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
            child: Row(
              children: [
                const Icon(Icons.layers_rounded, color: Color(0xFFF7DE77)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Choose card version',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildVariantRow(MasterSetSlotKind.normal),
          const Divider(height: 1, color: Colors.white12),
          _buildVariantRow(MasterSetSlotKind.reverseHolo),
          const Divider(height: 1, color: Colors.white12),
          _buildVariantRow(MasterSetSlotKind.holo),
        ],
      ),
    );
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
              decoration: authInputDecoration('Grade number').copyWith(
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
              decoration: authInputDecoration('Condition notes').copyWith(
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
    final card = _pricedCard;
    final selectedLabel = _labelForKind(selectedSlotKind);
    final selectedCount = _countForKind(selectedSlotKind);

    return PopScope<dynamic>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) => _handleBackRequested(didPop),
      child: Scaffold(
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
                        onRefreshPrice: () => _refreshExternalPrice(),
                        refreshingPrice: _refreshingPrice,
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
                                    'Swipe left or right to flow through slots ($_navigationPosition / $_navigationTotal).',
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
                      _buildVariantSelector(),
                      const SizedBox(height: 12),
                      Card(
                        color: const Color(0xFF102754),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Text(
                                '$selectedLabel in Set Pokédex',
                                style: const TextStyle(
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
                                      onPressed: widget.readOnly || selectedCount <= 0 || _savingOwnership
                                          ? null
                                          : _removeSelectedCard,
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
                                    child: _savingOwnership
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : Text(
                                            '$selectedCount',
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
                                      onPressed: widget.readOnly || _savingOwnership ? null : _addSelectedCard,
                                      child: const Text('Add Card'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                widget.readOnly
                                    ? '${widget.ownerLabel ?? 'Shared Pokédex'} is read-only in this view.'
                                    : 'Choose Normal, Reverse Holo, or Holo above. Add Card only updates the selected version.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        color: const Color(0xFF102754),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              const Icon(Icons.inventory_2_outlined, color: Color(0xFFF7DE77)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Total saved copies: x$_totalCopies',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
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
                                      onPressed: _savingOwnership
                                          ? null
                                          : () async {
                                              await _saveCurrentOwnershipNow('Card saved to Set Pokédex');
                                              if (mounted) _finishDetails();
                                            },
                                      child: const Text('Save and Return'),
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
      ),
    );
  }
}
