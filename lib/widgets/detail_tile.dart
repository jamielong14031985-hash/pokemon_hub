import 'package:flutter/material.dart';

class DetailTile extends StatelessWidget {
  const DetailTile({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF102754),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(
          label,
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(color: Colors.white70),
        ),
      ),
    );
  }
}