import 'package:flutter/material.dart';

class ProfileInitialAvatar extends StatelessWidget {
  const ProfileInitialAvatar({
    super.key,
    required this.displayLetter,
  });

  final String displayLetter;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF102754),
      alignment: Alignment.center,
      child: Text(
        displayLetter,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
