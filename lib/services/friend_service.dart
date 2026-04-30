import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user_profile.dart';
import '../models/friend_models.dart';

String _friendRequestId(String fromUid, String toUid) => '${fromUid}_to_$toUid';

class FriendService {
  static CollectionReference<Map<String, dynamic>> get _users =>
      FirebaseFirestore.instance.collection('users');

  static CollectionReference<Map<String, dynamic>> get _requests =>
      FirebaseFirestore.instance.collection('friend_requests');

  static DocumentReference<Map<String, dynamic>> _friendDoc(String uid, String friendUid) =>
      _users.doc(uid).collection('friends').doc(friendUid);

  static DocumentReference<Map<String, dynamic>> _requestDoc(String fromUid, String toUid) =>
      _requests.doc(_friendRequestId(fromUid, toUid));

  static Stream<List<FriendSummary>> friendsStream(String uid) {
    return _users.doc(uid).collection('friends').snapshots().map((snapshot) {
      final items = snapshot.docs.map(FriendSummary.fromDoc).toList()
        ..sort((a, b) => b.sinceMs.compareTo(a.sinceMs));
      return items;
    });
  }

  static Future<List<FriendSummary>> fetchFriends(String uid) async {
    if (uid.trim().isEmpty) {
      return const <FriendSummary>[];
    }

    final snapshot = await _users.doc(uid).collection('friends').get();
    final items = snapshot.docs.map(FriendSummary.fromDoc).toList()
      ..sort((a, b) => b.sinceMs.compareTo(a.sinceMs));
    return items;
  }

  static Stream<List<FriendRequest>> incomingRequestsStream(String uid) {
    return _requests.where('toUid', isEqualTo: uid).snapshots().map((snapshot) {
      final items = snapshot.docs
          .map(FriendRequest.fromDoc)
          .where((request) => request.isPending)
          .toList()
        ..sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
      return items;
    });
  }

  static Stream<List<FriendRequest>> outgoingRequestsStream(String uid) {
    return _requests.where('fromUid', isEqualTo: uid).snapshots().map((snapshot) {
      final items = snapshot.docs
          .map(FriendRequest.fromDoc)
          .where((request) => request.isPending)
          .toList()
        ..sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
      return items;
    });
  }

  static Stream<FriendActionState> watchActionState({
    required String currentUid,
    required String otherUid,
  }) {
    final controller = StreamController<FriendActionState>.broadcast();
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? friendSub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? outgoingSub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? incomingSub;

    Future<void> emit() async {
      try {
        final state = await fetchActionState(currentUid: currentUid, otherUid: otherUid);
        if (!controller.isClosed) {
          controller.add(state);
        }
      } catch (_) {
        if (!controller.isClosed) {
          controller.add(const FriendActionState(status: FriendActionStatus.none));
        }
      }
    }

    friendSub = _friendDoc(currentUid, otherUid).snapshots().listen((_) => emit());
    outgoingSub = _requestDoc(currentUid, otherUid).snapshots().listen((_) => emit());
    incomingSub = _requestDoc(otherUid, currentUid).snapshots().listen((_) => emit());
    emit();

    controller.onCancel = () async {
      await friendSub?.cancel();
      await outgoingSub?.cancel();
      await incomingSub?.cancel();
      if (!controller.isClosed) {
        await controller.close();
      }
    };

    return controller.stream;
  }

  static Future<FriendActionState> fetchActionState({
    required String currentUid,
    required String otherUid,
  }) async {
    if (currentUid.trim().isEmpty || otherUid.trim().isEmpty || currentUid == otherUid) {
      return const FriendActionState(status: FriendActionStatus.none);
    }

    final friendSnapshot = await _friendDoc(currentUid, otherUid).get();
    if (friendSnapshot.exists) {
      return const FriendActionState(status: FriendActionStatus.friends);
    }

    final incomingSnapshot = await _requestDoc(otherUid, currentUid).get();
    final incomingRequest = incomingSnapshot.exists ? FriendRequest.fromDoc(incomingSnapshot) : null;
    if (incomingRequest != null && incomingRequest.isPending) {
      return FriendActionState(
        status: FriendActionStatus.pendingIncoming,
        request: incomingRequest,
      );
    }

    final outgoingSnapshot = await _requestDoc(currentUid, otherUid).get();
    final outgoingRequest = outgoingSnapshot.exists ? FriendRequest.fromDoc(outgoingSnapshot) : null;
    if (outgoingRequest != null && outgoingRequest.isPending) {
      return FriendActionState(
        status: FriendActionStatus.pendingOutgoing,
        request: outgoingRequest,
      );
    }

    return const FriendActionState(status: FriendActionStatus.none);
  }

  static Future<void> sendRequest({
    required AppUserProfile currentProfile,
    required String otherUid,
    required String otherName,
  }) async {
    final currentUid = currentProfile.uid.trim();
    final targetUid = otherUid.trim();
    if (currentUid.isEmpty || targetUid.isEmpty || currentUid == targetUid) return;

    final currentState = await fetchActionState(currentUid: currentUid, otherUid: targetUid);
    if (currentState.status == FriendActionStatus.friends ||
        currentState.status == FriendActionStatus.pendingOutgoing) {
      return;
    }

    if (currentState.status == FriendActionStatus.pendingIncoming && currentState.request != null) {
      await acceptRequest(currentState.request!);
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    await _requestDoc(currentUid, targetUid).set({
      'fromUid': currentUid,
      'toUid': targetUid,
      'fromName': currentProfile.displayName,
      'toName': otherName.trim().isEmpty ? 'Trainer' : otherName.trim(),
      'status': 'pending',
      'createdAtMs': now,
      'updatedAtMs': now,
    }, SetOptions(merge: true));
  }

  static Future<void> acceptRequest(FriendRequest request) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = FirebaseFirestore.instance.batch();

    batch.set(
      _friendDoc(request.fromUid, request.toUid),
      {
        'uid': request.toUid,
        'username': request.toName,
        'sinceMs': now,
      },
      SetOptions(merge: true),
    );
    batch.set(
      _friendDoc(request.toUid, request.fromUid),
      {
        'uid': request.fromUid,
        'username': request.fromName,
        'sinceMs': now,
      },
      SetOptions(merge: true),
    );
    batch.set(
      _requestDoc(request.fromUid, request.toUid),
      {
        'status': 'accepted',
        'updatedAtMs': now,
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  static Future<void> declineRequest(FriendRequest request) async {
    await _requestDoc(request.fromUid, request.toUid).set({
      'status': 'declined',
      'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
    }, SetOptions(merge: true));
  }
}
