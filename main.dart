import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'firebase_options.dart';
import 'pokemon_hub_vision_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await CurrencySettings.init();
  runApp(const PokemonHubApp());
}

final ValueNotifier<int> collectionRefreshNotifier = ValueNotifier<int>(0);
final ValueNotifier<int> currencyRefreshNotifier = ValueNotifier<int>(0);

class SupportedCurrency {
  const SupportedCurrency({
    required this.code,
    required this.label,
    required this.symbol,
  });

  final String code;
  final String label;
  final String symbol;
}

class CurrencySettings {
  static const String _prefsKey = 'selected_currency_code';

  static const Map<String, SupportedCurrency> supportedCurrencies =
      <String, SupportedCurrency>{
    'GBP': SupportedCurrency(
      code: 'GBP',
      label: 'British Pound',
      symbol: '£',
    ),
    'USD': SupportedCurrency(
      code: 'USD',
      label: 'US Dollar',
      symbol: r'$',
    ),
    'EUR': SupportedCurrency(
      code: 'EUR',
      label: 'Euro',
      symbol: '€',
    ),
  };

  static final Map<String, Map<String, double>> _ratesByBase =
      <String, Map<String, double>>{
    'USD': <String, double>{'USD': 1, 'GBP': 0.79, 'EUR': 0.92},
    'EUR': <String, double>{'EUR': 1, 'GBP': 0.86, 'USD': 1.09},
    'GBP': <String, double>{'GBP': 1, 'USD': 1.26, 'EUR': 1.16},
  };

  static String _selectedCode = 'GBP';

  static String get selectedCode => _selectedCode;

  static SupportedCurrency get selectedCurrency =>
      supportedCurrencies[_selectedCode] ?? supportedCurrencies['GBP']!;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(_prefsKey)?.toUpperCase();
    if (savedCode != null && supportedCurrencies.containsKey(savedCode)) {
      _selectedCode = savedCode;
    }

    await Future.wait(<Future<void>>[
      _ensureRatesForBase('USD'),
      _ensureRatesForBase('EUR'),
      _ensureRatesForBase('GBP'),
    ]);
  }

  static Future<void> setSelectedCode(String code) async {
    final normalized = code.trim().toUpperCase();
    if (!supportedCurrencies.containsKey(normalized)) return;

    await Future.wait(<Future<void>>[
      _ensureRatesForBase('USD'),
      _ensureRatesForBase('EUR'),
      _ensureRatesForBase('GBP'),
    ]);

    _selectedCode = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, normalized);
    currencyRefreshNotifier.value++;
  }

  static Future<void> _ensureRatesForBase(String base) async {
    final quotes = supportedCurrencies.keys.where((item) => item != base).join(',');
    final uri = Uri.parse(
      'https://api.frankfurter.dev/v1/latest?base=$base&symbols=$quotes',
    );

    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) return;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final rawRates = (json['rates'] as Map<String, dynamic>? ?? const <String, dynamic>{});
      final parsed = <String, double>{base: 1};

      for (final entry in rawRates.entries) {
        final value = (entry.value as num?)?.toDouble();
        if (value != null && value > 0) {
          parsed[entry.key.toUpperCase()] = value;
        }
      }

      for (final currency in supportedCurrencies.keys) {
        parsed.putIfAbsent(
          currency,
          () => _ratesByBase[base]?[currency] ?? (currency == base ? 1 : 0),
        );
      }

      _ratesByBase[base] = parsed;
    } catch (_) {}
  }

  static double? convertAmountSync(
    double? amount, {
    required String fromCurrency,
  }) {
    if (amount == null || !amount.isFinite) return null;

    final normalizedFrom = fromCurrency.trim().toUpperCase();
    if (amount <= 0) return amount;
    if (normalizedFrom == _selectedCode) return amount;

    final directRate = _ratesByBase[normalizedFrom]?[_selectedCode];
    if (directRate != null && directRate > 0) {
      return amount * directRate;
    }

    if (normalizedFrom != 'USD') {
      final toUsd = _ratesByBase[normalizedFrom]?['USD'];
      final fromUsd = _ratesByBase['USD']?[_selectedCode];
      if (toUsd != null && toUsd > 0 && fromUsd != null && fromUsd > 0) {
        return amount * toUsd * fromUsd;
      }
    }

    return amount;
  }

  static String formatAmount(
    double? amount, {
    String fromCurrency = 'USD',
  }) {
    final converted = convertAmountSync(amount, fromCurrency: fromCurrency);
    if (converted == null || converted <= 0) return 'Unavailable';
    return '${selectedCurrency.symbol}${converted.toStringAsFixed(2)}';
  }

  static String formatSelectedAmount(double? amount) {
    if (amount == null || !amount.isFinite || amount <= 0) {
      return 'Unavailable';
    }
    return '${selectedCurrency.symbol}${amount.toStringAsFixed(2)}';
  }
}

class _MoneyValue {
  const _MoneyValue({
    required this.amount,
    required this.currencyCode,
  });

  final double amount;
  final String currencyCode;
}

class LocalImageStore {
  static Future<Directory> _rootDirectory() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final directory = Directory('${documentsDir.path}/pokemon_hub_images');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  static String _safeFileName(String value) {
    final cleaned = value
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
    return cleaned.isEmpty ? 'image' : cleaned;
  }

  static String _extensionFromPath(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1) return '.jpg';

    final extension = path.substring(dotIndex);
    if (extension.length > 8 || extension.contains('/') || extension.contains(r'\')) {
      return '.jpg';
    }
    return extension;
  }

  static Future<String> saveImagePermanently({
    required String sourcePath,
    required String category,
    required String fileNamePrefix,
  }) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      return sourcePath;
    }

    final rootDirectory = await _rootDirectory();
    final categoryDirectory = Directory('${rootDirectory.path}/$category');
    if (!await categoryDirectory.exists()) {
      await categoryDirectory.create(recursive: true);
    }

    final extension = _extensionFromPath(sourcePath);
    final safePrefix = _safeFileName(fileNamePrefix);
    final fileName = '${safePrefix}_${DateTime.now().microsecondsSinceEpoch}$extension';
    final savedFile = await sourceFile.copy('${categoryDirectory.path}/$fileName');
    return savedFile.path;
  }

  static Future<String?> migrateImagePathIfNeeded({
    required String? currentPath,
    required String category,
    required String fileNamePrefix,
  }) async {
    if (currentPath == null || currentPath.trim().isEmpty) return currentPath;

    final trimmedPath = currentPath.trim();
    final sourceFile = File(trimmedPath);
    if (!await sourceFile.exists()) {
      return currentPath;
    }

    final rootDirectory = await _rootDirectory();
    if (trimmedPath.startsWith(rootDirectory.path)) {
      return trimmedPath;
    }

    return saveImagePermanently(
      sourcePath: trimmedPath,
      category: category,
      fileNamePrefix: fileNamePrefix,
    );
  }

  static Future<void> deleteManagedImage(String? path) async {
    if (path == null || path.trim().isEmpty) return;

    final trimmedPath = path.trim();
    final rootDirectory = await _rootDirectory();
    if (!trimmedPath.startsWith(rootDirectory.path)) return;

    final file = File(trimmedPath);
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }
}

class LocalProfileImageStore {
  static String _prefsKey(String uid) => 'profile_image_path_$uid';

  static Future<String?> loadForUser(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    String? imagePath = prefs.getString(_prefsKey(uid));

    final migratedImagePath = await LocalImageStore.migrateImagePathIfNeeded(
      currentPath: imagePath,
      category: 'profiles',
      fileNamePrefix: '${uid}_profile_avatar',
    );

    if (migratedImagePath != null && migratedImagePath != imagePath) {
      await prefs.setString(_prefsKey(uid), migratedImagePath);
      imagePath = migratedImagePath;
    }

    return imagePath;
  }

  static Future<String?> saveForUser({
    required String uid,
    required String sourcePath,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final oldManagedPath = prefs.getString(_prefsKey(uid));

    final permanentPath = await LocalImageStore.saveImagePermanently(
      sourcePath: sourcePath,
      category: 'profiles',
      fileNamePrefix: '${uid}_profile_avatar',
    );

    await prefs.setString(_prefsKey(uid), permanentPath);
    if (oldManagedPath != permanentPath) {
      await LocalImageStore.deleteManagedImage(oldManagedPath);
    }
    return permanentPath;
  }

  static Future<void> clearForUser(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final existingPath = prefs.getString(_prefsKey(uid));
    await prefs.remove(_prefsKey(uid));
    await LocalImageStore.deleteManagedImage(existingPath);
  }
}

class AppUserProfile {
  const AppUserProfile({
    required this.uid,
    required this.email,
    required this.username,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  final String uid;
  final String email;
  final String username;
  final int createdAtMs;
  final int updatedAtMs;

  String get displayName => username.trim().isEmpty ? 'Trainer' : username.trim();

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'username': username,
        'createdAtMs': createdAtMs,
        'updatedAtMs': updatedAtMs,
      };

  factory AppUserProfile.fromMap(Map<String, dynamic> json) {
    return AppUserProfile(
      uid: (json['uid'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
      updatedAtMs: (json['updatedAtMs'] as num?)?.toInt() ?? 0,
    );
  }
}

class UserProfileService {
  static CollectionReference<Map<String, dynamic>> get _users =>
      FirebaseFirestore.instance.collection('users');

  static Stream<AppUserProfile?> streamProfile(String uid) {
    return _users.doc(uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) return null;
      return AppUserProfile.fromMap(data);
    });
  }

  static Future<AppUserProfile?> fetchProfile(String uid) async {
    final snapshot = await _users.doc(uid).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) return null;
    return AppUserProfile.fromMap(data);
  }

  static Future<void> upsertProfile({
    required User user,
    required String username,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await _users.doc(user.uid).get();
    final createdAtMs = (existing.data()?['createdAtMs'] as num?)?.toInt() ?? now;

    final profile = AppUserProfile(
      uid: user.uid,
      email: user.email ?? '',
      username: username,
      createdAtMs: createdAtMs,
      updatedAtMs: now,
    );

    await _users.doc(user.uid).set(profile.toJson(), SetOptions(merge: true));
  }
}


enum FriendActionStatus { none, pendingOutgoing, pendingIncoming, friends }

class FriendActionState {
  const FriendActionState({
    required this.status,
    this.request,
  });

  final FriendActionStatus status;
  final FriendRequest? request;
}

class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.fromName,
    required this.toName,
    required this.status,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  final String id;
  final String fromUid;
  final String toUid;
  final String fromName;
  final String toName;
  final String status;
  final int createdAtMs;
  final int updatedAtMs;

  DateTime get createdAt => DateTime.fromMillisecondsSinceEpoch(createdAtMs);
  DateTime get updatedAt => DateTime.fromMillisecondsSinceEpoch(updatedAtMs);

  bool get isPending => status == 'pending';

  factory FriendRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final json = doc.data() ?? <String, dynamic>{};
    return FriendRequest(
      id: doc.id,
      fromUid: (json['fromUid'] ?? '').toString(),
      toUid: (json['toUid'] ?? '').toString(),
      fromName: (json['fromName'] ?? 'Trainer').toString(),
      toName: (json['toName'] ?? 'Trainer').toString(),
      status: (json['status'] ?? 'pending').toString(),
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
      updatedAtMs: (json['updatedAtMs'] as num?)?.toInt() ?? 0,
    );
  }
}

class FriendSummary {
  const FriendSummary({
    required this.uid,
    required this.username,
    required this.sinceMs,
  });

  final String uid;
  final String username;
  final int sinceMs;

  DateTime get since => DateTime.fromMillisecondsSinceEpoch(sinceMs);

  factory FriendSummary.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final json = doc.data() ?? <String, dynamic>{};
    return FriendSummary(
      uid: (json['uid'] ?? doc.id).toString(),
      username: (json['username'] ?? 'Trainer').toString(),
      sinceMs: (json['sinceMs'] as num?)?.toInt() ?? 0,
    );
  }
}

String _friendRequestId(String fromUid, String toUid) => '${fromUid}_to_$toUid';

String _friendPokedexLabel(String friendName) {
  final trimmed = friendName.trim();
  if (trimmed.isEmpty) return 'Friend Pokédex';
  return trimmed.toLowerCase().endsWith('s') ? "$trimmed' Pokédex" : "$trimmed's Pokédex";
}

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

class WishlistEntry {
  const WishlistEntry({
    required this.cardId,
    required this.name,
    required this.setId,
    required this.setName,
    required this.number,
    required this.createdAtMs,
    this.imageUrl,
    this.largeImageUrl,
    this.setLogoUrl,
    this.rawPrice,
    this.rawPriceCurrency = 'USD',
  });

  final String cardId;
  final String name;
  final String setId;
  final String setName;
  final String number;
  final int createdAtMs;
  final String? imageUrl;
  final String? largeImageUrl;
  final String? setLogoUrl;
  final double? rawPrice;
  final String rawPriceCurrency;

  DateTime get createdAt => DateTime.fromMillisecondsSinceEpoch(createdAtMs);

  factory WishlistEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final json = doc.data() ?? <String, dynamic>{};
    return WishlistEntry(
      cardId: (json['cardId'] ?? doc.id).toString(),
      name: (json['name'] ?? 'Unknown Card').toString(),
      setId: (json['setId'] ?? '').toString(),
      setName: (json['setName'] ?? 'Unknown Set').toString(),
      number: (json['number'] ?? '').toString(),
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
      imageUrl: json['imageUrl']?.toString(),
      largeImageUrl: json['largeImageUrl']?.toString(),
      setLogoUrl: json['setLogoUrl']?.toString(),
      rawPrice: (json['rawPrice'] as num?)?.toDouble(),
      rawPriceCurrency: (json['rawPriceCurrency'] ?? 'USD').toString().toUpperCase(),
    );
  }

  TcgCard toSummaryCard() {
    return TcgCard(
      id: cardId,
      name: name,
      setId: setId,
      setName: setName,
      number: number,
      types: const <String>[],
      imageUrl: imageUrl,
      largeImageUrl: largeImageUrl ?? imageUrl,
      setLogoUrl: setLogoUrl,
      rawPrice: rawPrice,
      rawPriceCurrency: rawPriceCurrency,
    );
  }
}

class WishlistService {
  static CollectionReference<Map<String, dynamic>> _collection(String ownerUid) =>
      FirebaseFirestore.instance.collection('users').doc(ownerUid).collection('wishlist');

  static Stream<List<WishlistEntry>> wishlistStream(String ownerUid) {
    if (ownerUid.trim().isEmpty) {
      return Stream.value(const <WishlistEntry>[]);
    }
    return _collection(ownerUid).snapshots().map((snapshot) {
      final items = snapshot.docs.map(WishlistEntry.fromDoc).toList()
        ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
      return items;
    });
  }

  static Stream<bool> cardInWishlistStream(String ownerUid, String cardId) {
    if (ownerUid.trim().isEmpty || cardId.trim().isEmpty) {
      return Stream.value(false);
    }
    return _collection(ownerUid).doc(cardId).snapshots().map((snapshot) => snapshot.exists);
  }

  static Future<void> addCard({required String ownerUid, required TcgCard card}) async {
    final safeRawPrice = card.rawPrice;
    final rawPriceValue = (safeRawPrice != null && safeRawPrice.isFinite) ? safeRawPrice : null;
    await _collection(ownerUid).doc(card.id).set({
      'cardId': card.id,
      'name': card.name,
      'setId': card.setId,
      'setName': card.setName,
      'number': card.number,
      'imageUrl': card.imageUrl,
      'largeImageUrl': card.largeImageUrl,
      'setLogoUrl': card.setLogoUrl,
      if (rawPriceValue != null) 'rawPrice': rawPriceValue,
      'createdAtMs': DateTime.now().millisecondsSinceEpoch,
    }, SetOptions(merge: true));
  }

  static Future<void> removeCard({required String ownerUid, required String cardId}) async {
    await _collection(ownerUid).doc(cardId).delete();
  }
}

class LocalPokedexStore {
  static String storageKeyForSet(String setId) => 'set_pokedex_$setId';

  static bool isOwned(CardOwnership ownership) {
    return ownership.effectiveCopies > 0 ||
        ownership.normal ||
        ownership.reverseHolo ||
        ownership.holo;
  }

  static Future<Map<String, CardOwnership>> loadSetOwnershipMap(String setId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKeyForSet(setId));
    final ownershipByCardId = <String, CardOwnership>{};

    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        decoded.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            ownershipByCardId[key] = CardOwnership.fromJson(value);
          } else if (value is Map) {
            ownershipByCardId[key] = CardOwnership.fromJson(Map<String, dynamic>.from(value));
          }
        });
      } catch (_) {}
    }

    return ownershipByCardId;
  }

  static Future<void> saveSetOwnershipMap(
    String setId,
    Map<String, CardOwnership> ownershipByCardId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, dynamic>{
      for (final entry in ownershipByCardId.entries)
        if (isOwned(entry.value)) entry.key: entry.value.toJson(),
    };

    if (map.isEmpty) {
      await prefs.remove(storageKeyForSet(setId));
    } else {
      await prefs.setString(storageKeyForSet(setId), jsonEncode(map));
    }
    collectionRefreshNotifier.value++;
  }

  static Future<void> removeCard(String setId, String cardId) async {
    final ownershipByCardId = await loadSetOwnershipMap(setId);
    ownershipByCardId.remove(cardId);
    await saveSetOwnershipMap(setId, ownershipByCardId);
  }

  static Future<Set<String>> allTrackedSetIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs
        .getKeys()
        .where((key) => key.startsWith('set_pokedex_'))
        .map((key) => key.replaceFirst('set_pokedex_', ''))
        .toSet();
  }

  static Future<Set<String>> allNonEmptySetIds() async {
    final setIds = await allTrackedSetIds();
    final nonEmpty = <String>{};
    for (final setId in setIds) {
      final ownershipByCardId = await loadSetOwnershipMap(setId);
      if (ownershipByCardId.values.any(isOwned)) {
        nonEmpty.add(setId);
      }
    }
    return nonEmpty;
  }

  static Future<Map<String, int>> loadAllCardCopies() async {
    final setIds = await allTrackedSetIds();
    final cardCopies = <String, int>{};

    for (final setId in setIds) {
      final ownershipByCardId = await loadSetOwnershipMap(setId);
      for (final entry in ownershipByCardId.entries) {
        final copies = entry.value.effectiveCopies;
        if (copies > 0) {
          cardCopies.update(entry.key, (existing) => existing + copies, ifAbsent: () => copies);
        }
      }
    }

    return cardCopies;
  }
}

class PokedexSyncService {
  static CollectionReference<Map<String, dynamic>> _setCollection(String ownerUid) =>
      FirebaseFirestore.instance.collection('users').doc(ownerUid).collection('pokedex_sets');

  static Future<void> syncCurrentUserLocalPokedex({bool force = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final profileRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final profileSnapshot = await profileRef.get();
    final migratedAtMs = (profileSnapshot.data()?['pokedexMigratedAtMs'] as num?)?.toInt() ?? 0;
    if (!force && migratedAtMs > 0) return;

    final setIds = await LocalPokedexStore.allTrackedSetIds();
    for (final setId in setIds) {
      await syncSetFromLocal(ownerUid: user.uid, setId: setId);
    }

    await profileRef.set({
      'pokedexMigratedAtMs': DateTime.now().millisecondsSinceEpoch,
    }, SetOptions(merge: true));
  }

  static Future<void> syncCurrentSetForCurrentUser(String setId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await syncSetFromLocal(ownerUid: user.uid, setId: setId);
  }

  static Future<void> syncSetFromLocal({
    required String ownerUid,
    required String setId,
  }) async {
    final ownershipByCardId = await LocalPokedexStore.loadSetOwnershipMap(setId);
    final ownedEntries = ownershipByCardId.entries.where((entry) => LocalPokedexStore.isOwned(entry.value)).toList();
    final setRef = _setCollection(ownerUid).doc(setId);
    final existingCards = await setRef.collection('cards').get();
    final existingIds = existingCards.docs.map((doc) => doc.id).toSet();
    final desiredIds = ownedEntries.map((entry) => entry.key).toSet();
    final batch = FirebaseFirestore.instance.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final cardDoc in existingCards.docs) {
      if (!desiredIds.contains(cardDoc.id)) {
        batch.delete(cardDoc.reference);
      }
    }

    for (final entry in ownedEntries) {
      batch.set(
        setRef.collection('cards').doc(entry.key),
        {
          'cardId': entry.key,
          ...entry.value.toJson(),
          'updatedAtMs': now,
        },
        SetOptions(merge: true),
      );
    }

    if (ownedEntries.isEmpty && existingIds.isEmpty) {
      await setRef.delete().catchError((_) {});
      return;
    }

    if (ownedEntries.isEmpty) {
      batch.delete(setRef);
    } else {
      batch.set(
        setRef,
        {
          'setId': setId,
          'ownedCount': ownedEntries.length,
          'updatedAtMs': now,
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  static Stream<List<String>> ownedSetIdsStream(String ownerUid) {
    return _setCollection(ownerUid).snapshots().map((snapshot) {
      final setIds = snapshot.docs
          .where((doc) => ((doc.data()['ownedCount'] as num?)?.toInt() ?? 0) > 0)
          .map((doc) => doc.id)
          .toList()
        ..sort();
      return setIds;
    });
  }

  static Stream<Map<String, CardOwnership>> setOwnershipStream({
    required String ownerUid,
    required String setId,
  }) {
    return _setCollection(ownerUid).doc(setId).collection('cards').snapshots().map((snapshot) {
      final ownershipByCardId = <String, CardOwnership>{};
      for (final doc in snapshot.docs) {
        ownershipByCardId[doc.id] = CardOwnership.fromJson(doc.data());
      }
      return ownershipByCardId;
    });
  }
}

class PokemonHubApp extends StatelessWidget {
  const PokemonHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pokemon Hub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B3A82)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF041B4A),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _FullScreenLoader();
        }

        final user = authSnapshot.data;
        if (user == null) {
          return const SignInPage();
        }

        return StreamBuilder<AppUserProfile?>(
          stream: UserProfileService.streamProfile(user.uid),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const _FullScreenLoader();
            }

            final profile = profileSnapshot.data;
            if (profile == null || profile.username.trim().isEmpty) {
              return CompleteProfilePage(user: user);
            }

            return AppShell(profile: profile);
          },
        );
      },
    );
  }
}

class _FullScreenLoader extends StatelessWidget {
  const _FullScreenLoader();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF041B4A),
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  static const String _termsVersion = '2025-04-17';

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isSignUp = false;
  bool _submitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Enter your email and password');
      return;
    }

    if (_isSignUp && password != confirmPassword) {
      _showMessage('Passwords do not match');
      return;
    }

    if (_isSignUp && !_acceptedTerms) {
      _showMessage('Please read and accept the Terms & Conditions to continue');
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      if (_isSignUp) {
        final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        final user = credential.user;
        if (user != null) {
          final now = DateTime.now().millisecondsSinceEpoch;
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'email': user.email ?? email,
            'username': '',
            'createdAtMs': now,
            'updatedAtMs': now,
            'acceptedTermsVersion': _termsVersion,
            'acceptedTermsAtMs': now,
          }, SetOptions(merge: true));
        }
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
    } on FirebaseAuthException catch (e) {
      _showMessage(e.message ?? 'Authentication failed');
    } catch (_) {
      _showMessage('Authentication failed');
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openTermsAndConditions() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF102754),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 18,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Terms & Conditions',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please read and accept these before creating an account.',
                  style: TextStyle(
                    color: Color(0xFFC8D4F0),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16366E),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF3F5C96)),
                      ),
                      child: const SelectableText(
                        _kPokemonHubTermsAndConditions,
                        style: TextStyle(
                          color: Color(0xFFE4ECFF),
                          fontSize: 14,
                          height: 1.55,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                color: const Color(0xFF102754),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.catching_pokemon,
                        color: Color(0xFFF7DE77),
                        size: 54,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _isSignUp ? 'Create your account' : 'Welcome back',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isSignUp
                            ? 'Sign up to unlock community sale and swap posts.'
                            : 'Sign in to view your profile and post in the community.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFC8D4F0),
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _AuthModeChip(
                              label: 'Sign In',
                              selected: !_isSignUp,
                              onTap: () => setState(() => _isSignUp = false),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _AuthModeChip(
                              label: 'Sign Up',
                              selected: _isSignUp,
                              onTap: () => setState(() => _isSignUp = true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white),
                        decoration: _authInputDecoration('Email address'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: Colors.white),
                        decoration: _authInputDecoration('Password').copyWith(
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ),
                      if (_isSignUp) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          style: const TextStyle(color: Colors.white),
                          decoration: _authInputDecoration('Confirm password').copyWith(
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                              icon: Icon(
                                _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16366E),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFF3F5C96)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Checkbox(
                                    value: _acceptedTerms,
                                    activeColor: const Color(0xFFF7DE77),
                                    checkColor: Colors.black,
                                    onChanged: (value) {
                                      setState(() {
                                        _acceptedTerms = value ?? false;
                                      });
                                    },
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 10),
                                      child: RichText(
                                        text: const TextSpan(
                                          style: TextStyle(
                                            color: Color(0xFFE4ECFF),
                                            fontSize: 13,
                                            height: 1.4,
                                          ),
                                          children: [
                                            TextSpan(text: 'I have read and agree to the '),
                                            TextSpan(
                                              text: 'Terms & Conditions',
                                              style: TextStyle(
                                                color: Color(0xFFF7DE77),
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            TextSpan(text: ' for Pokémon Hub.'),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: _openTermsAndConditions,
                                  icon: const Icon(Icons.description_outlined),
                                  label: const Text('Read Terms & Conditions'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: _submitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(_isSignUp ? 'Create account' : 'Sign in'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const String _kPokemonHubTermsAndConditions = '''Pokémon Hub Terms & Conditions

Effective date: 17 April 2025

1. Acceptance of these terms
By creating an account or using Pokémon Hub, you agree to these Terms & Conditions. If you do not agree, do not create an account or use the app.

2. Community use
Pokémon Hub is intended for collectors to track cards, share wishlists, discuss the hobby, and connect with other users. You agree to use the app respectfully and lawfully.

3. Buying, selling, swapping, and arranging meetups
Any sale, swap, trade, payment, postage, meetup, or other arrangement made through the community area is strictly between the users involved. Pokémon Hub does not verify users, inspect items, guarantee payment, guarantee delivery, or guarantee the condition, authenticity, legality, or value of any card or product. Use your own judgment and take appropriate safety precautions.

4. Acceptable behaviour
You must not post or send content that is abusive, threatening, discriminatory, sexually explicit, fraudulent, misleading, or unlawful. You must not harass other users, impersonate anyone, spam the community, or attempt to scam, phish, or manipulate others.

5. Images and content you upload
You are responsible for the text, images, and other content you upload or send through Pokémon Hub. By posting content, you confirm that you have the right to share it and that it does not infringe another person's rights.

6. Account responsibility
You are responsible for keeping your login details secure and for activity that happens through your account. Tell the app owner promptly if you believe your account has been used without permission.

7. Data and visibility
Some information you add, such as your community posts, friend-visible wishlist, and friend-visible Pokédex data, may be shown to other users based on the app's social features. Do not upload anything you do not want shared within those features.

8. Availability and changes
Pokémon Hub may be updated, changed, suspended, or removed at any time. Features may be added, changed, or discontinued without notice.

9. Termination
Accounts or content may be removed, limited, or suspended if a user breaks these terms or misuses the app or community features.

10. Liability
Pokémon Hub is provided on an "as is" basis. To the fullest extent allowed by law, the app owner is not responsible for losses, damage, disputes, failed trades, payment problems, shipping issues, counterfeit items, meetups, or other issues arising from user activity or third-party services.

11. Children and safety
If a user is under the age required by local law to manage an online account, a parent or guardian should review and approve use of the app. Never share sensitive personal information publicly, and use extra caution when arranging in-person meetups.

12. Changes to these terms
These terms may be updated from time to time. Continued use of Pokémon Hub after changes take effect means you accept the updated terms.

13. Contact
If you have questions, concerns, or need to report misuse, use the contact method provided by the app owner.

These terms are a practical in-app starter set and may need review to match your local laws, privacy wording, and how you run the app.''';

const String _kCommunityForumDisclaimer = '''Disclaimer: Pokémon Hub and the creators of this app are not responsible for any sales, swaps, trades, payments, deliveries, meetups, item condition, authenticity, losses, disputes, or damages arising from community posts or arrangements made between users. All transactions and interactions are carried out entirely at the users’ own risk.''';

InputDecoration _authInputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white70),
    filled: true,
    fillColor: const Color(0xFF16366E),
    border: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(18)),
      borderSide: BorderSide(color: Color(0xFF3F5C96)),
    ),
    enabledBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(18)),
      borderSide: BorderSide(color: Color(0xFF3F5C96)),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(18)),
      borderSide: BorderSide(color: Color(0xFFF7DE77), width: 1.5),
    ),
  );
}

class _AuthModeChip extends StatelessWidget {
  const _AuthModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF7DE77) : const Color(0xFF16366E),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.black : const Color(0xFFE4ECFF),
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}

class CompleteProfilePage extends StatefulWidget {
  const CompleteProfilePage({super.key, required this.user});

  final User user;

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  bool _saving = false;
  String? _profileImagePath;

  @override
  void initState() {
    super.initState();
    _loadLocalImage();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadLocalImage() async {
    final imagePath = await LocalProfileImageStore.loadForUser(widget.user.uid);
    if (mounted) {
      setState(() {
        _profileImagePath = imagePath;
      });
    }
  }

  Future<void> _pickImage() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null) return;

    final permanentPath = await LocalProfileImageStore.saveForUser(
      uid: widget.user.uid,
      sourcePath: picked.path,
    );

    if (mounted) {
      setState(() {
        _profileImagePath = permanentPath;
      });
    }
  }

  Future<void> _saveProfile() async {
    final username = _nameController.text.trim();
    if (username.isEmpty) {
      _showMessage('Enter a trainer name');
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await UserProfileService.upsertProfile(
        user: widget.user,
        username: username,
      );
    } catch (_) {
      _showMessage('Could not save your profile');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final imageFile = _profileImagePath != null ? File(_profileImagePath!) : null;
    final imageExists = imageFile != null && imageFile.existsSync();

    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Card(
                color: const Color(0xFF102754),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Complete your trainer profile',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.user.email ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFC8D4F0)),
                      ),
                      const SizedBox(height: 18),
                      Center(
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 48,
                                backgroundColor: Colors.white12,
                                backgroundImage: imageExists ? FileImage(imageFile!) : null,
                                child: !imageExists
                                    ? const Icon(Icons.person, color: Colors.white, size: 44)
                                    : null,
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF7DE77),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFF041B4A), width: 2),
                                  ),
                                  child: const Icon(Icons.edit, color: Colors.black, size: 18),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Profile pictures stay on this device in this version.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _authInputDecoration('Trainer name'),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _saving ? null : _saveProfile,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Save profile and continue'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => FirebaseAuth.instance.signOut(),
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.profile});

  final AppUserProfile profile;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  bool _communityDisclaimerAccepted = false;
  bool _loadingCommunityDisclaimer = true;
  final GlobalKey<_CardSearchPageState> _cardSearchKey = GlobalKey<_CardSearchPageState>();
  final GlobalKey<_MasterSetsPageState> _masterSetsKey = GlobalKey<_MasterSetsPageState>();

  @override
  void initState() {
    super.initState();
    _loadCommunityDisclaimerAcceptance();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PokedexSyncService.syncCurrentUserLocalPokedex();
    });
  }

  String _communityDisclaimerPrefsKey() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? widget.profile.uid;
    return 'community_forum_disclaimer_accepted_$uid';
  }

  Future<void> _loadCommunityDisclaimerAcceptance() async {
    final prefs = await SharedPreferences.getInstance();
    final accepted = prefs.getBool(_communityDisclaimerPrefsKey()) ?? false;
    if (!mounted) return;
    setState(() {
      _communityDisclaimerAccepted = accepted;
      _loadingCommunityDisclaimer = false;
    });
  }

  Future<void> _saveCommunityDisclaimerAcceptance() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_communityDisclaimerPrefsKey(), true);
    if (!mounted) return;
    setState(() {
      _communityDisclaimerAccepted = true;
    });
  }

  Future<bool> _ensureCommunityDisclaimerAccepted() async {
    if (_communityDisclaimerAccepted) return true;
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF102754),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 18,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Community Disclaimer',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16366E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF3F5C96)),
                  ),
                  child: const Text(
                    _kCommunityForumDisclaimer,
                    style: TextStyle(
                      color: Color(0xFFE4ECFF),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'You must accept this before entering the community page.',
                  style: TextStyle(
                    color: Color(0xFFC8D4F0),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF3F5C96)),
                          minimumSize: const Size.fromHeight(50),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                        ),
                        child: const Text('I Accept'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (accepted == true) {
      await _saveCommunityDisclaimerAcceptance();
      return true;
    }
    return false;
  }

  void _applyDestinationSelected(int index) {
    final wasOnCards = _currentIndex == 0;

    setState(() {
      _currentIndex = index;
    });

    if (index == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _cardSearchKey.currentState?.scrollToTop(animated: wasOnCards);
      });
    }

    if (index == 2) {
      _masterSetsKey.currentState?.refreshSets();
    }
  }

  Future<void> _onDestinationSelected(int index) async {
    HapticFeedback.lightImpact();

    if (index == 3) {
      if (_loadingCommunityDisclaimer) {
        await _loadCommunityDisclaimerAcceptance();
      }
      final accepted = await _ensureCommunityDisclaimerAccepted();
      if (!accepted) return;
    }

    _applyDestinationSelected(index);
  }

  String get _appBarTitle {
    switch (_currentIndex) {
      case 1:
        return 'Scan Card';
      case 2:
        return 'Master Sets';
      case 3:
        return 'Community';
      case 0:
      default:
        return 'Pokemon Hub';
    }
  }

  Widget _buildCurrentPage() {
    switch (_currentIndex) {
      case 1:
        return const CardScannerPage(showAppBar: false);
      case 2:
        return MasterSetsPage(key: _masterSetsKey);
      case 3:
        return CommunityPage(profile: widget.profile);
      case 0:
      default:
        return CardSearchPage(key: _cardSearchKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
        actions: [
          _ProfileAppBarButton(profile: widget.profile),
        ],
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: currencyRefreshNotifier,
        builder: (context, _, __) => _buildCurrentPage(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.style_outlined),
            selectedIcon: Icon(Icons.style),
            label: 'Cards',
          ),
          NavigationDestination(
            icon: Icon(Icons.document_scanner_outlined),
            selectedIcon: Icon(Icons.document_scanner),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.collections_bookmark_outlined),
            selectedIcon: Icon(Icons.collections_bookmark),
            label: 'Master Sets',
          ),
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum),
            label: 'Community',
          ),
        ],
      ),
    );
  }
}

