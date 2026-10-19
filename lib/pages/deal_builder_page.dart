import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/deal_builder_models.dart';
import '../models/tcg_card.dart';
import '../services/currency_settings.dart';
import '../services/local_card_price_store.dart';
import '../services/local_deal_builder_store.dart';
import '../services/pokemon_tcg_service.dart';
import '../services/sealed_collection_store.dart';
import 'master_sets_page.dart';
import 'card_search_page.dart';
import 'sealed_collection_page.dart';

const _navy = Color(0xFF071C49);
const _panel = Color(0xFF142D60);
const _yellow = Color(0xFFF7DE77);

class DealBuilderPage extends StatefulWidget {
  const DealBuilderPage({
    super.key,
    this.initialCard,
    this.initialVariant,
    this.initialSealedProduct,
  });

  /// When opened from a card detail screen, preload the exact selected card.
  final TcgCard? initialCard;
  final String? initialVariant;
  final SealedCollectionItem? initialSealedProduct;

  @override
  State<DealBuilderPage> createState() => _DealBuilderPageState();
}

class _DealBuilderPageState extends State<DealBuilderPage> with SingleTickerProviderStateMixin {
  CollectorDeal? _deal;
  List<CollectorDeal> _saved = <CollectorDeal>[];
  final _titleController = TextEditingController(text: 'New trade');
  final _theirPercentController = TextEditingController(text: '100');
  final _myPercentController = TextEditingController(text: '100');
  late final TabController _tabs;
  bool _loading = true;
  bool _unsaved = false;
  // Legacy saved deals predate image persistence; resolve card artwork lazily.
  final Map<String, Future<String?>> _legacyArtwork = <String, Future<String?>>{};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _tabs.dispose();
    _theirPercentController.dispose();
    _myPercentController.dispose();
    super.dispose();
  }

  CollectorDeal _newDeal() => CollectorDeal(
    id: 'deal_${DateTime.now().microsecondsSinceEpoch}',
    title: 'New trade',
    direction: DealDirection.buying,
    currencyCode: CurrencySettings.selectedCode,
    percentage: 100,
    myPercentage: 100,
    items: const <DealItem>[],
    savedAtMs: 0,
  );

  Future<void> _load() async {
    final deals = await LocalDealBuilderStore.load();
    if (!mounted) return;
    setState(() {
      _saved = deals;
      _deal = _newDeal();
      _loading = false;
    });

    if (widget.initialCard != null || widget.initialSealedProduct != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.initialCard != null) {
          _addCardFromDetails();
        } else {
          _addSealedFromCollection();
        }
      });
    }
  }

  /// Choose where to save a card/sealed product. Does not call pricing APIs.
  Future<bool> _chooseDestination(String title) async {
    final destination = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _panel,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Choose a trade',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ListTile(
              leading: const Icon(Icons.add_circle_outline, color: _yellow),
              title: const Text('Create new trade', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(sheetContext, 'new'),
            ),
            if (_saved.isNotEmpty) SizedBox(
              height: (_saved.length * 65.0).clamp(0.0, 240.0).toDouble(),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _saved.length,
                itemBuilder: (_, index) {
                  final saved = _saved[index];
                  return ListTile(
                    title: Text(saved.title, style: const TextStyle(color: Colors.white)),
                    subtitle: Text('${saved.items.length} items',
                      style: const TextStyle(color: Colors.white70)),
                    onTap: () => Navigator.pop(sheetContext, saved.id),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
    if (!mounted || destination == null) return false;
    if (destination == 'new') {
      _selectDeal(_newDeal().copyWith(title: '$title trade'));
      return true;
    }
    final existing = _saved.where((value) => value.id == destination);
    if (existing.isEmpty) {
      _notice('That saved trade is unavailable.');
      return false;
    }
    _selectDeal(existing.first);
    return true;
  }

  /// Every card/product is explicitly assigned to a side before being saved.
  Future<DealSide?> _chooseSide() async => showModalBottomSheet<DealSide>(
    context: context,
    backgroundColor: _panel,
    builder: (sheetContext) => SafeArea(child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        const Text('Who is offering this item?',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ListTile(
          leading: const Icon(Icons.person_outline, color: _yellow),
          title: const Text('My items', style: TextStyle(color: Colors.white)),
          onTap: () => Navigator.pop(sheetContext, DealSide.mine),
        ),
        ListTile(
          leading: const Icon(Icons.swap_horiz, color: _yellow),
          title: const Text('Their items', style: TextStyle(color: Colors.white)),
          onTap: () => Navigator.pop(sheetContext, DealSide.theirs),
        ),
        const SizedBox(height: 10),
      ],
    )),
  );

  Future<void> _addCardFromDetails() async {
    final card = widget.initialCard;
    if (card == null || !mounted) return;
    if (!await _chooseDestination(card.name) || !mounted) return;
    final side = await _chooseSide();
    if (side == null || !mounted) return;
    _tabs.index = side == DealSide.mine ? 1 : 0;

    final resolved = await LocalCardPriceStore.applySavedPrice(card);
    if (!mounted) return;
    final market = resolved.marketPrice;
    final validMarket = market != null && market > 0 && market.isFinite;
    final sameCurrency = _deal?.currencyCode == CurrencySettings.selectedCode;
    final converted = validMarket && sameCurrency
        ? CurrencySettings.convertAmountSync(
            market, fromCurrency: resolved.marketPriceCurrency)
        : null;
    final price = converted != null && converted > 0 && converted.isFinite
        ? converted : null;
    final variant = widget.initialVariant?.trim() ?? '';
    final description = '${card.setName} · ${card.number}'
        '${variant.isEmpty ? '' : ' · $variant'}';
    final item = await _editItem(
      kind: DealItemKind.card,
      title: card.name,
      subtitle: description,
      source: 'Reference: ${resolved.marketPriceSource}',
      referenceId: card.id,
      imageUrl: resolved.effectiveImageUrl ?? '',
      initialPrice: price,
      side: side,
    );
    if (!mounted || item == null) return;
    _update((deal) => deal.copyWith(items: [...deal.items, item]));
    try {
      await _save();
    } catch (_) {
      _notice('Could not save trade. Please retry.');
    }
  }

  Future<void> _addSealedFromCollection() async {
    final sealed = widget.initialSealedProduct;
    if (sealed == null || !mounted) return;
    if (!await _chooseDestination(sealed.title) || !mounted) return;
    final side = await _chooseSide();
    if (side == null || !mounted) return;
    _tabs.index = side == DealSide.mine ? 1 : 0;
    final canConvert = _deal?.currencyCode == CurrencySettings.selectedCode;
    final price = sealed.marketPrice > 0 && canConvert
        ? CurrencySettings.convertAmountSync(
            sealed.marketPrice, fromCurrency: sealed.currencyCode)
        : null;
    final item = await _editItem(
      kind: DealItemKind.sealedProduct,
      title: sealed.title,
      subtitle: '${sealed.productTypeLabel} · ${sealed.condition}',
      source: 'Saved sealed product guide',
      referenceId: sealed.id,
      imageUrl: sealed.catalogueImageApproved ? sealed.imageUrl : '',
      initialPrice: price != null && price > 0 && price.isFinite ? price : null,
      side: side,
    );
    if (!mounted || item == null) return;
    _update((deal) => deal.copyWith(items: [...deal.items, item]));
    try {
      await _save();
    } catch (_) {
      _notice('Could not save trade. Please retry.');
    }
  }

  String _money(double value) {
    final symbol = CurrencySettings.supportedCurrencies[_deal?.currencyCode]?.symbol ?? '£';
    return '$symbol${value.toStringAsFixed(2)}';
  }

  String _percentText(double value) => value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);

  void _update(CollectorDeal Function(CollectorDeal) change) {
    final current = _deal;
    if (current == null) return;
    setState(() {
      _deal = change(current);
      _unsaved = true;
    });
  }

  Future<bool> _confirmDiscard() async {
    if (!_unsaved) return true;
    return await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Discard unsaved changes?'),
      content: const Text('Save this deal first if you want to keep the current list and percentage.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep editing')),
        TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Discard')),
      ],
    )) ?? false;
  }

  Future<void> _save({bool announce = true}) async {
    final current = _deal;
    if (current == null) {
      _notice('Trade is not ready.');
      return;
    }
    final saved = current.copyWith(
      title: _titleController.text.trim().isEmpty ? 'Untitled trade' : _titleController.text.trim(),
      savedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await LocalDealBuilderStore.save(saved);
    final deals = await LocalDealBuilderStore.load();
    if (!mounted) return;
    setState(() {
      _deal = saved;
      _saved = deals;
      _unsaved = false;
    });
    if (announce) _notice('Trade saved on this device.');
  }

  void _notice(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _selectDeal(CollectorDeal saved) {
    setState(() {
      _deal = saved;
      _titleController.text = saved.title;
      _theirPercentController.text = _percentText(saved.percentage);
      _myPercentController.text = _percentText(saved.myPercentage);
      _unsaved = false;
    });
  }

  Future<void> _openSaved() async {
    final selection = await showModalBottomSheet<String>(
      context: context, isScrollControlled: true,
      backgroundColor: _panel,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Saved trades', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            if (_saved.isEmpty)
              const Padding(padding: EdgeInsets.all(20), child: Text('No saved trades yet.', style: TextStyle(color: Colors.white70))),
            Flexible(child: ListView(shrinkWrap: true, children: _saved.map((deal) => ListTile(
              title: Text(deal.title, style: const TextStyle(color: Colors.white)),
              subtitle: Text('${deal.items.length} items · ${deal.currencyCode}',
                style: const TextStyle(color: Colors.white70)),
              trailing: IconButton(
                tooltip: 'Delete saved deal',
                onPressed: () => Navigator.pop(sheetContext, 'delete:${deal.id}'),
                icon: const Icon(Icons.delete_outline, color: Colors.white70),
              ),
              onTap: () => Navigator.pop(sheetContext, deal.id),
            )).toList())),
          ]),
        ),
      ),
    );
    if (!mounted || selection == null) return;
    if (selection.startsWith('delete:')) {
      final id = selection.substring(7);
      await LocalDealBuilderStore.delete(id);
      final saved = await LocalDealBuilderStore.load();
      if (!mounted) return;
      setState(() => _saved = saved);
      _notice('Saved trade deleted.');
      return;
    }
    if (!await _confirmDiscard() || !mounted) return;
    for (final deal in _saved) {
      if (deal.id == selection) {
        _selectDeal(deal);
        break;
      }
    }
  }

  Future<void> _new() async {
    if (!await _confirmDiscard() || !mounted) return;
    _selectDeal(_newDeal());
  }

  Future<void> _share() async {
    final deal = _deal;
    if (deal == null || deal.items.isEmpty) {
      _notice('Add some trade items first.');
      return;
    }
    final buffer = StringBuffer('PocketChase trade — ${deal.title}\n');
    for (final side in DealSide.values) {
      buffer.writeln(side == DealSide.mine ? 'MY ITEMS' : 'THEIR ITEMS');
      final values = deal.items.where((item) => item.side == side);
      for (final item in values) {
        buffer.writeln('${item.quantity} × ${item.title}'
          '${item.subtitle.isEmpty ? '' : ' (${item.subtitle})'}: '
          '${item.hasPrice ? _money(item.pricedTotal) : 'Unpriced'}');
      }
      buffer.writeln('Subtotal: ${_money(side == DealSide.mine ? deal.myValue : deal.theirValue)}');
    }
    buffer.writeln('Their adjusted value (${_percentText(deal.percentage)}%): ${_money(deal.adjustedTheirValue)}');
    buffer.writeln('My adjusted value (${_percentText(deal.myPercentage)}%): ${_money(deal.adjustedMyValue)}');
    if (deal.unpricedCount > 0) {
      buffer.writeln('WARNING: ${deal.unpricedCount} unpriced item(s); cash balance is incomplete.');
    }
    if (deal.cashBalance > 0.005) {
      buffer.writeln('You add ${_money(deal.cashBalance)} cash.');
    } else if (deal.cashBalance < -0.005) {
      buffer.writeln('They add ${_money(-deal.cashBalance)} cash.');
    } else {
      buffer.writeln('No cash difference based on entered prices.');
    }
    buffer.writeln('Guide values only; not verified sales or a binding agreement.');
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    _notice('Trade summary copied.');
  }

  // Keep text controllers owned by the dialog itself, not this page.
  // showDialog's Future can complete before the reverse route animation ends;
  // disposing here would detach controllers while TextFields still animate out.
  Future<DealItem?> _editItem({
    required DealItemKind kind,
    String title = '', String subtitle = '', String source = '', String referenceId = '',
    String imageUrl = '',
    DealSide side = DealSide.mine,
    int quantity = 1, double? initialPrice,
    String? existingId,
  }) => showDialog<DealItem>(
    context: context,
    builder: (_) => _DealItemEditorDialog(
      kind: kind,
      title: title,
      subtitle: subtitle,
      source: source,
      referenceId: referenceId,
      imageUrl: imageUrl,
      side: side,
      quantity: quantity,
      initialPrice: initialPrice,
      existingId: existingId,
      currencyCode: _deal?.currencyCode ?? 'GBP',
    ),
  );

  void _changeQuantity(DealItem item, int quantity) {
    if (quantity < 1 || quantity > 999) return;
    _update((deal) => deal.copyWith(items: [
      for (final old in deal.items) old.id == item.id ? old.copyWith(quantity: quantity) : old,
    ]));
  }

  Future<void> _editExisting(DealItem item) async {
    final changed = await _editItem(
      kind: item.kind, title: item.title, subtitle: item.subtitle,
      initialPrice: item.unitPrice, quantity: item.quantity,
      source: item.priceSource, referenceId: item.referenceId,
      imageUrl: item.imageUrl,
      existingId: item.id,
      side: item.side,
    );
    if (changed == null) return;
    _update((deal) => deal.copyWith(items: [
      for (final old in deal.items) old.id == item.id ? changed : old,
    ]));
  }

  Future<String?> _findLegacyArtwork(String cardId) async {
    try {
      // Uses the existing Pokémon catalogue's cached card lookup, NOT JustTCG.
      // It doesn't refresh or alter the saved guide price.
      final card = await PokemonTcgService.fetchCardById(cardId);
      return card.effectiveImageUrl;
    } catch (_) {
      return null;
    }
  }

  Widget _imagePlaceholder(DealItem item) => Container(
    width: 72,
    height: 102,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: const Color(0xFF203966),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white12),
    ),
    child: Icon(
      item.kind == DealItemKind.card
          ? Icons.style_outlined
          : Icons.inventory_2_outlined,
      color: _yellow,
      size: 28,
    ),
  );

  Widget _thumbnailFromUrl(DealItem item, String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      return _imagePlaceholder(item);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 72,
        height: 102,
        color: const Color(0xFF203966),
        child: Image.network(
          url,
          width: 72,
          height: 102,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => _imagePlaceholder(item),
          loadingBuilder: (context, child, loadingProgress) =>
              loadingProgress == null ? child : _imagePlaceholder(item),
        ),
      ),
    );
  }

  Widget _itemThumbnail(DealItem item) {
    if (item.imageUrl.trim().isNotEmpty) {
      return _thumbnailFromUrl(item, item.imageUrl.trim());
    }
    if (item.kind != DealItemKind.card || item.referenceId.trim().isEmpty) {
      return _imagePlaceholder(item);
    }
    // Older deals don't have imageUrl. Try to show the exact original card
    // without forcing the collector to delete and re-add the saved item.
    final id = item.referenceId.trim();
    return FutureBuilder<String?>(
      future: _legacyArtwork.putIfAbsent(id, () => _findLegacyArtwork(id)),
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (url == null || url.trim().isEmpty) return _imagePlaceholder(item);
        return _thumbnailFromUrl(item, url.trim());
      },
    );
  }

  // Full-width card. The small side-by-side v5 columns made this unreadable.
  Widget _tradeItem(DealItem item) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: _panel,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 64, height: 92, child: _itemThumbnail(item)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(item.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 7),
          Text(item.hasPrice ? _money(item.pricedTotal) : 'Unpriced',
            style: const TextStyle(color: _yellow, fontSize: 18, fontWeight: FontWeight.bold)),
          if (item.hasPrice) Text('${_money(item.unitPrice!)} each · ${item.priceSource}',
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white60, fontSize: 11))
          else const Text('Not counted in cash difference',
            style: TextStyle(color: Colors.white70, fontSize: 11)),
        ])),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        const Text('Qty', style: TextStyle(color: Colors.white70, fontSize: 12)),
        IconButton(tooltip: 'Decrease quantity',
          visualDensity: VisualDensity.compact,
          onPressed: item.quantity > 1 ? () => _changeQuantity(item, item.quantity - 1) : null,
          icon: const Icon(Icons.remove_circle_outline, color: Colors.white70, size: 22)),
        Text('${item.quantity}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        IconButton(tooltip: 'Increase quantity',
          visualDensity: VisualDensity.compact,
          onPressed: item.quantity < 999 ? () => _changeQuantity(item, item.quantity + 1) : null,
          icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 22)),
        const Spacer(),
        IconButton(tooltip: 'Move to other collector',
          onPressed: () => _update((deal) => deal.copyWith(items: [
            for (final old in deal.items) old.id == item.id
                ? old.copyWith(side: old.side == DealSide.mine ? DealSide.theirs : DealSide.mine)
                : old,
          ])),
          icon: const Icon(Icons.swap_horiz, color: _yellow)),
        IconButton(tooltip: 'Edit item', onPressed: () => _editExisting(item),
          icon: const Icon(Icons.edit_outlined, color: Colors.white70)),
        IconButton(tooltip: 'Remove item',
          onPressed: () => _update((deal) => deal.copyWith(items:
            deal.items.where((old) => old.id != item.id).toList())),
          icon: const Icon(Icons.delete_outline, color: Colors.white70)),
      ]),
    ]),
  );

  Future<void> _addCatalogueCard(DealSide side) async {
    // Use PocketChase's real Search cards page, in selection mode.
    // The regular search UI and set results remain available.
    // CardSearchPage is embedded inside AppShell in normal browsing. Give
    // this standalone selection route the same Material/Scaffold ancestors,
    // otherwise its Material widgets can render incorrectly.
    final card = await Navigator.of(context).push<TcgCard>(MaterialPageRoute<TcgCard>(
      builder: (_) => Scaffold(
        backgroundColor: _navy,
        appBar: AppBar(
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          title: const Text('Search Cards'),
        ),
        body: const SafeArea(child: CardSearchPage(selectForDeal: true)),
      ),
    ));
    if (card == null || !mounted) return;
    final resolved = await LocalCardPriceStore.applySavedPrice(card);
    if (!mounted) return;
    final market = resolved.marketPrice;
    final sameCurrency = _deal?.currencyCode == CurrencySettings.selectedCode;
    final converted = market != null && market > 0 && market.isFinite && sameCurrency
        ? CurrencySettings.convertAmountSync(market, fromCurrency: resolved.marketPriceCurrency)
        : null;
    final price = converted != null && converted > 0 && converted.isFinite ? converted : null;
    final chosen = await _editItem(
      kind: DealItemKind.card,
      title: card.name,
      subtitle: '${card.setName} · ${card.number}',
      referenceId: card.id,
      imageUrl: resolved.effectiveImageUrl ?? '',
      initialPrice: price,
      source: 'Reference: ${resolved.marketPriceSource}',
      side: side,
    );
    if (!mounted || chosen == null) return;
    _update((deal) => deal.copyWith(items: [...deal.items, chosen]));
  }

  Future<void> _addSealedItem(DealSide side) async {
    // Open the full sealed collection even when empty; this behaves like
    // PocketChase's normal sealed-items button and never spends pricing credits.
    // Show the real sealed collection, grouped by Pokémon set, rather
    // than the old flat picker. Choose a product within its set.
    final sealed = await Navigator.of(context).push<SealedCollectionItem>(
      MaterialPageRoute<SealedCollectionItem>(
        builder: (_) => const SealedCollectionPage(selectForDeal: true),
      ),
    );
    if (sealed == null || !mounted) return;
    final canConvert = _deal?.currencyCode == CurrencySettings.selectedCode;
    final converted = sealed.marketPrice > 0 && canConvert
        ? CurrencySettings.convertAmountSync(sealed.marketPrice, fromCurrency: sealed.currencyCode)
        : null;
    final price = converted != null && converted > 0 && converted.isFinite ? converted : null;
    final item = await _editItem(
      kind: DealItemKind.sealedProduct,
      title: sealed.title,
      subtitle: '${sealed.productTypeLabel} · ${sealed.condition}',
      referenceId: sealed.id,
      imageUrl: sealed.catalogueImageApproved ? sealed.imageUrl : '',
      initialPrice: price,
      source: 'Saved sealed product guide',
      side: side,
    );
    if (!mounted || item == null) return;
    _update((deal) => deal.copyWith(items: [...deal.items, item]));
  }

  /// Open the existing Sets and Binders page. The card-detail Add to Deal
  /// action already knows how to add a card to an existing locally saved trade.
  Future<void> _openBinders(DealSide side) async {
    final current = _deal;
    if (current == null) return;
    try {
      await _save(announce: false); // Including empty drafts: destination must exist.
    } catch (_) {
      _notice('Save this trade before opening binders.');
      return;
    }
    if (!mounted) return;
    _notice('In Binders, open a card, tap Add to Deal and choose ${side == DealSide.mine ? 'My items' : 'Their items'}.');
    // MasterSetsPage is normally hosted inside AppShell's Scaffold. Opening
    // it as a bare route leaves InkWells without a Material ancestor and can
    // trigger 'No Material widget found' when opening binders.
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        backgroundColor: _navy,
        appBar: AppBar(
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          title: const Text('Sets & Binders'),
        ),
        body: const SafeArea(child: MasterSetsPage()),
      ),
    ));
    if (!mounted) return;
    final stored = await LocalDealBuilderStore.load();
    if (!mounted) return;
    final matches = stored.where((value) => value.id == current.id);
    setState(() => _saved = stored);
    if (matches.isNotEmpty) _selectDeal(matches.first);
  }

  Widget _addButton(String label, IconData icon, VoidCallback tap) =>
    Expanded(child: OutlinedButton(
      onPressed: tap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white24),
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: _yellow, size: 21),
        const SizedBox(height: 4),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
      ]),
    ));

  Widget _percentageControl(CollectorDeal deal, DealSide side) {
    final mine = side == DealSide.mine;
    final percent = mine ? deal.myPercentage : deal.percentage;
    final controller = mine ? _myPercentController : _theirPercentController;
    void changePercent(double value) {
      if (!value.isFinite || value < 0 || value > 200) return;
      _update((old) => mine
          ? old.copyWith(myPercentage: value)
          : old.copyWith(percentage: value));
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('Percentage of market guide',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14))),
          SizedBox(width: 76, child: TextField(
            controller: controller,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(isDense: true, suffixText: '%'),
            onChanged: (value) {
              final parsed = double.tryParse(value);
              if (parsed != null) changePercent(parsed);
            },
          )),
        ]),
        Slider(
          min: 0, max: 150, divisions: 30,
          activeColor: _yellow,
          value: percent.clamp(0.0, 150.0).toDouble(),
          onChanged: (value) {
            controller.text = _percentText(value);
            changePercent(value);
          },
        ),
        Wrap(spacing: 7, runSpacing: 5, children: [
          for (final value in [70, 80, 85, 90, 100])
            ChoiceChip(
              label: Text('$value%'),
              selected: (percent - value).abs() < 0.001,
              selectedColor: _yellow,
              labelStyle: TextStyle(color: (percent - value).abs() < 0.001
                  ? Colors.black : Colors.white),
              backgroundColor: _navy,
              onSelected: (_) {
                controller.text = '$value';
                changePercent(value.toDouble());
              },
            ),
        ]),
      ]),
    );
  }

  Widget _tabContents(CollectorDeal deal, DealSide side) {
    final mine = side == DealSide.mine;
    final items = mine ? deal.myItems : deal.theirItems;
    final value = mine ? deal.myValue : deal.theirValue;
    final adjusted = mine ? deal.adjustedMyValue : deal.adjustedTheirValue;
    final unpriced = mine ? deal.myUnpriced : deal.theirUnpriced;
    return ListView(
      key: PageStorageKey<String>('deal_tab_${side.name}'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
      children: [
        Row(children: [
          Expanded(child: Text('${items.length} item(s)',
            style: const TextStyle(color: Colors.white70, fontSize: 13))),
          Text('Guide ${_money(value)}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _addButton('Search cards', Icons.search, () => _addCatalogueCard(side)),
          const SizedBox(width: 8),
          _addButton('Sealed items', Icons.inventory_2_outlined, () => _addSealedItem(side)),
          const SizedBox(width: 8),
          _addButton('Binders', Icons.collections_bookmark_outlined, () => _openBinders(side)),
        ]),
        const SizedBox(height: 14),
        if (items.isEmpty) Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(14)),
          child: Text(mine
            ? 'No items on your side yet. Choose a source above to add an item.'
            : 'No items on their side yet. Choose a source above to add an item.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, height: 1.4)),
        ),
        for (final item in items) _tradeItem(item),
        const SizedBox(height: 8),
        _percentageControl(deal, side),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            _sideTotalRow('Guide total', _money(value)),
            const SizedBox(height: 6),
            _sideTotalRow('Adjusted total', _money(adjusted), strong: true),
            if (unpriced > 0) Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text('$unpriced unpriced item(s) excluded from totals',
                style: const TextStyle(color: _yellow, fontSize: 12)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text('In Binders, open a card, tap Add to Deal, choose this trade and ${mine ? 'My items' : 'Their items'}. Return here to see it.',
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ),
      ],
    );
  }

  Widget _sideTotalRow(String label, String value, {bool strong = false}) =>
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(color: strong ? Colors.white : Colors.white70,
        fontWeight: strong ? FontWeight.w600 : FontWeight.normal)),
      Text(value, style: TextStyle(color: strong ? _yellow : Colors.white,
        fontSize: strong ? 18 : 14, fontWeight: FontWeight.w700)),
    ]);

  Widget _footer(CollectorDeal deal) {
    final bothSides = deal.myItems.isNotEmpty && deal.theirItems.isNotEmpty;
    final diff = deal.cashBalance;
    final String cashMessage;
    if (!bothSides) {
      cashMessage = 'Add items to both tabs to compare';
    } else if (diff > 0.005) {
      cashMessage = 'You add ${_money(diff)} cash';
    } else if (diff < -0.005) {
      cashMessage = 'They add ${_money(-diff)} cash';
    } else {
      cashMessage = 'Even trade — no cash needed';
    }
    return SafeArea(top: false, child: Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 10),
      decoration: const BoxDecoration(color: _panel,
        border: Border(top: BorderSide(color: Colors.white24))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(child: Text('Their ${_money(deal.adjustedTheirValue)}  ·  My ${_money(deal.adjustedMyValue)}',
            style: const TextStyle(color: Colors.white70, fontSize: 12))),
        ]),
        const SizedBox(height: 6),
        Text(cashMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _yellow, fontSize: 19, fontWeight: FontWeight.w800)),
        if (deal.unpricedCount > 0) Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('${deal.unpricedCount} unpriced item(s); cash amount is incomplete',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _yellow, fontSize: 11)),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: FilledButton.icon(
            onPressed: () => _save(),
            icon: const Icon(Icons.save_outlined, size: 18),
            label: Text(_unsaved ? 'Save trade *' : 'Save trade'),
            style: FilledButton.styleFrom(backgroundColor: _yellow, foregroundColor: Colors.black),
          )),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(
            onPressed: _share,
            icon: const Icon(Icons.copy_outlined, size: 18),
            label: const Text('Copy offer'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
          )),
        ]),
      ]),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final deal = _deal;
    return Scaffold(
      backgroundColor: _navy,
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: const Text('Deal Builder'),
        actions: [
          IconButton(tooltip: 'Saved trades', onPressed: _loading ? null : _openSaved,
            icon: const Icon(Icons.folder_open_outlined)),
          IconButton(tooltip: 'New trade', onPressed: _loading ? null : _new,
            icon: const Icon(Icons.note_add_outlined)),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: _yellow,
          labelColor: _yellow,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Their items', icon: Icon(Icons.people_outline)),
            Tab(text: 'My items', icon: Icon(Icons.person_outline)),
          ],
        ),
      ),
      body: _loading || deal == null
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(controller: _tabs, children: [
              _tabContents(deal, DealSide.theirs),
              _tabContents(deal, DealSide.mine),
            ]),
      bottomNavigationBar: _loading || deal == null ? null : _footer(deal),
    );
  }
}

