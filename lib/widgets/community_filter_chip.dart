import 'package:flutter/material.dart';

class CommunityFilterChip extends StatelessWidget {
  const CommunityFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.minWidth = 88,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: minWidth),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? null : const Color(0xFF16366E),
              gradient: selected
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFF7DE77),
                        Color(0xFFFFF2B3),
                      ],
                    )
                  : null,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? const Color(0xFFFFF2B3)
                    : Colors.white.withValues(alpha: 0.14),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: const Color(0xFFF7DE77).withValues(alpha: 0.26),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : const [],
            ),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.black : const Color(0xFFE4ECFF),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