class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.postType,
    required this.title,
    required this.description,
    required this.contact,
    required this.createdAtMs,
    this.imageBase64List = const <String>[],
    this.hiddenReplyIds = const <String>[],
  });

  final String id;
  final String authorId;
  final String authorName;
  final String postType;
  final String title;
  final String description;
  final String contact;
  final int createdAtMs;
  final List<String> imageBase64List;
  final List<String> hiddenReplyIds;

  DateTime get createdAt => DateTime.fromMillisecondsSinceEpoch(createdAtMs);
  bool get hasImages => imageBase64List.isNotEmpty;
  int get imageCount => imageBase64List.length;
  String? get primaryImageBase64 => hasImages ? imageBase64List.first : null;

  Map<String, dynamic> toJson() => {
        'authorId': authorId,
        'authorName': authorName,
        'postType': postType,
        'title': title,
        'description': description,
        'contact': contact,
        'createdAtMs': createdAtMs,
        'imageBase64List': imageBase64List,
        if (hiddenReplyIds.isNotEmpty) 'hiddenReplyIds': hiddenReplyIds,
        if (primaryImageBase64 != null) 'imageBase64': primaryImageBase64,
      };

  factory CommunityPost.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final json = doc.data() ?? <String, dynamic>{};
    final rawImageList = json['imageBase64List'];
    final legacyImage = (json['imageBase64'] ?? '').toString();

    final imageBase64List = <String>[];
    if (rawImageList is List) {
      for (final value in rawImageList) {
        final encoded = value.toString().trim();
        if (encoded.isNotEmpty) {
          imageBase64List.add(encoded);
        }
      }
    }
    if (imageBase64List.isEmpty && legacyImage.trim().isNotEmpty) {
      imageBase64List.add(legacyImage.trim());
    }

    return CommunityPost(
      id: doc.id,
      authorId: (json['authorId'] ?? '').toString(),
      authorName: (json['authorName'] ?? 'Trainer').toString(),
      postType: (json['postType'] ?? 'Swap').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      contact: (json['contact'] ?? '').toString(),
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
      imageBase64List: imageBase64List,
      hiddenReplyIds: ((json['hiddenReplyIds'] as List<dynamic>?) ?? const <dynamic>[])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(),
    );
  }
}

class CommunityReply {
  const CommunityReply({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.message,
    required this.createdAtMs,
    this.imageBase64,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String message;
  final int createdAtMs;
  final String? imageBase64;

  DateTime get createdAt => DateTime.fromMillisecondsSinceEpoch(createdAtMs);
  bool get hasImage => imageBase64 != null && imageBase64!.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'authorId': authorId,
        'authorName': authorName,
        'message': message,
        'createdAtMs': createdAtMs,
        if (hasImage) 'imageBase64': imageBase64!.trim(),
      };

  factory CommunityReply.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final json = doc.data() ?? <String, dynamic>{};
    final rawImage = (json['imageBase64'] ?? '').toString().trim();
    return CommunityReply(
      id: doc.id,
      authorId: (json['authorId'] ?? '').toString(),
      authorName: (json['authorName'] ?? 'Trainer').toString(),
      message: (json['message'] ?? '').toString(),
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
      imageBase64: rawImage.isEmpty ? null : rawImage,
    );
  }
}

class CommunityImageCodec {
  static const int maxImagesPerPost = 4;
  static const int _maxImageBytes = 180 * 1024;
  static const int _maxDimension = 960;

  static Future<List<String>> pickAndEncodeMultiFromGallery({
    int limit = maxImagesPerPost,
  }) async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(
      imageQuality: 92,
      maxWidth: 1800,
      maxHeight: 1800,
    );
    if (picked.isEmpty) return const <String>[];

    final encoded = <String>[];
    for (final file in picked.take(limit)) {
      encoded.add(await encodeFileAsBase64(file.path));
    }
    return encoded;
  }

  static Future<String?> pickAndEncodeSingle(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 92,
      maxWidth: 1800,
      maxHeight: 1800,
    );
    if (picked == null) return null;
    return encodeFileAsBase64(picked.path);
  }

  static Future<String> encodeFileAsBase64(String path) async {
    final bytes = await File(path).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Could not read this image.');
    }

    img.Image current = img.bakeOrientation(decoded);
    if (current.width > _maxDimension || current.height > _maxDimension) {
      current = img.copyResize(
        current,
        width: current.width >= current.height ? _maxDimension : null,
        height: current.height > current.width ? _maxDimension : null,
        interpolation: img.Interpolation.average,
      );
    }

    var quality = 86;
    List<int> encoded = img.encodeJpg(current, quality: quality);

    while (encoded.length > _maxImageBytes && quality > 48) {
      quality -= 8;
      encoded = img.encodeJpg(current, quality: quality);
    }

    while (encoded.length > _maxImageBytes &&
        (current.width > 520 || current.height > 520)) {
      current = img.copyResize(
        current,
        width: current.width >= current.height
            ? math.max(520, (current.width * 0.84).round())
            : null,
        height: current.height > current.width
            ? math.max(520, (current.height * 0.84).round())
            : null,
        interpolation: img.Interpolation.average,
      );
      quality = math.min(quality, 74);
      encoded = img.encodeJpg(current, quality: quality);
      while (encoded.length > _maxImageBytes && quality > 42) {
        quality -= 6;
        encoded = img.encodeJpg(current, quality: quality);
      }
    }

    if (encoded.length > _maxImageBytes) {
      throw Exception(
        'This photo is still too large. Try a tighter shot of the card.',
      );
    }

    return base64Encode(encoded);
  }

  static Uint8List? decode(String? imageBase64) {
    if (imageBase64 == null || imageBase64.trim().isEmpty) return null;
    try {
      return base64Decode(imageBase64);
    } catch (_) {
      return null;
    }
  }
}

String _communityImageCountLabel(int count) {
  if (count <= 0) return 'No photos';
  if (count == 1) return '1 photo';
  return '$count photos';
}


enum _CommunityPostMenuAction { edit, delete }

enum _CardSearchMode { cards, sets }

String _formatCommunityDate(DateTime dt) {
  final day = dt.day.toString().padLeft(2, '0');
  final month = dt.month.toString().padLeft(2, '0');
  final year = dt.year.toString();
  final hour = dt.hour.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$day/$month/$year  $hour:$minute';
}

String _formatCommunityRelativeTime(DateTime dt) {
  final difference = DateTime.now().difference(dt);
  if (difference.inSeconds < 45) return 'Just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
  if (difference.inHours < 24) return '${difference.inHours}h ago';
  if (difference.inDays < 7) return '${difference.inDays}d ago';
  return _formatCommunityDate(dt).split('  ').first;
}

String _communityConversationIdForPost({
  required String postId,
  required String userAId,
  required String userBId,
}) {
  final ids = <String>[userAId, userBId]..sort();
  final safePostId = postId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  return '${safePostId}_${ids.join('_')}';
}

class CommunityPrivateConversation {
  const CommunityPrivateConversation({
    required this.id,
    required this.participants,
    required this.participantNames,
    required this.relatedPostId,
    required this.relatedPostTitle,
    required this.createdAtMs,
    required this.updatedAtMs,
    required this.lastMessage,
    required this.lastSenderId,
  });

  final String id;
  final List<String> participants;
  final Map<String, String> participantNames;
  final String relatedPostId;
  final String relatedPostTitle;
  final int createdAtMs;
  final int updatedAtMs;
  final String lastMessage;
  final String lastSenderId;

  DateTime get createdAt => DateTime.fromMillisecondsSinceEpoch(createdAtMs);
  DateTime get updatedAt => DateTime.fromMillisecondsSinceEpoch(updatedAtMs);

  String otherUserName(String currentUid) {
    for (final participant in participants) {
      if (participant != currentUid) {
        final name = participantNames[participant]?.trim() ?? '';
        if (name.isNotEmpty) return name;
      }
    }
    return 'Trainer';
  }

  factory CommunityPrivateConversation.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final json = doc.data() ?? <String, dynamic>{};
    final rawParticipants = (json['participants'] as List<dynamic>? ?? const [])
        .map((value) => value.toString())
        .where((value) => value.trim().isNotEmpty)
        .toList();
    final rawNames = json['participantNames'] as Map<String, dynamic>? ?? const {};
    final participantNames = <String, String>{
      for (final entry in rawNames.entries) entry.key: entry.value.toString(),
    };

    return CommunityPrivateConversation(
      id: doc.id,
      participants: rawParticipants,
      participantNames: participantNames,
      relatedPostId: (json['relatedPostId'] ?? '').toString(),
      relatedPostTitle: (json['relatedPostTitle'] ?? 'Community post').toString(),
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
      updatedAtMs: (json['updatedAtMs'] as num?)?.toInt() ?? 0,
      lastMessage: (json['lastMessage'] ?? '').toString(),
      lastSenderId: (json['lastSenderId'] ?? '').toString(),
    );
  }
}

class CommunityPrivateMessage {
  const CommunityPrivateMessage({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.message,
    required this.createdAtMs,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String message;
  final int createdAtMs;

  DateTime get createdAt => DateTime.fromMillisecondsSinceEpoch(createdAtMs);

  Map<String, dynamic> toJson() => {
        'authorId': authorId,
        'authorName': authorName,
        'message': message,
        'createdAtMs': createdAtMs,
      };

  factory CommunityPrivateMessage.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final json = doc.data() ?? <String, dynamic>{};
    return CommunityPrivateMessage(
      id: doc.id,
      authorId: (json['authorId'] ?? '').toString(),
      authorName: (json['authorName'] ?? 'Trainer').toString(),
      message: (json['message'] ?? '').toString(),
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
    );
  }
}

class CommunityPostThreadPage extends StatefulWidget {
  const CommunityPostThreadPage({
    super.key,
    required this.post,
    required this.currentProfile,
  });

  final CommunityPost post;
  final AppUserProfile currentProfile;

  @override
  State<CommunityPostThreadPage> createState() => _CommunityPostThreadPageState();
}

class _CommunityPostThreadPageState extends State<CommunityPostThreadPage> {
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;
  bool _pendingScrollToLatestReply = false;
  String? _replyImageBase64;

  DocumentReference<Map<String, dynamic>> get _postRef =>
      FirebaseFirestore.instance.collection('community_posts').doc(widget.post.id);

  CollectionReference<Map<String, dynamic>> get _repliesRef => _postRef.collection('replies');

  @override
  void dispose() {
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _requestScrollToLatestReply() {
    _pendingScrollToLatestReply = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollRepliesToLatest();
    });
    Future<void>.delayed(const Duration(milliseconds: 140), () {
      if (!mounted) return;
      _scrollRepliesToLatest();
    });
  }

  void _scrollRepliesToLatest() {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    _pendingScrollToLatestReply = false;
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  Future<void> _pickReplyImage() async {
    if (_sending) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF102754),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: Colors.white),
                title: const Text(
                  'Take photo',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: Colors.white),
                title: const Text(
                  'Choose from gallery',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) return;

