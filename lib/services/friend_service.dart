import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user_profile.dart';
import '../models/friend_models.dart';

const Duration _kFirebaseReadTimeout = Duration(seconds: 12);
const Duration _kFirebaseWriteTimeout = Duration(seconds: 15);

String _friendRequestId(String fromUid, String toUid) => '${fromUid}_to_$toUid';

String _safeName(String value, {String fallback = 'Trainer'}) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? fallback : trimmed;
}

class FriendService {
  static CollectionReference<Map<String, dynamic>> get _users =>
      FirebaseFirestore.instance.collection('users');

  static CollectionReference<Map<String, dynamic>> get _requests =>
      FirebaseFirestore.instance.collection('friend_requests');

  static DocumentReference<Map<String, dynamic>> _friendDoc(
    String uid,
    String friendUid,
  ) =>
      _users.doc(uid.trim()).collection('friends').doc(friendUid.trim());

  static DocumentReference<Map<String, dynamic>> _requestDoc(
    String fromUid,
    String toUid,
  ) =>
      _requests.doc(_friendRequestId(fromUid.trim(), toUid.trim()));

  static FriendSummary? _safeFriendSummaryFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    try {
      return FriendSummary.fromDoc(doc);
    } catch (_) {
      return null;
    }
  }

  static FriendRequest? _safeFriendRequestFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    try {
      return FriendRequest.fromDoc(doc);
    } catch (_) {
      return null;
    }
  }

  static FriendRequest? _safeFriendRequestFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    try {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return FriendRequest.fromDoc(snapshot);
    } catch (_) {
      return null;
    }
  }

  static Stream<List<FriendSummary>> friendsStream(String uid) async* {
    final safeUid = uid.trim();
    if (safeUid.isEmpty) {
      yield const <FriendSummary>[];
      return;
    }

    try {
      await for (final snapshot
          in _users.doc(safeUid).collection('friends').snapshots()) {
        final items = snapshot.docs
            .map(_safeFriendSummaryFromDoc)
            .whereType<FriendSummary>()
            .toList()
          ..sort((a, b) => b.sinceMs.compareTo(a.sinceMs));

        yield items;
      }
    } catch (_) {
      yield const <FriendSummary>[];
    }
  }

  static Future<List<FriendSummary>> fetchFriends(String uid) async {
    final safeUid = uid.trim();
    if (safeUid.isEmpty) {
      return const <FriendSummary>[];
    }

    try {
      final snapshot = await _users
          .doc(safeUid)
          .collection('friends')
          .get()
          .timeout(_kFirebaseReadTimeout);

      final items = snapshot.docs
          .map(_safeFriendSummaryFromDoc)
          .whereType<FriendSummary>()
          .toList()
        ..sort((a, b) => b.sinceMs.compareTo(a.sinceMs));

      return items;
    } catch (_) {
      return const <FriendSummary>[];
    }
  }

  static Stream<List<FriendRequest>> incomingRequestsStream(String uid) async* {
    final safeUid = uid.trim();
    if (safeUid.isEmpty) {
      yield const <FriendRequest>[];
      return;
    }

    try {
      await for (final snapshot
          in _requests.where('toUid', isEqualTo: safeUid).snapshots()) {
        final items = snapshot.docs
            .map(_safeFriendRequestFromDoc)
            .whereType<FriendRequest>()
            .where((request) => request.isPending)
            .toList()
          ..sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));

        yield items;
      }
    } catch (_) {
      yield const <FriendRequest>[];
    }
  }

  static Stream<List<FriendRequest>> outgoingRequestsStream(String uid) async* {
    final safeUid = uid.trim();
    if (safeUid.isEmpty) {
      yield const <FriendRequest>[];
      return;
    }

    try {
      await for (final snapshot
          in _requests.where('fromUid', isEqualTo: safeUid).snapshots()) {
        final items = snapshot.docs
            .map(_safeFriendRequestFromDoc)
            .whereType<FriendRequest>()
            .where((request) => request.isPending)
            .toList()
          ..sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));

        yield items;
      }
    } catch (_) {
      yield const <FriendRequest>[];
    }
  }

  static Stream<FriendActionState> watchActionState({
    required String currentUid,
    required String otherUid,
  }) {
    final safeCurrentUid = currentUid.trim();
    final safeOtherUid = otherUid.trim();

    final controller = StreamController<FriendActionState>.broadcast();
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? friendSub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? outgoingSub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? incomingSub;

    Future<void> emit() async {
      try {
        final state = await fetchActionState(
          currentUid: safeCurrentUid,
          otherUid: safeOtherUid,
        );
        if (!controller.isClosed) {
          controller.add(state);
        }
      } catch (_) {
        if (!controller.isClosed) {
          controller.add(const FriendActionState(status: FriendActionStatus.none));
        }
      }
    }

    if (safeCurrentUid.isEmpty ||
        safeOtherUid.isEmpty ||
        safeCurrentUid == safeOtherUid) {
      scheduleMicrotask(() {
        if (!controller.isClosed) {
          controller.add(const FriendActionState(status: FriendActionStatus.none));
        }
      });
      return controller.stream;
    }

    friendSub = _friendDoc(safeCurrentUid, safeOtherUid).snapshots().listen(
          (_) => emit(),
          onError: (_) => emit(),
        );

    outgoingSub = _requestDoc(safeCurrentUid, safeOtherUid).snapshots().listen(
          (_) => emit(),
          onError: (_) => emit(),
        );

    incomingSub = _requestDoc(safeOtherUid, safeCurrentUid).snapshots().listen(
          (_) => emit(),
          onError: (_) => emit(),
        );

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
    final safeCurrentUid = currentUid.trim();
    final safeOtherUid = otherUid.trim();

    if (safeCurrentUid.isEmpty ||
        safeOtherUid.isEmpty ||
        safeCurrentUid == safeOtherUid) {
      return const FriendActionState(status: FriendActionStatus.none);
    }

    try {
      final friendSnapshot = await _friendDoc(safeCurrentUid, safeOtherUid)
          .get()
          .timeout(_kFirebaseReadTimeout);

      if (friendSnapshot.exists) {
        return const FriendActionState(status: FriendActionStatus.friends);
      }

      final incomingSnapshot = await _requestDoc(safeOtherUid, safeCurrentUid)
          .get()
          .timeout(_kFirebaseReadTimeout);

      final incomingRequest = _safeFriendRequestFromSnapshot(incomingSnapshot);
      if (incomingRequest != null && incomingRequest.isPending) {
        return FriendActionState(
          status: FriendActionStatus.pendingIncoming,
          request: incomingRequest,
        );
      }

      final outgoingSnapshot = await _requestDoc(safeCurrentUid, safeOtherUid)
          .get()
          .timeout(_kFirebaseReadTimeout);

      final outgoingRequest = _safeFriendRequestFromSnapshot(outgoingSnapshot);
      if (outgoingRequest != null && outgoingRequest.isPending) {
        return FriendActionState(
          status: FriendActionStatus.pendingOutgoing,
          request: outgoingRequest,
        );
      }

      return const FriendActionState(status: FriendActionStatus.none);
    } catch (_) {
      return const FriendActionState(status: FriendActionStatus.none);
    }
  }

  static Future<void> sendRequest({
    required AppUserProfile currentProfile,
    required String otherUid,
    required String otherName,
  }) async {
    final currentUid = currentProfile.uid.trim();
    final targetUid = otherUid.trim();

    if (currentUid.isEmpty || targetUid.isEmpty || currentUid == targetUid) {
      return;
    }

    final currentState = await fetchActionState(
      currentUid: currentUid,
      otherUid: targetUid,
    );

    if (currentState.status == FriendActionStatus.friends ||
        currentState.status == FriendActionStatus.pendingOutgoing) {
      return;
    }

    if (currentState.status == FriendActionStatus.pendingIncoming &&
        currentState.request != null) {
      await acceptRequest(currentState.request!);
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      await _requestDoc(currentUid, targetUid).set({
        'fromUid': currentUid,
        'toUid': targetUid,
        'fromName': _safeName(currentProfile.displayName),
        'toName': _safeName(otherName),
        'status': 'pending',
        'createdAtMs': now,
        'updatedAtMs': now,
      }, SetOptions(merge: true)).timeout(_kFirebaseWriteTimeout);
    } catch (_) {
      throw Exception(
        'Could not send friend request. Please check your connection and try again.',
      );
    }
  }

  static Future<void> acceptRequest(FriendRequest request) async {
    final fromUid = request.fromUid.trim();
    final toUid = request.toUid.trim();

    if (fromUid.isEmpty || toUid.isEmpty || fromUid == toUid) {
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = FirebaseFirestore.instance.batch();

    batch.set(
      _friendDoc(fromUid, toUid),
      {
        'uid': toUid,
        'username': _safeName(request.toName),
        'sinceMs': now,
      },
      SetOptions(merge: true),
    );

    batch.set(
      _friendDoc(toUid, fromUid),
      {
        'uid': fromUid,
        'username': _safeName(request.fromName),
        'sinceMs': now,
      },
      SetOptions(merge: true),
    );

    batch.set(
      _requestDoc(fromUid, toUid),
      {
        'status': 'accepted',
        'updatedAtMs': now,
      },
      SetOptions(merge: true),
    );

    try {
      await batch.commit().timeout(_kFirebaseWriteTimeout);
    } catch (_) {
      throw Exception(
        'Could not accept friend request. Please check your connection and try again.',
      );
    }
  }

  static Future<void> declineRequest(FriendRequest request) async {
    final fromUid = request.fromUid.trim();
    final toUid = request.toUid.trim();

    if (fromUid.isEmpty || toUid.isEmpty || fromUid == toUid) {
      return;
    }

    try {
      await _requestDoc(fromUid, toUid).set({
        'status': 'declined',
        'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true)).timeout(_kFirebaseWriteTimeout);
    } catch (_) {
      throw Exception(
        'Could not decline friend request. Please check your connection and try again.',
      );
    }
  }

  static Future<void> removeFriend({
    required String currentUid,
    required String friendUid,
  }) async {
    final safeCurrentUid = currentUid.trim();
    final safeFriendUid = friendUid.trim();

    if (safeCurrentUid.isEmpty ||
        safeFriendUid.isEmpty ||
        safeCurrentUid == safeFriendUid) {
      return;
    }

    final batch = FirebaseFirestore.instance.batch();

    batch.delete(_friendDoc(safeCurrentUid, safeFriendUid));
    batch.delete(_friendDoc(safeFriendUid, safeCurrentUid));

    try {
      await batch.commit().timeout(_kFirebaseWriteTimeout);
    } catch (_) {
      throw Exception(
        'Could not remove friend. Please check your connection and try again.',
      );
    }
  }
}
