import 'package:flutter/material.dart';

class TradeSafetyPrivateReminder extends StatelessWidget {
  const TradeSafetyPrivateReminder({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF7DE77).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFF7DE77).withValues(alpha: 0.24)),
          ),
          child: const Row(
            children: [
              Icon(Icons.shield_outlined, color: Color(0xFFF7DE77), size: 20),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Safety reminder: confirm photos, condition, tracking, and payment details before agreeing.',
                  style: TextStyle(
                    color: Color(0xFFFFF2B3),
                    fontSize: 12,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: Color(0xFFF7DE77)),
            ],
          ),
        ),
      ),
    );
  }
}
