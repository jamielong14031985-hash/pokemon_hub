import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/master_set_slot_helpers.dart';

class CardRaritySymbolBadge extends StatelessWidget {
  const CardRaritySymbolBadge({
    super.key,
    required this.slot,
    required this.owned,
  });

  final MasterSetCardSlot slot;
  final bool owned;

  bool get _isJapaneseCard {
    final id = slot.card.id.toLowerCase().trim();
    final setId = slot.card.setId.toLowerCase().trim();
    return id.startsWith('jp_') || setId.startsWith('jp_');
  }

  @override
  Widget build(BuildContext context) {
    Widget symbol;

    if (slot.kind == MasterSetSlotKind.pokeBallReverse) {
      symbol = const _BallSymbol(masterBall: false);
    } else if (slot.kind == MasterSetSlotKind.masterBallReverse) {
      symbol = const _BallSymbol(masterBall: true);
    } else if (_isJapaneseCard) {
      symbol = _buildJapaneseSymbol();
    } else {
      symbol = _buildEnglishSymbol();
    }

    return Opacity(
      opacity: owned ? 1 : 0.68,
      child: SizedBox(
        width: 22,
        height: 14,
        child: Align(
          alignment: Alignment.bottomLeft,
          child: symbol,
        ),
      ),
    );
  }

