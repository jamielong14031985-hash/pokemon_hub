import 'package:flutter/material.dart';

class TradeSafetyComposerChecklist extends StatelessWidget {
  const TradeSafetyComposerChecklist({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TradeSafetyComposerTip(
          icon: Icons.photo_library_outlined,
          text: 'Add clear photos and mention condition issues before publishing.',
        ),
        SizedBox(height: 8),
        TradeSafetyComposerTip(
          icon: Icons.local_shipping_outlined,
          text: 'Agree tracked postage or a busy public meetup location in messages.',
        ),
        SizedBox(height: 8),
        TradeSafetyComposerTip(
          icon: Icons.description_outlined,
          text: 'Keep a written record of the exact card, price or trade value, and timing.',
        ),
      ],
    );
  }
}

class TradeSafetyComposerTip extends StatelessWidget {
  const TradeSafetyComposerTip({
    super.key,
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFFF7DE77), size: 18),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFFC8D4F0),
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
