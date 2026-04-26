import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

  User? get _currentUser => _auth.currentUser;

  String _chatIdFor(String userIdA, String userIdB) {
    final ids = [userIdA, userIdB]..sort();
    return '${ids[0]}_${ids[1]}';
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

  Future<void> _sendMessage() async {
    final user = _currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to send messages.')),
      );
      return;
    }

    if (widget.otherUserId == user.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot message yourself.')),
      );
      return;
    }

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    final chatId = _chatIdFor(user.uid, widget.otherUserId);
    final chatRef = _firestore.collection('chats').doc(chatId);

    await chatRef.set({
      'participants': [user.uid, widget.otherUserId],
      'participantNames': {
        user.uid: _currentUserName,
        widget.otherUserId: widget.otherUserName.trim().isEmpty
            ? 'User'
            : widget.otherUserName.trim(),
      },
      'participantPhotoUrls': {
        user.uid: _currentUserPhotoUrl,
        widget.otherUserId: widget.otherUserPhotoUrl,
      },
      'lastMessage': text,
      'lastSenderId': user.uid,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _messagesRef(chatId).add({
      'senderId': user.uid,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Widget _buildAvatar() {
    final photoUrl = widget.otherUserPhotoUrl?.trim();

    return CircleAvatar(
      backgroundImage:
          photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
      child: photoUrl == null || photoUrl.isEmpty
          ? Text(
              widget.otherUserName.trim().isNotEmpty
                  ? widget.otherUserName.trim()[0].toUpperCase()
                  : '?',
            )
          : null,
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> data) {
    final user = _currentUser;
    final bool isMe = user != null && data['senderId'] == user.uid;
    final String message = (data['text'] ?? '').toString();

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

    final chatId = _chatIdFor(user.uid, widget.otherUserId);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            _buildAvatar(),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.otherUserName.trim().isEmpty
                    ? 'User'
                    : widget.otherUserName.trim(),
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
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        'Could not load messages.\n\n${snapshot.error}',
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
                      'No messages yet.\nSend ${widget.otherUserName} a message.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return _buildMessageBubble(messages[index].data());
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
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Message ${widget.otherUserName}',
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
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
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