  Widget _buildEnglishSymbol() {
    final rarity = (slot.card.rarity ?? '').toLowerCase().trim();
    final isReverse = slot.kind == MasterSetSlotKind.reverseHolo;
    final isHolo = slot.kind == MasterSetSlotKind.holo;

    final symbol = _englishPrintedRaritySymbol(rarity);

    // Reverse/Holo are print treatments rather than separate rarity symbols.
    // Keep the real card rarity symbol and add only a tiny foil sparkle so
    // duplicate printings can still be distinguished without RH/H text.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Align(
          alignment: Alignment.bottomLeft,
          child: symbol,
        ),
        if (isReverse)
          const Positioned(
            right: 0,
            top: -1,
            child: _TinySparkle(
              color: Color(0xFFD7E2EE),
            ),
          ),
        if (isHolo)
          const Positioned(
            right: 0,
            top: -1,
            child: _TinySparkle(
              color: Color(0xFFF2D46B),
            ),
          ),
      ],
    );
  }

  Widget _englishPrintedRaritySymbol(String rarity) {
    if (rarity.contains('special illustration rare') ||
        rarity.contains('special art rare')) {
      return const _LabelSymbol(
        label: 'SIR',
        tone: _LabelTone.gold,
      );
    }

    if (rarity.contains('illustration rare')) {
      return const _LabelSymbol(
        label: 'IR',
        tone: _LabelTone.gold,
      );
    }

    if (rarity.contains('ultra rare') ||
        rarity.contains('rare ultra')) {
      return const _LabelSymbol(
        label: 'UR',
        tone: _LabelTone.silver,
      );
    }

    if (rarity.contains('hyper rare')) {
      return const _LabelSymbol(
        label: 'HR',
        tone: _LabelTone.gold,
      );
    }

    if (rarity.contains('secret rare') ||
        rarity.contains('rare secret')) {
      return const _LabelSymbol(
        label: 'SR',
        tone: _LabelTone.gold,
      );
    }

    if (rarity.contains('ace spec')) {
      return const _LabelSymbol(
        label: 'ACE',
        tone: _LabelTone.magenta,
      );
    }

    if (rarity.contains('double rare')) {
      return const _LabelSymbol(
        label: 'DR',
        tone: _LabelTone.silver,
      );
    }

    if (rarity.contains('radiant')) {
      return const _LabelSymbol(
        label: 'RAD',
        tone: _LabelTone.gold,
      );
    }

    if (rarity.contains('amazing rare')) {
      return const _LabelSymbol(
        label: 'AR',
        tone: _LabelTone.gold,
      );
    }

    if (rarity.contains('rainbow')) {
      return const _LabelSymbol(
        label: 'RR',
        tone: _LabelTone.gold,
      );
    }

    if (rarity.contains('rare holo vmax') ||
        rarity.contains('vmax')) {
      return const _LabelSymbol(
        label: 'VMAX',
        tone: _LabelTone.silver,
      );
    }

    if (rarity.contains('rare holo vstar') ||
        rarity.contains('vstar')) {
      return const _LabelSymbol(
        label: 'VSTAR',
        tone: _LabelTone.silver,
      );
    }

    if (rarity.contains('rare holo gx')) {
      return const _LabelSymbol(
        label: 'GX',
        tone: _LabelTone.silver,
      );
    }

    if (rarity.contains('rare holo ex')) {
      return const _LabelSymbol(
        label: 'EX',
        tone: _LabelTone.silver,
      );
    }

    if (rarity.contains('rare holo v')) {
      return const _LabelSymbol(
        label: 'V',
        tone: _LabelTone.silver,
      );
    }

    if (rarity.contains('rare prime')) {
      return const _LabelSymbol(
        label: 'PRM',
        tone: _LabelTone.silver,
      );
    }

    if (rarity.contains('rare prism')) {
      return const _LabelSymbol(
        label: 'PS',
        tone: _LabelTone.silver,
      );
    }

    if (rarity.contains('rare break')) {
      return const _LabelSymbol(
        label: 'BRK',
        tone: _LabelTone.silver,
      );
    }

    // Check Uncommon before Common because "uncommon" contains "common".
    if (rarity.contains('uncommon')) {
      return const _DiamondSymbol();
    }

    if (rarity.contains('common')) {
      return const _CircleSymbol();
    }

    if (rarity.contains('rare') || rarity.contains('holo')) {
      return const _StarSymbol();
    }

    return const _UnknownRaritySymbol();
  }

  Widget _buildJapaneseSymbol() {
    final rawRarity = (slot.card.rarity ?? '').trim();
    final code = _japaneseRarityCode(rawRarity);
    final isReverse = slot.kind == MasterSetSlotKind.reverseHolo;
    final isHolo = slot.kind == MasterSetSlotKind.holo;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Align(
          alignment: Alignment.bottomLeft,
          child: Text(
            code.isEmpty ? '•' : code,
            style: TextStyle(
              color: _japaneseRarityColour(code),
              fontSize: _japaneseFontSize(code),
              fontWeight: FontWeight.w900,
              height: 1,
              letterSpacing: -0.45,
              shadows: const [
                Shadow(
                  color: Colors.white70,
                  blurRadius: 1,
                ),
              ],
            ),
          ),
        ),
        if (isReverse)
          const Positioned(
            right: 0,
            top: -1,
            child: _TinySparkle(
              color: Color(0xFFD7E2EE),
            ),
          ),
        if (isHolo)
          const Positioned(
            right: 0,
            top: -1,
            child: _TinySparkle(
              color: Color(0xFFF2D46B),
            ),
          ),
      ],
    );
  }

  String _japaneseRarityCode(String raw) {
    if (raw.trim().isEmpty) return '';

    final compact = raw
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '');

    const printedCodes = <String>{
      'C',
      'U',
      'R',
      'RR',
      'AR',
      'SR',
      'SAR',
      'UR',
      'HR',
      'CHR',
      'CSR',
      'SSR',
      'S',
      'K',
      'A',
      'PR',
      'BWR',
      'MHR',
    };

    if (printedCodes.contains(compact)) {
      return compact;
    }

    final rarity = raw.toLowerCase();

    if (rarity.contains('special illustration rare') ||
        rarity.contains('special art rare')) {
      return 'SAR';
    }
    if (rarity.contains('character super rare')) return 'CSR';
    if (rarity.contains('character rare')) return 'CHR';
    if (rarity.contains('shiny ultra rare')) return 'SSR';
    if (rarity.contains('shiny rare')) return 'S';
    if (rarity.contains('mega hyper rare')) return 'MHR';
    if (rarity.contains('black white rare')) return 'BWR';
    if (rarity.contains('illustration rare')) return 'AR';
    if (rarity.contains('double rare')) return 'RR';
    if (rarity.contains('ultra rare')) return 'UR';
    if (rarity.contains('hyper rare')) return 'HR';
    if (rarity.contains('secret rare')) return 'SR';
    if (rarity.contains('amazing rare')) return 'A';
    if (rarity.contains('radiant')) return 'K';
    if (rarity.contains('promo')) return 'PR';
    if (rarity.contains('uncommon')) return 'U';
    if (rarity.contains('common')) return 'C';
    if (rarity.contains('rare')) return 'R';

    return compact.length <= 4
        ? compact
        : compact.substring(0, 4);
  }

  Color _japaneseRarityColour(String code) {
    switch (code) {
      case 'UR':
      case 'HR':
      case 'SAR':
      case 'SR':
      case 'AR':
        return const Color(0xFFD5AA2A);

      case 'RR':
      case 'SSR':
        return const Color(0xFF9DA8B5);

      default:
        return Colors.black;
    }
  }

  double _japaneseFontSize(String code) {
    if (code.length <= 1) return 7.5;
    if (code.length == 2) return 6.8;
    if (code.length == 3) return 6.2;
    return 5.6;
  }
}

