import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/private_chat_screen.dart';

class ClickableUserName extends StatelessWidget {
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const ClickableUserName({
    super.key,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = userName.trim().isEmpty ? 'User' : userName.trim();

    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () {
        final currentUser = FirebaseAuth.instance.currentUser;

        if (currentUser == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please log in to send a message.')),
          );
          return;
        }

        if (userId.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This user cannot be messaged.')),
          );
          return;
        }

        if (userId == currentUser.uid) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This is your account.')),
          );
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PrivateChatScreen(
              otherUserId: userId,
              otherUserName: displayName,
              otherUserPhotoUrl: userPhotoUrl,
            ),
          ),
        );
      },
      child: Text(
        displayName,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
        style: style ??
            const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blueAccent,
            ),
      ),
    );
  }
}
