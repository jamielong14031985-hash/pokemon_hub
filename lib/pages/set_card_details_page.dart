import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/card_ownership.dart';
import '../models/set_card_details_result.dart';
import '../models/tcg_card.dart';
import '../services/local_pokedex_store.dart';
import '../services/pokedex_sync_service.dart';
import '../services/wishlist_service.dart';
import '../utils/auth_input_decoration.dart';
import '../utils/card_condition_helpers.dart';
import '../utils/ebay_sold_search.dart';
import '../utils/master_set_slot_helpers.dart';
import '../widgets/custom_binder_sheets.dart';
import '../widgets/graded_prices_button.dart';
import '../widgets/price_lookup_card.dart';
import '../widgets/set_logo_widgets.dart';
import 'graded_prices_page.dart';


class _ElementalCardImageStage extends StatelessWidget {
  const _ElementalCardImageStage({
    required this.card,
    required this.imageUrl,
  });

  final TcgCard card;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final theme = _ElementalCardTheme.forCard(card);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 360),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: theme.gradientColors,
        ),
        border: Border.all(color: theme.glowColor.withValues(alpha: 0.50)),
        boxShadow: [
          BoxShadow(
            color: theme.glowColor.withValues(alpha: 0.30),
            blurRadius: 28,
            spreadRadius: 2,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: _ElementalBackdrop(theme: theme)),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = (constraints.maxWidth * 0.82).clamp(240.0, 430.0);

              return Padding(
                padding: const EdgeInsets.fromLTRB(18, 28, 18, 28),
                child: Align(
                  alignment: Alignment.center,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      width: cardWidth,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ElementalBackdrop extends StatelessWidget {
  const _ElementalBackdrop({required this.theme});

  final _ElementalCardTheme theme;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          theme.assetPath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: theme.gradientColors,
                ),
              ),
              child: Center(
                child: Icon(
                  theme.icon,
                  color: theme.highlightColor.withValues(alpha: 0.35),
                  size: 90,
                ),
              ),
            );
          },
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.04),
                Colors.black.withValues(alpha: 0.12),
                Colors.black.withValues(alpha: 0.30),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ElementalCardTheme {
  const _ElementalCardTheme({
    required this.patternKey,
    required this.icon,
    required this.gradientColors,
    required this.glowColor,
    required this.accentColor,
    required this.highlightColor,
    required this.assetPath,
  });

  final String patternKey;
  final IconData icon;
  final List<Color> gradientColors;
  final Color glowColor;
  final Color accentColor;
  final Color highlightColor;
  final String assetPath;

  static _ElementalCardTheme forCard(TcgCard card) {
    final key = _elementKeyForCard(card);
    switch (key) {
      case 'grass':
        return const _ElementalCardTheme(
          patternKey: 'grass',
          icon: Icons.energy_savings_leaf_rounded,
          gradientColors: [Color(0xFF061B18), Color(0xFF0A5A33), Color(0xFF9AD05C)],
          glowColor: Color(0xFF70FF87),
          accentColor: Color(0xFF184B25),
          highlightColor: Color(0xFFD8FF8E),
          assetPath: 'assets/card_backgrounds/grass.jpg',
        );
      case 'fire':
        return const _ElementalCardTheme(
          patternKey: 'fire',
          icon: Icons.local_fire_department_rounded,
          gradientColors: [Color(0xFF26070A), Color(0xFFB72E16), Color(0xFFFFB13B)],
          glowColor: Color(0xFFFF6A3D),
          accentColor: Color(0xFF8F1D16),
          highlightColor: Color(0xFFFFE28A),
          assetPath: 'assets/card_backgrounds/fire.jpg',
        );
      case 'water':
        return const _ElementalCardTheme(
          patternKey: 'water',
          icon: Icons.water_drop_rounded,
          gradientColors: [Color(0xFF041635), Color(0xFF0766A3), Color(0xFF7FE7FF)],
          glowColor: Color(0xFF54D8FF),
          accentColor: Color(0xFF0A4779),
          highlightColor: Color(0xFFCFF8FF),
          assetPath: 'assets/card_backgrounds/water.jpg',
        );
      case 'lightning':
        return const _ElementalCardTheme(
          patternKey: 'lightning',
          icon: Icons.bolt_rounded,
          gradientColors: [Color(0xFF211900), Color(0xFFB38300), Color(0xFFFFEC6C)],
          glowColor: Color(0xFFFFE14A),
          accentColor: Color(0xFF7A5800),
          highlightColor: Color(0xFFFFFFB4),
          assetPath: 'assets/card_backgrounds/lightning.jpg',
        );
      case 'psychic':
        return const _ElementalCardTheme(
          patternKey: 'psychic',
          icon: Icons.auto_awesome_rounded,
          gradientColors: [Color(0xFF170A2E), Color(0xFF6D2BC5), Color(0xFFFF86D7)],
          glowColor: Color(0xFFD778FF),
          accentColor: Color(0xFF4D227C),
          highlightColor: Color(0xFFFFD2F1),
          assetPath: 'assets/card_backgrounds/psychic.jpg',
        );
      case 'fighting':
        return const _ElementalCardTheme(
          patternKey: 'fighting',
          icon: Icons.terrain_rounded,
          gradientColors: [Color(0xFF231207), Color(0xFF8F5523), Color(0xFFE6B16A)],
          glowColor: Color(0xFFE5964B),
          accentColor: Color(0xFF6F3D18),
          highlightColor: Color(0xFFFFD9A3),
          assetPath: 'assets/card_backgrounds/fighting.jpg',
        );
      case 'darkness':
        return const _ElementalCardTheme(
          patternKey: 'darkness',
          icon: Icons.dark_mode_rounded,
          gradientColors: [Color(0xFF05070E), Color(0xFF18213B), Color(0xFF58627F)],
          glowColor: Color(0xFF9EA9D6),
          accentColor: Color(0xFF151B2E),
          highlightColor: Color(0xFFD6DCFF),
          assetPath: 'assets/card_backgrounds/darkness.jpg',
        );
      case 'metal':
        return const _ElementalCardTheme(
          patternKey: 'metal',
          icon: Icons.hexagon_rounded,
          gradientColors: [Color(0xFF121821), Color(0xFF56616E), Color(0xFFC7D1DA)],
          glowColor: Color(0xFFCCD7E5),
          accentColor: Color(0xFF38414C),
          highlightColor: Color(0xFFFFFFFF),
          assetPath: 'assets/card_backgrounds/metal.jpg',
        );
      case 'fairy':
        return const _ElementalCardTheme(
          patternKey: 'fairy',
          icon: Icons.favorite_rounded,
          gradientColors: [Color(0xFF2A0A24), Color(0xFFD95EA9), Color(0xFFFFC9EA)],
          glowColor: Color(0xFFFF8CD8),
          accentColor: Color(0xFF923B72),
          highlightColor: Color(0xFFFFE3F5),
          assetPath: 'assets/card_backgrounds/fairy.jpg',
        );
      case 'dragon':
        return const _ElementalCardTheme(
          patternKey: 'dragon',
          icon: Icons.auto_awesome_rounded,
          gradientColors: [Color(0xFF0E1025), Color(0xFF4249B7), Color(0xFFFFC857)],
          glowColor: Color(0xFFFFC857),
          accentColor: Color(0xFF31359C),
          highlightColor: Color(0xFFFFF1A5),
          assetPath: 'assets/card_backgrounds/dragon.jpg',
        );
      default:
        return const _ElementalCardTheme(
          patternKey: 'colorless',
          icon: Icons.style_rounded,
          gradientColors: [Color(0xFF07183D), Color(0xFF16366E), Color(0xFF6E8BC5)],
          glowColor: Color(0xFF86A7F3),
          accentColor: Color(0xFF102754),
          highlightColor: Color(0xFFE2EBFF),
          assetPath: 'assets/card_backgrounds/colorless.jpg',
        );
    }
  }
}