    try {
      final encoded = await CommunityImageCodec.pickAndEncodeSingle(source);
      if (encoded == null || !mounted) return;
      setState(() {
        _replyImageBase64 = encoded;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not add photo right now.')),
        );
      }
    }
  }

  Future<void> _addReply() async {
    final message = _replyController.text.trim();
    final imageBase64 = _replyImageBase64?.trim();
    if ((message.isEmpty && (imageBase64 == null || imageBase64.isEmpty)) || _sending) {
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      final replyDoc = _repliesRef.doc();
      await replyDoc.set(
        CommunityReply(
          id: replyDoc.id,
          authorId: FirebaseAuth.instance.currentUser!.uid,
          authorName: widget.currentProfile.displayName,
          message: message,
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
          imageBase64: imageBase64,
        ).toJson(),
      );
      _replyController.clear();
      if (mounted) {
        setState(() {
          _replyImageBase64 = null;
        });
      }
      _requestScrollToLatestReply();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send reply')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Future<void> _deleteReply(CommunityReply reply) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You need to be signed in to delete comments.')),
        );
      }
      return;
    }

    try {
      if (currentUid == reply.authorId) {
        await _repliesRef.doc(reply.id).delete();
      } else if (currentUid == widget.post.authorId) {
        await _postRef.set(
          {
            'hiddenReplyIds': FieldValue.arrayUnion([reply.id]),
          },
          SetOptions(merge: true),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Only the comment author or post owner can delete comments.')),
          );
        }
        return;
      }
    } on FirebaseException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? 'Could not delete comment.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete comment.')),
        );
      }
    }
  }

  String _formatDate(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/$year  $hour:$minute';
  }

  Widget _buildThreadHeaderCard({
    required CommunityPost livePost,
    required bool keyboardOpen,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: keyboardOpen
            ? Card(
                key: const ValueKey('compact-thread-header'),
                color: const Color(0xFF102754),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: livePost.postType == 'For Sale'
                              ? const Color(0xFF8E1E2E)
                              : livePost.postType == 'Thread'
                                  ? const Color(0xFF5B3FD6)
                                  : const Color(0xFF0B6B5B),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          livePost.postType,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              livePost.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Replying to ${livePost.authorName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFD8E3FB),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(livePost.createdAt).split('  ').first,
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              )
            : Card(
                key: const ValueKey('full-thread-header'),
                color: const Color(0xFF102754),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: livePost.postType == 'For Sale'
                                  ? const Color(0xFF8E1E2E)
                                  : livePost.postType == 'Thread'
                                      ? const Color(0xFF5B3FD6)
                                      : const Color(0xFF0B6B5B),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              livePost.postType,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatDate(livePost.createdAt),
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        livePost.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        livePost.description,
                        style: const TextStyle(
                          color: Color(0xFFD8E3FB),
                          fontSize: 15,
                          height: 1.45,
                        ),
                      ),
                      if (livePost.hasImages) ...[
                        const SizedBox(height: 12),
                        _CommunityImageStrip(
                          imageBase64List: livePost.imageBase64List,
                          height: 180,
                        ),
                      ],
                      const SizedBox(height: 12),
                      _CommunityInfoRow(label: 'Posted by', value: livePost.authorName),
                      _CommunityInfoRow(
                        label: 'Contact',
                        value: livePost.contact.isEmpty ? 'Not added' : livePost.contact,
                      ),
                      if (livePost.hasImages)
                        _CommunityInfoRow(
                          label: 'Photos',
                          value: _communityImageCountLabel(livePost.imageCount),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildReplyCard({
    required CommunityReply reply,
    required CommunityPost livePost,
    required String? currentUid,
  }) {
    final canDelete = reply.authorId == currentUid || livePost.authorId == currentUid;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Card(
        color: const Color(0xFF102754),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      reply.authorName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    _formatDate(reply.createdAt),
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                  if (canDelete)
                    PopupMenuButton<String>(
                      iconColor: Colors.white,
                      color: const Color(0xFF264A8A),
                      onSelected: (value) {
                        if (value == 'delete') {
                          _deleteReply(reply);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Delete comment',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              if (reply.message.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  reply.message,
                  style: const TextStyle(
                    color: Color(0xFFD8E3FB),
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ],
              if (reply.hasImage) ...[
                const SizedBox(height: 10),
                Builder(
                  builder: (context) {
                    final imageBytes = CommunityImageCodec.decode(reply.imageBase64);
                    if (imageBytes == null) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          'Image could not be displayed.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      );
                    }
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => _CommunityImageViewerPage(
                              imageBase64List: [reply.imageBase64!],
                              initialIndex: 0,
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.memory(
                          imageBytes,
                          fit: BoxFit.cover,
                          height: 220,
                          width: double.infinity,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        title: const Text('Post replies'),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        bottom: true,
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _postRef.snapshots(),
          builder: (context, postSnapshot) {
            final livePost = postSnapshot.hasData && postSnapshot.data?.exists == true
                ? CommunityPost.fromDoc(postSnapshot.data!)
                : widget.post;
            final hiddenReplyIds = livePost.hiddenReplyIds.toSet();

            return Column(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _repliesRef.orderBy('createdAtMs').snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Could not load replies.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        );
                      }

                      final replies = (snapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                          .map(CommunityReply.fromDoc)
                          .where((reply) => !hiddenReplyIds.contains(reply.id))
                          .toList();

                      if (_pendingScrollToLatestReply && replies.isNotEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _scrollRepliesToLatest();
                        });
                      }

                      final itemCount = replies.isEmpty ? 2 : replies.length + 1;

                      return ListView.builder(
                        controller: _scrollController,
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.only(bottom: 12),
                        itemCount: itemCount,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _buildThreadHeaderCard(
                              livePost: livePost,
                              keyboardOpen: keyboardOpen,
                            );
                          }

                          if (replies.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: Card(
                                color: Color(0xFF102754),
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text(
                                    'No replies yet. Start the conversation below.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white70, fontSize: 15),
                                  ),
                                ),
                              ),
                            );
                          }

                          final reply = replies[index - 1];
                          return _buildReplyCard(
                            reply: reply,
                            livePost: livePost,
                            currentUid: currentUid,
                          );
                        },
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_replyImageBase64 != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.memory(
                                    CommunityImageCodec.decode(_replyImageBase64)!,
                                    height: 96,
                                    width: 96,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: InkWell(
                                    onTap: () => setState(() => _replyImageBase64 = null),
                                    borderRadius: BorderRadius.circular(999),
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.58),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF16366E),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0xFF3F5C96)),
                            ),
                            child: IconButton(
                              onPressed: _sending ? null : _pickReplyImage,
                              icon: const Icon(Icons.add_a_photo_outlined),
                              color: Colors.white,
                              tooltip: 'Add photo reply',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _replyController,
                              minLines: 1,
                              maxLines: 4,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                hintText: 'Write a reply or add a photo...',
                                hintStyle: TextStyle(color: Color(0xFFAFC0E6)),
                                filled: true,
                                fillColor: Color(0xFF16366E),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(18)),
                                  borderSide: BorderSide(color: Color(0xFF3F5C96)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(18)),
                                  borderSide: BorderSide(color: Color(0xFF3F5C96)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(18)),
                                  borderSide: BorderSide(color: Color(0xFFF7DE77), width: 1.5),
                                ),
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          FilledButton(
                            onPressed: _sending ? null : _addReply,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                            ),
                            child: const Text('Reply'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key, required this.profile});

  final AppUserProfile profile;

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  String _section = 'Marketplace';
  String _filter = 'All';
  int? _lastSeenAtMs;
  bool _loadedLastSeen = false;
  bool _savedVisitMarker = false;
  late final int _visitStartedAtMs;

  Stream<QuerySnapshot<Map<String, dynamic>>> get _postsStream => FirebaseFirestore.instance
      .collection('community_posts')
      .orderBy('createdAtMs', descending: true)
      .snapshots();

  @override
  void initState() {
    super.initState();
    _visitStartedAtMs = DateTime.now().millisecondsSinceEpoch;
    _loadLastSeen();
  }

  String _lastSeenPrefsKey() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? widget.profile.uid;
    return 'community_last_seen_$uid';
  }

  Future<void> _loadLastSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_lastSeenPrefsKey());
    if (!mounted) return;
    setState(() {
      _lastSeenAtMs = saved;
      _loadedLastSeen = true;
    });
  }

  Future<void> _markVisitSeenIfNeeded() async {
    if (_savedVisitMarker) return;
    _savedVisitMarker = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSeenPrefsKey(), _visitStartedAtMs);
  }

  Future<void> _openCreatePostSheet({String? initialPostType}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF102754),
      builder: (_) => _CreateCommunityPostSheet(
        profile: widget.profile,
        initialPostType: initialPostType,
      ),
    );
  }

  Future<void> _openEditPostSheet(CommunityPost post) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF102754),
      builder: (_) => _CreateCommunityPostSheet(
        profile: widget.profile,
        existingPost: post,
      ),
    );
  }

  Future<void> _deletePost(CommunityPost post) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF102754),
        title: const Text('Delete post', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will remove the post and all replies from the community forum.',
          style: TextStyle(color: Color(0xFFC8D4F0)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB13B59),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    final postRef = FirebaseFirestore.instance.collection('community_posts').doc(post.id);
    final replies = await postRef.collection('replies').get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in replies.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(postRef);
    await batch.commit();
  }

  List<CommunityPost> _visiblePosts(List<CommunityPost> posts) {
    final sectionPosts = _section == 'Discussions'
        ? posts.where((post) => post.postType == 'Thread').toList()
        : posts.where((post) => post.postType != 'Thread').toList();

    if (_section == 'Discussions') {
      return sectionPosts;
    }

    if (_filter == 'All') return sectionPosts;
    return sectionPosts.where((post) => post.postType == _filter).toList();
  }

  Future<void> _openPrivateInbox() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityPrivateInboxPage(currentProfile: widget.profile),
      ),
    );
  }

  Future<void> _openFriendRequestsPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FriendRequestsPage(currentProfile: widget.profile),
      ),
    );
  }

  Future<void> _openPrivateMessageForPost(CommunityPost post) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final otherUserId = post.authorId.trim();
    if (otherUserId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This post cannot be messaged right now.')),
      );
      return;
    }

    if (otherUserId == currentUser.uid) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This is your post. Open your inbox for existing chats.')),
      );
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final conversationId = _communityConversationIdForPost(
      postId: post.id,
      userAId: currentUser.uid,
      userBId: otherUserId,
    );

    try {
      await FirebaseFirestore.instance
          .collection('community_private_conversations')
          .doc(conversationId)
          .set({
        'participants': <String>[currentUser.uid, otherUserId],
        'participantNames': <String, String>{
          currentUser.uid: widget.profile.displayName,
          otherUserId: post.authorName,
        },
        'relatedPostId': post.id,
        'relatedPostTitle': post.title,
        'createdAtMs': now,
        'updatedAtMs': now,
        'lastMessage': '',
        'lastSenderId': '',
      }, SetOptions(merge: true));
    } catch (_) {}

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityPrivateChatPage(
          conversationId: conversationId,
          currentProfile: widget.profile,
          otherUserId: otherUserId,
          otherUserName: post.authorName,
          relatedPostId: post.id,
          relatedPostTitle: post.title,
        ),
      ),
    );
  }

  Widget _buildHeaderCard({
    required bool hasNewPosts,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF173A78), Color(0xFF0F2759)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.14),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7DE77).withOpacity(0.16),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFF7DE77).withOpacity(0.24)),
                  ),
                  child: const Icon(
                    Icons.forum_rounded,
                    color: Color(0xFFF7DE77),
                    size: 17,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Community forum',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (hasNewPosts)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7DE77).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFF7DE77).withOpacity(0.28)),
                    ),
                    child: const Text(
                      'NEW',
                      style: TextStyle(
                        color: Color(0xFFF7DE77),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: OutlinedButton.icon(
                      onPressed: _openPrivateInbox,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.14)),
                        backgroundColor: Colors.white.withOpacity(0.05),
                        padding: const EdgeInsets.symmetric(vertical: 0),
                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      icon: const Icon(Icons.mail_outline_rounded, size: 16),
                      label: const Text('Inbox'),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: OutlinedButton.icon(
                      onPressed: _openFriendRequestsPage,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.14)),
                        backgroundColor: Colors.white.withOpacity(0.05),
                        padding: const EdgeInsets.symmetric(vertical: 0),
                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
                      label: const Text('Requests'),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: FilledButton.icon(
                      onPressed: () => _openCreatePostSheet(
                        initialPostType: _section == 'Discussions' ? 'Thread' : null,
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF7DE77),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 0),
                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                      ),
                      icon: Icon(
                        _section == 'Discussions'
                            ? Icons.forum_outlined
                            : Icons.add_comment_outlined,
                        size: 16,
                      ),
                      label: Text(_section == 'Discussions' ? 'Start thread' : 'Post'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _CommunityFilterChip(
                    label: 'Marketplace',
                    selected: _section == 'Marketplace',
                    minWidth: 140,
                    onTap: () => setState(() {
                      _section = 'Marketplace';
                      if (_filter == 'Thread') {
                        _filter = 'All';
                      }
                    }),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CommunityFilterChip(
                    label: 'Discussions',
                    selected: _section == 'Discussions',
                    minWidth: 140,
                    onTap: () => setState(() => _section = 'Discussions'),
                  ),
                ),
              ],
            ),
            if (_section == 'Marketplace') ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _CommunityFilterChip(
                    label: 'All',
                    selected: _filter == 'All',
                    minWidth: 82,
                    onTap: () => setState(() => _filter = 'All'),
                  ),
                  _CommunityFilterChip(
                    label: 'Swap',
                    selected: _filter == 'Swap',
                    minWidth: 94,
                    onTap: () => setState(() => _filter = 'Swap'),
                  ),
                  _CommunityFilterChip(
                    label: 'For Sale',
                    selected: _filter == 'For Sale',
                    minWidth: 118,
                    onTap: () => setState(() => _filter = 'For Sale'),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                ),
                child: const Text(
                  'Discussion threads are separated from sale and swap posts so it is easier to chat and meet new friends.',
                  style: TextStyle(
                    color: Color(0xFFC8D4F0),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _postsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting || !_loadedLastSeen) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Could not load community posts.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ),
              );
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              _markVisitSeenIfNeeded();
            });

            final allPosts = (snapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                .map(CommunityPost.fromDoc)
                .toList();
            final posts = _visiblePosts(allPosts);
            final hasNewPosts = _lastSeenAtMs != null &&
                allPosts.any((post) => post.createdAtMs > (_lastSeenAtMs ?? 0));

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              itemCount: posts.isEmpty ? 2 : posts.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildHeaderCard(
                    hasNewPosts: hasNewPosts,
                  );
                }

                if (posts.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF102754),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _section == 'Discussions'
                              ? Icons.forum_outlined
                              : Icons.storefront_outlined,
                          color: const Color(0xFFF7DE77),
                          size: 36,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _section == 'Discussions'
                              ? 'No discussion threads yet'
                              : 'No posts match this view yet',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _section == 'Discussions'
                              ? 'Start a thread to chat about cards, collecting, trades, and making friends.'
                              : 'Create a new swap or sale post to get the conversation started.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final post = posts[index - 1];
                final isNew = _lastSeenAtMs != null && post.createdAtMs > (_lastSeenAtMs ?? 0);
                return _CommunityPostCard(
                  post: post,
                  currentProfile: widget.profile,
                  canEdit: post.authorId == currentUid,
                  canMessage: post.authorId.isNotEmpty && post.authorId != currentUid,
                  isNew: isNew,
                  onEdit: () => _openEditPostSheet(post),
                  onDelete: () => _deletePost(post),
                  onMessage: () => _openPrivateMessageForPost(post),
                  onOpen: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CommunityPostThreadPage(
                          post: post,
                          currentProfile: widget.profile,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _CommunityHeaderStat extends StatelessWidget {
  const _CommunityHeaderStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityFilterChip extends StatelessWidget {
  const _CommunityFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.minWidth = 88,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: minWidth),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFF7DE77) : const Color(0xFF16366E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? const Color(0xFFF7DE77)
                    : Colors.white.withOpacity(0.14),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: const Color(0xFFF7DE77).withOpacity(0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : const [],
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.black : const Color(0xFFE4ECFF),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CommunityPostCard extends StatelessWidget {
  const _CommunityPostCard({
    required this.post,
    required this.currentProfile,
    required this.canEdit,
    required this.canMessage,
    required this.isNew,
    required this.onEdit,
    required this.onDelete,
    required this.onMessage,
    required this.onOpen,
  });

  final CommunityPost post;
  final AppUserProfile currentProfile;
  final bool canEdit;
  final bool canMessage;
  final bool isNew;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMessage;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final isSale = post.postType == 'For Sale';
    final isDiscussion = post.postType == 'Thread';
    final accentColor = isDiscussion
        ? const Color(0xFF5B3FD6)
        : isSale
            ? const Color(0xFF8E1E2E)
            : const Color(0xFF0B6B5B);
    final postIcon = isDiscussion
        ? Icons.forum_outlined
        : isSale
            ? Icons.sell_outlined
            : Icons.swap_horiz_rounded;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isNew
              ? const Color(0xFFF7DE77).withOpacity(0.38)
              : Colors.white.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.16),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Card(
        color: const Color(0xFF102754),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (post.hasImages)
                Stack(
                  children: [
                    _CommunityImageStrip(
                      imageBase64List: post.imageBase64List,
                      height: 190,
                    ),
                    Positioned(
                      left: 12,
                      top: 12,
                      child: _CommunityMetaChip(
                        icon: postIcon,
                        label: isDiscussion ? 'Discussion' : post.postType,
                        color: accentColor,
                      ),
                    ),
                    Positioned(
                      right: 12,
                      top: 12,
                      child: _CommunityMetaChip(
                        icon: Icons.photo_library_outlined,
                        label: _communityImageCountLabel(post.imageCount),
                        color: Colors.black.withOpacity(0.62),
                      ),
                    ),
                    if (isNew)
                      const Positioned(
                        left: 12,
                        bottom: 12,
                        child: _CommunityNewBadge(),
                      ),
                  ],
                )
              else
                Container(
                  height: 104,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accentColor,
                        const Color(0xFF143163),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          postIcon,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    isDiscussion ? 'Discussion' : post.postType,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                if (isNew) ...[
                                  const SizedBox(width: 8),
                                  const _CommunityNewBadge(compact: true),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatCommunityRelativeTime(post.createdAt),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  height: 1.12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Posted by ${post.authorName} • ${_formatCommunityRelativeTime(post.createdAt)}',
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (canEdit)
                          PopupMenuButton<_CommunityPostMenuAction>(
                            iconColor: Colors.white70,
                            color: const Color(0xFF143163),
                            onSelected: (value) {
                              if (value == _CommunityPostMenuAction.edit) onEdit();
                              if (value == _CommunityPostMenuAction.delete) onDelete();
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem<_CommunityPostMenuAction>(
                                value: _CommunityPostMenuAction.edit,
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined, color: Color(0xFFF7DE77)),
                                    SizedBox(width: 10),
                                    Text(
                                      'Edit post',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem<_CommunityPostMenuAction>(
                                value: _CommunityPostMenuAction.delete,
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline, color: Colors.redAccent),
                                    SizedBox(width: 10),
                                    Text(
                                      'Delete post',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      post.description,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFD8E3FB),
                        fontSize: 15,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _CommunitySecondaryChip(
                          icon: Icons.person_outline_rounded,
                          label: post.authorName,
                        ),
                        _CommunitySecondaryChip(
                          icon: Icons.schedule_rounded,
                          label: _formatCommunityDate(post.createdAt).split('  ').first,
                        ),
                        if (post.contact.trim().isNotEmpty || !isDiscussion)
                          _CommunitySecondaryChip(
                            icon: Icons.alternate_email_rounded,
                            label: post.contact.isEmpty ? 'No contact added' : post.contact,
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onOpen,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(color: Colors.white.withOpacity(0.16)),
                              backgroundColor: const Color(0xFF16366E),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                            icon: const Icon(Icons.forum_outlined),
                            label: Text(isDiscussion ? 'Open discussion' : 'Open thread'),
                          ),
                        ),
                        if (canMessage) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: onMessage,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFF7DE77),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                              ),
                              icon: const Icon(Icons.mail_outline_rounded),
                              label: const Text(
                                'Message',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (canMessage) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: _FriendActionButton(
                          currentProfile: currentProfile,
                          otherUserId: post.authorId,
                          otherUserName: post.authorName,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommunityMetaChip extends StatelessWidget {
  const _CommunityMetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunitySecondaryChip extends StatelessWidget {
  const _CommunitySecondaryChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFFF7DE77)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityNewBadge extends StatelessWidget {
  const _CommunityNewBadge({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF7DE77),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'NEW',
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w900,
          fontSize: compact ? 10 : 11,
        ),
      ),
    );
  }
}

class _CommunityInfoRow extends StatelessWidget {
  const _CommunityInfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 74,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityImageStrip extends StatelessWidget {
  const _CommunityImageStrip({
    required this.imageBase64List,
    required this.height,
  });

  final List<String> imageBase64List;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (imageBase64List.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: imageBase64List.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final bytes = CommunityImageCodec.decode(imageBase64List[index]);
          return GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _CommunityImageViewerPage(
                    imageBase64List: imageBase64List,
                    initialIndex: index,
                  ),
                ),
              );
            },
            child: AspectRatio(
              aspectRatio: 0.72,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: const Color(0xFF16366E)),
                    if (bytes != null)
                      Image.memory(bytes, fit: BoxFit.cover)
                    else
                      const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white54,
                        ),
                      ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.60),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${index + 1}/${imageBase64List.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CommunityImageViewerPage extends StatefulWidget {
  const _CommunityImageViewerPage({
    required this.imageBase64List,
    required this.initialIndex,
  });

  final List<String> imageBase64List;
  final int initialIndex;

  @override
  State<_CommunityImageViewerPage> createState() =>
      _CommunityImageViewerPageState();
}

class _CommunityImageViewerPageState extends State<_CommunityImageViewerPage> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(
      0,
      math.max(0, widget.imageBase64List.length - 1),
    );
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1}/${widget.imageBase64List.length}'),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imageBase64List.length,
        onPageChanged: (value) {
          setState(() {
            _currentIndex = value;
          });
        },
        itemBuilder: (context, index) {
          final bytes = CommunityImageCodec.decode(widget.imageBase64List[index]);
          if (bytes == null) {
            return const Center(
              child: Text(
                'Image could not be loaded',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          return InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: Center(
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
          );
        },
      ),
    );
  }
}

class _CreateCommunityPostSheet extends StatefulWidget {
  const _CreateCommunityPostSheet({
    required this.profile,
    this.existingPost,
    this.initialPostType,
  });

  final AppUserProfile profile;
  final CommunityPost? existingPost;
  final String? initialPostType;

  @override
  State<_CreateCommunityPostSheet> createState() => _CreateCommunityPostSheetState();
}

class _CreateCommunityPostSheetState extends State<_CreateCommunityPostSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();

  String _postType = 'Swap';
  bool _saving = false;
  bool _processingImages = false;
  List<String> _imageBase64List = <String>[];

  bool get _isEditing => widget.existingPost != null;
  bool get _isDiscussionPost => _postType == 'Thread';

  int get _remainingImageSlots =>
      CommunityImageCodec.maxImagesPerPost - _imageBase64List.length;

  @override
  void initState() {
    super.initState();
    final existingPost = widget.existingPost;
    if (existingPost != null) {
      _postType = existingPost.postType;
      _titleController.text = existingPost.title;
      _descriptionController.text = existingPost.description;
      _contactController.text = existingPost.contact;
      _imageBase64List = List<String>.from(existingPost.imageBase64List);
    } else if (widget.initialPostType != null && widget.initialPostType!.trim().isNotEmpty) {
      _postType = widget.initialPostType!.trim();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  void _showComposerMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addPhotoFromCamera() async {
    if (_processingImages || _remainingImageSlots <= 0) {
      _showComposerMessage(
        'You can add up to ${CommunityImageCodec.maxImagesPerPost} photos per post.',
      );
      return;
    }

    setState(() {
      _processingImages = true;
    });

    try {
      final encoded = await CommunityImageCodec.pickAndEncodeSingle(
        ImageSource.camera,
      );
      if (encoded == null || !mounted) return;
      setState(() {
        _imageBase64List = <String>[..._imageBase64List, encoded];
      });
    } catch (error) {
      _showComposerMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _processingImages = false;
        });
      }
    }
  }

  Future<void> _addPhotosFromGallery() async {
    if (_processingImages || _remainingImageSlots <= 0) {
      _showComposerMessage(
        'You can add up to ${CommunityImageCodec.maxImagesPerPost} photos per post.',
      );
      return;
    }

    setState(() {
      _processingImages = true;
    });

    try {
      final picked = await CommunityImageCodec.pickAndEncodeMultiFromGallery(
        limit: _remainingImageSlots,
      );
      if (picked.isEmpty || !mounted) return;
      setState(() {
        _imageBase64List = <String>[..._imageBase64List, ...picked];
      });
    } catch (error) {
      _showComposerMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _processingImages = false;
        });
      }
    }
  }

  void _removePhotoAt(int index) {
    if (index < 0 || index >= _imageBase64List.length) return;
    setState(() {
      final updated = List<String>.from(_imageBase64List);
      updated.removeAt(index);
      _imageBase64List = updated;
    });
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (title.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Add a title and description')));
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      if (_isEditing) {
        final existingPost = widget.existingPost!;
        final updatedPost = CommunityPost(
          id: existingPost.id,
          authorId: existingPost.authorId,
          authorName: existingPost.authorName,
          postType: _postType,
          title: title,
          description: description,
          contact: _contactController.text.trim(),
          createdAtMs: existingPost.createdAtMs,
          imageBase64List: _imageBase64List,
        );

        await FirebaseFirestore.instance
            .collection('community_posts')
            .doc(existingPost.id)
            .set(updatedPost.toJson());
      } else {
        final postDoc = FirebaseFirestore.instance.collection('community_posts').doc();
        final post = CommunityPost(
          id: postDoc.id,
          authorId: FirebaseAuth.instance.currentUser!.uid,
          authorName: widget.profile.displayName,
          postType: _postType,
          title: title,
          description: description,
          contact: _contactController.text.trim(),
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
          imageBase64List: _imageBase64List,
        );
        await postDoc.set(post.toJson());
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditing ? 'Could not update post' : 'Could not create post')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final sheetTitle = _isEditing
        ? _isDiscussionPost
            ? 'Edit discussion thread'
            : 'Edit community post'
        : _isDiscussionPost
            ? 'Start discussion thread'
            : 'Create community post';
    final sheetSubtitle = _isDiscussionPost
        ? 'Start a conversation where collectors can talk cards, share tips, and make friends.'
        : _isEditing
            ? 'Update your swap or sale listing and keep or change its photos.'
            : 'Post a swap or sale listing with up to four card photos.';
    final titleHint = _isDiscussionPost
        ? 'Favourite modern sets right now?'
        : 'Looking to swap Charizard ex';
    final descriptionHint = _isDiscussionPost
        ? 'Kick off the discussion and let other collectors jump in.'
        : 'Write what you are offering, what you want back, and any card condition details.';
    final contactLabel = _isDiscussionPost ? 'Contact info (optional)' : 'Contact info';
    final contactHint = _isDiscussionPost
        ? 'Instagram, Discord, or leave blank if you only want replies.'
        : 'Instagram, Discord, phone, etc.';
    final photoHelp = _isDiscussionPost
        ? 'Add up to 4 photos if you want, or leave this empty for a text-only discussion thread.'
        : 'Add up to 4 card photos. Camera adds one at a time, and gallery can add several at once.';
    final submitLabel = _isEditing
        ? 'Save changes'
        : _isDiscussionPost
            ? 'Start thread'
            : 'Post';

    const fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(18)),
      borderSide: BorderSide(color: Color(0xFF3F5C96)),
    );

    return Material(
      color: const Color(0xFF102754),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Center(
                      child: Text(
                        sheetTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        sheetSubtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFC8D4F0),
                          fontSize: 14,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Post type',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _postType,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      iconEnabledColor: const Color(0xFFE4ECFF),
                      dropdownColor: const Color(0xFF143163),
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Color(0xFF16366E),
                        border: fieldBorder,
                        enabledBorder: fieldBorder,
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(18)),
                          borderSide: BorderSide(color: Color(0xFFF7DE77), width: 1.5),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Swap', child: Text('Swap')),
                        DropdownMenuItem(value: 'For Sale', child: Text('For Sale')),
                        DropdownMenuItem(value: 'Thread', child: Text('Discussion Thread')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _postType = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Title',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _titleController,
                      style: const TextStyle(color: Colors.white, fontSize: 17),
                      decoration: InputDecoration(
                        hintText: titleHint,
                        hintStyle: TextStyle(color: Color(0xFFAFC0E6)),
                        filled: true,
                        fillColor: Color(0xFF16366E),
                        border: fieldBorder,
                        enabledBorder: fieldBorder,
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(18)),
                          borderSide: BorderSide(color: Color(0xFFF7DE77), width: 1.5),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Description',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 5,
                      style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.35),
                      decoration: InputDecoration(
                        hintText: descriptionHint,
                        hintStyle: TextStyle(color: Color(0xFFAFC0E6)),
                        filled: true,
                        fillColor: Color(0xFF16366E),
                        border: fieldBorder,
                        enabledBorder: fieldBorder,
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(18)),
                          borderSide: BorderSide(color: Color(0xFFF7DE77), width: 1.5),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      contactLabel,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _contactController,
                      style: const TextStyle(color: Colors.white, fontSize: 17),
                      decoration: InputDecoration(
                        hintText: contactHint,
                        hintStyle: TextStyle(color: Color(0xFFAFC0E6)),
                        filled: true,
                        fillColor: Color(0xFF16366E),
                        border: fieldBorder,
                        enabledBorder: fieldBorder,
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(18)),
                          borderSide: BorderSide(color: Color(0xFFF7DE77), width: 1.5),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text(
                          'Photos',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_imageBase64List.length}/${CommunityImageCodec.maxImagesPerPost}',
                          style: const TextStyle(
                            color: Color(0xFFF7DE77),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_imageBase64List.isNotEmpty)
                      SizedBox(
                        height: 126,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _imageBase64List.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final bytes = CommunityImageCodec.decode(_imageBase64List[index]);
                            return Stack(
                              children: [
                                Container(
                                  width: 92,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF16366E),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: Colors.white.withOpacity(0.10)),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: bytes == null
                                      ? const Center(
                                          child: Icon(
                                            Icons.broken_image_outlined,
                                            color: Colors.white54,
                                          ),
                                        )
                                      : Image.memory(bytes, fit: BoxFit.cover),
                                ),
                                Positioned(
                                  right: 6,
                                  top: 6,
                                  child: InkWell(
                                    onTap: () => _removePhotoAt(index),
                                    borderRadius: BorderRadius.circular(999),
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.62),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16366E),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white.withOpacity(0.10)),
                        ),
                        child: Text(
                          photoHelp,
                          style: TextStyle(
                            color: Color(0xFFC8D4F0),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _processingImages ? null : _addPhotoFromCamera,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(color: Colors.white.withOpacity(0.18)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: _processingImages
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.camera_alt_outlined),
                            label: const Text('Camera'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _processingImages ? null : _addPhotosFromGallery,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: _processingImages
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.photo_library_outlined),
                            label: const Text('Gallery'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isDiscussionPost
                          ? 'Photos are optional for discussion threads and are stored directly in Firestore, so you do not need Firebase Storage.'
                          : 'Photos are compressed and stored directly in the Firestore post so you do not need Firebase Storage.',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: (_saving || _processingImages) ? null : _submit,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            submitLabel,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class CommunityPrivateInboxPage extends StatelessWidget {
  const CommunityPrivateInboxPage({
    super.key,
    required this.currentProfile,
  });

  final AppUserProfile currentProfile;

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        title: const Text('Private inbox'),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('community_private_conversations')
              .where('participants', arrayContains: currentUid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Could not load private messages.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              );
            }

            final conversations = (snapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                .map(CommunityPrivateConversation.fromDoc)
                .toList()
              ..sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));

            if (conversations.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No private conversations yet. Open a post and tap Message.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: conversations.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final conversation = conversations[index];
                final otherName = conversation.otherUserName(currentUid);
                return Card(
                  color: const Color(0xFF102754),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () {
                      String otherUserId = '';
                      for (final participant in conversation.participants) {
                        if (participant != currentUid) {
                          otherUserId = participant;
                          break;
                        }
                      }
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CommunityPrivateChatPage(
                            conversationId: conversation.id,
                            currentProfile: currentProfile,
                            otherUserId: otherUserId,
                            otherUserName: otherName,
                            relatedPostId: conversation.relatedPostId,
                            relatedPostTitle: conversation.relatedPostTitle,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  otherName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Text(
                                _formatCommunityRelativeTime(conversation.updatedAt),
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            conversation.relatedPostTitle,
                            style: const TextStyle(
                              color: Color(0xFFF7DE77),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            conversation.lastMessage.trim().isEmpty
                                ? 'Tap to start the conversation.'
                                : conversation.lastMessage,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFD8E3FB),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class CommunityPrivateChatPage extends StatefulWidget {
  const CommunityPrivateChatPage({
    super.key,
    required this.conversationId,
    required this.currentProfile,
    required this.otherUserId,
    required this.otherUserName,
    required this.relatedPostId,
    required this.relatedPostTitle,
  });

  final String conversationId;
  final AppUserProfile currentProfile;
  final String otherUserId;
  final String otherUserName;
  final String relatedPostId;
  final String relatedPostTitle;

  @override
  State<CommunityPrivateChatPage> createState() => _CommunityPrivateChatPageState();
}

class _CommunityPrivateChatPageState extends State<CommunityPrivateChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;

  CollectionReference<Map<String, dynamic>> get _messagesRef => FirebaseFirestore.instance
      .collection('community_private_conversations')
      .doc(widget.conversationId)
      .collection('messages');

  @override
  void initState() {
    super.initState();
    _ensureConversationExists();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _ensureConversationExists() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      await FirebaseFirestore.instance
          .collection('community_private_conversations')
          .doc(widget.conversationId)
          .set({
        'participants': <String>[currentUser.uid, widget.otherUserId],
        'participantNames': <String, String>{
          currentUser.uid: widget.currentProfile.displayName,
          widget.otherUserId: widget.otherUserName,
        },
        'relatedPostId': widget.relatedPostId,
        'relatedPostTitle': widget.relatedPostTitle,
        'createdAtMs': now,
        'updatedAtMs': now,
        'lastMessage': '',
        'lastSenderId': '',
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _sending) return;

    setState(() {
      _sending = true;
    });

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final doc = _messagesRef.doc();
      final privateMessage = CommunityPrivateMessage(
        id: doc.id,
        authorId: FirebaseAuth.instance.currentUser!.uid,
        authorName: widget.currentProfile.displayName,
        message: message,
        createdAtMs: now,
      );
      await doc.set(privateMessage.toJson());
      await FirebaseFirestore.instance
          .collection('community_private_conversations')
          .doc(widget.conversationId)
          .set({
        'participants': <String>[
          FirebaseAuth.instance.currentUser!.uid,
          widget.otherUserId,
        ],
        'participantNames': <String, String>{
          FirebaseAuth.instance.currentUser!.uid: widget.currentProfile.displayName,
          widget.otherUserId: widget.otherUserName,
        },
        'relatedPostId': widget.relatedPostId,
        'relatedPostTitle': widget.relatedPostTitle,
        'updatedAtMs': now,
        'createdAtMs': now,
        'lastMessage': message,
        'lastSenderId': FirebaseAuth.instance.currentUser!.uid,
      }, SetOptions(merge: true));
      _messageController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent + 120,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send private message')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        title: Text(widget.otherUserName),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Card(
                color: const Color(0xFF102754),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7DE77).withOpacity(0.14),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.mail_outline_rounded,
                              color: Color(0xFFF7DE77),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Private chat about',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  widget.relatedPostTitle,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: _FriendActionButton(
                          currentProfile: widget.currentProfile,
                          otherUserId: widget.otherUserId,
                          otherUserName: widget.otherUserName,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _messagesRef.orderBy('createdAtMs').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Could not load messages.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    );
                  }

                  final messages = (snapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                      .map(CommunityPrivateMessage.fromDoc)
                      .toList();

                  if (messages.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No private messages yet. Say hello below.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    itemCount: messages.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMine = message.authorId == currentUid;
                      return Align(
                        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isMine ? const Color(0xFF204D97) : const Color(0xFF102754),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(18),
                                topRight: const Radius.circular(18),
                                bottomLeft: Radius.circular(isMine ? 18 : 8),
                                bottomRight: Radius.circular(isMine ? 8 : 18),
                              ),
                              border: Border.all(color: Colors.white.withOpacity(0.07)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        isMine ? 'You' : message.authorName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _formatCommunityRelativeTime(message.createdAt),
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  message.message,
                                  style: const TextStyle(
                                    color: Color(0xFFD8E3FB),
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Write a private message...',
                        hintStyle: TextStyle(color: Color(0xFFAFC0E6)),
                        filled: true,
                        fillColor: Color(0xFF16366E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(18)),
                          borderSide: BorderSide(color: Color(0xFF3F5C96)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(18)),
                          borderSide: BorderSide(color: Color(0xFF3F5C96)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(18)),
                          borderSide: BorderSide(color: Color(0xFFF7DE77), width: 1.5),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _sending ? null : _sendMessage,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF7DE77),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    ),
                    child: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Send'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _FriendActionButton extends StatefulWidget {
  const _FriendActionButton({
    required this.currentProfile,
    required this.otherUserId,
    required this.otherUserName,
    this.padding = const EdgeInsets.symmetric(vertical: 13),
  });

  final AppUserProfile currentProfile;
  final String otherUserId;
  final String otherUserName;
  final EdgeInsetsGeometry padding;

  @override
  State<_FriendActionButton> createState() => _FriendActionButtonState();
}

class _FriendActionButtonState extends State<_FriendActionButton> {
  bool _working = false;

  Future<void> _handleAction(FriendActionState state) async {
    if (_working) return;
    setState(() {
      _working = true;
    });

    try {
      if (state.status == FriendActionStatus.none) {
        await FriendService.sendRequest(
          currentProfile: widget.currentProfile,
          otherUid: widget.otherUserId,
          otherName: widget.otherUserName,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Friend request sent to ${widget.otherUserName}.')),
          );
        }
      } else if (state.status == FriendActionStatus.pendingIncoming && state.request != null) {
        await FriendService.acceptRequest(state.request!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('You are now friends with ${widget.otherUserName}.')),
          );
        }
      } else if (state.status == FriendActionStatus.pendingOutgoing) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Friend request already sent.')),
          );
        }
      } else if (state.status == FriendActionStatus.friends) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FriendPokedexSetsPage(
              currentProfile: widget.currentProfile,
              friendUid: widget.otherUserId,
              friendName: widget.otherUserName,
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update friendship right now.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.otherUserId.trim().isEmpty || widget.otherUserId == widget.currentProfile.uid) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<FriendActionState>(
      stream: FriendService.watchActionState(
        currentUid: widget.currentProfile.uid,
        otherUid: widget.otherUserId,
      ),
      builder: (context, snapshot) {
        final state = snapshot.data ?? const FriendActionState(status: FriendActionStatus.none);

        IconData icon;
        String label;
        Color? backgroundColor;
        Color? foregroundColor;

        switch (state.status) {
          case FriendActionStatus.pendingIncoming:
            icon = Icons.handshake_outlined;
            label = 'Accept Friend';
            backgroundColor = const Color(0xFFF7DE77);
            foregroundColor = Colors.black;
            break;
          case FriendActionStatus.pendingOutgoing:
            icon = Icons.schedule_outlined;
            label = 'Request Sent';
            backgroundColor = const Color(0xFF1B3B73);
            foregroundColor = Colors.white;
            break;
          case FriendActionStatus.friends:
            icon = Icons.collections_bookmark_outlined;
            label = 'View Pokédex';
            backgroundColor = const Color(0xFF2C7A5B);
            foregroundColor = Colors.white;
            break;
          case FriendActionStatus.none:
          default:
            icon = Icons.person_add_alt_1_outlined;
            label = 'Add Friend';
            backgroundColor = const Color(0xFF16366E);
            foregroundColor = Colors.white;
            break;
        }

        return FilledButton.icon(
          onPressed: _working
              ? null
              : () => _handleAction(state),
          style: FilledButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            padding: widget.padding,
          ),
          icon: _working
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon),
          label: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        );
      },
    );
  }
}

class FriendRequestsPage extends StatelessWidget {
  const FriendRequestsPage({
    super.key,
    required this.currentProfile,
  });

