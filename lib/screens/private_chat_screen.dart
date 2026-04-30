import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const Duration _kFirebaseWriteTimeout = Duration(seconds: 15);

class PrivateChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPhotoUrl;

  const PrivateChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPhotoUrl,
  });

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isSending = false;

  User? get _currentUser => _auth.currentUser;

  String _safeDisplayName(String value, {String fallback = 'User'}) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  String _chatIdFor(String userIdA, String userIdB) {
    final ids = <String>[
      userIdA.trim(),
      userIdB.trim(),
    ].where((id) => id.isNotEmpty).toList()
      ..sort();

    if (ids.length < 2) return '';

    return '${ids[0]}_${ids[1]}'.replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]'),
      '_',
    );
  }

  String get _currentUserName {
    final user = _currentUser;
    final displayName = user?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;

    final email = user?.email?.trim();
    if (email != null && email.isNotEmpty) return email.split('@').first;

    return 'User';
  }

  String? get _currentUserPhotoUrl {
    final photoUrl = _currentUser?.photoURL?.trim();
    if (photoUrl == null || photoUrl.isEmpty) return null;
    return photoUrl;
  }

  CollectionReference<Map<String, dynamic>> _messagesRef(String chatId) {
    return _firestore.collection('chats').doc(chatId).collection('messages');
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _sendMessage() async {
    if (_isSending) return;

    final user = _currentUser;
    if (user == null) {
      _showMessage('Please log in to send messages.');
      return;
    }

    final otherUserId = widget.otherUserId.trim();
    if (otherUserId.isEmpty) {
      _showMessage('This user could not be found.');
      return;
    }

    if (otherUserId == user.uid) {
      _showMessage('You cannot message yourself.');
      return;
    }

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final chatId = _chatIdFor(user.uid, otherUserId);
    if (chatId.isEmpty) {
      _showMessage('Could not start this chat.');
      return;
    }

    setState(() {
      _isSending = true;
    });

    _messageController.clear();

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final chatRef = _firestore.collection('chats').doc(chatId);
    final messageRef = _messagesRef(chatId).doc();

    try {
      final batch = _firestore.batch();

      batch.set(
        chatRef,
        {
          'participants': <String>[user.uid, otherUserId],
          'participantNames': <String, String>{
            user.uid: _currentUserName,
            otherUserId: _safeDisplayName(widget.otherUserName),
          },
          'participantPhotoUrls': <String, String?>{
            user.uid: _currentUserPhotoUrl,
            otherUserId: widget.otherUserPhotoUrl?.trim(),
          },
          'lastMessage': text,
          'lastSenderId': user.uid,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedAtMs': nowMs,
          'createdAt': FieldValue.serverTimestamp(),
          'createdAtMs': nowMs,
        },
        SetOptions(merge: true),
      );

      batch.set(
        messageRef,
        {
          'id': messageRef.id,
          'senderId': user.uid,
          'text': text,
          'createdAt': FieldValue.serverTimestamp(),
          'createdAtMs': nowMs,
        },
        SetOptions(merge: true),
      );

      await batch.commit().timeout(_kFirebaseWriteTimeout);
    } catch (_) {
      if (mounted) {
        _messageController.text = text;
        _messageController.selection = TextSelection.fromPosition(
          TextPosition(offset: _messageController.text.length),
        );
      }

      _showMessage(
        'Could not send this message. Please check your connection and try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Widget _buildAvatar() {
    final photoUrl = widget.otherUserPhotoUrl?.trim();
    final displayName = _safeDisplayName(widget.otherUserName);

    return CircleAvatar(
      backgroundImage:
          photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
      child: photoUrl == null || photoUrl.isEmpty
          ? Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : '?')
          : null,
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> data) {
    final user = _currentUser;
    final bool isMe = user != null && data['senderId'] == user.uid;
    final String message = (data['text'] ?? '').toString().trim();

    if (message.isEmpty) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: isMe ? Colors.blueAccent : Colors.grey.shade300,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Text(
          message,
          style: TextStyle(
            color: isMe ? Colors.white : Colors.black87,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Private Message')),
        body: const Center(
          child: Text('Please log in to send private messages.'),
        ),
      );
    }

    final otherUserId = widget.otherUserId.trim();
    if (otherUserId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Private Message')),
        body: const Center(
          child: Text('This user could not be found.'),
        ),
      );
    }

    final chatId = _chatIdFor(user.uid, otherUserId);
    final otherUserName = _safeDisplayName(widget.otherUserName);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            _buildAvatar(),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                otherUserName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _messagesRef(chatId)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text(
                        'Could not load messages right now.\nPlease check your connection and try again.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data?.docs ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet.\nSend $otherUserName a message.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    try {
                      return _buildMessageBubble(messages[index].data());
                    } catch (_) {
                      return const SizedBox.shrink();
                    }
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      enabled: !_isSending,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Message $otherUserName',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor:
                        _isSending ? Colors.grey : Colors.blueAccent,
                    child: IconButton(
                      icon: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.send, color: Colors.white),
                      onPressed: _isSending ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
