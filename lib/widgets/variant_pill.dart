import 'package:flutter/material.dart';

class VariantPill extends StatelessWidget {
  const VariantPill({
    super.key,
    required this.label,
    required this.active,
  });

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? const Color(0xFFF7DE77) : Colors.white12,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active ? const Color(0xFFF7DE77) : Colors.white24,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? Colors.black : Colors.white70,
          fontSize: 8,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