  final AppUserProfile currentProfile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        title: const Text('Friend requests'),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Incoming',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            StreamBuilder<List<FriendRequest>>(
              stream: FriendService.incomingRequestsStream(currentProfile.uid),
              builder: (context, snapshot) {
                final requests = snapshot.data ?? const <FriendRequest>[];
                if (requests.isEmpty) {
                  return _friendEmptyCard('No incoming friend requests right now.');
                }
                return Column(
                  children: requests
                      .map(
                        (request) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _FriendRequestCard(
                            request: request,
                            incoming: true,
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 18),
            const Text(
              'Sent',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            StreamBuilder<List<FriendRequest>>(
              stream: FriendService.outgoingRequestsStream(currentProfile.uid),
              builder: (context, snapshot) {
                final requests = snapshot.data ?? const <FriendRequest>[];
                if (requests.isEmpty) {
                  return _friendEmptyCard('No pending sent requests.');
                }
                return Column(
                  children: requests
                      .map(
                        (request) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _FriendRequestCard(
                            request: request,
                            incoming: false,
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

Widget _friendEmptyCard(String text) {
  return Card(
    color: const Color(0xFF102754),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white70),
      ),
    ),
  );
}

class _FriendRequestCard extends StatefulWidget {
  const _FriendRequestCard({
    required this.request,
    required this.incoming,
  });

  final FriendRequest request;
  final bool incoming;

  @override
  State<_FriendRequestCard> createState() => _FriendRequestCardState();
}

class _FriendRequestCardState extends State<_FriendRequestCard> {
  bool _working = false;

  Future<void> _accept() async {
    setState(() {
      _working = true;
    });
    try {
      await FriendService.acceptRequest(widget.request);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You are now friends with ${widget.request.fromName}.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not accept the request.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  Future<void> _decline() async {
    setState(() {
      _working = true;
    });
    try {
      await FriendService.declineRequest(widget.request);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update the request.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.incoming ? widget.request.fromName : widget.request.toName;
    final subtitle = widget.incoming
        ? "Wants to see each other's Pokédex."
        : 'Waiting for them to accept your request.';

    return Card(
      color: const Color(0xFF102754),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(color: Color(0xFFD8E3FB), height: 1.35),
            ),
            const SizedBox(height: 8),
            Text(
              _formatCommunityRelativeTime(widget.request.createdAt),
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            if (widget.incoming) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _working ? null : _decline,
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _working ? null : _accept,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF7DE77),
                        foregroundColor: Colors.black,
                      ),
                      child: _working
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class FriendsPage extends StatelessWidget {
  const FriendsPage({
    super.key,
    required this.currentProfile,
  });

  final AppUserProfile currentProfile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        title: const Text('Friends'),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: StreamBuilder<List<FriendSummary>>(
          stream: FriendService.friendsStream(currentProfile.uid),
          builder: (context, snapshot) {
            final friends = snapshot.data ?? const <FriendSummary>[];
            if (friends.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No friends yet. Add them from community posts or private chats.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: friends.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final friend = friends[index];
                return Card(
                  color: const Color(0xFF102754),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          friend.username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Friends since ${_formatCommunityDate(friend.since).split('  ').first}',
                          style: const TextStyle(color: Colors.white60),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => FriendPokedexSetsPage(
                                        currentProfile: currentProfile,
                                        friendUid: friend.uid,
                                        friendName: friend.username,
                                      ),
                                    ),
                                  );
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF2C7A5B),
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.collections_bookmark_outlined),
                                label: Text(_friendPokedexLabel(friend.username)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => WishlistPage(
                                        ownerUid: friend.uid,
                                        ownerName: friend.username,
                                        showAddHint: false,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.favorite_outline_rounded),
                                label: const Text('Wishlist'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class WishlistPage extends StatelessWidget {
  const WishlistPage({
    super.key,
    required this.ownerUid,
    required this.ownerName,
    this.showAddHint = true,
  });

  final String ownerUid;
  final String ownerName;
  final bool showAddHint;

  Future<void> _openCard(BuildContext context, WishlistEntry entry) async {
    try {
      final fullCard = await PokemonTcgService.fetchCardById(entry.cardId);
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CardDetailsPage(card: fullCard),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CardDetailsPage(card: entry.toSummaryCard()),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isOwnWishlist = currentUid == ownerUid;

    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        title: Text(isOwnWishlist ? 'Wishlist' : "${ownerName}'s Wishlist"),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: StreamBuilder<List<WishlistEntry>>(
          stream: WishlistService.wishlistStream(ownerUid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Could not load wishlist right now.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              );
            }

            final entries = snapshot.data ?? const <WishlistEntry>[];
            if (entries.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    isOwnWishlist
                        ? 'Your wishlist is empty. Open a card and tap Add to Wishlist.'
                        : '$ownerName has not added any wishlist cards yet.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length + (showAddHint && isOwnWishlist ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (showAddHint && isOwnWishlist && index == 0) {
                  return Card(
                    color: const Color(0xFF102754),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Tip: open any card from search or a set and tap Add to Wishlist to save it here.',
                        style: TextStyle(color: Color(0xFFD8E3FB), height: 1.4),
                      ),
                    ),
                  );
                }

                final entry = entries[index - (showAddHint && isOwnWishlist ? 1 : 0)];
                return Card(
                  color: const Color(0xFF102754),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _openCard(context, entry),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: SizedBox(
                              width: 72,
                              height: 100,
                              child: entry.imageUrl == null || entry.imageUrl!.isEmpty
                                  ? Container(
                                      color: const Color(0xFF0E2A5E),
                                      child: const Icon(Icons.image_not_supported, color: Colors.white),
                                    )
                                  : Image.network(entry.imageUrl!, fit: BoxFit.cover),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  entry.setName,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Card #${entry.number}',
                                  style: const TextStyle(color: Colors.white60),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  entry.rawPrice == null
                                      ? 'Price unavailable'
                                      : 'Est. raw price: ${_formatPrice(entry.rawPrice, fromCurrency: entry.rawPriceCurrency)}',
                                  style: const TextStyle(
                                    color: Color(0xFFF7DE77),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right_rounded, color: Colors.white54),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class FriendPokedexSetsPage extends StatelessWidget {
  const FriendPokedexSetsPage({
    super.key,
    required this.currentProfile,
    required this.friendUid,
    required this.friendName,
  });

  final AppUserProfile currentProfile;
  final String friendUid;
  final String friendName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        title: Text(_friendPokedexLabel(friendName)),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: StreamBuilder<List<String>>(
          stream: PokedexSyncService.ownedSetIdsStream(friendUid),
          builder: (context, idsSnapshot) {
            final setIds = idsSnapshot.data ?? const <String>[];
            return FutureBuilder<List<TcgSet>>(
              future: PokemonTcgService.fetchSets(),
              builder: (context, setsSnapshot) {
                if (setsSnapshot.connectionState == ConnectionState.waiting ||
                    idsSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (setsSnapshot.hasError) {
                  return Center(
                    child: Text(
                      'Could not load Pokédex sets: ${setsSnapshot.error}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }

                final allSets = setsSnapshot.data ?? const <TcgSet>[];
                final setIdLookup = setIds.toSet();
                final visibleSets = allSets.where((set) => setIdLookup.contains(set.id)).toList();

                if (visibleSets.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        '${friendName.trim().isEmpty ? 'This trainer' : friendName} has not synced any Pokédex sets yet.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 15),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  itemCount: visibleSets.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final set = visibleSets[index];
                    return Card(
                      color: const Color(0xFF102754),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => FriendSetPokedexPage(
                                friendUid: friendUid,
                                friendName: friendName,
                                set: set,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          alignment: Alignment.center,
                          constraints: const BoxConstraints(minHeight: 110),
                          child: (set.logoUrl != null && set.logoUrl!.isNotEmpty)
                              ? Image.network(
                                  set.logoUrl!,
                                  fit: BoxFit.contain,
                                  height: 64,
                                  errorBuilder: (_, __, ___) => Text(
                                    set.name,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18,
                                    ),
                                  ),
                                )
                              : Text(
                                  set.name,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                  ),
                                ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class FriendSetPokedexPage extends StatelessWidget {
  const FriendSetPokedexPage({
    super.key,
    required this.friendUid,
    required this.friendName,
    required this.set,
  });

  final String friendUid;
  final String friendName;
  final TcgSet set;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        title: Text(_friendPokedexLabel(friendName)),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<TcgCard>>(
        future: PokemonTcgService.fetchCardsBySet(set.id),
        builder: (context, cardsSnapshot) {
          if (cardsSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (cardsSnapshot.hasError) {
            return Center(
              child: Text(
                'Could not load cards: ${cardsSnapshot.error}',
                style: const TextStyle(color: Colors.white),
              ),
            );
          }

          final cards = cardsSnapshot.data ?? const <TcgCard>[];
          cards.sort((a, b) => _compareCardNumbers(a.number, b.number));

          return StreamBuilder<Map<String, CardOwnership>>(
            stream: PokedexSyncService.setOwnershipStream(ownerUid: friendUid, setId: set.id),
            builder: (context, ownershipSnapshot) {
              final ownershipByCardId = ownershipSnapshot.data ?? const <String, CardOwnership>{};
              final ownedCards = cards
                  .where((card) => LocalPokedexStore.isOwned(ownershipByCardId[card.id] ?? const CardOwnership()))
                  .toList();

              if (ownedCards.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No saved cards found in this set yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(10, 12, 10, 16),
                children: [
                  if (set.logoUrl != null && set.logoUrl!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SizedBox(
                        height: 64,
                        child: Image.network(
                          set.logoUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  Card(
                    color: const Color(0xFF102754),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        '${ownedCards.length} card${ownedCards.length == 1 ? '' : 's'} saved in this set.',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: ownedCards.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                      childAspectRatio: 0.76,
                    ),
                    itemBuilder: (context, index) {
                      final card = ownedCards[index];
                      final ownership = ownershipByCardId[card.id] ?? const CardOwnership();
                      return GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => SetCardDetailsPage(
                                card: card,
                                ownership: ownership,
                                readOnly: true,
                                ownerLabel: _friendPokedexLabel(friendName),
                              ),
                            ),
                          );
                        },
                        child: BinderCardTile(
                          card: card,
                          ownership: ownership,
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class CardSearchPage extends StatefulWidget {
  const CardSearchPage({super.key});

  @override
  State<CardSearchPage> createState() => _CardSearchPageState();
}

class _CardSearchPageState extends State<CardSearchPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;
  late Future<CardSearchResult> _futureResults;
  _CardSearchMode _searchMode = _CardSearchMode.cards;

  @override
  void initState() {
    super.initState();
    _futureResults = Future.value(const CardSearchResult());
  }

  void _search() {
    final query = _controller.text.trim();
    setState(() {
      if (query.isEmpty) {
        _futureResults = Future.value(const CardSearchResult());
      } else if (_searchMode == _CardSearchMode.cards) {
        _futureResults = PokemonTcgService.searchCardsOnlyResult(query);
      } else {
        _futureResults = PokemonTcgService.searchSetsOnlyResult(query);
      }
    });
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _search);
  }

  void _setSearchMode(_CardSearchMode mode) {
    if (_searchMode == mode) return;
    _searchDebounce?.cancel();
    setState(() {
      _searchMode = mode;
      _controller.clear();
      _futureResults = Future.value(const CardSearchResult());
    });
    FocusScope.of(context).unfocus();
  }

  void scrollToTop({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    if (animated) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildModeChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF7DE77) : const Color(0xFF16366E),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFFF7DE77) : const Color(0xFF3F5C96),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.black : const Color(0xFFE4ECFF),
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchTopCard() {
    return Card(
      color: const Color(0xFF102754),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: _searchMode == _CardSearchMode.cards
                    ? 'Search cards, e.g. Pikachu'
                    : 'Search sets, e.g. Base Set',
                hintStyle: const TextStyle(color: Color(0xFFB7C4E0)),
                filled: true,
                fillColor: const Color(0xFF0E2A5E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
              ),
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildModeChip(
                    label: 'Cards',
                    selected: _searchMode == _CardSearchMode.cards,
                    onTap: () => _setSearchMode(_CardSearchMode.cards),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildModeChip(
                    label: 'Sets',
                    selected: _searchMode == _CardSearchMode.sets,
                    onTap: () => _setSearchMode(_CardSearchMode.sets),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CardSearchResult>(
      future: _futureResults,
      builder: (context, snapshot) {
        final query = _controller.text.trim();
        final result = snapshot.data ?? const CardSearchResult();
        final cards = result.cards;
        final sets = result.sets;

        final children = <Widget>[
          _buildSearchTopCard(),
          const SizedBox(height: 14),
        ];

        if (snapshot.connectionState == ConnectionState.waiting && query.isNotEmpty) {
          children.add(
            const Card(
              color: Color(0xFF102754),
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Searching Pokémon TCG...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        } else if (snapshot.hasError) {
          children.add(
            Card(
              color: const Color(0xFF5B1D28),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  'Could not load results: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          );
        } else if (query.isEmpty) {
          children.add(const _CardsSearchPlaceholder());
        } else if (_searchMode == _CardSearchMode.cards) {
          if (cards.isEmpty) {
            children.add(
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No cards found.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            );
          } else {
            children.add(
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  '${cards.length} card results',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
            children.addAll(
              cards.map(
                (card) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    color: const Color(0xFF102754),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CardDetailsPage(card: card),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          SizedBox(
                            width: 110,
                            height: 150,
                            child: card.imageUrl == null
                                ? const ColoredBox(
                                    color: Colors.black12,
                                    child: Icon(Icons.image_not_supported, color: Colors.white),
                                  )
                                : Image.network(card.imageUrl!, fit: BoxFit.cover),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    card.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(color: Colors.white),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Set: ${card.setName}',
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                  Text(
                                    'Number: ${card.number}',
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                  if (card.rarity != null)
                                    Text(
                                      'Rarity: ${card.rarity}',
                                      style: const TextStyle(color: Colors.white70),
                                    ),
                                  if (card.hp != null)
                                    Text(
                                      'HP: ${card.hp}',
                                      style: const TextStyle(color: Colors.white70),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
        } else {
          if (sets.isEmpty) {
            children.add(
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No sets found.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            );
          } else {
            children.add(
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  '${sets.length} set results',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
            children.addAll(
              sets.map(
                (set) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SetSearchResultCard(set: set),
                ),
              ),
            );
          }
        }

        return ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          children: children,
        );
      },
    );
  }
}

class CardScanAnalysis {
  const CardScanAnalysis({
    required this.extractedText,
    required this.candidateNames,
    required this.candidateNumbers,
    required this.matches,
    required this.exactConfirmed,
  });

  final String extractedText;
  final List<String> candidateNames;
  final List<String> candidateNumbers;
  final List<TcgCard> matches;
  final bool exactConfirmed;

  TcgCard? get bestMatch => exactConfirmed && matches.isNotEmpty ? matches.first : null;
}

class _ScanLineHint {
  const _ScanLineHint({
    required this.text,
    required this.topFraction,
    required this.leftFraction,
    required this.widthFraction,
    required this.heightFraction,
  });

  final String text;
  final double topFraction;
  final double leftFraction;
  final double widthFraction;
  final double heightFraction;
}

class CardScannerPage extends StatefulWidget {
  const CardScannerPage({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  State<CardScannerPage> createState() => _CardScannerPageState();
}

class _CardScannerPageState extends State<CardScannerPage>
    with WidgetsBindingObserver {
  static const double _cardAspectRatio = 63 / 88;

  final ImagePicker _imagePicker = ImagePicker();

  CameraController? _cameraController;
  bool _initializingCamera = true;
  bool _cameraReady = false;
  bool _flashEnabled = false;
  bool _autoCaptureEnabled = false;
  XFile? _capturedImage;
  CardScanAnalysis? _analysis;
  bool _scanning = false;
  String? _errorMessage;
  String? _confirmedMatchId;
  Offset? _focusPoint;
  Timer? _focusRingTimer;
  Timer? _autoCaptureTimer;
  int? _autoCountdown;

  static const _visionClient = PokemonHubVisionClient(
    endpoint: 'https://us-central1-cardmon-7dc24.cloudfunctions.net/identifyPokemonCardExact',
  );

  TcgCard _fallbackVisionCard(VisionResolvedCard card) {
    return TcgCard(
      id: card.id,
      name: card.name,
      setId: card.setId,
      setName: card.setName,
      number: card.number,
      types: const <String>[],
      hp: card.hp,
      imageUrl: card.imageUrl,
      largeImageUrl: card.largeImageUrl,
    );
  }

  String _formatVisionResolvedCard(VisionResolvedCard card) {
    final parts = <String>[
      card.name,
      if (card.setName.trim().isNotEmpty) card.setName,
      if (card.number.trim().isNotEmpty) '#${card.number}',
      if ((card.hp ?? '').trim().isNotEmpty) 'HP ${card.hp}',
      if ((card.supertype ?? '').trim().isNotEmpty) card.supertype!,
      if (card.score > 0) 'score ${card.score}',
    ];
    return parts.join(' | ');
  }

  String _formatTcgCard(TcgCard card) {
    final parts = <String>[
      card.name,
      if (card.setName.trim().isNotEmpty) card.setName,
      if (card.number.trim().isNotEmpty) '#${card.number}',
      if ((card.hp ?? '').trim().isNotEmpty) 'HP ${card.hp}',
    ];
    return parts.join(' | ');
  }

  TcgCard? _findConfirmedMatch(List<TcgCard> matches) {
    final confirmedId = _confirmedMatchId;
    if (confirmedId == null || confirmedId.trim().isEmpty) return null;
    for (final card in matches) {
      if (card.id == confirmedId) return card;
    }
    return null;
  }

  void _confirmMatch(TcgCard card) {
    setState(() {
      _confirmedMatchId = card.id;
      _errorMessage = null;
    });
  }

  Future<CardScanAnalysis> _buildVisionAnalysis(String imagePath) async {
    final vision = await _visionClient.scanImage(imagePath);

    final matches = <TcgCard>[];
    final seenIds = <String>{};

    Future<void> addMatch(VisionResolvedCard card) async {
      if (card.id.trim().isEmpty || seenIds.contains(card.id)) return;
      seenIds.add(card.id);

      try {
        final fullCard = await PokemonTcgService.fetchCardById(card.id);
        matches.add(fullCard);
      } catch (_) {
        matches.add(_fallbackVisionCard(card));
      }
    }

    if (vision.bestMatch != null) {
      await addMatch(vision.bestMatch!);
    }

    for (final card in vision.possibleMatches) {
      await addMatch(card);
      if (matches.length >= 8) break;
    }

    final candidateNames = <String>[
      if ((vision.extraction.cardName ?? '').trim().isNotEmpty)
        vision.extraction.cardName!.trim(),
      if ((vision.extraction.pokemonName ?? '').trim().isNotEmpty)
        vision.extraction.pokemonName!.trim(),
    ].toSet().toList();

    final candidateNumbers = <String>[
      if ((vision.extraction.collectorNumber ?? '').trim().isNotEmpty)
        vision.extraction.collectorNumber!.trim(),
      if ((vision.extraction.collectorNumber ?? '').trim().isNotEmpty &&
          (vision.extraction.printedTotal ?? '').trim().isNotEmpty)
        '${vision.extraction.collectorNumber!.trim()}/${vision.extraction.printedTotal!.trim()}',
    ].toSet().toList();

    final extractedLines = <String>[
      if ((vision.extraction.cardName ?? '').trim().isNotEmpty)
        'Card: ${vision.extraction.cardName}',
      if ((vision.extraction.pokemonName ?? '').trim().isNotEmpty)
        'Pokémon: ${vision.extraction.pokemonName}',
      if ((vision.extraction.collectorNumber ?? '').trim().isNotEmpty)
        'Number: ${vision.extraction.collectorNumber}'
        '${(vision.extraction.printedTotal ?? '').trim().isNotEmpty ? '/${vision.extraction.printedTotal}' : ''}',
      if ((vision.extraction.setCode ?? '').trim().isNotEmpty)
        'Set code: ${vision.extraction.setCode}',
      if ((vision.extraction.setName ?? '').trim().isNotEmpty)
        'Set: ${vision.extraction.setName}',
      if (vision.extraction.hp != null) 'HP: ${vision.extraction.hp}',
      if (vision.extraction.supertype != null &&
          vision.extraction.supertype!.trim().isNotEmpty)
        'Supertype: ${vision.extraction.supertype}',
      if (vision.extraction.subtypes.isNotEmpty)
        'Subtypes: ${vision.extraction.subtypes.join(', ')}',
      if (vision.extraction.attacks.isNotEmpty)
        'Attacks: ${vision.extraction.attacks.join(', ')}',
      if (vision.extraction.abilities.isNotEmpty)
        'Abilities: ${vision.extraction.abilities.join(', ')}',
      if (vision.extraction.rulesText.isNotEmpty)
        'Rules: ${vision.extraction.rulesText.join(' • ')}',
      if ((vision.extraction.rarityHint ?? '').trim().isNotEmpty)
        'Rarity hint: ${vision.extraction.rarityHint}',
      'Exact confirmed: ${vision.exactConfirmed ? 'yes' : 'no'}',
      'Vision exact confidence: ${vision.extraction.exactCardConfidence.toStringAsFixed(2)}',
      if (vision.candidateSetIds.isNotEmpty)
        'Candidate set ids: ${vision.candidateSetIds.join(', ')}',
      if (vision.extraction.notes.isNotEmpty)
        'Notes: ${vision.extraction.notes.join(' • ')}',
      if (vision.bestMatch != null) '',
      if (vision.bestMatch != null) 'Backend best match:',
      if (vision.bestMatch != null) '- ${_formatVisionResolvedCard(vision.bestMatch!)}',
      if (vision.debug.initialBestMatch != null) '',
      if (vision.debug.initialBestMatch != null) 'Initial backend best match:',
      if (vision.debug.initialBestMatch != null)
        '- ${_formatVisionResolvedCard(vision.debug.initialBestMatch!)}',
      if (vision.debug.initialPossibleMatches.isNotEmpty) '',
      if (vision.debug.initialPossibleMatches.isNotEmpty) 'Initial backend shortlist:',
      ...vision.debug.initialPossibleMatches
          .take(8)
          .map((card) => '- ${_formatVisionResolvedCard(card)}'),
      if (vision.possibleMatches.isNotEmpty) '',
      if (vision.possibleMatches.isNotEmpty) 'Reranked backend matches:',
      ...vision.possibleMatches.take(8).map((card) => '- ${_formatVisionResolvedCard(card)}'),
      if (matches.isNotEmpty) '',
      if (matches.isNotEmpty) 'Rendered app matches:',
      ...matches.take(8).map((card) => '- ${_formatTcgCard(card)}'),
    ];

    return CardScanAnalysis(
      extractedText: extractedLines.join('\n'),
      candidateNames: candidateNames,
      candidateNumbers: candidateNumbers,
      matches: matches,
      exactConfirmed: vision.exactConfirmed,
    );
  }

  @override
  void initState() {
    super.initState();
    _cameraReady = false;
    _initializingCamera = false;
  }

  @override
  void dispose() {
    _focusRingTimer?.cancel();
    _autoCaptureTimer?.cancel();
    super.dispose();
  }

  Future<void> _disposeCamera() async {
    final controller = _cameraController;
    _cameraController = null;
    _cameraReady = false;
    if (controller != null) {
      await controller.dispose();
    }
  }

  void _cancelAutoCaptureCountdown() {
    _autoCaptureTimer?.cancel();
    _autoCaptureTimer = null;
    if (mounted && _autoCountdown != null) {
      setState(() {
        _autoCountdown = null;
      });
    }
  }

  Future<void> _initializeCamera() async {
    if (!mounted) return;

    _cancelAutoCaptureCountdown();
    _focusRingTimer?.cancel();

    setState(() {
      _initializingCamera = true;
      _errorMessage = null;
      _focusPoint = null;
    });

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No camera found on this device.');
      }

      final preferredCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      await _disposeCamera();

      final controller = CameraController(
        preferredCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      _cameraController = controller;
      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraReady = true;
        _initializingCamera = false;
        _flashEnabled = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _cameraReady = false;
        _initializingCamera = false;
        _errorMessage = 'Could not start live camera preview: $error';
      });
    }
  }

  Future<void> _toggleFlash() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized || _scanning) {
      return;
    }

    try {
      final newFlashState = !_flashEnabled;
      await controller.setFlashMode(
        newFlashState ? FlashMode.torch : FlashMode.off,
      );
      if (!mounted) return;
      setState(() {
        _flashEnabled = newFlashState;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not change flash: $error';
      });
    }
  }

  Future<void> _setFocusPoint(
    TapUpDetails details,
    BoxConstraints constraints,
  ) async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized || _scanning) {
      return;
    }

    final local = details.localPosition;
    final normalized = Offset(
      (local.dx / constraints.maxWidth).clamp(0.0, 1.0),
      (local.dy / constraints.maxHeight).clamp(0.0, 1.0),
    );

    try {
      await controller.setFocusPoint(normalized);
      await controller.setExposurePoint(normalized);
    } catch (_) {}

    _focusRingTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _focusPoint = normalized;
      _errorMessage = null;
    });
    _focusRingTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _focusPoint = null;
      });
    });

  }

  void _startAutoCaptureCountdown() {
    // Manual-only capture mode.
  }

  Future<void> _captureAndScanFromLivePreview() async {
    _cancelAutoCaptureCountdown();
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (picked == null) return;
      await _scanPickedImage(picked);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _errorMessage = 'Could not take a photo: $error';
      });
    }
  }

  Future<void> _scanFromGallery() async {
    _cancelAutoCaptureCountdown();
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (picked == null) return;
      await _scanPickedImage(picked);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _errorMessage = 'Could not open the gallery: $error';
      });
    }
  }

  Future<void> _scanPickedImage(XFile picked) async {
    if (!mounted) return;

    setState(() {
      _capturedImage = picked;
      _analysis = null;
      _errorMessage = null;
      _confirmedMatchId = null;
      _scanning = true;
    });

    try {
      final analysis = await _buildVisionAnalysis(picked.path);
      if (!mounted) return;
      setState(() {
        _analysis = analysis;
        _scanning = false;
        if (analysis.exactConfirmed && analysis.matches.isNotEmpty) {
          _confirmedMatchId = analysis.matches.first.id;
        }
        if (analysis.matches.isEmpty) {
          _errorMessage =
              'No likely matches yet. Try one full card with less glare and a clearer photo.';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _errorMessage = 'Could not scan this card: $error';
      });
    }
  }

  void _resetScanner() {
    _cancelAutoCaptureCountdown();
    setState(() {
      _capturedImage = null;
      _analysis = null;
      _errorMessage = null;
      _focusPoint = null;
    });
  }

  Widget _buildScannerHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF102754),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 108,
            height: 108,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withOpacity(0.09),
                        Colors.white.withOpacity(0.025),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.03),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            color: const Color(0xFFDA3C3C).withOpacity(0.85),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            color: Colors.white.withOpacity(0.92),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 62,
                  height: 5,
                  color: const Color(0xFF1E1E1E).withOpacity(0.9),
                ),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAEAEA),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF1E1E1E).withOpacity(0.9),
                      width: 4,
                    ),
                  ),
                ),
                Positioned(
                  right: 13,
                  bottom: 15,
                  child: Transform.rotate(
                    angle: -0.18,
                    child: Container(
                      width: 44,
                      height: 62,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.white.withOpacity(0.08),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.16),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Scan cards fast',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Take one clear photo or choose a saved card image from your gallery.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewViewport(double frameWidth, double frameHeight) {
    final controller = _cameraController;
    if (_cameraReady && controller != null) {
      final previewSize = controller.value.previewSize;
      final previewWidth = previewSize?.height ?? frameWidth;
      final previewHeight = previewSize?.width ?? frameHeight;

      return ColoredBox(
        color: Colors.black,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: previewWidth,
            height: previewHeight,
            child: CameraPreview(controller),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF143163), Color(0xFF0E224D)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: _initializingCamera
          ? const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                SizedBox(height: 14),
                Text(
                  'Starting live preview...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            )
          : const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.camera_alt_outlined,
                  color: Colors.white70,
                  size: 56,
                ),
                SizedBox(height: 12),
                Text(
                  'Camera preview unavailable',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLiveFrame() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxFrameWidth = constraints.maxWidth * 0.92;
        final maxFrameHeight = constraints.maxHeight * 0.92;

        double frameWidth = maxFrameWidth;
        double frameHeight = frameWidth / _cardAspectRatio;
        if (frameHeight > maxFrameHeight) {
          frameHeight = maxFrameHeight;
          frameWidth = frameHeight * _cardAspectRatio;
        }

        return Center(
          child: GestureDetector(
            onTapUp: (_cameraReady && !_scanning)
                ? (details) => _setFocusPoint(
                      details,
                      BoxConstraints.tightFor(
                        width: frameWidth,
                        height: frameHeight,
                      ),
                    )
                : null,
            child: Container(
              width: frameWidth,
              height: frameHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFFF7DE77),
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF7DE77).withOpacity(0.22),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildPreviewViewport(frameWidth, frameHeight),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white.withOpacity(0.16),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.52),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _scanning ? Icons.radar : Icons.center_focus_strong,
                            size: 16,
                            color: const Color(0xFFF7DE77),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _scanning ? 'Scanning now' : 'Tap card to focus',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_focusPoint != null)
                    Positioned(
                      left: (_focusPoint!.dx * frameWidth) - 26,
                      top: (_focusPoint!.dy * frameHeight) - 26,
                      child: IgnorePointer(
                        child: AnimatedOpacity(
                          opacity: _focusPoint == null ? 0 : 1,
                          duration: const Duration(milliseconds: 180),
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFF7DE77),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_scanning)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.38),
                        alignment: Alignment.center,
                        child: const SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPreviewCard() {
    final previewFile = _capturedImage != null ? File(_capturedImage!.path) : null;

    return Card(
      color: const Color(0xFF102754),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 0.82,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF122D63), Color(0xFF0A1E47)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Photo-only mode',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Take one steady photo of the full card, or choose a clear saved image. This is more reliable than live scanning.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: previewFile == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.photo_camera_back_outlined,
                                size: 54,
                                color: Color(0xFFF7DE77),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'No photo selected yet',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 6),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 22),
                                child: Text(
                                  'Use Take Photo or Gallery below to scan a card.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.file(previewFile, fit: BoxFit.cover),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScannerActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _scanning ? null : _captureAndScanFromLivePreview,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF7DE77),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Take Photo'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _scanning ? null : _scanFromGallery,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withOpacity(0.18)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  backgroundColor: const Color(0xFF102754),
                ),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Gallery'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF16366E),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified_outlined, color: Color(0xFFF7DE77)),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Photo-only scanning',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_capturedImage != null || _analysis != null || _errorMessage != null) ...[
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _scanning ? null : _resetScanner,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.18)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    backgroundColor: const Color(0xFF102754),
                  ),
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('Reset'),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildTipCard() {
    Widget tipPill(IconData icon, String label) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: const Color(0xFFF7DE77)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      color: const Color(0xFF102754),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Best scan tips',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                tipPill(Icons.crop_portrait, 'Keep the full card in frame'),
                tipPill(Icons.photo_camera_outlined, 'Take one steady photo'),
                tipPill(Icons.wb_sunny_outlined, 'Avoid glare and shadows'),
                tipPill(Icons.photo_library_outlined, 'Gallery often works best'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLastCaptureCard() {
    if (_capturedImage == null) {
      return const SizedBox.shrink();
    }

    return Card(
      color: const Color(0xFF102754),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Image.file(
            File(_capturedImage!.path),
            width: 96,
            height: 132,
            fit: BoxFit.cover,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Last capture',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _scanning
                        ? 'Scanning this image now...'
                        : 'You can scan live again, tap the frame to refocus, or choose a different photo from your gallery.',
                    style: const TextStyle(
                      color: Colors.white70,
                      height: 1.35,
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

  Widget _buildScanningCard() {
    return Card(
      color: const Color(0xFF102754),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Padding(
        padding: EdgeInsets.all(18),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                'Reading the card and finding the best match...',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      color: const Color(0xFF5B1D28),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          _errorMessage!,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildScanSummaryCard({
    required TcgCard card,
    required String eyebrow,
    required String message,
    bool confirmed = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF102754),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF7DE77).withOpacity(0.30)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: Color(0xFFF7DE77),
                shape: BoxShape.circle,
              ),
              child: Icon(
                confirmed ? Icons.verified_rounded : Icons.touch_app_rounded,
                color: Colors.black,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eyebrow,
                    style: const TextStyle(
                      color: Color(0xFFF7DE77),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    card.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${card.setName} • #${card.number}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Color(0xFFD8E3FB),
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Raw price',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatPrice(card.rawPrice, fromCurrency: card.rawPriceCurrency),
                  style: const TextStyle(
                    color: Color(0xFFF7DE77),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChooseMatchCard(int count) {
    return Card(
      color: const Color(0xFF102754),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Likely matches found',
              style: TextStyle(
                color: Color(0xFFF7DE77),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose the correct card below.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The scanner is not confident enough to auto-confirm an exact print yet. Tap “This is my card” on the closest result.',
              style: const TextStyle(
                color: Color(0xFFD8E3FB),
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Showing top ${count.clamp(1, 3)} likely matches.',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExtractedTextCard() {
    return Card(
      color: const Color(0xFF102754),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'What the scanner read',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            if ((_analysis?.candidateNumbers.isNotEmpty ?? false))
              Text(
                'Card number hints: ${_analysis!.candidateNumbers.join(', ')}',
                style: const TextStyle(color: Color(0xFFF7DE77)),
              ),
            if ((_analysis?.candidateNames.isNotEmpty ?? false)) ...[
              const SizedBox(height: 6),
              Text(
                'Name hints: ${_analysis!.candidateNames.take(3).join(' • ')}',
                style: const TextStyle(color: Color(0xFFD8E3FB)),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              _analysis!.extractedText,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final autoBestMatch = _analysis?.bestMatch;
    final matches = _analysis?.matches ?? const <TcgCard>[];
    final confirmedMatch = _findConfirmedMatch(matches);
    final primaryMatch = confirmedMatch ?? autoBestMatch;
    final requiresConfirmation =
        !_scanning && _errorMessage == null && primaryMatch == null && matches.isNotEmpty;
    final extractedText = _analysis?.extractedText.trim() ?? '';

    final List<Widget> children = <Widget>[
      _buildScannerHeader(),
      const SizedBox(height: 14),
      _buildPreviewCard(),
      const SizedBox(height: 12),
      _buildScannerActions(),
    ];

    if (_capturedImage != null) {
      children.addAll(<Widget>[
        const SizedBox(height: 14),
        _buildLastCaptureCard(),
      ]);
    }

    if (_scanning) {
      children.addAll(<Widget>[
        const SizedBox(height: 14),
        _buildScanningCard(),
      ]);
    }

    if (_errorMessage != null && !_scanning) {
      children.addAll(<Widget>[
        const SizedBox(height: 14),
        _buildErrorCard(),
      ]);
    }

    if (primaryMatch != null) {
      children.addAll(<Widget>[
        const SizedBox(height: 14),
        _buildScanSummaryCard(
          card: primaryMatch,
          eyebrow: _analysis?.exactConfirmed == true
              ? 'Exact card confirmed'
              : 'Card selected',
          message: _analysis?.exactConfirmed == true
              ? 'The scanner found a strong enough match to confirm this exact print automatically.'
              : 'You selected this card from the likely matches below.',
          confirmed: true,
        ),
        const SizedBox(height: 18),
        Text(
          _analysis?.exactConfirmed == true ? 'Confirmed match' : 'Selected card',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        _ScanResultMatchCard(
          card: primaryMatch,
          highlight: true,
          actionLabel: 'View details',
          onActionTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CardDetailsPage(card: primaryMatch),
              ),
            );
          },
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CardDetailsPage(card: primaryMatch),
              ),
            );
          },
        ),
      ]);
    }

    if (requiresConfirmation) {
      children.addAll(<Widget>[
        const SizedBox(height: 14),
        _buildChooseMatchCard(matches.length),
        const SizedBox(height: 18),
        const Text(
          'Choose the correct card',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
      ]);
      for (final card in matches.take(3)) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ScanResultMatchCard(
              card: card,
              actionLabel: 'This is my card',
              onActionTap: () => _confirmMatch(card),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CardDetailsPage(card: card),
                  ),
                );
              },
            ),
          ),
        );
      }
    }

    final alternativeMatches = primaryMatch == null
        ? matches.skip(3).take(5)
        : matches.where((card) => card.id != primaryMatch.id).take(7);

    if (alternativeMatches.isNotEmpty) {
      children.addAll(<Widget>[
        const SizedBox(height: 18),
        Text(
          requiresConfirmation ? 'More likely matches' : 'Other likely matches',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
      ]);
      for (final card in alternativeMatches) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ScanResultMatchCard(
              card: card,
              actionLabel: 'This is my card',
              onActionTap: () => _confirmMatch(card),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CardDetailsPage(card: card),
                  ),
                );
              },
            ),
          ),
        );
      }
    }

    if (extractedText.isNotEmpty) {
      children.addAll(<Widget>[
        const SizedBox(height: 18),
        _buildExtractedTextCard(),
      ]);
    }

    final content = SafeArea(
      top: !widget.showAppBar,
      bottom: true,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: children,
      ),
    );

    if (!widget.showAppBar) {
      return content;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        title: const Text('Scan Card'),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
      ),
      body: content,
    );
  }
}

class _ScanCorner extends StatelessWidget {
  const _ScanCorner({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final isTop = alignment.y < 0;
    final isLeft = alignment.x < 0;

    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        border: Border(
          top: isTop ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
          bottom: !isTop ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
          left: isLeft ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
          right: !isLeft ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
        ),
      ),
    );
  }
}

class _ScanResultMatchCard extends StatelessWidget {
  const _ScanResultMatchCard({
    required this.card,
    required this.onTap,
    this.highlight = false,
    this.actionLabel,
    this.onActionTap,
  });

  final TcgCard card;
  final VoidCallback onTap;
  final bool highlight;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: highlight ? const Color(0xFF16366E) : const Color(0xFF102754),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: highlight
            ? const BorderSide(color: Color(0xFFF7DE77), width: 1.2)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            SizedBox(
              width: 96,
              height: 132,
              child: card.imageUrl == null
                  ? const ColoredBox(
                      color: Colors.black12,
                      child: Icon(Icons.image_not_supported, color: Colors.white),
                    )
                  : Image.network(card.imageUrl!, fit: BoxFit.cover),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      card.setName,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    Text(
                      'Number: ${card.number}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    if (card.rarity != null)
                      Text(
                        'Rarity: ${card.rarity}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Current raw price: ${_formatPrice(card.rawPrice, fromCurrency: card.rawPriceCurrency)}',
                      style: const TextStyle(
                        color: Color(0xFFF7DE77),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tap for full details',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    if (onActionTap != null && actionLabel != null) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.tonal(
                          onPressed: onActionTap,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFF7DE77),
                            foregroundColor: Colors.black,
                          ),
                          child: Text(actionLabel!),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardsSearchPlaceholder extends StatelessWidget {
  const _CardsSearchPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF102754),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 210,
            height: 210,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withOpacity(0.10),
                  Colors.white.withOpacity(0.03),
                  Colors.transparent,
                ],
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.04),
                        blurRadius: 30,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            color: const Color(0xFFDA3C3C).withOpacity(0.85),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            color: Colors.white.withOpacity(0.92),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 112,
                  height: 8,
                  color: const Color(0xFF1E1E1E).withOpacity(0.9),
                ),
                Container(
                  width: 34,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAEAEA),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF1E1E1E).withOpacity(0.9),
                      width: 7,
                    ),
                  ),
                ),
                Positioned(
                  right: 28,
                  bottom: 30,
                  child: Transform.rotate(
                    angle: -0.18,
                    child: Container(
                      width: 86,
                      height: 118,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: Colors.white.withOpacity(0.08),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.16),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Search cards or sets',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose Cards or Sets above, then type a Pokémon name, card name, or set name to start.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _SetSearchResultCard extends StatelessWidget {
  const _SetSearchResultCard({required this.set});

  final TcgSet set;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF102754),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SearchSetDetailsPage(set: set),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (set.logoUrl != null && set.logoUrl!.isNotEmpty)
                Center(
                  child: SizedBox(
                    height: 72,
                    child: Image.network(
                      set.logoUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Text(
                        set.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                )
              else
                Text(
                  set.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SetInfoChip(label: '${set.total} cards'),
                  _SetInfoChip(label: set.series),
                  _SetInfoChip(label: set.releaseDate),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: const [
                  Expanded(
                    child: Text(
                      'Tap this set to open it and view all of the cards inside.',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white70,
                    size: 28,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SearchSetDetailsPage extends StatefulWidget {
  const SearchSetDetailsPage({super.key, required this.set});

  final TcgSet set;

  @override
  State<SearchSetDetailsPage> createState() => _SearchSetDetailsPageState();
}

class _SearchSetDetailsPageState extends State<SearchSetDetailsPage> {
  late Future<List<TcgCard>> _cardsFuture;
  final Map<String, CardOwnership> _ownershipByCardId = <String, CardOwnership>{};
  bool _loadedOwnership = false;

  @override
  void initState() {
    super.initState();
    _cardsFuture = PokemonTcgService.fetchCardsBySet(widget.set.id);
    _loadOwnership();
  }

  Future<void> _loadOwnership() async {
    final loaded = await LocalPokedexStore.loadSetOwnershipMap(widget.set.id);
    _ownershipByCardId
      ..clear()
      ..addAll(loaded);

    if (mounted) {
      setState(() {
        _loadedOwnership = true;
      });
    }
  }

  Future<void> _saveOwnership() async {
    await LocalPokedexStore.saveSetOwnershipMap(widget.set.id, _ownershipByCardId);
    await PokedexSyncService.syncCurrentSetForCurrentUser(widget.set.id);
  }

  CardOwnership _ownershipFor(TcgCard card) {
    return _ownershipByCardId[card.id] ?? const CardOwnership();
  }

  bool _isOwned(TcgCard card) {
    final ownership = _ownershipFor(card);
    return ownership.effectiveCopies > 0 ||
        ownership.normal ||
        ownership.reverseHolo ||
        ownership.holo;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        title: Text(widget.set.name),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<TcgCard>>(
        future: _cardsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting || !_loadedOwnership) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load set cards: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            );
          }

          final cards = (snapshot.data ?? const <TcgCard>[]).toList()
            ..sort((a, b) => _compareCardNumbers(a.number, b.number));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: const Color(0xFF102754),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.set.logoUrl != null && widget.set.logoUrl!.isNotEmpty)
                        Center(
                          child: SizedBox(
                            height: 72,
                            child: Image.network(
                              widget.set.logoUrl!,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Text(
                                widget.set.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        Text(
                          widget.set.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _SetInfoChip(label: '${widget.set.total} cards'),
                          _SetInfoChip(label: widget.set.series),
                          _SetInfoChip(label: widget.set.releaseDate),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (cards.isEmpty)
                Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: const Color(0xFF102754),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'No cards found in this set.',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: cards.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.71,
                  ),
                  itemBuilder: (context, index) {
                    final card = cards[index];
                    final ownership = _ownershipFor(card);
                    final isOwned = _isOwned(card);
                    final hasShine = ownership.effectiveCopies > 1;

                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () async {
                        final updatedOwnership = await Navigator.of(context).push<CardOwnership>(
                          MaterialPageRoute(
                            builder: (_) => SearchSetCardManagePage(
                              card: card,
                              setName: widget.set.name,
                              ownership: ownership,
                            ),
                          ),
                        );
                        if (updatedOwnership != null) {
                          setState(() {
                            _ownershipByCardId[card.id] = updatedOwnership;
                          });
                          await _saveOwnership();
                        }
                      },
                      child: hasShine
                          ? _GlimmerBorder(
                              borderRadius: 14,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: card.imageUrl == null
                                    ? Container(
                                        color: const Color(0xFF0E2A5E),
                                        child: const Icon(
                                          Icons.image_not_supported,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      )
                                    : Image.network(
                                        card.imageUrl!,
                                        fit: BoxFit.cover,
                                      ),
                              ),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: card.imageUrl == null
                                  ? Container(
                                      color: const Color(0xFF0E2A5E),
                                      child: const Icon(
                                        Icons.image_not_supported,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    )
                                  : Image.network(
                                      card.imageUrl!,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                    );
                  },
                ),
              const SizedBox(height: 12),
              const Text(
                'Tap a card first to open its details and then choose whether to add or remove it from this set Pokédex.',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class MasterSetsPage extends StatefulWidget {
  const MasterSetsPage({super.key});

  @override
  State<MasterSetsPage> createState() => _MasterSetsPageState();
}

class _MasterSetsPageState extends State<MasterSetsPage> {
  late Future<List<TcgSet>> _futureSets;
  final Set<String> _trackedSetIds = <String>{};
  final Set<String> _nonEmptySetIds = <String>{};
  bool _loadedCollectionState = false;

  @override
  void initState() {
    super.initState();
    _futureSets = PokemonTcgService.fetchSets();
    _loadSetCollectionState();
    collectionRefreshNotifier.addListener(_handleCollectionRefresh);
  }

  void _handleCollectionRefresh() {
    refreshSets();
  }

  @override
  void dispose() {
    collectionRefreshNotifier.removeListener(_handleCollectionRefresh);
    super.dispose();
  }

  Future<void> refreshSets() async {
    setState(() {
      _loadedCollectionState = false;
      _futureSets = PokemonTcgService.fetchSets();
    });
    await _loadSetCollectionState();
  }

  Future<void> _loadSetCollectionState() async {
    final trackedSetIds = await LocalPokedexStore.allTrackedSetIds();
    final nonEmptySetIds = await LocalPokedexStore.allNonEmptySetIds();

    _trackedSetIds
      ..clear()
      ..addAll(trackedSetIds);
    _nonEmptySetIds
      ..clear()
      ..addAll(nonEmptySetIds);

    if (mounted) {
      setState(() {
        _loadedCollectionState = true;
      });
    }
  }

  bool _shouldShowSet(TcgSet set) {
    return _nonEmptySetIds.contains(set.id);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TcgSet>>(
      future: _futureSets,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || !_loadedCollectionState) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Could not load sets: ${snapshot.error}',
              style: const TextStyle(color: Colors.white),
            ),
          );
        }

        final allSets = snapshot.data ?? const <TcgSet>[];
        if (allSets.isEmpty) {
          return const Center(
            child: Text('No sets found.', style: TextStyle(color: Colors.white)),
          );
        }

        final visibleSets = allSets.where(_shouldShowSet).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                color: const Color(0xFF102754),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Only sets with saved cards show here. Add a card to a set and it will appear here.',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      Text(
                        '${visibleSets.length}/${allSets.length}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: refreshSets,
                child: visibleSets.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'No set Pokédex entries yet.\nPull down to refresh, or add a card to a set first and then that set will appear here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white70, fontSize: 16),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: visibleSets.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final set = visibleSets[index];

                          return Card(
                            color: const Color(0xFF102754),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => SetPokedexPage(set: set),
                                  ),
                                );
                                await _loadSetCollectionState();
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                alignment: Alignment.center,
                                constraints: const BoxConstraints(minHeight: 110),
                                child: (set.logoUrl != null && set.logoUrl!.isNotEmpty)
                                    ? Image.network(
                                        set.logoUrl!,
                                        fit: BoxFit.contain,
                                        height: 64,
                                        errorBuilder: (_, __, ___) => Text(
                                          set.name,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 18,
                                          ),
                                        ),
                                      )
                                    : Text(
                                        set.name,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 18,
                                        ),
                                      ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class SetPokedexPage extends StatefulWidget {
  const SetPokedexPage({super.key, required this.set});

  final TcgSet set;

  @override
  State<SetPokedexPage> createState() => _SetPokedexPageState();
}

class _SetPokedexPageState extends State<SetPokedexPage> {
  late Future<List<TcgCard>> _futureCards;
  final Map<String, CardOwnership> _ownershipByCardId = <String, CardOwnership>{};
  bool _loadedOwned = false;
  List<TcgCard> _allCards = <TcgCard>[];
  int _currentPage = 1;

  String get _storageKey => 'set_pokedex_${widget.set.id}';

  @override
  void initState() {
    super.initState();
    _futureCards = _loadCards();
    _loadOwnership();
  }

  Future<List<TcgCard>> _loadCards() async {
    final cards = await PokemonTcgService.fetchCardsBySet(widget.set.id);
    cards.sort((a, b) => _compareCardNumbers(a.number, b.number));
    _allCards = cards;
    return cards;
  }

  Future<void> _loadOwnership() async {
    final loaded = await LocalPokedexStore.loadSetOwnershipMap(widget.set.id);
    _ownershipByCardId
      ..clear()
      ..addAll(loaded);
    if (mounted) {
      setState(() {
        _loadedOwned = true;
      });
    }
  }

  Future<void> _saveOwnership() async {
    await LocalPokedexStore.saveSetOwnershipMap(widget.set.id, _ownershipByCardId);
    await PokedexSyncService.syncCurrentSetForCurrentUser(widget.set.id);
  }

  CardOwnership _ownershipFor(TcgCard card) {
    return _ownershipByCardId[card.id] ?? const CardOwnership();
  }

  bool _isOwned(CardOwnership ownership) {
    return ownership.effectiveCopies > 0 ||
        ownership.normal ||
        ownership.reverseHolo ||
        ownership.holo;
  }

  Future<void> _updateOwnership(TcgCard card, CardOwnership ownership) async {
    setState(() {
      _ownershipByCardId[card.id] = ownership;
    });
    await _saveOwnership();
  }

  List<TcgCard> get _filteredCards {
    final list = _allCards.toList();
    list.sort((a, b) => _compareCardNumbers(a.number, b.number));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFFF7DE77);

    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        toolbarHeight: 44,
        title: const Text(''),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<TcgCard>>(
        future: _futureCards,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting || !_loadedOwned) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Could not load cards: ${snapshot.error}',
                style: const TextStyle(color: Colors.white),
              ),
            );
          }

          final visibleCards = _filteredCards;
          final ownedCount = _allCards.where((c) => _isOwned(_ownershipFor(c))).length;
          final total = _allCards.length;
          final percent = total == 0 ? 0 : ((ownedCount / total) * 100).round();
          const cardsPerPage = 9;
          final totalPages = visibleCards.isEmpty ? 1 : ((visibleCards.length - 1) ~/ cardsPerPage) + 1;
          final safePage = _currentPage.clamp(1, totalPages).toInt();
          if (safePage != _currentPage) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _currentPage = safePage;
                });
              }
            });
          }
          final startIndex = (safePage - 1) * cardsPerPage;
          final endIndex = (startIndex + cardsPerPage).clamp(0, visibleCards.length).toInt();
          final pageCards = visibleCards.sublist(startIndex, endIndex);

          return SafeArea(
            bottom: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 2),
              child: Column(
                children: [
                  Transform.translate(
                    offset: const Offset(0, 6),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 2, right: 2),
                      child: Column(
                        children: [
                          if (widget.set.logoUrl != null && widget.set.logoUrl!.isNotEmpty)
                            SizedBox(
                              height: 64,
                              child: Image.network(
                                widget.set.logoUrl!,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                              ),
                            )
                          else
                            const SizedBox.shrink(),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: _CollectionStatCard(
                                  label: 'Owned',
                                  value: '$ownedCount/$total',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _CollectionStatCard(
                                  label: 'Complete',
                                  value: '$percent%',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: total == 0 ? 0 : ownedCount / total,
                            minHeight: 5,
                            backgroundColor: Colors.white12,
                            valueColor: AlwaysStoppedAnimation<Color>(accent),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: pageCards.isEmpty
                        ? const Center(
                            child: Text(
                              'No cards found in this set.',
                              style: TextStyle(color: Colors.white),
                            ),
                          )
                        : GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: pageCards.length,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 4,
                              mainAxisSpacing: 4,
                              childAspectRatio: 0.76,
                            ),
                            itemBuilder: (context, index) {
                              final card = pageCards[index];
                              final ownership = _ownershipFor(card);
                              return GestureDetector(
                                onLongPress: () async {
                                  final isOwned = ownership.effectiveCopies > 0 ||
                                      ownership.normal ||
                                      ownership.reverseHolo ||
                                      ownership.holo;
                                  final quickOwnership = isOwned
                                      ? const CardOwnership()
                                      : const CardOwnership(normal: true);
                                  await _updateOwnership(card, quickOwnership);
                                },
                                onTap: () async {
                                  final updated = await Navigator.of(context).push<CardOwnership>(
                                    MaterialPageRoute(
                                      builder: (_) => SetCardDetailsPage(
                                        card: card,
                                        ownership: ownership,
                                      ),
                                    ),
                                  );
                                  if (updated != null) {
                                    await _updateOwnership(card, updated);
                                  }
                                },
                                child: BinderCardTile(
                                  card: card,
                                  ownership: ownership,
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: safePage > 1
                              ? () {
                                  setState(() {
                                    _currentPage = safePage - 1;
                                  });
                                }
                              : null,
                          child: const Text('Previous'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '$safePage / $totalPages',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: safePage < totalPages
                              ? () {
                                  setState(() {
                                    _currentPage = safePage + 1;
                                  });
                                }
                              : null,
                          child: const Text('Next'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class SetCardDetailsPage extends StatefulWidget {
  const SetCardDetailsPage({
    super.key,
    required this.card,
    required this.ownership,
    this.readOnly = false,
    this.ownerLabel,
  });

  final TcgCard card;
  final CardOwnership ownership;
  final bool readOnly;
  final String? ownerLabel;

  @override
  State<SetCardDetailsPage> createState() => _SetCardDetailsPageState();
}

class _SetCardDetailsPageState extends State<SetCardDetailsPage> {
  late bool normal;
  late bool reverseHolo;
  late bool holo;
  late int copies;
  bool _setWishlistBusy = false;

  @override
  void initState() {
    super.initState();
    normal = widget.ownership.normal;
    reverseHolo = widget.ownership.reverseHolo;
    holo = widget.ownership.holo;
    copies = widget.ownership.effectiveCopies;
  }

  CardOwnership get _currentOwnership => CardOwnership(
        normal: normal,
        reverseHolo: reverseHolo,
        holo: holo,
        copies: copies,
      );

  Future<void> _toggleWishlist(bool isInWishlist) async {
    final ownerUid = FirebaseAuth.instance.currentUser?.uid;
    if (ownerUid == null || _setWishlistBusy) return;

    setState(() {
      _setWishlistBusy = true;
    });

    try {
      if (isInWishlist) {
        await WishlistService.removeCard(ownerUid: ownerUid, cardId: widget.card.id);
      } else {
        await WishlistService.addCard(ownerUid: ownerUid, card: widget.card);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isInWishlist ? 'Removed from wishlist' : 'Added to wishlist')),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Could not update wishlist right now')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update wishlist right now')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _setWishlistBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;

    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        title: Text(card.name),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SetLogoTile(setName: card.setName, logoUrl: card.setLogoUrl),
                  if (card.largeImageUrl != null)
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFBECBE1), Color(0xFF879CC4)],
                        ),
                      ),
                      padding: const EdgeInsets.all(7),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Image.network(card.largeImageUrl!),
                      ),
                    ),
                  const SizedBox(height: 16),
                  _DetailTile(label: 'Raw Price', value: _formatPrice(card.rawPrice, fromCurrency: card.rawPriceCurrency)),
                  _GradedPricesCard(card: card, gradedPrices: card.gradedPrices),
                  if (widget.readOnly && (widget.ownerLabel ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Card(
                      color: const Color(0xFF102754),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          widget.ownerLabel!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Card(
                    color: const Color(0xFF102754),
                    child: Column(
                      children: [
                        SwitchListTile(
                          value: normal,
                          onChanged: widget.readOnly ? null : (value) => setState(() => normal = value),
                          title: const Text('Normal', style: TextStyle(color: Colors.white)),
                        ),
                        const Divider(height: 1, color: Colors.white12),
                        SwitchListTile(
                          value: reverseHolo,
                          onChanged: widget.readOnly ? null : (value) => setState(() => reverseHolo = value),
                          title: const Text('Reverse Holo', style: TextStyle(color: Colors.white)),
                        ),
                        const Divider(height: 1, color: Colors.white12),
                        SwitchListTile(
                          value: holo,
                          onChanged: widget.readOnly ? null : (value) => setState(() => holo = value),
                          title: const Text('Holo', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    color: const Color(0xFF102754),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text(
                            'Copies in Set Pokédex',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: widget.readOnly
                                      ? null
                                      : copies > 0
                                          ? () {
                                              setState(() {
                                                copies--;
                                              });
                                            }
                                          : null,
                                  child: const Text('- Remove'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 72,
                                height: 48,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  '$copies',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton(
                                  onPressed: widget.readOnly
                                      ? null
                                      : () {
                                          setState(() {
                                            copies++;
                                          });
                                        },
                                  child: const Text('+ Add'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            widget.readOnly
                                ? '${widget.ownerLabel ?? 'Shared Pokédex'} is read-only in this view.'
                                : 'Cards with more than 1 saved copy get a shiny border in the set Pokédex.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StreamBuilder<bool>(
                    stream: WishlistService.cardInWishlistStream(
                      FirebaseAuth.instance.currentUser?.uid ?? '',
                      card.id,
                    ),
                    builder: (context, snapshot) {
                      final isInWishlist = snapshot.data ?? false;
                      return SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _setWishlistBusy ? null : () => _toggleWishlist(isInWishlist),
                          icon: Icon(
                            isInWishlist
                                ? Icons.favorite_rounded
                                : Icons.favorite_outline_rounded,
                          ),
                          label: Text(
                            isInWishlist ? 'Remove from Wishlist' : 'Add to Wishlist',
                          ),
                        ),
                      );
                    },
                  ),
                  if (!widget.readOnly) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(context).pop(_currentOwnership);
                        },
                        child: const Text('Save Card to Set Pokédex'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SearchSetCardManagePage extends StatefulWidget {
  const SearchSetCardManagePage({
    super.key,
    required this.card,
    required this.setName,
    required this.ownership,
  });

  final TcgCard card;
  final String setName;
  final CardOwnership ownership;

  @override
  State<SearchSetCardManagePage> createState() => _SearchSetCardManagePageState();
}

class _SearchSetCardManagePageState extends State<SearchSetCardManagePage> {
  late int _copies;

  @override
  void initState() {
    super.initState();
    _copies = widget.ownership.effectiveCopies;
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;

    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        title: Text(card.name),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SetLogoTile(setName: widget.setName, logoUrl: card.setLogoUrl),
                  if (card.largeImageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(card.largeImageUrl!, height: 320),
                    ),
                  const SizedBox(height: 16),
                  _DetailTile(label: 'Raw Price', value: _formatPrice(card.rawPrice, fromCurrency: card.rawPriceCurrency)),
                  _GradedPricesCard(card: card, gradedPrices: card.gradedPrices),
                  Card(
                    color: const Color(0xFF102754),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text(
                            'Copies in Set Pokédex',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _copies > 0
                                      ? () {
                                          setState(() {
                                            _copies--;
                                          });
                                        }
                                      : null,
                                  child: const Text('- Remove'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 72,
                                height: 48,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  '$_copies',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () {
                                    setState(() {
                                      _copies++;
                                    });
                                  },
                                  child: const Text('+ Add'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'If a card has more than 1 copy, it will get a shiny border in the set Pokédex.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop(
                      widget.ownership.copyWith(copies: _copies),
                    );
                  },
                  child: const Text('Save Card Count'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetInfoChip extends StatelessWidget {
  const _SetInfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CollectionStatCard extends StatelessWidget {
  const _CollectionStatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlimmerBorder extends StatefulWidget {
  const _GlimmerBorder({
    required this.child,
    required this.borderRadius,
  });

  final Widget child;
  final double borderRadius;

  @override
  State<_GlimmerBorder> createState() => _GlimmerBorderState();
}

class _GlimmerBorderState extends State<_GlimmerBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final bright = Color.lerp(
          const Color(0xFFFFF2A8),
          Colors.white,
          t,
        )!;
        final mid = Color.lerp(
          const Color(0xFFF7DE77),
          const Color(0xFFFFE082),
          t,
        )!;
        final blur = 8.0 + (t * 8.0);
        final spread = 0.8 + (t * 1.4);
        final padding = 2.0 + (t * 0.8);

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1 + (t * 2), -1),
              end: Alignment(1, 1 - (t * 2)),
              colors: [bright, mid, bright],
            ),
            boxShadow: [
              BoxShadow(
                color: mid.withOpacity(0.45 + (t * 0.25)),
                blurRadius: blur,
                spreadRadius: spread,
              ),
            ],
          ),
          padding: EdgeInsets.all(padding),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class BinderCardTile extends StatelessWidget {
  const BinderCardTile({
    super.key,
    required this.card,
    required this.ownership,
  });

  final TcgCard card;
  final CardOwnership ownership;

  bool get isOwned =>
      ownership.effectiveCopies > 0 ||
      ownership.normal ||
      ownership.reverseHolo ||
      ownership.holo;

  bool get hasShine => ownership.effectiveCopies > 1;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: isOwned ? 1 : 0.42,
      child: hasShine
          ? _GlimmerBorder(
              borderRadius: 14,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColorFiltered(
                      colorFilter: isOwned
                          ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                          : const ColorFilter.matrix(<double>[
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0, 0, 0, 1, 0,
                            ]),
                      child: card.imageUrl == null
                          ? Container(
                              color: const Color(0xFF102754),
                              child: const Center(
                                child: Icon(
                                  Icons.image_not_supported,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            )
                          : Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(card.imageUrl!, fit: BoxFit.cover),
                                if (!isOwned)
                                  Container(color: Colors.black.withOpacity(0.25)),
                              ],
                            ),
                    ),
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.72),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '#${card.number}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    if (ownership.effectiveCopies > 0)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: hasShine ? const Color(0xFFF7DE77) : Colors.black.withOpacity(0.72),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'x${ownership.effectiveCopies}',
                            style: TextStyle(
                              color: hasShine ? Colors.black : Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _VariantPill(label: 'N', active: ownership.normal),
                          const SizedBox(width: 3),
                          _VariantPill(label: 'RH', active: ownership.reverseHolo),
                          const SizedBox(width: 3),
                          _VariantPill(label: 'H', active: ownership.holo),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Container(
              decoration: const BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Color.fromARGB(45, 0, 0, 0),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColorFiltered(
                      colorFilter: isOwned
                          ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                          : const ColorFilter.matrix(<double>[
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0, 0, 0, 1, 0,
                            ]),
                      child: card.imageUrl == null
                          ? Container(
                              color: const Color(0xFF102754),
                              child: const Center(
                                child: Icon(
                                  Icons.image_not_supported,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            )
                          : Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(card.imageUrl!, fit: BoxFit.cover),
                                if (!isOwned)
                                  Container(color: Colors.black.withOpacity(0.25)),
                              ],
                            ),
                    ),
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.72),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '#${card.number}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    if (ownership.effectiveCopies > 0)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.72),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'x${ownership.effectiveCopies}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _VariantPill(label: 'N', active: ownership.normal),
                          const SizedBox(width: 3),
                          _VariantPill(label: 'RH', active: ownership.reverseHolo),
                          const SizedBox(width: 3),
                          _VariantPill(label: 'H', active: ownership.holo),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _VariantPill extends StatelessWidget {
  const _VariantPill({required this.label, required this.active});

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

class _ProfileAppBarButton extends StatefulWidget {
  const _ProfileAppBarButton({required this.profile});

  final AppUserProfile profile;

  @override
  State<_ProfileAppBarButton> createState() => _ProfileAppBarButtonState();
}

class _ProfileAppBarButtonState extends State<_ProfileAppBarButton> {
  String? _profileImagePath;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
  }

  @override
  void didUpdateWidget(covariant _ProfileAppBarButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.uid != widget.profile.uid) {
      _loadProfileImage();
    }
  }

  Future<void> _loadProfileImage() async {
    final imagePath = await LocalProfileImageStore.loadForUser(widget.profile.uid);
    if (mounted) {
      setState(() {
        _profileImagePath = imagePath;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _profileImagePath != null && _profileImagePath!.trim().isNotEmpty;
    final displayLetter = widget.profile.displayName.isEmpty ? 'T' : widget.profile.displayName[0].toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ProfilePage(profile: widget.profile)),
          );
          await _loadProfileImage();
        },
        child: CircleAvatar(
          radius: 18,
          backgroundColor: Colors.white12,
          backgroundImage: hasImage ? FileImage(File(_profileImagePath!)) : null,
          child: hasImage
              ? null
              : Text(
                  displayLetter,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.profile});

  final AppUserProfile profile;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  String? _profileImagePath;
  bool _loadingProfile = true;
  bool _savingName = false;
  bool _savingCurrency = false;
  String _selectedCurrencyCode = CurrencySettings.selectedCode;
  late Future<ProfileStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _loadStats();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    _nameController.text = widget.profile.displayName;
    final imagePath = await LocalProfileImageStore.loadForUser(widget.profile.uid);

    if (mounted) {
      setState(() {
        _profileImagePath = imagePath;
        _selectedCurrencyCode = CurrencySettings.selectedCode;
        _loadingProfile = false;
      });
    }
  }

  Future<void> _saveName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a trainer name')),
      );
      return;
    }

    setState(() {
      _savingName = true;
    });

    try {
      await UserProfileService.upsertProfile(user: user, username: newName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name updated')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update your name')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _savingName = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null) return;

    final permanentPath = await LocalProfileImageStore.saveForUser(
      uid: widget.profile.uid,
      sourcePath: picked.path,
    );

    if (mounted) {
      setState(() {
        _profileImagePath = permanentPath;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture saved on this device')),
      );
    }
  }


  Future<void> _updateCurrency(String? value) async {
    if (value == null || value == _selectedCurrencyCode) return;

    setState(() {
      _savingCurrency = true;
    });

    try {
      await CurrencySettings.setSelectedCode(value);
      if (!mounted) return;

      setState(() {
        _selectedCurrencyCode = CurrencySettings.selectedCode;
        _statsFuture = _loadStats();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Currency changed to ${CurrencySettings.selectedCurrency.code}')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update your currency right now')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingCurrency = false;
        });
      }
    }
  }

  Future<ProfileStats> _loadStats() async {
    final cardCopies = await LocalPokedexStore.loadAllCardCopies();

    if (cardCopies.isEmpty) {
      return const ProfileStats(
        totalCards: 0,
        totalEstimatedPrice: 0,
        mostExpensiveCard: null,
        mostExpensiveCardCopies: 0,
      );
    }

    final fetchedCards = await Future.wait(
      cardCopies.keys.map(PokemonTcgService.fetchCardById),
    );

    double totalEstimatedPrice = 0;
    TcgCard? mostExpensiveCard;
    int mostExpensiveCardCopies = 0;
    double mostExpensivePrice = -1;

    for (final card in fetchedCards) {
      final copies = cardCopies[card.id] ?? 0;
      final convertedUnitPrice = CurrencySettings.convertAmountSync(
            card.marketPrice,
            fromCurrency: card.rawPriceCurrency,
          ) ??
          0;
      totalEstimatedPrice += convertedUnitPrice * copies;

      if (convertedUnitPrice > mostExpensivePrice) {
        mostExpensivePrice = convertedUnitPrice;
        mostExpensiveCard = card;
        mostExpensiveCardCopies = copies;
      }
    }

    final totalCards = cardCopies.values.fold<int>(0, (sum, value) => sum + value);

    return ProfileStats(
      totalCards: totalCards,
      totalEstimatedPrice: totalEstimatedPrice,
      mostExpensiveCard: mostExpensiveCard,
      mostExpensiveCardCopies: mostExpensiveCardCopies,
    );
  }

  Future<void> _refreshStats() async {
    setState(() {
      _statsFuture = _loadStats();
    });
  }

  Future<void> _openFriends() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FriendsPage(currentProfile: widget.profile),
      ),
    );
  }

  Future<void> _openWishlist() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WishlistPage(
          ownerUid: widget.profile.uid,
          ownerName: widget.profile.displayName,
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imageFile = _profileImagePath != null ? File(_profileImagePath!) : null;
    final imageExists = imageFile != null && imageFile.existsSync();
    final bottomSafePadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _loadingProfile
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshStats,
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 28 + bottomSafePadding),
                children: [
                  Card(
                    color: const Color(0xFF102754),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _pickImage,
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Colors.white12,
                                  backgroundImage: imageExists ? FileImage(imageFile!) : null,
                                  child: !imageExists
                                      ? const Icon(
                                          Icons.person,
                                          color: Colors.white,
                                          size: 50,
                                        )
                                      : null,
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF7DE77),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFF041B4A), width: 2),
                                    ),
                                    child: const Icon(Icons.edit, color: Colors.black, size: 18),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'This picture is stored only on this device in the no-Storage version.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _nameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Trainer Name',
                              labelStyle: const TextStyle(color: Colors.white70),
                              filled: true,
                              fillColor: const Color(0xFF0E2A5E),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            readOnly: true,
                            style: const TextStyle(color: Colors.white70),
                            decoration: InputDecoration(
                              labelText: 'Email',
                              hintText: widget.profile.email,
                              hintStyle: const TextStyle(color: Colors.white70),
                              labelStyle: const TextStyle(color: Colors.white70),
                              filled: true,
                              fillColor: const Color(0xFF0E2A5E),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _selectedCurrencyCode,
                            dropdownColor: const Color(0xFF102754),
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Display Currency',
                              labelStyle: const TextStyle(color: Colors.white70),
                              filled: true,
                              fillColor: const Color(0xFF0E2A5E),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            items: CurrencySettings.supportedCurrencies.values
                                .map(
                                  (currency) => DropdownMenuItem<String>(
                                    value: currency.code,
                                    child: Text(
                                      '${currency.code} • ${currency.label}',
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: _savingCurrency ? null : _updateCurrency,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Card prices update across the app when you change this setting.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          if (_savingCurrency) ...[
                            const SizedBox(height: 10),
                            const LinearProgressIndicator(),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _pickImage,
                                  icon: const Icon(Icons.photo_library_outlined),
                                  label: const Text('Choose Picture'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _savingName ? null : _saveName,
                                  icon: const Icon(Icons.save_outlined),
                                  label: Text(_savingName ? 'Saving...' : 'Save Name'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: const Color(0xFF102754),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Friends & shared Pokédex',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Open your friends list, review requests, and browse their synced Pokédex collections.',
                            style: TextStyle(color: Color(0xFFD8E3FB), height: 1.35),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => FriendRequestsPage(currentProfile: widget.profile),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.person_add_alt_1_outlined),
                                  label: const Text('Requests'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _openFriends,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF2C7A5B),
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: const Icon(Icons.collections_bookmark_outlined),
                                  label: const Text('Friends'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<List<WishlistEntry>>(
                    stream: WishlistService.wishlistStream(widget.profile.uid),
                    builder: (context, snapshot) {
                      final wishlistCount = (snapshot.data ?? const <WishlistEntry>[]).length;
                      return Card(
                        color: const Color(0xFF102754),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Wishlist',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                wishlistCount == 1
                                    ? '1 card saved for later.'
                                    : '$wishlistCount cards saved for later.',
                                style: const TextStyle(color: Color(0xFFD8E3FB), height: 1.35),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _openWishlist,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFFB13B59),
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: const Icon(Icons.favorite_outline_rounded),
                                  label: const Text('Open Wishlist'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<ProfileStats>(
                    future: _statsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      if (snapshot.hasError) {
                        return Card(
                          color: const Color(0xFF102754),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Could not load profile stats: ${snapshot.error}',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        );
                      }

                      final stats = snapshot.data ?? const ProfileStats(
                        totalCards: 0,
                        totalEstimatedPrice: 0,
                        mostExpensiveCard: null,
                        mostExpensiveCardCopies: 0,
                      );

                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _ProfileStatCard(
                                  title: 'Total Cards',
                                  value: '${stats.totalCards}',
                                  icon: Icons.style_outlined,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _ProfileStatCard(
                                  title: 'Total Value',
                                  value: CurrencySettings.formatSelectedAmount(stats.totalEstimatedPrice),
                                  icon: Icons.payments_outlined,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _MostExpensiveCardWidget(
                            card: stats.mostExpensiveCard,
                            copies: stats.mostExpensiveCardCopies,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

class _ProfileStatCard extends StatelessWidget {
  const _ProfileStatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF102754),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFF7DE77), size: 28),
            const SizedBox(height: 10),
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MostExpensiveCardWidget extends StatelessWidget {
  const _MostExpensiveCardWidget({
    required this.card,
    required this.copies,
  });

  final TcgCard? card;
  final int copies;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF102754),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      clipBehavior: Clip.antiAlias,
      child: card == null
          ? const Padding(
              padding: EdgeInsets.all(18),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Most Expensive Card',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No saved cards yet.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            )
          : InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CardDetailsPage(card: card!),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 86,
                        height: 120,
                        child: card!.imageUrl == null
                            ? Container(
                                color: const Color(0xFF0E2A5E),
                                child: const Icon(
                                  Icons.image_not_supported,
                                  color: Colors.white,
                                ),
                              )
                            : Image.network(card!.imageUrl!, fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Most Expensive Card',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            card!.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            card!.setName,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Est. price: ${_formatPrice(card!.marketPrice, fromCurrency: card!.rawPriceCurrency)}',
                            style: const TextStyle(
                              color: Color(0xFFF7DE77),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Copies saved: $copies',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Tap to view raw and graded prices',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class ProfileStats {
  const ProfileStats({
    required this.totalCards,
    required this.totalEstimatedPrice,
    required this.mostExpensiveCard,
    required this.mostExpensiveCardCopies,
  });

  final int totalCards;
  final double totalEstimatedPrice;
  final TcgCard? mostExpensiveCard;
  final int mostExpensiveCardCopies;
}

class CardDetailsPage extends StatefulWidget {
  const CardDetailsPage({super.key, required this.card});

  final TcgCard card;

  @override
  State<CardDetailsPage> createState() => _CardDetailsPageState();
}

class _CardDetailsPageState extends State<CardDetailsPage> {
  late CardOwnership _ownership;
  bool _loadingOwnership = true;
  bool _wishlistBusy = false;

  String get _storageKey => 'set_pokedex_${widget.card.setId}';

  @override
  void initState() {
    super.initState();
    _loadOwnership();
  }

  Future<void> _loadOwnership() async {
    final ownershipByCardId = await LocalPokedexStore.loadSetOwnershipMap(widget.card.setId);
    final ownership = ownershipByCardId[widget.card.id] ?? const CardOwnership();

    if (mounted) {
      setState(() {
        _ownership = ownership;
        _loadingOwnership = false;
      });
    }
  }

  Future<void> _saveOwnership(CardOwnership ownership) async {
    final ownershipByCardId = await LocalPokedexStore.loadSetOwnershipMap(widget.card.setId);
    ownershipByCardId[widget.card.id] = ownership;
    await LocalPokedexStore.saveSetOwnershipMap(widget.card.setId, ownershipByCardId);
    await PokedexSyncService.syncCurrentSetForCurrentUser(widget.card.setId);

    if (mounted) {
      setState(() {
        _ownership = ownership;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Card saved to Set Pokédex')),
      );
    }
  }

  Future<void> _removeFromPokedex() async {
    await LocalPokedexStore.removeCard(widget.card.setId, widget.card.id);
    await PokedexSyncService.syncCurrentSetForCurrentUser(widget.card.setId);

    if (mounted) {
      setState(() {
        _ownership = const CardOwnership();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Card removed from Set Pokédex')),
      );
    }
  }

  Future<void> _toggleWishlist(bool isInWishlist) async {
    final ownerUid = FirebaseAuth.instance.currentUser?.uid;
    if (ownerUid == null || _wishlistBusy) return;

    setState(() {
      _wishlistBusy = true;
    });

    try {
      if (isInWishlist) {
        await WishlistService.removeCard(ownerUid: ownerUid, cardId: widget.card.id);
      } else {
        await WishlistService.addCard(ownerUid: ownerUid, card: widget.card);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isInWishlist ? 'Removed from wishlist' : 'Added to wishlist')),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Could not update wishlist right now')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update wishlist right now')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _wishlistBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final hasSavedCopies = !_loadingOwnership && _ownership.effectiveCopies > 0;

    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        title: Text(card.name),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SetLogoTile(setName: card.setName, logoUrl: card.setLogoUrl),
                  if (card.largeImageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(card.largeImageUrl!, height: 320),
                    ),
                  const SizedBox(height: 16),
                  _DetailTile(label: 'Raw Price', value: _formatPrice(card.rawPrice, fromCurrency: card.rawPriceCurrency)),
                  _GradedPricesCard(card: card, gradedPrices: card.gradedPrices),
                  const SizedBox(height: 12),
                  Card(
                    color: const Color(0xFF102754),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _loadingOwnership
                          ? const Center(child: CircularProgressIndicator())
                          : Column(
                              children: [
                                Text(
                                  hasSavedCopies
                                      ? 'Saved to Set Pokédex: x${_ownership.effectiveCopies}'
                                      : 'This card is not in your Set Pokédex yet.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Use the buttons below to add this card straight from search results.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
            if (!_loadingOwnership)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasSavedCopies)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _removeFromPokedex,
                          child: const Text('Remove from Set Pokédex'),
                        ),
                      ),
                    if (hasSavedCopies) const SizedBox(height: 8),
                    StreamBuilder<bool>(
                      stream: WishlistService.cardInWishlistStream(
                        FirebaseAuth.instance.currentUser?.uid ?? '',
                        card.id,
                      ),
                      builder: (context, snapshot) {
                        final isInWishlist = snapshot.data ?? false;
                        return SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _wishlistBusy ? null : () => _toggleWishlist(isInWishlist),
                            icon: Icon(
                              isInWishlist
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_outline_rounded,
                            ),
                            label: Text(
                              isInWishlist ? 'Remove from Wishlist' : 'Add to Wishlist',
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          final updatedOwnership =
                              await Navigator.of(context).push<CardOwnership>(
                            MaterialPageRoute(
                              builder: (_) => SearchSetCardManagePage(
                                card: card,
                                setName: card.setName,
                                ownership: _ownership,
                              ),
                            ),
                          );
                          if (updatedOwnership != null) {
                            await _saveOwnership(updatedOwnership);
                          }
                        },
                        child: Text(
                          hasSavedCopies
                              ? 'Edit Set Pokédex Count'
                              : 'Add to Set Pokédex',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SetLogoTile extends StatelessWidget {
  const _SetLogoTile({
    required this.setName,
    required this.logoUrl,
  });

  final String setName;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF102754),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: logoUrl != null && logoUrl!.isNotEmpty
              ? SizedBox(
                  height: 54,
                  child: Image.network(
                    logoUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Text(
                      setName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ),
                )
              : Text(
                  setName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
        ),
      ),
    );
  }
}

class _GradedPricesCard extends StatelessWidget {
  const _GradedPricesCard({
    required this.card,
    required this.gradedPrices,
  });

  final TcgCard card;
  final Map<String, double> gradedPrices;

  @override
  Widget build(BuildContext context) {
    final preferredLabels = <String>[
      'PSA 10',
      'BGS 10',
      'CGC 10',
      'SGC 10',
      'ACE 10',
      'GEM 10',
    ];

    final labelsToShow = <String>{
      ...preferredLabels,
      ...gradedPrices.keys,
    }.toList();

    return Card(
      color: const Color(0xFF102754),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'eBay Sold Searches',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            _EbaySoldRow(
              label: 'Raw',
              price: card.rawPrice,
              sourceCurrency: card.rawPriceCurrency,
              onTap: () => _openEbaySoldSearch(context: context, card: card),
            ),
            const SizedBox(height: 8),
            ...labelsToShow.map(
              (label) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _EbaySoldRow(
                  label: label,
                  price: gradedPrices[label],
                  onTap: () => _openEbaySoldSearch(
                    context: context,
                    card: card,
                    gradeLabel: label,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap any row to open recent sold eBay results for that version.',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EbaySoldRow extends StatelessWidget {
  const _EbaySoldRow({
    required this.label,
    required this.price,
    required this.onTap,
    this.sourceCurrency = 'USD',
  });

  final String label;
  final double? price;
  final VoidCallback onTap;
  final String sourceCurrency;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            Text(
              _formatPrice(price, fromCurrency: sourceCurrency),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.open_in_new,
              size: 18,
              color: Colors.white54,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF102754),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(label, style: const TextStyle(color: Colors.white)),
        subtitle: Text(value, style: const TextStyle(color: Colors.white70)),
      ),
    );
  }
}

class PokemonTcgService {
  static const String _baseUrl = 'https://api.pokemontcg.io/v2';
  static final Map<String, List<TcgCard>> _setCardsCache = <String, List<TcgCard>>{};
  static final Map<String, Future<List<TcgCard>>> _setCardsInFlight =
      <String, Future<List<TcgCard>>>{};

  static Future<CardSearchResult> searchCardsAndSets(String query) async {
    final results = await Future.wait<dynamic>([
      searchCardsOnly(query),
      searchSetsOnly(query),
    ]);
    final cards = results[0] as List<TcgCard>;
    final sets = results[1] as List<TcgSet>;
    return CardSearchResult(
      cards: cards,
      sets: sets,
      matchedSet: sets.isEmpty ? null : sets.first,
    );
  }

  static Future<List<TcgCard>> _fetchAllCardsForSearch(String cardSearch) async {
    const pageSize = 250;
    final cardsById = <String, TcgCard>{};
    var page = 1;

    while (true) {
      final cardsUri = Uri.parse(
        '$_baseUrl/cards?q=$cardSearch&pageSize=$pageSize&page=$page&orderBy=name,set.releaseDate,number',
      );
      final cardsResponse = await http.get(cardsUri);

      if (cardsResponse.statusCode != 200) {
        throw Exception('HTTP ${cardsResponse.statusCode}');
      }

      final cardsData = jsonDecode(cardsResponse.body) as Map<String, dynamic>;
      final cardsItems = (cardsData['data'] as List<dynamic>? ?? []);

      if (cardsItems.isEmpty) {
        break;
      }

      for (final item in cardsItems) {
        final card = TcgCard.fromJson(item as Map<String, dynamic>);
        cardsById.putIfAbsent(card.id, () => card);
      }

      if (cardsItems.length < pageSize || page >= 40) {
        break;
      }

      page++;
    }

    final cards = cardsById.values.toList()
      ..sort((a, b) {
        final nameCompare = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        if (nameCompare != 0) return nameCompare;

        final setCompare = a.setName.toLowerCase().compareTo(b.setName.toLowerCase());
        if (setCompare != 0) return setCompare;

        return _compareCardNumbers(a.number, b.number);
      });

    return cards;
  }


  static Future<CardSearchResult> searchCardsOnlyResult(String query) async {
    final cards = await searchCardsOnly(query);
    return CardSearchResult(cards: cards);
  }

  static Future<CardSearchResult> searchSetsOnlyResult(String query) async {
    final sets = await searchSetsOnly(query);
    return CardSearchResult(sets: sets, matchedSet: sets.isEmpty ? null : sets.first);
  }

  static Future<List<TcgCard>> searchCardsOnly(String query) async {
    final cleanQuery = query.trim();
    final terms = cleanQuery
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (terms.isEmpty) return const <TcgCard>[];

    final cardSearch = terms.map((term) => 'name:*$term*').join(' AND ');
    final allCards = <TcgCard>[];
    var page = 1;

    while (true) {
      final uri = Uri.parse(
        '$_baseUrl/cards?q=$cardSearch&pageSize=250&page=$page&orderBy=name,number,set.releaseDate',
      );
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final items = (data['data'] as List<dynamic>? ?? const []);
      if (items.isEmpty) break;

      allCards.addAll(
        items.map((item) => TcgCard.fromJson(item as Map<String, dynamic>)),
      );

      if (items.length < 250) break;
      page++;
      if (page > 8) break;
    }

    return allCards;
  }

  static Future<List<TcgSet>> searchSetsOnly(String query) async {
    final cleanQuery = query.trim();
    final terms = cleanQuery
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (terms.isEmpty) return const <TcgSet>[];

    final escapedTerms = terms.map(_escapeTcgQueryValue).toList();
    final exactPrefixSearch = escapedTerms
        .map((term) => 'name:${term}*')
        .join(' AND ');
    final broadSearch = escapedTerms
        .map((term) => 'name:*$term*')
        .join(' AND ');

    final setsById = <String, TcgSet>{};

    Future<void> fetchSets(String setSearch, {int maxPages = 5}) async {
      var page = 1;
      while (true) {
        final uri = Uri.parse(
          '$_baseUrl/sets?q=$setSearch&pageSize=100&page=$page&orderBy=releaseDate',
        );
        final response = await http.get(uri);
        if (response.statusCode != 200) {
          throw Exception('HTTP ${response.statusCode}');
        }

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final items = (data['data'] as List<dynamic>? ?? const []);
        if (items.isEmpty) break;

        for (final item in items) {
          final set = TcgSet.fromJson(item as Map<String, dynamic>);
          setsById.putIfAbsent(set.id, () => set);
        }

        if (items.length < 100) break;
        page++;
        if (page > maxPages) break;
      }
    }

    await fetchSets(exactPrefixSearch, maxPages: 3);
    if (setsById.isEmpty) {
      await fetchSets(broadSearch, maxPages: 5);
    }

    final sets = setsById.values.toList()
      ..sort((a, b) => _compareSetSearchResults(a, b, cleanQuery));

    final prefixMatches = sets
        .where((set) => _matchesSetPrefixSearch(set, cleanQuery))
        .toList();
    if (prefixMatches.isNotEmpty) {
      return prefixMatches;
    }

    return sets;
  }

  static String _escapeTcgQueryValue(String value) {
    return value
        .trim()
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"');
  }

  static int _compareSetSearchResults(TcgSet a, TcgSet b, String query) {
    final scoreA = _scoreSetSearchResult(a, query);
    final scoreB = _scoreSetSearchResult(b, query);
    if (scoreA != scoreB) {
      return scoreB.compareTo(scoreA);
    }

    final dateA = _tryParseReleaseDate(a.releaseDate);
    final dateB = _tryParseReleaseDate(b.releaseDate);
    if (dateA != null && dateB != null) {
      final dateCompare = dateA.compareTo(dateB);
      if (dateCompare != 0) return dateCompare;
    } else if (dateA != null) {
      return -1;
    } else if (dateB != null) {
      return 1;
    }

    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  static int _scoreSetSearchResult(TcgSet set, String query) {
    final normalizedQuery = _normalizeSearchMatchText(query);
    final normalizedName = _normalizeSearchMatchText(set.name);
    if (normalizedQuery.isEmpty || normalizedName.isEmpty) return 0;

    if (normalizedName == normalizedQuery) return 500;
    if (normalizedName.startsWith(normalizedQuery)) return 460;
    if (_matchesSetPrefixSearch(set, query)) return 430;
    if (normalizedName.contains(normalizedQuery)) return 320;

    final queryWords = normalizedQuery.split(' ').where((word) => word.isNotEmpty).toList();
    final nameWords = normalizedName.split(' ').where((word) => word.isNotEmpty).toList();
    var score = 0;
    for (final word in queryWords) {
      if (normalizedName == word) {
        score += 120;
      } else if (normalizedName.startsWith(word)) {
        score += 95;
      } else if (nameWords.any((nameWord) => nameWord.startsWith(word))) {
        score += 80;
      } else if (normalizedName.contains(word)) {
        score += 35;
      }
    }

    return score;
  }

  static bool _matchesSetPrefixSearch(TcgSet set, String query) {
    final normalizedQuery = _normalizeSearchMatchText(query);
    final normalizedName = _normalizeSearchMatchText(set.name);
    if (normalizedQuery.isEmpty || normalizedName.isEmpty) return false;

    final queryWords = normalizedQuery.split(' ').where((word) => word.isNotEmpty).toList();
    final nameWords = normalizedName.split(' ').where((word) => word.isNotEmpty).toList();
    if (queryWords.isEmpty || nameWords.isEmpty) return false;

    return queryWords.every(
      (queryWord) => nameWords.any((nameWord) => nameWord.startsWith(queryWord)),
    );
  }

  static String _normalizeSearchMatchText(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static DateTime? _tryParseReleaseDate(String value) {
    try {
      return DateTime.tryParse(value);
    } catch (_) {
      return null;
    }
  }

  static Future<List<TcgCard>> searchCards(String query) async {
    return searchCardsOnly(query);
  }

  static Future<CardScanAnalysis> scanCardFromImage(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    String? croppedImagePath;
    String? bottomLeftCropPath;
    String bottomLeftOcrText = '';

    try {
      croppedImagePath = await _createScannerCrop(imagePath);

      final primaryPath = croppedImagePath ?? imagePath;
      final primaryRecognizedText = await recognizer.processImage(
        InputImage.fromFilePath(primaryPath),
      );
      var primaryAnalysis = await analyzeRecognizedScan(primaryRecognizedText);

      bottomLeftCropPath = await _createBottomLeftScannerCrop(primaryPath);
      if (bottomLeftCropPath != null) {
        final bottomLeftRecognizedText = await recognizer.processImage(
          InputImage.fromFilePath(bottomLeftCropPath),
        );
        bottomLeftOcrText = bottomLeftRecognizedText.text;
        primaryAnalysis = await _refineAnalysisWithBottomLeftText(
          analysis: primaryAnalysis,
          bottomLeftText: bottomLeftOcrText,
        );
      }

      if (croppedImagePath == null) {
        return primaryAnalysis;
      }

      if (_scanAnalysisConfidence(primaryAnalysis) >= 80) {
        return primaryAnalysis;
      }

      final fallbackRecognizedText = await recognizer.processImage(
        InputImage.fromFilePath(imagePath),
      );
      var fallbackAnalysis = await analyzeRecognizedScan(fallbackRecognizedText);
      if (bottomLeftOcrText.trim().isNotEmpty) {
        fallbackAnalysis = await _refineAnalysisWithBottomLeftText(
          analysis: fallbackAnalysis,
          bottomLeftText: bottomLeftOcrText,
        );
      }

      return _preferScanAnalysis(primaryAnalysis, fallbackAnalysis);
    } finally {
      await recognizer.close();
      for (final tempPath in <String?>[croppedImagePath, bottomLeftCropPath]) {
        if (tempPath == null) continue;
        try {
          final file = File(tempPath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}
      }
    }
  }

  static Future<String?> _createScannerCrop(String imagePath) async {
    try {
      final sourceBytes = await File(imagePath).readAsBytes();
      final decodedImage = img.decodeImage(sourceBytes);
      if (decodedImage == null) return null;

      final oriented = img.bakeOrientation(decodedImage);
      final imageWidth = oriented.width;
      final imageHeight = oriented.height;
      if (imageWidth < 200 || imageHeight < 200) {
        return null;
      }

      const cardAspectRatio = 63 / 88;
      var cropWidth = (imageWidth * 0.78).round();
      var cropHeight = (cropWidth / cardAspectRatio).round();

      final maxHeight = (imageHeight * 0.86).round();
      if (cropHeight > maxHeight) {
        cropHeight = maxHeight;
        cropWidth = (cropHeight * cardAspectRatio).round();
      }

      final maxWidth = (imageWidth * 0.88).round();
      if (cropWidth > maxWidth) {
        cropWidth = maxWidth;
        cropHeight = (cropWidth / cardAspectRatio).round();
      }

      cropWidth = cropWidth.clamp(120, imageWidth).toInt();
      cropHeight = cropHeight.clamp(160, imageHeight).toInt();

      final cropX = ((imageWidth - cropWidth) / 2).round().clamp(0, imageWidth - cropWidth).toInt();
      final cropY = ((imageHeight - cropHeight) / 2).round().clamp(0, imageHeight - cropHeight).toInt();

      var cropped = img.copyCrop(
        oriented,
        x: cropX,
        y: cropY,
        width: cropWidth,
        height: cropHeight,
      );

      if (cropped.width > 1400) {
        cropped = img.copyResize(cropped, width: 1400);
      }

      final tempDir = await getTemporaryDirectory();
      final croppedPath =
          '${tempDir.path}/scan_crop_${DateTime.now().microsecondsSinceEpoch}.jpg';
      final croppedBytes = img.encodeJpg(cropped, quality: 92);
      final croppedFile = File(croppedPath);
      await croppedFile.writeAsBytes(croppedBytes, flush: true);
      return croppedFile.path;
    } catch (_) {
      return null;
    }
  }


  static Future<String?> _createBottomLeftScannerCrop(String imagePath) async {
    try {
      final sourceBytes = await File(imagePath).readAsBytes();
      final decodedImage = img.decodeImage(sourceBytes);
      if (decodedImage == null) return null;

      final oriented = img.bakeOrientation(decodedImage);
      final imageWidth = oriented.width;
      final imageHeight = oriented.height;
      if (imageWidth < 160 || imageHeight < 220) {
        return null;
      }

      final cropWidth = (imageWidth * 0.58).round().clamp(120, imageWidth).toInt();
      final cropHeight = (imageHeight * 0.24).round().clamp(90, imageHeight).toInt();
      final cropX = (imageWidth * 0.02).round().clamp(0, imageWidth - cropWidth).toInt();
      final bottomPadding = (imageHeight * 0.03).round();
      final cropY = (imageHeight - cropHeight - bottomPadding)
          .clamp(0, imageHeight - cropHeight)
          .toInt();

      var cropped = img.copyCrop(
        oriented,
        x: cropX,
        y: cropY,
        width: cropWidth,
        height: cropHeight,
      );

      if (cropped.width < 1000) {
        cropped = img.copyResize(cropped, width: 1000);
      }

      cropped = img.adjustColor(
        cropped,
        contrast: 1.15,
        saturation: 0.92,
        brightness: 1.03,
      );

      final tempDir = await getTemporaryDirectory();
      final croppedPath =
          '${tempDir.path}/scan_bottom_left_${DateTime.now().microsecondsSinceEpoch}.jpg';
      final croppedBytes = img.encodeJpg(cropped, quality: 96);
      final croppedFile = File(croppedPath);
      await croppedFile.writeAsBytes(croppedBytes, flush: true);
      return croppedFile.path;
    } catch (_) {
      return null;
    }
  }

  static Future<CardScanAnalysis> _refineAnalysisWithBottomLeftText({
    required CardScanAnalysis analysis,
    required String bottomLeftText,
  }) async {
    final cleanedBottomLeftText = bottomLeftText.trim();
    if (cleanedBottomLeftText.isEmpty) {
      return analysis;
    }

    final bottomLeftNumbers = _mergeUniqueStrings(
      _extractScanNumberCandidates(cleanedBottomLeftText),
    );
    final mergedCandidateNumbers = _mergeUniqueStrings(<String>[
      ...bottomLeftNumbers,
      ...analysis.candidateNumbers,
    ]);

    final combinedExtractedText =
        '${analysis.extractedText}\n\nBottom-left focus:\n$cleanedBottomLeftText';

    if (bottomLeftNumbers.isEmpty) {
      return CardScanAnalysis(
        extractedText: combinedExtractedText,
        candidateNames: analysis.candidateNames,
        candidateNumbers: mergedCandidateNumbers,
        matches: analysis.matches,
        exactConfirmed: analysis.exactConfirmed,
      );
    }

    final combinedNormalizedText = _normalizeScanText(
      '${analysis.extractedText} $cleanedBottomLeftText',
    );
    final combinedNormalizedOcrText = _normalizeOcrTextForMatching(
      '${analysis.extractedText} $cleanedBottomLeftText',
    );

    final bottomLeftSetCandidates = _mergeUniqueStrings(<String>[
      ..._extractScanSetCandidates(cleanedBottomLeftText),
      ..._extractScanSetCandidates(analysis.extractedText),
    ]);

    final likelySets = await _findLikelySets(
      setCandidates: bottomLeftSetCandidates,
      candidateNames: analysis.candidateNames,
      phraseCandidates: _extractScanPhraseCandidates(cleanedBottomLeftText),
      normalizedText: combinedNormalizedText,
      normalizedOcrText: combinedNormalizedOcrText,
    );
    final likelySetIds = likelySets.map((set) => set.id).toSet();

    final exactMatchesById = <String, TcgCard>{};

    for (final card in analysis.matches) {
      final normalizedCardNumber = _normalizeCardNumberHint(card.number);
      if (bottomLeftNumbers.any(
        (number) => _normalizeCardNumberHint(number) == normalizedCardNumber,
      )) {
        exactMatchesById.putIfAbsent(card.id, () => card);
      }
    }

    for (final set in likelySets.take(4)) {
      for (final bottomLeftNumber in bottomLeftNumbers.take(5)) {
        try {
          final exactCards = await _fetchCardsBySetAndNumber(
            set.id,
            bottomLeftNumber,
          );
          for (final card in exactCards) {
            exactMatchesById.putIfAbsent(card.id, () => card);
          }
        } catch (_) {}
      }
    }

    final prioritizedMatches = exactMatchesById.values.toList()
      ..sort((a, b) {
        final scoreA = _scoreScannedCard(
              card: a,
              normalizedText: combinedNormalizedText,
              normalizedOcrText: combinedNormalizedOcrText,
              candidateNames: analysis.candidateNames,
              candidateNumbers: mergedCandidateNumbers,
              phraseCandidates: _extractScanPhraseCandidates(cleanedBottomLeftText),
              setCandidates: bottomLeftSetCandidates,
              likelySetIds: likelySetIds,
            ) +
            _scoreBottomLeftExactMatch(
              card: a,
              bottomLeftNumbers: bottomLeftNumbers,
              likelySetIds: likelySetIds,
            );
        final scoreB = _scoreScannedCard(
              card: b,
              normalizedText: combinedNormalizedText,
              normalizedOcrText: combinedNormalizedOcrText,
              candidateNames: analysis.candidateNames,
              candidateNumbers: mergedCandidateNumbers,
              phraseCandidates: _extractScanPhraseCandidates(cleanedBottomLeftText),
              setCandidates: bottomLeftSetCandidates,
              likelySetIds: likelySetIds,
            ) +
            _scoreBottomLeftExactMatch(
              card: b,
              bottomLeftNumbers: bottomLeftNumbers,
              likelySetIds: likelySetIds,
            );
        return scoreB.compareTo(scoreA);
      });

    final mergedMatches = <TcgCard>[
      ...prioritizedMatches,
      ...analysis.matches.where((card) => !exactMatchesById.containsKey(card.id)),
    ];

    return CardScanAnalysis(
      extractedText: combinedExtractedText,
      candidateNames: analysis.candidateNames,
      candidateNumbers: mergedCandidateNumbers,
      matches: mergedMatches.take(8).toList(),
      exactConfirmed: exactMatchesById.isNotEmpty || analysis.exactConfirmed,
    );
  }

  static int _scoreBottomLeftExactMatch({
    required TcgCard card,
    required List<String> bottomLeftNumbers,
    required Set<String> likelySetIds,
  }) {
    final normalizedCardNumber = _normalizeCardNumberHint(card.number);
    final hasNumberMatch = bottomLeftNumbers.any(
      (number) => _normalizeCardNumberHint(number) == normalizedCardNumber,
    );
    if (!hasNumberMatch) return 0;
    if (likelySetIds.contains(card.setId)) return 520;
    return 320;
  }

  static int _scanAnalysisConfidence(CardScanAnalysis analysis) {
    var score = 0;
    if (analysis.bestMatch != null) score += 60;
    score += math.min(analysis.matches.length, 4) * 10;
    score += math.min(analysis.candidateNumbers.length, 3) * 15;
    score += math.min(analysis.candidateNames.length, 3) * 8;
    score += math.min((analysis.extractedText.length / 60).floor(), 10);
    return score;
  }

  static CardScanAnalysis _preferScanAnalysis(
    CardScanAnalysis primary,
    CardScanAnalysis fallback,
  ) {
    final primaryScore = _scanAnalysisConfidence(primary);
    final fallbackScore = _scanAnalysisConfidence(fallback);
    if (primaryScore == fallbackScore) {
      return primary.matches.length >= fallback.matches.length ? primary : fallback;
    }
    return primaryScore >= fallbackScore ? primary : fallback;
  }

  static Future<CardScanAnalysis> analyzeRecognizedScan(RecognizedText recognizedText) async {
    final rawText = recognizedText.text.trim();
    final normalizedText = _normalizeScanText(rawText);
    final normalizedOcrText = _normalizeOcrTextForMatching(rawText);
    final lineHints = _extractScanLineHints(recognizedText);

    final spatialNameCandidates = _extractSpatialNameCandidates(lineHints);
    final spatialNumberCandidates = _extractSpatialNumberCandidates(lineHints);
    final spatialSetCandidates = _extractSpatialSetCandidates(lineHints);

    final candidateNames = _mergeUniqueStrings(<String>[
      ...spatialNameCandidates,
      ..._extractScanNameCandidates(rawText),
    ]);
    final candidateNumbers = _mergeUniqueStrings(<String>[
      ...spatialNumberCandidates,
      ..._extractScanNumberCandidates(rawText),
    ]);
    final setCandidates = _mergeUniqueStrings(<String>[
      ...spatialSetCandidates,
      ..._extractScanSetCandidates(rawText),
    ]);
    final phraseCandidates = _extractScanPhraseCandidates(rawText);

    final queryCandidates = <String>{};

    void addQueryCandidate(String candidate) {
      final query = _buildScanQuery(candidate);
      if (query.isNotEmpty) {
        queryCandidates.add(query);
      }
    }

    for (final candidate in <String>[
      ...spatialNameCandidates,
      ...candidateNames,
      ...phraseCandidates,
    ].take(16)) {
      addQueryCandidate(candidate);
    }

    if (queryCandidates.isEmpty && normalizedText.isNotEmpty) {
      final fallbackWords = normalizedText
          .split(' ')
          .where((word) => word.length > 2 && !_scanStopWords.contains(word))
          .take(5)
          .join(' ');
      if (fallbackWords.isNotEmpty) {
        queryCandidates.add(fallbackWords);
      }
    }

    final likelySets = await _findLikelySets(
      setCandidates: setCandidates,
      candidateNames: candidateNames,
      phraseCandidates: phraseCandidates,
      normalizedText: normalizedText,
      normalizedOcrText: normalizedOcrText,
    );
    final likelySetIds = likelySets.map((set) => set.id).toSet();

    final matchesById = <String, TcgCard>{};

    for (final set in likelySets.take(3)) {
      for (final numberHint in candidateNumbers.take(3)) {
        try {
          final exactSetNumberCards = await _fetchCardsBySetAndNumber(set.id, numberHint);
          for (final card in exactSetNumberCards) {
            matchesById.putIfAbsent(card.id, () => card);
          }
        } catch (_) {}
      }

      for (final nameHint in candidateNames.take(4)) {
        try {
          final exactNameCards = await _searchCardsForExactNameCandidate(
            nameHint,
            setId: set.id,
            numberHint: candidateNumbers.isEmpty ? null : candidateNumbers.first,
          );
          for (final card in exactNameCards) {
            matchesById.putIfAbsent(card.id, () => card);
          }
        } catch (_) {}
      }

      try {
        final setCards = await _topCardsFromLikelySet(
          setId: set.id,
          normalizedText: normalizedText,
          normalizedOcrText: normalizedOcrText,
          candidateNames: candidateNames,
          candidateNumbers: candidateNumbers,
          phraseCandidates: phraseCandidates,
          setCandidates: setCandidates,
          likelySetIds: likelySetIds,
        );
        for (final card in setCards) {
          matchesById.putIfAbsent(card.id, () => card);
        }
      } catch (_) {}

      if (matchesById.length >= 16) {
        break;
      }
    }

    for (final nameHint in candidateNames.take(5)) {
      try {
        final exactNameCards = await _searchCardsForExactNameCandidate(
          nameHint,
          numberHint: candidateNumbers.isEmpty ? null : candidateNumbers.first,
        );
        for (final card in exactNameCards) {
          matchesById.putIfAbsent(card.id, () => card);
        }
      } catch (_) {}

      if (matchesById.length >= 22) {
        break;
      }
    }

    for (final numberHint in candidateNumbers.take(5)) {
      try {
        final cards = await _searchCardsByNumberHint(numberHint);
        for (final card in cards) {
          matchesById.putIfAbsent(card.id, () => card);
        }
      } catch (_) {}

      if (matchesById.length >= 24) {
        break;
      }
    }

    final numberSearchHints = candidateNumbers.isEmpty
        ? <String?>[null]
        : <String?>[...candidateNumbers.take(3), null];

    for (final numberHint in numberSearchHints) {
      for (final query in queryCandidates.take(10)) {
        try {
          final cards = await _searchCardsForScanCandidate(
            query,
            numberHint: numberHint,
          );
          for (final card in cards) {
            matchesById.putIfAbsent(card.id, () => card);
          }
        } catch (_) {}

        if (matchesById.length >= 32) {
          break;
        }
      }
      if (matchesById.length >= 32) {
        break;
      }
    }

    final matches = matchesById.values.toList()
      ..sort((a, b) {
        final scoreA = _scoreScannedCard(
          card: a,
          normalizedText: normalizedText,
          normalizedOcrText: normalizedOcrText,
          candidateNames: candidateNames,
          candidateNumbers: candidateNumbers,
          phraseCandidates: phraseCandidates,
          setCandidates: setCandidates,
          likelySetIds: likelySetIds,
        );
        final scoreB = _scoreScannedCard(
          card: b,
          normalizedText: normalizedText,
          normalizedOcrText: normalizedOcrText,
          candidateNames: candidateNames,
          candidateNumbers: candidateNumbers,
          phraseCandidates: phraseCandidates,
          setCandidates: setCandidates,
          likelySetIds: likelySetIds,
        );
        if (scoreA != scoreB) {
          return scoreB.compareTo(scoreA);
        }
        return a.name.compareTo(b.name);
      });

    return CardScanAnalysis(
      extractedText: rawText,
      candidateNames: candidateNames,
      candidateNumbers: candidateNumbers,
      matches: matches.take(8).toList(),
      exactConfirmed: false,
    );
  }

  static List<String> _mergeUniqueStrings(List<String> values) {
    final results = <String>[];
    final seen = <String>{};
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) continue;
      final key = trimmed.toLowerCase();
      if (seen.add(key)) {
        results.add(trimmed);
      }
    }
    return results;
  }

  static List<_ScanLineHint> _extractScanLineHints(RecognizedText recognizedText) {
    final rawLines = <_ScanLineHint>[];
    final bounds = <Rect>[];

    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        final box = line.boundingBox;
        if (text.isEmpty || box.width <= 0 || box.height <= 0) continue;
        bounds.add(box);
      }
    }

    if (bounds.isEmpty) {
      return _buildFallbackLineHints(recognizedText.text);
    }

    final minLeft = bounds.map((box) => box.left).reduce(math.min);
    final minTop = bounds.map((box) => box.top).reduce(math.min);
    final maxRight = bounds.map((box) => box.right).reduce(math.max);
    final maxBottom = bounds.map((box) => box.bottom).reduce(math.max);
    final totalWidth = math.max(1.0, maxRight - minLeft);
    final totalHeight = math.max(1.0, maxBottom - minTop);

    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        final box = line.boundingBox;
        if (text.isEmpty || box.width <= 0 || box.height <= 0) continue;
        rawLines.add(
          _ScanLineHint(
            text: text,
            topFraction: ((box.top - minTop) / totalHeight).clamp(0.0, 1.0),
            leftFraction: ((box.left - minLeft) / totalWidth).clamp(0.0, 1.0),
            widthFraction: (box.width / totalWidth).clamp(0.0, 1.0),
            heightFraction: (box.height / totalHeight).clamp(0.0, 1.0),
          ),
        );
      }
    }

    rawLines.sort((a, b) {
      final topCompare = a.topFraction.compareTo(b.topFraction);
      if (topCompare != 0) return topCompare;
      return a.leftFraction.compareTo(b.leftFraction);
    });

    return rawLines;
  }

  static List<_ScanLineHint> _buildFallbackLineHints(String text) {
    final lines = text
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) return const <_ScanLineHint>[];

    return List<_ScanLineHint>.generate(lines.length, (index) {
      final fraction = index / math.max(1, lines.length);
      return _ScanLineHint(
        text: lines[index],
        topFraction: fraction,
        leftFraction: 0.1,
        widthFraction: 0.8,
        heightFraction: 1 / math.max(1, lines.length),
      );
    });
  }

  static bool _looksLikeCardNameLine(String line) {
    final cleaned = line
        .replaceAll(RegExp(r'\b\d{2,4}\s*HP\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.length < 2 || cleaned.length > 32) return false;
    if (RegExp(r'^\d+[\d/ ]*$').hasMatch(cleaned)) return false;

    final normalized = _normalizeScanText(cleaned);
    if (normalized.isEmpty) return false;

    const blocked = <String>[
      'ability',
      'basic pokemon',
      'flip a coin',
      'pokemon power',
      'search your deck',
      'this attack',
      'weakness',
      'resistance',
      'retreat cost',
      'trainer',
      'supporter',
      'stadium',
    ];
    if (blocked.any(normalized.contains)) return false;

    final meaningfulWords = normalized
        .split(' ')
        .where((word) => word.length > 1 && !_scanStopWords.contains(word))
        .toList();
    return meaningfulWords.isNotEmpty;
  }

  static List<String> _extractSpatialNameCandidates(List<_ScanLineHint> lineHints) {
    final results = <String>[];
    final seen = <String>{};

    final topLines = lineHints
        .where((line) => line.topFraction <= 0.40 && _looksLikeCardNameLine(line.text))
        .toList()
      ..sort((a, b) {
        final topCompare = a.topFraction.compareTo(b.topFraction);
        if (topCompare != 0) return topCompare;
        return b.widthFraction.compareTo(a.widthFraction);
      });

    for (final line in topLines.take(6)) {
      final cleaned = line.text
          .replaceAll(RegExp(r'\b\d{2,4}\s*HP\b', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final key = _normalizeScanText(cleaned);
      if (cleaned.isEmpty || !seen.add(key)) continue;
      results.add(cleaned);
    }

    return results;
  }

  static List<String> _extractSpatialNumberCandidates(List<_ScanLineHint> lineHints) {
    final results = <String>[];
    final seen = <String>{};

    final bottomLines = lineHints
        .where((line) => line.topFraction >= 0.58)
        .toList()
      ..sort((a, b) {
        final topCompare = b.topFraction.compareTo(a.topFraction);
        if (topCompare != 0) return topCompare;
        return a.leftFraction.compareTo(b.leftFraction);
      });

    for (final line in bottomLines.take(8)) {
      final text = line.text;

      final slashMatches = RegExp(
        r'\b([A-Za-z]{0,5}[\s-]*[0-9OQDSIBLZG]{1,4}[A-Za-z]?)\s*/\s*[0-9OQDSIBLZG]{1,4}\b',
        caseSensitive: false,
      ).allMatches(text);
      for (final match in slashMatches) {
        _appendCardNumberHint(results, seen, match.group(1) ?? '');
      }

      final prefixedMatches = RegExp(
        r'\b(?:TG|GG|SWSH|SVP|SM|XY|BW|SV|PROMO)[\s-]*[0-9OQDSIBLZG]{1,4}[A-Za-z]?\b',
        caseSensitive: false,
      ).allMatches(text);
      for (final match in prefixedMatches) {
        _appendCardNumberHint(results, seen, match.group(0) ?? '');
      }
    }

    return results;
  }

  static List<String> _extractSpatialSetCandidates(List<_ScanLineHint> lineHints) {
    final results = <String>[];
    final seen = <String>{};

    final candidateLines = lineHints
        .where((line) => line.topFraction >= 0.42 && line.topFraction <= 0.95)
        .toList()
      ..sort((a, b) {
        final widthCompare = b.widthFraction.compareTo(a.widthFraction);
        if (widthCompare != 0) return widthCompare;
        return b.topFraction.compareTo(a.topFraction);
      });

    for (final line in candidateLines.take(10)) {
      final cleaned = line.text
          .replaceAll(RegExp(r'[^A-Za-z0-9\s-]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final normalized = _normalizeScanText(cleaned);
      if (cleaned.length < 4 || cleaned.length > 28) continue;
      if (normalized.contains('pokemon') || normalized.contains('trainer')) continue;
      if (normalized.contains('weakness') || normalized.contains('resistance')) continue;
      if (normalized.split(' ').where((word) => word.length > 2 && !_scanStopWords.contains(word)).isEmpty) {
        continue;
      }
      if (seen.add(normalized)) {
        results.add(cleaned);
      }
      if (results.length >= 6) break;
    }

    return results;
  }

  static Future<List<TcgSet>> _findLikelySets({
    required List<String> setCandidates,
    required List<String> candidateNames,
    required List<String> phraseCandidates,
    required String normalizedText,
    required String normalizedOcrText,
  }) async {
    final setById = <String, TcgSet>{};

    for (final candidate in <String>[
      ...setCandidates,
      ...phraseCandidates,
      ...candidateNames,
    ].take(10)) {
      try {
        final sets = await _searchSetsForScanCandidate(candidate);
        for (final set in sets) {
          setById.putIfAbsent(set.id, () => set);
        }
      } catch (_) {}
      if (setById.length >= 12) {
        break;
      }
    }

    final sets = setById.values.toList()
      ..sort((a, b) {
        final scoreA = _scoreScannedSet(
          set: a,
          normalizedText: normalizedText,
          normalizedOcrText: normalizedOcrText,
          setCandidates: setCandidates,
        );
        final scoreB = _scoreScannedSet(
          set: b,
          normalizedText: normalizedText,
          normalizedOcrText: normalizedOcrText,
          setCandidates: setCandidates,
        );
        return scoreB.compareTo(scoreA);
      });

    return sets.take(3).toList();
  }

  static Future<List<TcgSet>> _searchSetsForScanCandidate(String candidate) async {
    final normalizedCandidate = _buildScanQuery(candidate);
    if (normalizedCandidate.isEmpty) return const <TcgSet>[];

    final terms = normalizedCandidate.split(' ').where((term) => term.isNotEmpty).toList();
    if (terms.isEmpty) return const <TcgSet>[];

    final query = terms.map((term) => 'name:*$term*').join(' AND ');
    final uri = Uri.https('api.pokemontcg.io', '/v2/sets', {
      'q': query,
      'pageSize': '8',
      'orderBy': '-releaseDate',
    });

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (data['data'] as List<dynamic>? ?? const []);
    return items.map((item) => TcgSet.fromJson(item as Map<String, dynamic>)).toList();
  }

  static Future<List<TcgCard>> _topCardsFromLikelySet({
    required String setId,
    required String normalizedText,
    required String normalizedOcrText,
    required List<String> candidateNames,
    required List<String> candidateNumbers,
    required List<String> phraseCandidates,
    required List<String> setCandidates,
    required Set<String> likelySetIds,
  }) async {
    final cards = await fetchCardsBySet(setId);
    final scored = cards
        .map((card) => MapEntry(
              card,
              _scoreScannedCard(
                card: card,
                normalizedText: normalizedText,
                normalizedOcrText: normalizedOcrText,
                candidateNames: candidateNames,
                candidateNumbers: candidateNumbers,
                phraseCandidates: phraseCandidates,
                setCandidates: setCandidates,
                likelySetIds: likelySetIds,
              ),
            ))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final threshold = candidateNumbers.isNotEmpty ? 120 : 150;
    final filtered = scored.where((entry) => entry.value >= threshold).take(8).map((entry) => entry.key).toList();

    if (filtered.isNotEmpty) {
      return filtered;
    }

    return scored.take(4).map((entry) => entry.key).toList();
  }

  static Future<List<TcgCard>> _fetchCardsBySetAndNumber(String setId, String numberHint) async {
    final cleaned = _normalizeCardNumberHint(numberHint);
    if (cleaned.isEmpty) return const <TcgCard>[];

    final variants = <String>{cleaned};
    final plainDigitsMatch = RegExp(r'^0*(\d+[A-Z]?)$').firstMatch(cleaned);
    if (plainDigitsMatch != null) {
      variants.add(plainDigitsMatch.group(1)!);
    }

    final cardsById = <String, TcgCard>{};
    for (final variant in variants.take(4)) {
      final uri = Uri.https('api.pokemontcg.io', '/v2/cards', {
        'q': 'set.id:$setId AND number:$variant',
        'pageSize': '40',
      });

      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final items = (data['data'] as List<dynamic>? ?? const []);
      for (final item in items) {
        final card = TcgCard.fromJson(item as Map<String, dynamic>);
        cardsById.putIfAbsent(card.id, () => card);
      }
    }

    return cardsById.values.toList();
  }

  static Future<List<TcgCard>> _searchCardsForExactNameCandidate(
    String candidate, {
    String? setId,
    String? numberHint,
  }) async {
    final normalizedCandidate = _buildScanQuery(candidate);
    if (normalizedCandidate.isEmpty) return const <TcgCard>[];

    final escaped = normalizedCandidate.replaceAll('"', '');
    final queryParts = <String>['name:"$escaped"'];
    if (setId != null && setId.trim().isNotEmpty) {
      queryParts.add('set.id:$setId');
    }
    if (numberHint != null && numberHint.trim().isNotEmpty) {
      queryParts.add('number:${_normalizeCardNumberHint(numberHint)}');
    }

    final uri = Uri.https('api.pokemontcg.io', '/v2/cards', {
      'q': queryParts.join(' AND '),
      'pageSize': '30',
      'orderBy': 'set.releaseDate,name',
    });

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (data['data'] as List<dynamic>? ?? const []);
    return items.map((item) => TcgCard.fromJson(item as Map<String, dynamic>)).toList();
  }

  static Future<List<TcgCard>> _searchCardsByNumberHint(String numberHint) async {
    final cleaned = _normalizeCardNumberHint(numberHint);
    if (cleaned.isEmpty) return const <TcgCard>[];

    final variants = <String>{cleaned};
    final plainDigitsMatch = RegExp(r'^0*(\d+[A-Z]?)$').firstMatch(cleaned);
    if (plainDigitsMatch != null) {
      variants.add(plainDigitsMatch.group(1)!);
    }

    final prefixedMatch = RegExp(r'^([A-Z]+)0*(\d+[A-Z]?)$').firstMatch(cleaned);
    if (prefixedMatch != null) {
      variants.add('${prefixedMatch.group(1)}${prefixedMatch.group(2)}');
    }

    final cardsById = <String, TcgCard>{};

    for (final variant in variants.take(4)) {
      final uri = Uri.https('api.pokemontcg.io', '/v2/cards', {
        'q': 'number:$variant',
        'pageSize': '120',
      });

      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final items = (data['data'] as List<dynamic>? ?? const []);
      for (final item in items) {
        final card = TcgCard.fromJson(item as Map<String, dynamic>);
        cardsById.putIfAbsent(card.id, () => card);
      }
    }

    return cardsById.values.toList();
  }

  static Future<List<TcgCard>> _searchCardsForScanCandidate(
    String candidate, {
    String? numberHint,
  }) async {
    final normalizedCandidate = _buildScanQuery(candidate);
    if (normalizedCandidate.isEmpty) return const <TcgCard>[];

    final terms = normalizedCandidate
        .split(' ')
        .where((term) => term.isNotEmpty)
        .toList();
    if (terms.isEmpty) return const <TcgCard>[];

    final nameClause = terms
        .map((term) => '(name:*$term* OR set.name:*$term*)')
        .join(' AND ');

    final queryParts = <String>[nameClause];
    if (numberHint != null && numberHint.trim().isNotEmpty) {
      queryParts.add('number:${_normalizeCardNumberHint(numberHint.trim())}');
    }

    final uri = Uri.https('api.pokemontcg.io', '/v2/cards', {
      'q': queryParts.join(' AND '),
      'pageSize': '50',
      'orderBy': 'set.releaseDate,name',
    });

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (data['data'] as List<dynamic>? ?? const []);
    return items.map((item) => TcgCard.fromJson(item as Map<String, dynamic>)).toList();
  }

  static void _appendCardNumberHint(
    List<String> results,
    Set<String> seen,
    String rawValue,
  ) {
    final cleaned = _normalizeCardNumberHint(rawValue);
    if (cleaned.isEmpty) return;

    final variants = <String>{cleaned};
    final plainDigits = RegExp(r'^0*(\d+[A-Z]?)$').firstMatch(cleaned)?.group(1);
    if (plainDigits != null && plainDigits.isNotEmpty) {
      variants.add(plainDigits);
    }

    final prefixed = RegExp(r'^([A-Z]+)0*(\d+[A-Z]?)$').firstMatch(cleaned);
    if (prefixed != null) {
      variants.add('${prefixed.group(1)}${prefixed.group(2)}');
    }

    for (final variant in variants) {
      if (seen.add(variant)) {
        results.add(variant);
      }
    }
  }

  static const Set<String> _scanStopWords = <String>{
    'a',
    'an',
    'and',
    'attack',
    'basic',
    'bench',
    'card',
    'choose',
    'coin',
    'damage',
    'discard',
    'during',
    'energy',
    'evolves',
    'flip',
    'from',
    'hand',
    'has',
    'hp',
    'if',
    'in',
    'of',
    'on',
    'opponent',
    'pokemon',
    'power',
    'put',
    'retreat',
    'rule',
    'search',
    'stage',
    'switch',
    'take',
    'the',
    'this',
    'to',
    'trainer',
    'turn',
    'weakness',
    'your',
  };

  static String _normalizeScanText(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _normalizeOcrTextForMatching(String value) {
    return _normalizeScanText(value)
        .replaceAll('0', 'o')
        .replaceAll('1', 'l')
        .replaceAll('5', 's')
        .replaceAll('8', 'b');
  }

  static String _normalizeOcrWord(String value) {
    return _normalizeOcrTextForMatching(value).replaceAll(' ', '');
  }

  static String _normalizeCardNumberHint(String value) {
    final upper = value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (upper.isEmpty) return '';

    final chars = upper.split('');
    for (var i = 0; i < chars.length; i++) {
      final previous = i > 0 ? chars[i - 1] : '';
      final next = i + 1 < chars.length ? chars[i + 1] : '';
      final nearDigit = RegExp(r'\d').hasMatch(previous) || RegExp(r'\d').hasMatch(next);
      switch (chars[i]) {
        case 'O':
        case 'Q':
        case 'D':
          if (nearDigit) chars[i] = '0';
          break;
        case 'I':
        case 'L':
          if (nearDigit) chars[i] = '1';
          break;
        case 'Z':
          if (nearDigit) chars[i] = '2';
          break;
        case 'S':
          if (nearDigit) chars[i] = '5';
          break;
        case 'B':
          if (nearDigit) chars[i] = '8';
          break;
        case 'G':
          if (nearDigit) chars[i] = '6';
          break;
      }
    }
    return chars.join();
  }

  static List<String> _extractScanNameCandidates(String text) {
    final lines = text
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final results = <String>[];
    final seen = <String>{};

    for (var line in lines) {
      line = line.replaceAll(RegExp(r'\s+'), ' ').trim();
      line = line.replaceAll(RegExp(r'\b\d{2,4}\s*HP\b', caseSensitive: false), '').trim();

      if (!_looksLikeCardNameLine(line)) continue;

      final normalized = _normalizeScanText(line);
      if (seen.add(normalized)) {
        results.add(line);
      }

      if (results.length >= 8) break;
    }

    return results;
  }

  static List<String> _extractScanSetCandidates(String text) {
    final lines = text
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final results = <String>[];
    final seen = <String>{};

    for (var line in lines) {
      line = line
          .replaceAll(RegExp(r'[^A-Za-z0-9\s-]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (line.length < 4 || line.length > 28) continue;
      final normalized = _normalizeScanText(line);
      if (normalized.contains('pokemon') || normalized.contains('weakness')) continue;
      if (normalized.split(' ').where((word) => word.length > 2 && !_scanStopWords.contains(word)).isEmpty) continue;
      if (seen.add(normalized)) {
        results.add(line);
      }
      if (results.length >= 6) break;
    }

    return results;
  }

  static List<String> _extractScanNumberCandidates(String text) {
    final results = <String>[];
    final seen = <String>{};

    final slashMatches = RegExp(
      r'\b([A-Za-z]{0,5}[\s-]*[0-9OQDSIBLZG]{1,4}[A-Za-z]?)\s*/\s*[0-9OQDSIBLZG]{1,4}\b',
      caseSensitive: false,
    ).allMatches(text);

    for (final match in slashMatches) {
      _appendCardNumberHint(results, seen, match.group(1) ?? '');
    }

    final prefixedMatches = RegExp(
      r'\b(?:TG|GG|SWSH|SVP|SM|XY|BW|SV|PROMO)[\s-]*[0-9OQDSIBLZG]{1,4}[A-Za-z]?\b',
      caseSensitive: false,
    ).allMatches(text);

    for (final match in prefixedMatches) {
      _appendCardNumberHint(results, seen, match.group(0) ?? '');
    }

    return results;
  }

  static List<String> _extractScanPhraseCandidates(String text) {
    final results = <String>[];
    final seen = <String>{};

    final lines = text
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .take(10)
        .toList();

    for (var line in lines) {
      line = line
          .replaceAll(RegExp(r'\b\d{2,4}\s*HP\b', caseSensitive: false), '')
          .replaceAll(RegExp(r'[^A-Za-z0-9\s-]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (line.isEmpty) continue;

      final words = _normalizeScanText(line)
          .split(' ')
          .where((word) => word.length > 2 && !_scanStopWords.contains(word))
          .toList();

      if (words.isEmpty) continue;

      for (final length in const [3, 2, 1]) {
        if (words.length < length) continue;
        for (var index = 0; index <= words.length - length; index++) {
          final phrase = words.sublist(index, index + length).join(' ');
          if (phrase.length < 3) continue;
          if (seen.add(phrase)) {
            results.add(phrase);
          }
          if (results.length >= 16) {
            return results;
          }
        }
      }
    }

    return results;
  }

  static String _buildScanQuery(String candidate) {
    final normalized = _normalizeScanText(candidate);
    if (normalized.isEmpty) return '';

    final filtered = normalized
        .split(' ')
        .where((word) => word.length > 1 && !_scanStopWords.contains(word))
        .take(5)
        .join(' ');

    return filtered;
  }

  static int _scoreScannedSet({
    required TcgSet set,
    required String normalizedText,
    required String normalizedOcrText,
    required List<String> setCandidates,
  }) {
    var score = 0;
    final normalizedSetName = _normalizeScanText(set.name);
    final fuzzySetName = _normalizeOcrTextForMatching(set.name);

    if (normalizedText.contains(normalizedSetName)) {
      score += 180;
    }
    if (normalizedOcrText.contains(fuzzySetName)) {
      score += 180;
    }

    for (final candidate in setCandidates.take(8)) {
      final normalizedCandidate = _normalizeScanText(candidate);
      final fuzzyCandidate = _normalizeOcrTextForMatching(candidate);
      if (normalizedCandidate.isEmpty) continue;
      if (normalizedCandidate == normalizedSetName || fuzzyCandidate == fuzzySetName) {
        score += 160;
        continue;
      }
      final similarity = _stringSimilarity(fuzzyCandidate, fuzzySetName);
      if (similarity >= 0.90) {
        score += 120;
      } else if (similarity >= 0.82) {
        score += 72;
      } else if (similarity >= 0.72) {
        score += 32;
      }
    }

    return score;
  }

  static int _scoreScannedCard({
    required TcgCard card,
    required String normalizedText,
    required String normalizedOcrText,
    required List<String> candidateNames,
    required List<String> candidateNumbers,
    required List<String> phraseCandidates,
    required List<String> setCandidates,
    required Set<String> likelySetIds,
  }) {
    var score = 0;
    final cardName = _normalizeScanText(card.name);
    final fuzzyCardName = _normalizeOcrTextForMatching(card.name);
    final setName = _normalizeScanText(card.setName);
    final fuzzySetName = _normalizeOcrTextForMatching(card.setName);
    final cardNumber = _normalizeCardNumberHint(card.number);

    if (normalizedText.contains(cardName)) {
      score += 210;
    }
    if (normalizedOcrText.contains(fuzzyCardName)) {
      score += 210;
    }
    if (normalizedText.contains(setName) || normalizedOcrText.contains(fuzzySetName)) {
      score += 44;
    }
    if (likelySetIds.contains(card.setId)) {
      score += 90;
    }
    if (candidateNumbers.any((candidate) => candidate == cardNumber)) {
      score += 260;
    } else if (candidateNumbers.isNotEmpty) {
      score -= 28;
    }

    final cardNameWords = cardName.split(' ').where((word) => word.length > 2).toList();
    score += _tokenCoverageScore(cardNameWords, normalizedText, normalizedOcrText);

    final setNameWords = setName
        .split(' ')
        .where((word) => word.length > 2 && !_scanStopWords.contains(word))
        .toList();
    score += (_tokenCoverageScore(setNameWords, normalizedText, normalizedOcrText) * 0.30).round();

    for (final candidate in setCandidates.take(6)) {
      final similarity = _stringSimilarity(
        _normalizeOcrTextForMatching(candidate),
        fuzzySetName,
      );
      if (similarity >= 0.90) {
        score += 85;
      } else if (similarity >= 0.80) {
        score += 42;
      }
    }

    for (final candidate in <String>[
      ...candidateNames,
      ...phraseCandidates,
    ].take(16)) {
      final normalizedCandidate = _normalizeScanText(candidate);
      final fuzzyCandidate = _normalizeOcrTextForMatching(candidate);
      if (normalizedCandidate.isEmpty || fuzzyCandidate.isEmpty) continue;

      if (normalizedCandidate == cardName || fuzzyCandidate == fuzzyCardName) {
        score += 200;
        continue;
      }

      if (cardName.startsWith(normalizedCandidate) || fuzzyCardName.startsWith(fuzzyCandidate)) {
        score += 130;
        continue;
      }

      if (cardName.contains(normalizedCandidate) || normalizedCandidate.contains(cardName)) {
        score += 100;
      }

      final similarity = _stringSimilarity(fuzzyCandidate, fuzzyCardName);
      if (similarity >= 0.93) {
        score += 170;
      } else if (similarity >= 0.86) {
        score += 120;
      } else if (similarity >= 0.78) {
        score += 72;
      } else if (similarity >= 0.68) {
        score += 28;
      }
    }

    if (card.hp != null && normalizedText.contains(card.hp!.toLowerCase())) {
      score += 16;
    }
    if (card.rarity != null && normalizedText.contains(_normalizeScanText(card.rarity!))) {
      score += 8;
    }

    return score;
  }

  static int _tokenCoverageScore(
    List<String> words,
    String normalizedText,
    String normalizedOcrText,
  ) {
    if (words.isEmpty) return 0;

    var hits = 0;
    for (final word in words) {
      final cleanWord = _normalizeScanText(word);
      final ocrWord = _normalizeOcrWord(word);
      if (cleanWord.isEmpty) continue;
      if (normalizedText.contains(cleanWord) || normalizedOcrText.contains(ocrWord)) {
        hits++;
      }
    }

    return ((hits / words.length) * 100).round();
  }

  static int _levenshteinDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final previous = List<int>.generate(b.length + 1, (index) => index);
    final current = List<int>.filled(b.length + 1, 0);

    for (var i = 1; i <= a.length; i++) {
      current[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final substitutionCost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        current[j] = math.min(
          math.min(
            current[j - 1] + 1,
            previous[j] + 1,
          ),
          previous[j - 1] + substitutionCost,
        );
      }
      for (var j = 0; j <= b.length; j++) {
        previous[j] = current[j];
      }
    }

    return previous[b.length];
  }

  static double _stringSimilarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    if (a == b) return 1;
    final distance = _levenshteinDistance(a, b);
    return 1 - (distance / math.max(a.length, b.length));
  }

  static Future<List<TcgSet>> fetchSets() async {
    final allSets = <TcgSet>[];
    int page = 1;

    while (true) {
      final uri = Uri.parse(
        '$_baseUrl/sets?pageSize=250&page=$page&orderBy=-releaseDate',
      );
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final items = (data['data'] as List<dynamic>? ?? []);

      if (items.isEmpty) {
        break;
      }

      allSets.addAll(
        items.map((item) => TcgSet.fromJson(item as Map<String, dynamic>)),
      );

      if (items.length < 250) {
        break;
      }

      page++;
    }

    return allSets;
  }

  static Future<List<TcgCard>> fetchCardsBySet(String setId) async {
    final cachedCards = _setCardsCache[setId];
    if (cachedCards != null) {
      return List<TcgCard>.from(cachedCards);
    }

    final inFlightRequest = _setCardsInFlight[setId];
    if (inFlightRequest != null) {
      final cards = await inFlightRequest;
      return List<TcgCard>.from(cards);
    }

    final request = _fetchAndCacheCardsBySet(setId);
    _setCardsInFlight[setId] = request;

    try {
      final cards = await request;
      return List<TcgCard>.from(cards);
    } finally {
      _setCardsInFlight.remove(setId);
    }
  }

  static Future<List<TcgCard>> _fetchAndCacheCardsBySet(String setId) async {
    final cardsByKey = <String, TcgCard>{};
    int page = 1;

    while (true) {
      final uri = Uri.parse(
        '$_baseUrl/cards?q=set.id:$setId&pageSize=250&page=$page&orderBy=number',
      );
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final items = (data['data'] as List<dynamic>? ?? []);

      if (items.isEmpty) {
        break;
      }

      for (final item in items) {
        final card = TcgCard.fromJson(item as Map<String, dynamic>);
        final key = _buildSetCardDedupKey(card);

        final existing = cardsByKey[key];
        if (existing == null || _preferCardForSetView(card, existing)) {
          cardsByKey[key] = card;
        }
      }

      if (items.length < 250) {
        break;
      }

      page++;
    }

    final allCards = cardsByKey.values.toList()
      ..sort((a, b) => _compareCardNumbers(a.number, b.number));

    _setCardsCache[setId] = List<TcgCard>.from(allCards);
    return allCards;
  }

  static String _buildSetCardDedupKey(TcgCard card) {
    final normalizedName = card.name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();

    final normalizedNumber = card.number
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '');

    return '${card.setId}__${normalizedNumber}__${normalizedName}';
  }

  static bool _preferCardForSetView(TcgCard candidate, TcgCard existing) {
    int score(TcgCard card) {
      var value = 0;
      if (card.largeImageUrl != null && card.largeImageUrl!.isNotEmpty) value += 4;
      if (card.imageUrl != null && card.imageUrl!.isNotEmpty) value += 2;
      if (card.rawPrice != null && card.rawPrice! > 0) value += 1;
      return value;
    }

    return score(candidate) > score(existing);
  }

  static Future<TcgCard> fetchCardById(String cardId) async {
    final uri = Uri.parse('$_baseUrl/cards/$cardId');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return TcgCard.fromJson(data['data'] as Map<String, dynamic>);
  }
}

class CardSearchResult {
  const CardSearchResult({
    this.cards = const <TcgCard>[],
    this.sets = const <TcgSet>[],
    this.matchedSet,
  });

  final List<TcgCard> cards;
  final List<TcgSet> sets;
  final TcgSet? matchedSet;
}

Uri _buildEbaySoldSearchUri({
  required TcgCard card,
  String? gradeLabel,
}) {
  final parts = <String>[
    card.name,
    card.setName,
    card.number,
    if (gradeLabel != null && gradeLabel.isNotEmpty) gradeLabel,
    'pokemon card',
  ];
  final query = parts.where((e) => e.trim().isNotEmpty).join(' ');
  return Uri.https('www.ebay.com', '/sch/i.html', {
    '_nkw': query,
    'LH_Sold': '1',
    'LH_Complete': '1',
  });
}

Future<void> _openEbaySoldSearch({
  required BuildContext context,
  required TcgCard card,
  String? gradeLabel,
}) async {
  final uri = _buildEbaySoldSearchUri(card: card, gradeLabel: gradeLabel);
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open eBay sold search.')),
    );
  }
}

double? _asPrice(dynamic value) {
  if (value is num) return value.toDouble();
  return null;
}

double? _pickFirstAvailablePrice(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final value = _asPrice(source[key]);
    if (value != null && value > 0) {
      return value;
    }
  }
  return null;
}

_MoneyValue? _extractRawCardMoney(Map<String, dynamic> json) {
  final tcgplayer = (json['tcgplayer'] as Map<String, dynamic>? ?? {});
  final tcgPrices = (tcgplayer['prices'] as Map<String, dynamic>? ?? {});
  final cardmarket = (json['cardmarket'] as Map<String, dynamic>? ?? {});
  final cardmarketPrices = (cardmarket['prices'] as Map<String, dynamic>? ?? {});

  for (final key in [
    'normal',
    'holofoil',
    'reverseHolofoil',
    '1stEditionNormal',
    '1stEditionHolofoil',
    'unlimitedHolofoil',
  ]) {
    final priceMap = (tcgPrices[key] as Map<String, dynamic>? ?? {});
    final price = _pickFirstAvailablePrice(priceMap, ['market', 'mid', 'low']);
    if (price != null) {
      return _MoneyValue(amount: price, currencyCode: 'USD');
    }
  }

  final cardmarketPrice = _pickFirstAvailablePrice(
    cardmarketPrices,
    ['averageSellPrice', 'trendPrice', 'avg30', 'lowPrice'],
  );
  if (cardmarketPrice != null) {
    return _MoneyValue(amount: cardmarketPrice, currencyCode: 'EUR');
  }

  return null;
}

Map<String, double> _extractRawPriceBreakdown(Map<String, dynamic> json) {
  final tcgplayer = (json['tcgplayer'] as Map<String, dynamic>? ?? {});
  final tcgPrices = (tcgplayer['prices'] as Map<String, dynamic>? ?? {});
  final cardmarket = (json['cardmarket'] as Map<String, dynamic>? ?? {});
  final cardmarketPrices = (cardmarket['prices'] as Map<String, dynamic>? ?? {});

  final result = <String, double>{};

  void addIf(String label, double? value) {
    if (value != null && value > 0) result[label] = value;
  }

  for (final entry in <String, String>{
    'Normal Market': 'normal',
    'Holofoil Market': 'holofoil',
    'Reverse Holo Market': 'reverseHolofoil',
    '1st Ed Normal Market': '1stEditionNormal',
    '1st Ed Holo Market': '1stEditionHolofoil',
    'Unlimited Holo Market': 'unlimitedHolofoil',
  }.entries) {
    final priceMap = (tcgPrices[entry.value] as Map<String, dynamic>? ?? {});
    addIf(entry.key, _pickFirstAvailablePrice(priceMap, ['market', 'mid', 'low']));
  }

  addIf('Cardmarket Avg Sell', _asPrice(cardmarketPrices['averageSellPrice']));
  addIf('Cardmarket Trend', _asPrice(cardmarketPrices['trendPrice']));
  addIf('Cardmarket Avg30', _asPrice(cardmarketPrices['avg30']));
  addIf('Cardmarket Low', _asPrice(cardmarketPrices['lowPrice']));

  return result;
}

Map<String, double> _extractGradedPrices(Map<String, dynamic> json) {
  final tcgplayer = (json['tcgplayer'] as Map<String, dynamic>? ?? {});
  final tcgPrices = (tcgplayer['prices'] as Map<String, dynamic>? ?? {});

  final gradedMappings = <String, List<String>>{
    'PSA 10': ['psa10'],
    'BGS 10': ['bgs10'],
    'CGC 10': ['cgc10'],
    'SGC 10': ['sgc10'],
    'ACE 10': ['ace10'],
    'GEM 10': ['gemMint10', 'grade10', 'graded10'],
  };

  final result = <String, double>{};

  for (final entry in gradedMappings.entries) {
    for (final key in entry.value) {
      final priceMap = (tcgPrices[key] as Map<String, dynamic>? ?? {});
      final price = _pickFirstAvailablePrice(priceMap, ['market', 'mid', 'low']);
      if (price != null) {
        result[entry.key] = price;
        break;
      }
    }
  }

  return result;
}

String _formatPrice(
  double? price, {
  String fromCurrency = 'USD',
}) {
  return CurrencySettings.formatAmount(price, fromCurrency: fromCurrency);
}

class TcgCard {
  TcgCard({
    required this.id,
    required this.name,
    required this.setId,
    required this.setName,
    required this.number,
    required this.types,
    this.rarity,
    this.hp,
    this.artist,
    this.flavorText,
    this.imageUrl,
    this.largeImageUrl,
    this.setLogoUrl,
    this.rawPrice,
    this.rawPriceCurrency = 'USD',
    this.rawPriceBreakdown = const {},
    this.gradedPrices = const {},
  });

  final String id;
  final String name;
  final String setId;
  final String setName;
  final String number;
  final List<String> types;
  final String? rarity;
  final String? hp;
  final String? artist;
  final String? flavorText;
  final String? imageUrl;
  final String? largeImageUrl;
  final String? setLogoUrl;
  final double? rawPrice;
  final String rawPriceCurrency;
  final Map<String, double> rawPriceBreakdown;
  final Map<String, double> gradedPrices;

  double? get marketPrice => rawPrice;

  factory TcgCard.fromJson(Map<String, dynamic> json) {
    final images = (json['images'] as Map<String, dynamic>? ?? {});
    final set = (json['set'] as Map<String, dynamic>? ?? {});
    final rawPriceMoney = _extractRawCardMoney(json);
    return TcgCard(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Unknown').toString(),
      setId: (set['id'] ?? '').toString(),
      setName: (set['name'] ?? 'Unknown').toString(),
      number: (json['number'] ?? 'Unknown').toString(),
      rarity: json['rarity']?.toString(),
      hp: json['hp']?.toString(),
      artist: json['artist']?.toString(),
      flavorText: json['flavorText']?.toString(),
      imageUrl: images['small']?.toString(),
      largeImageUrl: images['large']?.toString(),
      setLogoUrl: (set['images'] as Map<String, dynamic>? ?? {})['logo']?.toString(),
      rawPrice: rawPriceMoney?.amount,
      rawPriceCurrency: rawPriceMoney?.currencyCode ?? 'USD',
      rawPriceBreakdown: _extractRawPriceBreakdown(json),
      gradedPrices: _extractGradedPrices(json),
      types: (json['types'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class TcgSet {
  TcgSet({
    required this.id,
    required this.name,
    required this.series,
    required this.total,
    required this.releaseDate,
    this.logoUrl,
    this.symbolUrl,
  });

  final String id;
  final String name;
  final String series;
  final int total;
  final String releaseDate;
  final String? logoUrl;
  final String? symbolUrl;

  factory TcgSet.fromJson(Map<String, dynamic> json) {
    final images = json['images'] as Map<String, dynamic>? ?? {};
    return TcgSet(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Unknown').toString(),
      series: (json['series'] ?? 'Unknown').toString(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      releaseDate: (json['releaseDate'] ?? 'Unknown').toString(),
      logoUrl: images['logo']?.toString(),
      symbolUrl: images['symbol']?.toString(),
    );
  }
}

class CardOwnership {
  const CardOwnership({
    this.normal = false,
    this.reverseHolo = false,
    this.holo = false,
    this.copies = 0,
  });

  final bool normal;
  final bool reverseHolo;
  final bool holo;
  final int copies;

  int get effectiveCopies {
    if (copies > 0) return copies;
    if (normal || reverseHolo || holo) return 1;
    return 0;
  }

  CardOwnership copyWith({
    bool? normal,
    bool? reverseHolo,
    bool? holo,
    int? copies,
  }) {
    return CardOwnership(
      normal: normal ?? this.normal,
      reverseHolo: reverseHolo ?? this.reverseHolo,
      holo: holo ?? this.holo,
      copies: copies ?? this.copies,
    );
  }

  Map<String, dynamic> toJson() => {
        'normal': normal,
        'reverseHolo': reverseHolo,
        'holo': holo,
        'copies': copies,
      };

  factory CardOwnership.fromJson(Map<String, dynamic> json) {
    return CardOwnership(
      normal: json['normal'] == true,
      reverseHolo: json['reverseHolo'] == true,
      holo: json['holo'] == true,
      copies: (json['copies'] as num?)?.toInt() ?? 0,
    );
  }
}

int _compareCardNumbers(String a, String b) {
  final aParts = _splitCardNumber(a);
  final bParts = _splitCardNumber(b);

  if (aParts.number != bParts.number) {
    return aParts.number.compareTo(bParts.number);
  }
  return aParts.raw.compareTo(bParts.raw);
}

_CardNumberParts _splitCardNumber(String value) {
  final match = RegExp(r'^(\d+)').firstMatch(value);
  if (match != null) {
    return _CardNumberParts(int.tryParse(match.group(1) ?? '') ?? 999999, value);
  }
  return _CardNumberParts(999999, value);
}

class _CardNumberParts {
  const _CardNumberParts(this.number, this.raw);

  final int number;
  final String raw;
}