class _CircleSymbol extends StatelessWidget {
  const _CircleSymbol();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5.5,
      height: 5.5,
      decoration: const BoxDecoration(
        color: Colors.black,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.white70,
            blurRadius: 0.8,
          ),
        ],
      ),
    );
  }
}

class _DiamondSymbol extends StatelessWidget {
  const _DiamondSymbol();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        width: 5.5,
        height: 5.5,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(0.4),
          boxShadow: const [
            BoxShadow(
              color: Colors.white70,
              blurRadius: 0.8,
            ),
          ],
        ),
      ),
    );
  }
}

class _StarSymbol extends StatelessWidget {
  const _StarSymbol();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.star_rounded,
      size: 7,
      color: Colors.black,
      shadows: [
        Shadow(
          color: Colors.white70,
          blurRadius: 0.8,
        ),
      ],
    );
  }
}

enum _LabelTone {
  black,
  silver,
  gold,
  magenta,
}

class _LabelSymbol extends StatelessWidget {
  const _LabelSymbol({
    required this.label,
    required this.tone,
  });

  final String label;
  final _LabelTone tone;

  Color get _colour {
    switch (tone) {
      case _LabelTone.black:
        return Colors.black;
      case _LabelTone.silver:
        return const Color(0xFF9DA8B5);
      case _LabelTone.gold:
        return const Color(0xFFD5AA2A);
      case _LabelTone.magenta:
        return const Color(0xFFC233A9);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = label.length <= 2
        ? 7.0
        : label.length == 3
            ? 6.2
            : 5.4;

    return Text(
      label,
      maxLines: 1,
      style: TextStyle(
        color: _colour,
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        height: 1,
        letterSpacing: -0.45,
        shadows: const [
          Shadow(
            color: Colors.white70,
            blurRadius: 0.8,
          ),
        ],
      ),
    );
  }
}

class _UnknownRaritySymbol extends StatelessWidget {
  const _UnknownRaritySymbol();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5.5,
      height: 5.5,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.black,
          width: 0.9,
        ),
      ),
    );
  }
}

class _TinySparkle extends StatelessWidget {
  const _TinySparkle({
    required this.color,
  });

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.auto_awesome,
      size: 4.5,
      color: color,
      shadows: const [
        Shadow(
          color: Colors.black54,
          blurRadius: 1,
        ),
      ],
    );
  }
}

class _BallSymbol extends StatelessWidget {
  const _BallSymbol({
    required this.masterBall,
  });

  final bool masterBall;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 10,
      height: 10,
      child: CustomPaint(
        painter: _BallPainter(
          masterBall: masterBall,
        ),
      ),
    );
  }
}

class _BallPainter extends CustomPainter {
  const _BallPainter({
    required this.masterBall,
  });

  final bool masterBall;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 0.5;

    final glow = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(centre, radius + 0.25, glow);

    final outline = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(centre, radius, outline);

    final line = Paint()
      ..color = Colors.black
      ..strokeWidth = 0.8;

    canvas.drawLine(
      Offset(0.7, size.height / 2),
      Offset(size.width - 0.7, size.height / 2),
      line,
    );

    canvas.drawCircle(
      centre,
      1.5,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      centre,
      1.5,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7,
    );

    if (masterBall) {
      final painter = TextPainter(
        text: const TextSpan(
          text: 'M',
          style: TextStyle(
            color: Colors.black,
            fontSize: 4,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      painter.paint(
        canvas,
        Offset(
          centre.dx - painter.width / 2,
          -0.4,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BallPainter oldDelegate) {
    return oldDelegate.masterBall != masterBall;
  }
}
