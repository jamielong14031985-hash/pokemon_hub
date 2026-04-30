import 'package:flutter/material.dart';

class TradeSafetyMiniBanner extends StatelessWidget {
  const TradeSafetyMiniBanner({
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
          width: double.infinity,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: const Color(0xFFF7DE77).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFF7DE77).withValues(alpha: 0.26)),
          ),
          child: const Row(
            children: [
              Icon(Icons.shield_outlined, color: Color(0xFFF7DE77), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Trade safety centre: proof photos, tracked postage, safe meetups, and payment reminders.',
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