String _elementKeyForCard(TcgCard card) {
  final values = <String>[
    ...card.types,
    card.name,
  ].map((value) => value.toLowerCase()).join(' ');

  bool hasAny(List<String> needles) => needles.any(values.contains);

  final jpName = card.name;
  bool nameHasAny(List<String> needles) => needles.any(jpName.contains);

  if (nameHasAny(<String>[
    'フシギダネ', 'フシギソウ', 'フシギバナ', 'キャタピー', 'トランセル', 'バタフリー',
    'ビードル', 'コクーン', 'スピアー', 'ナゾノクサ', 'クサイハナ', 'ラフレシア',
    'パラス', 'パラセクト', 'コンパン', 'モルフォン', 'マダツボミ', 'ウツドン',
    'ウツボット', 'タマタマ', 'ナッシー', 'モンジャラ', 'ストライク', 'カイロス',
  ])) {
    return 'grass';
  }
  if (nameHasAny(<String>[
    'ヒトカゲ', 'リザード', 'リザードン', 'ロコン', 'キュウコン', 'ガーディ',
    'ウインディ', 'ポニータ', 'ギャロップ', 'ブーバー', 'ブースター', 'ファイヤー',
  ])) {
    return 'fire';
  }
  if (nameHasAny(<String>[
    'ゼニガメ', 'カメール', 'カメックス', 'コダック', 'ゴルダック', 'ニョロモ',
    'ニョロゾ', 'ニョロボン', 'メノクラゲ', 'ドククラゲ', 'ヤドン', 'ヤドラン',
    'パウワウ', 'ジュゴン', 'シェルダー', 'パルシェン', 'クラブ', 'キングラー',
    'タッツー', 'シードラ', 'トサキント', 'アズマオウ', 'ヒトデマン', 'スターミー',
    'コイキング', 'ギャラドス', 'ラプラス', 'シャワーズ', 'オムナイト', 'オムスター',
    'カブト', 'カブトプス', 'フリーザー',
  ])) {
    return 'water';
  }
  if (nameHasAny(<String>[
    'ピカチュウ', 'ライチュウ', 'コイル', 'レアコイル', 'ビリリダマ', 'マルマイン',
    'エレブー', 'サンダース', 'サンダー',
  ])) {
    return 'lightning';
  }
  if (nameHasAny(<String>[
    'ケーシィ', 'ユンゲラー', 'フーディン', 'スリープ', 'スリーパー', 'バリヤード',
    'ルージュラ', 'ミュウ', 'ミュウツー', 'ゴース', 'ゴースト', 'ゲンガー',
    'ニドラン', 'ニドリーナ', 'ニドクイン', 'ニドリーノ', 'ニドキング',
  ])) {
    return 'psychic';
  }
  if (nameHasAny(<String>[
    'サンド', 'サンドパン', 'ディグダ', 'ダグトリオ', 'マンキー', 'オコリザル',
    'ワンリキー', 'ゴーリキー', 'カイリキー', 'イシツブテ', 'ゴローン', 'ゴローニャ',
    'イワーク', 'カラカラ', 'ガラガラ', 'サワムラー', 'エビワラー', 'サイホーン',
    'サイドン',
  ])) {
    return 'fighting';
  }
  if (nameHasAny(<String>['ミニリュウ', 'ハクリュー', 'カイリュー'])) return 'dragon';

  if (hasAny(<String>['grass', 'leaf', 'plant', '草', 'くさ', 'リーフ'])) return 'grass';
  if (hasAny(<String>['fire', 'flame', '炎', 'ほのお', 'ファイヤー'])) return 'fire';
  if (hasAny(<String>['water', 'aqua', '水', 'みず', 'ウォーター'])) return 'water';
  if (hasAny(<String>['lightning', 'electric', 'thunder', '雷', 'でんき', '電'])) return 'lightning';
  if (hasAny(<String>['psychic', '超', 'エスパー'])) return 'psychic';
  if (hasAny(<String>['fighting', 'rock', 'ground', '闘', 'かくとう'])) return 'fighting';
  if (hasAny(<String>['darkness', 'dark', '悪', 'あく'])) return 'darkness';
  if (hasAny(<String>['metal', 'steel', '鋼', 'はがね'])) return 'metal';
  if (hasAny(<String>['fairy', '妖', 'フェアリー'])) return 'fairy';
  if (hasAny(<String>['dragon', '竜', 'ドラゴン'])) return 'dragon';
  return 'colorless';
}

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
  late int pokeBallReverseCopies;
  late int masterBallReverseCopies;
  late Map<String, int> extraVariantCopies;
  late MasterSetSlotKind selectedSlotKind;
  late String condition;
  late String gradingCompany;
  late final TextEditingController _gradeController;
  late final TextEditingController _conditionNotesController;
  bool _setWishlistBusy = false;
  bool _cardDetailsActionsVisible = true;
  bool _savingOwnership = false;

  Future<void> _addToCustomBinder() async {
    await addCardToCustomBinderFlow(context, widget.card);
  }

  @override
  void initState() {
    super.initState();
    if (isSinglePrintSetCard(widget.card)) {
      normalCopies = widget.ownership.collectionCount;
      reverseHoloCopies = 0;
      holoCopies = 0;
      pokeBallReverseCopies = 0;
      masterBallReverseCopies = 0;
      selectedSlotKind = MasterSetSlotKind.normal;
    } else {
      normalCopies = widget.ownership.normalCount;
      reverseHoloCopies = widget.ownership.reverseHoloCount;
      holoCopies = widget.ownership.holoCount;
      pokeBallReverseCopies = widget.ownership.pokeBallReverseCount;
      masterBallReverseCopies = widget.ownership.masterBallReverseCount;
      selectedSlotKind = _initialSelectedSlotKind();
    }
    extraVariantCopies = Map<String, int>.from(widget.ownership.extraVariantCopies);
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

  int get _totalCopies =>
      normalCopies +
      reverseHoloCopies +
      holoCopies +
      pokeBallReverseCopies +
      masterBallReverseCopies +
      extraVariantCopies.values.fold<int>(0, (total, value) => total + (value > 0 ? value : 0));

  CardOwnership get _currentOwnership => CardOwnership(
        normal: normalCopies > 0,
        reverseHolo: reverseHoloCopies > 0,
        holo: holoCopies > 0,
        pokeBallReverse: pokeBallReverseCopies > 0,
        masterBallReverse: masterBallReverseCopies > 0,
        copies: _totalCopies,
        normalCopies: normalCopies,
        reverseHoloCopies: reverseHoloCopies,
        holoCopies: holoCopies,
        pokeBallReverseCopies: pokeBallReverseCopies,
        masterBallReverseCopies: masterBallReverseCopies,
        extraVariantCopies: Map<String, int>.unmodifiable(extraVariantCopies),
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
        if (isSinglePrintSetCard(widget.card)) return 'Holo';
        return 'Normal';
      case MasterSetSlotKind.reverseHolo:
        return 'Reverse Holo';
      case MasterSetSlotKind.holo:
        return 'Holo';
      case MasterSetSlotKind.pokeBallReverse:
        return 'Poke Ball Reverse';
      case MasterSetSlotKind.masterBallReverse:
        return 'Master Ball Reverse';
      case MasterSetSlotKind.firstEditionNormal:
      case MasterSetSlotKind.firstEditionHolo:
      case MasterSetSlotKind.unlimitedNormal:
      case MasterSetSlotKind.unlimitedHolo:
      case MasterSetSlotKind.shadowlessNormal:
      case MasterSetSlotKind.shadowlessHolo:
      case MasterSetSlotKind.cosmosHolo:
      case MasterSetSlotKind.crackedIceHolo:
      case MasterSetSlotKind.setStamped:
      case MasterSetSlotKind.prereleaseStamped:
      case MasterSetSlotKind.staffStamped:
      case MasterSetSlotKind.leagueStamped:
      case MasterSetSlotKind.productExclusive:
        return kind.displayLabel;
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
      case MasterSetSlotKind.pokeBallReverse:
        return pokeBallReverseCopies;
      case MasterSetSlotKind.masterBallReverse:
        return masterBallReverseCopies;
      case MasterSetSlotKind.firstEditionNormal:
      case MasterSetSlotKind.firstEditionHolo:
      case MasterSetSlotKind.unlimitedNormal:
      case MasterSetSlotKind.unlimitedHolo:
      case MasterSetSlotKind.shadowlessNormal:
      case MasterSetSlotKind.shadowlessHolo:
      case MasterSetSlotKind.cosmosHolo:
      case MasterSetSlotKind.crackedIceHolo:
      case MasterSetSlotKind.setStamped:
      case MasterSetSlotKind.prereleaseStamped:
      case MasterSetSlotKind.staffStamped:
      case MasterSetSlotKind.leagueStamped:
      case MasterSetSlotKind.productExclusive:
        return extraVariantCopies[kind.storageId] ?? 0;
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
      case MasterSetSlotKind.pokeBallReverse:
        pokeBallReverseCopies = safeCount;
        break;
      case MasterSetSlotKind.masterBallReverse:
        masterBallReverseCopies = safeCount;
        break;
      case MasterSetSlotKind.firstEditionNormal:
      case MasterSetSlotKind.firstEditionHolo:
      case MasterSetSlotKind.unlimitedNormal:
      case MasterSetSlotKind.unlimitedHolo:
      case MasterSetSlotKind.shadowlessNormal:
      case MasterSetSlotKind.shadowlessHolo:
      case MasterSetSlotKind.cosmosHolo:
      case MasterSetSlotKind.crackedIceHolo:
      case MasterSetSlotKind.setStamped:
      case MasterSetSlotKind.prereleaseStamped:
      case MasterSetSlotKind.staffStamped:
      case MasterSetSlotKind.leagueStamped:
      case MasterSetSlotKind.productExclusive:
        if (safeCount > 0) {
          extraVariantCopies[kind.storageId] = safeCount;
        } else {
          extraVariantCopies.remove(kind.storageId);
        }
        break;
    }
  }

  Future<bool> _saveCurrentOwnershipNow(String message) async {
    if (widget.readOnly || _savingOwnership) return false;

    setState(() {
      _savingOwnership = true;
    });

    try {
      final ownershipByCardId = await PokedexSyncService.loadCurrentUserSetOwnership(widget.card.setId);
      ownershipByCardId[widget.card.id] = _currentOwnership;
      await LocalPokedexStore.saveSetOwnershipMap(widget.card.setId, ownershipByCardId);
      await PokedexSyncService.syncCurrentSetForCurrentUser(widget.card.setId);

      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save card: $error')),
      );
      return false;
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

  Future<void> _addSelectedCardAndReturn() async {
    if (widget.readOnly || _savingOwnership) return;

    setState(() {
      _setCountForKind(selectedSlotKind, _countForKind(selectedSlotKind) + 1);
    });

    final saved = await _saveCurrentOwnershipNow(
      '${_labelForKind(selectedSlotKind)} card added to set',
    );
    if (saved && mounted) _finishDetails();
  }

  MasterSetSlotKind? _firstOwnedSlotKind() {
    for (final kind in MasterSetSlotKind.values) {
      if (_countForKind(kind) > 0) return kind;
    }
    return null;
  }

  MasterSetSlotKind? _firstOwnedSlotKindOtherThan(MasterSetSlotKind kind) {
    for (final option in MasterSetSlotKind.values) {
      if (option == kind) continue;
      if (_countForKind(option) > 0) return option;
    }
    return null;
  }

  Future<void> _removeSelectedCard() async {
    if (widget.readOnly || _savingOwnership || _totalCopies <= 0) return;

    final kindToRemove = _countForKind(selectedSlotKind) > 0
        ? selectedSlotKind
        : _firstOwnedSlotKind();

    if (kindToRemove == null) return;

    setState(() {
      selectedSlotKind = kindToRemove;
      _setCountForKind(kindToRemove, _countForKind(kindToRemove) - 1);

      if (_countForKind(selectedSlotKind) <= 0) {
        final nextKind = _firstOwnedSlotKindOtherThan(selectedSlotKind);
        if (nextKind != null) {
          selectedSlotKind = nextKind;
        }
      }
    });

    await _saveCurrentOwnershipNow('${_labelForKind(kindToRemove)} count updated');
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
    final singlePrint = isSinglePrintSetCard(widget.card);
    final availableKinds = singlePrint
        ? <MasterSetSlotKind>[MasterSetSlotKind.normal]
        : buildMasterSetSlots(<TcgCard>[widget.card])
            .map((slot) => slot.kind)
            .toSet()
            .toList(growable: true);
    if (!availableKinds.contains(selectedSlotKind)) {
      availableKinds.add(selectedSlotKind);
    }
    for (final entry in extraVariantCopies.entries) {
      if (entry.value <= 0) continue;
      for (final kind in MasterSetSlotKind.values) {
        if (kind.storageId == entry.key && !availableKinds.contains(kind)) {
          availableKinds.add(kind);
        }
      }
    }
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
                    singlePrint ? 'Card copies' : 'Choose card version',
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
          for (var index = 0; index < availableKinds.length; index++) ...[
            if (index > 0) const Divider(height: 1, color: Colors.white12),
            _buildVariantRow(availableKinds[index]),
          ],
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
    final card = widget.card;
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
                        _ElementalCardImageStage(
                          card: card,
                          imageUrl: card.largeImageUrl!,
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
                                      onPressed: widget.readOnly || _totalCopies <= 0 || _savingOwnership
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
                                    : 'Choose the card version above. Add Card only updates the selected version.',
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
                                          : _addSelectedCardAndReturn,
                                      child: const Text('Add to Set'),
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
