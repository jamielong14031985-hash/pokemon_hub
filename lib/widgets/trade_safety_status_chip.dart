import 'package:flutter/material.dart';

class TradeSafetyChecklistItem {
  const TradeSafetyChecklistItem({
    required this.label,
    required this.complete,
    required this.icon,
    required this.helper,
  });

  final String label;
  final bool complete;
  final IconData icon;
  final String helper;
}

class TradeSafetyStatusChip extends StatelessWidget {
  const TradeSafetyStatusChip({
    super.key,
    required this.item,
  });

  final TradeSafetyChecklistItem item;

  @override
  Widget build(BuildContext context) {
    final completeColor = item.complete ? const Color(0xFF54D39A) : const Color(0xFFF0A83A);
    return Tooltip(
      message: item.helper,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: completeColor.withValues(alpha: item.complete ? 0.12 : 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: completeColor.withValues(alpha: item.complete ? 0.30 : 0.24)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.complete ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
              size: 14,
              color: completeColor,
            ),
            const SizedBox(width: 5),
            Text(
              item.label,
              style: TextStyle(
                color: item.complete ? const Color(0xFFDFFBEA) : const Color(0xFFFFE3B0),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