/// Owns the TextField controllers until the dialog route is fully disposed.
/// In particular this keeps the keyboard/Focus/TextField lifecycle stable
/// when confirming a sealed-product price with the keyboard still open.
class _DealItemEditorDialog extends StatefulWidget {
  const _DealItemEditorDialog({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.source,
    required this.referenceId,
    required this.imageUrl,
    required this.side,
    required this.quantity,
    required this.initialPrice,
    required this.existingId,
    required this.currencyCode,
  });

  final DealItemKind kind;
  final String title;
  final String subtitle;
  final String source;
  final String referenceId;
  final String imageUrl;
  final DealSide side;
  final int quantity;
  final double? initialPrice;
  final String? existingId;
  final String currencyCode;

  @override
  State<_DealItemEditorDialog> createState() => _DealItemEditorDialogState();
}

class _DealItemEditorDialogState extends State<_DealItemEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _detail;
  late final TextEditingController _price;
  late final TextEditingController _qty;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.title);
    _detail = TextEditingController(text: widget.subtitle);
    _price = TextEditingController(text: widget.initialPrice == null
        ? '' : widget.initialPrice!.toStringAsFixed(2));
    _qty = TextEditingController(text: '${widget.quantity}');
  }

  @override
  void dispose() {
    _name.dispose();
    _detail.dispose();
    _price.dispose();
    _qty.dispose();
    super.dispose();
  }

  void _confirm() {
    final cleanName = _name.text.trim();
    final count = int.tryParse(_qty.text.trim());
    final rawPrice = _price.text.replaceAll(',', '').trim();
    final amount = rawPrice.isEmpty ? null : double.tryParse(rawPrice);
    if (cleanName.isEmpty || count == null || count < 1 || count > 999 ||
        (rawPrice.isNotEmpty &&
            (amount == null || amount <= 0 || !amount.isFinite))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enter a name, quantity 1–999, and a valid positive price or leave price blank.'),
      ));
      return;
    }
    final initialPrice = widget.initialPrice;
    final wasModified = initialPrice != null && amount != null &&
        (initialPrice - amount).abs() > 0.001;
    final item = DealItem(
      id: widget.existingId ?? 'item_${DateTime.now().microsecondsSinceEpoch}',
      kind: widget.kind,
      title: cleanName,
      subtitle: _detail.text.trim(),
      quantity: count,
      unitPrice: amount,
      priceSource: amount == null
          ? 'Unpriced'
          : (wasModified || widget.source.isEmpty
              ? 'Manually entered guide' : widget.source),
      referenceId: widget.referenceId,
      imageUrl: widget.imageUrl.trim(),
      side: widget.side,
    );
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(item);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.kind == DealItemKind.card
        ? 'Add single card' : 'Add sealed product'),
    scrollable: true,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _name,
          maxLength: 120,
          decoration: const InputDecoration(labelText: 'Item name *'),
        ),
        TextField(
          controller: _detail,
          maxLength: 120,
          decoration: const InputDecoration(
              labelText: 'Set, number, variant or condition'),
        ),
        TextField(
          controller: _qty,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Quantity'),
        ),
        TextField(
          controller: _price,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Unit guide price (${widget.currencyCode})',
            helperText: 'Leave blank if unpriced. Review converted guides.',
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Prices are snapshots and can be edited. Reference guides are not verified sales.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () {
          FocusScope.of(context).unfocus();
          Navigator.of(context).pop();
        },
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _confirm, child: const Text('Add to deal')),
    ],
  );
}
