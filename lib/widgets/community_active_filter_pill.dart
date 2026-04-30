import 'package:flutter/material.dart';

class CommunityActiveFilterPill extends StatelessWidget {
  const CommunityActiveFilterPill({
    super.key,
    required this.label,
    required this.onRemove,
  });

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7DE77).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFF7DE77).withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF7DE77).withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFFFF2B3),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close,
              size: 15,
              color: Color(0xFFFFF2B3),
            ),
          ),
        ],
      ),
    );
  }
}
