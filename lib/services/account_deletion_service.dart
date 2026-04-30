import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/community_models.dart';
import '../models/custom_binder_models.dart';
import 'collection_refresh_notifier.dart';
import 'community_image_services.dart';
import 'local_custom_binder_store.dart';
import 'local_image_store.dart';

String _firstNonEmptyString(List<dynamic> values) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return '';
}

class AccountDeletionService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static Future<void> deleteCurrentAccount({required String password}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('You need to be signed in to delete your account.');
    }

    final email = (user.email ?? '').trim();
    if (email.isEmpty) {
      throw StateError('This account does not have an email address attached.');
    }

    final trimmedPassword = password.trim();
    if (trimmedPassword.isEmpty) {
      throw StateError('Enter your password to confirm account deletion.');
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: trimmedPassword,
    );
    await user.reauthenticateWithCredential(credential);

    await deleteUserData(uid: user.uid);
    await _clearLocalAccountData(uid: user.uid);
    await user.delete();
  }

  static Future<void> deleteUserData({required String uid}) async {
    final trimmedUid = uid.trim();
    if (trimmedUid.isEmpty) return;

    final userRef = _db.collection('users').doc(trimmedUid);
    final userSnapshot = await userRef.get();
    final profileImageRef = _firstNonEmptyString([
      userSnapshot.data()?['profileImageRef'],
      userSnapshot.data()?['profileImageUrl'],
      userSnapshot.data()?['profileImageBase64'],
    ]);
    await FirebaseImageStorageService.deleteByDownloadUrl(profileImageRef);

    await _deleteSimpleCollection(userRef.collection('wishlist'));
    await _deleteSimpleCollection(userRef.collection('friends'));
    await _deleteSimpleCollection(userRef.collection('blocked_users'));
    await _deletePokedexSets(userRef.collection('pokedex_sets'));
    await _deleteCustomBinders(userRef.collection('custom_binders'));
    await _deleteUserPrivateConversationCopies(trimmedUid);
    await _deleteFriendReferences(trimmedUid);
    await _deleteFriendRequests(trimmedUid);
    await _deleteBlockReferences(trimmedUid);
    await _deleteCommunityReports(trimmedUid);
    await _deleteCommunityRatings(trimmedUid);
    await _deleteCommunityRepliesByUser(trimmedUid);
    await _deleteCommunityPostsByUser(trimmedUid);
    await _deletePrivateConversationsContainingUser(trimmedUid);

    await userRef.delete().catchError((_) {});
  }

  static Future<void> _deleteSimpleCollection(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    while (true) {
      final snapshot = await collection.limit(300).get();
      if (snapshot.docs.isEmpty) break;

      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  static Future<void> _deletePokedexSets(
    CollectionReference<Map<String, dynamic>> setsCollection,
  ) async {
    final setsSnapshot = await setsCollection.get();
    for (final setDoc in setsSnapshot.docs) {
      await _deleteSimpleCollection(setDoc.reference.collection('cards'));
      await setDoc.reference.delete().catchError((_) {});
    }
  }

  static Future<void> _deleteCustomBinders(
    CollectionReference<Map<String, dynamic>> bindersCollection,
  ) async {
    final bindersSnapshot = await bindersCollection.get();
    for (final binderDoc in bindersSnapshot.docs) {
      final binder = CustomBinder.fromJson({
        ...binderDoc.data(),
        'id': binderDoc.id,
      });
      await FirebaseImageStorageService.deleteByDownloadUrl(binder.imageBase64);
      await _deleteSimpleCollection(binderDoc.reference.collection('cards'));
      await binderDoc.reference.delete().catchError((_) {});
    }
  }


  static DocumentReference<Map<String, dynamic>> _userCommunityPrivateConversationRef({
    required String ownerUid,
    required String conversationId,
  }) =>
      _db
          .collection('users')
          .doc(ownerUid)
          .collection('community_private_conversations')
          .doc(conversationId);

  static Future<void> _deleteCommunityPrivateConversationForUser({
    required String ownerUid,
    required String conversationId,
  }) async {
    final trimmedOwnerUid = ownerUid.trim();
    final trimmedConversationId = conversationId.trim();
    if (trimmedOwnerUid.isEmpty || trimmedConversationId.isEmpty) return;

    final conversationRef = _userCommunityPrivateConversationRef(
      ownerUid: trimmedOwnerUid,
      conversationId: trimmedConversationId,
    );

    while (true) {
      final messagesSnapshot = await conversationRef.collection('messages').limit(400).get();
      if (messagesSnapshot.docs.isEmpty) break;

      final batch = _db.batch();
      for (final messageDoc in messagesSnapshot.docs) {
        batch.delete(messageDoc.reference);
      }
      await batch.commit();
    }

    await conversationRef.delete().catchError((_) {});
  }

  static Future<void> _deleteUserPrivateConversationCopies(String uid) async {
    final conversations = await _db
        .collection('users')
        .doc(uid)
        .collection('community_private_conversations')
        .get();

    for (final conversationDoc in conversations.docs) {
      await _deleteCommunityPrivateConversationForUser(
        ownerUid: uid,
        conversationId: conversationDoc.id,
      );
    }
  }

  static Future<void> _deleteFriendReferences(String uid) async {
    final snapshot = await _db.collectionGroup('friends').where('uid', isEqualTo: uid).get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete().catchError((_) {});
    }
  }

  static Future<void> _deleteFriendRequests(String uid) async {
    await _deleteQuery(_db.collection('friend_requests').where('fromUid', isEqualTo: uid));
    await _deleteQuery(_db.collection('friend_requests').where('toUid', isEqualTo: uid));
  }

  static Future<void> _deleteBlockReferences(String uid) async {
    await _deleteQuery(_db.collectionGroup('blocked_users').where('blockedUid', isEqualTo: uid));
  }

  static Future<void> _deleteCommunityReports(String uid) async {
    await _deleteQuery(_db.collection('community_reports').where('reporterUid', isEqualTo: uid));
    await _deleteQuery(_db.collection('community_reports').where('reportedUid', isEqualTo: uid));
  }

  static Future<void> _deleteCommunityRatings(String uid) async {
    await _deleteQuery(_db.collection('community_user_ratings').where('sellerId', isEqualTo: uid));
    await _deleteQuery(_db.collection('community_user_ratings').where('raterId', isEqualTo: uid));
  }

  static Future<void> _deleteCommunityRepliesByUser(String uid) async {
    final replies = await _db.collectionGroup('replies').where('authorId', isEqualTo: uid).get();
    for (final replyDoc in replies.docs) {
      final reply = CommunityReply.fromDoc(replyDoc);
      await FirebaseImageStorageService.deleteByDownloadUrl(reply.imageBase64);
      await replyDoc.reference.delete().catchError((_) {});
    }
  }

  static Future<void> _deleteCommunityPostsByUser(String uid) async {
    final posts = await _db.collection('community_posts').where('authorId', isEqualTo: uid).get();
    for (final postDoc in posts.docs) {
      final post = CommunityPost.fromDoc(postDoc);
      final replies = await postDoc.reference.collection('replies').get();
      for (final replyDoc in replies.docs) {
        final reply = CommunityReply.fromDoc(replyDoc);
        await FirebaseImageStorageService.deleteByDownloadUrl(reply.imageBase64);
        await replyDoc.reference.delete().catchError((_) {});
      }
      for (final imageRef in post.imageBase64List) {
        await FirebaseImageStorageService.deleteByDownloadUrl(imageRef);
      }
      await postDoc.reference.delete().catchError((_) {});
    }
  }

  static Future<void> _deletePrivateConversationsContainingUser(String uid) async {
    final conversations = await _db
        .collection('community_private_conversations')
        .where('participants', arrayContains: uid)
        .get();

    for (final conversationDoc in conversations.docs) {
      final data = conversationDoc.data();
      final participants = ((data['participants'] as List<dynamic>?) ?? const <dynamic>[])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toSet();

      for (final participantUid in participants) {
        await _deleteCommunityPrivateConversationForUser(
          ownerUid: participantUid,
          conversationId: conversationDoc.id,
        );
      }

      await _deleteSimpleCollection(conversationDoc.reference.collection('messages'));
      await conversationDoc.reference.delete().catchError((_) {});
    }
  }

  static Future<void> _deleteQuery(Query<Map<String, dynamic>> query) async {
    while (true) {
      final snapshot = await query.limit(300).get();
      if (snapshot.docs.isEmpty) break;

      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  static Future<void> _clearLocalAccountData({required String uid}) async {
    await LocalProfileImageStore.clearForUser(uid);

    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().toList();
    for (final key in keys) {
      if (key.startsWith('set_pokedex_') || key.startsWith('custom_binder_cards_')) {
        await prefs.remove(key);
      }
    }
    await prefs.remove(LocalCustomBinderStore.bindersKey);
    collectionRefreshNotifier.value++;
  }
}
