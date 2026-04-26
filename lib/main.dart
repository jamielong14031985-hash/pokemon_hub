// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_element_parameter, unreachable_switch_default, unnecessary_import

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

const int _kCommunityMinimumAge = 18;

DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

int _calculateAgeYears(DateTime dateOfBirth, {DateTime? now}) {
  final today = _dateOnly(now ?? DateTime.now());
  final birthDate = _dateOnly(dateOfBirth);
  var age = today.year - birthDate.year;
  if (today.month < birthDate.month ||
      (today.month == birthDate.month && today.day < birthDate.day)) {
    age--;
  }
  return age;
}

String _formatDateOfBirth(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year.toString();
  return '$day/$month/$year';
}

const Duration _kCardSearchDebounce = Duration(milliseconds: 220);
const int _kFastCardSearchPageSize = 100;
const int _kFastCardSearchMaxPages = 2;
const int _kFastSetSearchMaxPages = 2;

class _FastNetworkImage extends StatelessWidget {
  const _FastNetworkImage({
    super.key,
    required this.imageUrl,
    required this.fit,
    this.width,
    this.height,
    this.cacheWidth,
    this.cacheHeight,
    this.errorChild,
    this.loadingColor = const Color(0xFF0E2A5E),
  });

  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int? cacheWidth;
  final int? cacheHeight;
  final Widget? errorChild;
  final Color loadingColor;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.low,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }

        return Container(
          width: width,
          height: height,
          color: loadingColor,
          alignment: Alignment.center,
          child: const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
            ),
          ),
        );
      },
      errorBuilder: (_, __, ___) {
        return errorChild ??
            Container(
              width: width,
              height: height,
              color: loadingColor,
              alignment: Alignment.center,
              child: const Icon(
                Icons.image_not_supported,
                color: Colors.white,
              ),
            );
      },
    );
  }
}

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
    this.dateOfBirthMs,
  });

  final String uid;
  final String email;
  final String username;
  final int createdAtMs;
  final int updatedAtMs;
  final int? dateOfBirthMs;

  String get displayName => username.trim().isEmpty ? 'Trainer' : username.trim();
  bool get hasDateOfBirth => dateOfBirthMs != null && dateOfBirthMs! > 0;
  DateTime? get dateOfBirth => hasDateOfBirth ? DateTime.fromMillisecondsSinceEpoch(dateOfBirthMs!) : null;
  int? get ageYears => dateOfBirth == null ? null : _calculateAgeYears(dateOfBirth!);
  bool get isAdult => (ageYears ?? -1) >= _kCommunityMinimumAge;

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'username': username,
        'createdAtMs': createdAtMs,
        'updatedAtMs': updatedAtMs,
        if (dateOfBirthMs != null) 'dateOfBirthMs': dateOfBirthMs,
      };

  factory AppUserProfile.fromMap(Map<String, dynamic> json) {
    return AppUserProfile(
      uid: (json['uid'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
      updatedAtMs: (json['updatedAtMs'] as num?)?.toInt() ?? 0,
      dateOfBirthMs: (json['dateOfBirthMs'] as num?)?.toInt(),
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
    int? dateOfBirthMs,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await _users.doc(user.uid).get();
    final createdAtMs = (existing.data()?['createdAtMs'] as num?)?.toInt() ?? now;
    final resolvedDateOfBirthMs = dateOfBirthMs ?? (existing.data()?['dateOfBirthMs'] as num?)?.toInt();

    final profile = AppUserProfile(
      uid: user.uid,
      email: user.email ?? '',
      username: username,
      createdAtMs: createdAtMs,
      updatedAtMs: now,
      dateOfBirthMs: resolvedDateOfBirthMs,
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

  static Future<List<WishlistEntry>> fetchWishlist(String ownerUid) async {
    if (ownerUid.trim().isEmpty) {
      return const <WishlistEntry>[];
    }

    final snapshot = await _collection(ownerUid).get();
    final items = snapshot.docs.map(WishlistEntry.fromDoc).toList()
      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    return items;
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

  static bool hasSavedCopies(CardOwnership ownership) {
    return ownership.copies > 0;
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
        if (hasSavedCopies(entry.value)) entry.key: entry.value.toJson(),
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

  static Future<void> clearSet(String setId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKeyForSet(setId));
    collectionRefreshNotifier.value++;
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
    final prefs = await SharedPreferences.getInstance();
    final setIds = await allTrackedSetIds();
    final nonEmpty = <String>{};

    for (final setId in setIds) {
      final ownershipByCardId = await loadSetOwnershipMap(setId);
      final hasAnySavedCopies = ownershipByCardId.values.any(hasSavedCopies);

      if (hasAnySavedCopies) {
        nonEmpty.add(setId);
      } else {
        // Remove old empty/zero-copy local records so the Master Sets page
        // immediately stops showing this set.
        await prefs.remove(storageKeyForSet(setId));
      }
    }

    return nonEmpty;
  }

  static Future<Map<String, int>> savedCopyCountsBySetId({
    bool cleanEmptySets = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final setIds = await allTrackedSetIds();
    final counts = <String, int>{};

    for (final setId in setIds) {
      final ownershipByCardId = await loadSetOwnershipMap(setId);
      var totalCopies = 0;

      for (final ownership in ownershipByCardId.values) {
        if (ownership.copies > 0) {
          totalCopies += ownership.copies;
        }
      }

      if (totalCopies > 0) {
        counts[setId] = totalCopies;
      } else if (cleanEmptySets) {
        await prefs.remove(storageKeyForSet(setId));
      }
    }

    return counts;
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
    final ownedEntries = ownershipByCardId.entries.where((entry) => LocalPokedexStore.hasSavedCopies(entry.value)).toList();
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

  static Future<Map<String, CardOwnership>> fetchAllOwnedCards(String ownerUid) async {
    if (ownerUid.trim().isEmpty) {
      return const <String, CardOwnership>{};
    }

    final setSnapshot = await _setCollection(ownerUid).get();
    final ownershipByCardId = <String, CardOwnership>{};

    for (final setDoc in setSnapshot.docs) {
      final cardsSnapshot = await setDoc.reference.collection('cards').get();
      for (final cardDoc in cardsSnapshot.docs) {
        final ownership = CardOwnership.fromJson(cardDoc.data());
        if (!LocalPokedexStore.isOwned(ownership)) continue;
        final existingCopies = ownershipByCardId[cardDoc.id]?.effectiveCopies ?? 0;
        final mergedCopies = existingCopies + ownership.effectiveCopies;
        ownershipByCardId[cardDoc.id] = ownership.copyWith(copies: mergedCopies);
      }
    }

    return ownershipByCardId;
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


String _generateLocalDocumentId() {
  final random = math.Random();
  return '${DateTime.now().millisecondsSinceEpoch}_${random.nextInt(1 << 32)}';
}

class CustomBinder {
  const CustomBinder({
    required this.id,
    required this.name,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.imageBase64,
  });

  final String id;
  final String name;
  final int createdAtMs;
  final int updatedAtMs;
  final String? imageBase64;

  bool get hasImage => imageBase64 != null && imageBase64!.trim().isNotEmpty;

  CustomBinder copyWith({
    String? name,
    int? createdAtMs,
    int? updatedAtMs,
    String? imageBase64,
    bool clearImage = false,
  }) {
    return CustomBinder(
      id: id,
      name: name ?? this.name,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      imageBase64: clearImage ? null : (imageBase64 ?? this.imageBase64),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAtMs': createdAtMs,
        'updatedAtMs': updatedAtMs,
        if (hasImage) 'imageBase64': imageBase64!.trim(),
      };

  factory CustomBinder.fromJson(Map<String, dynamic> json) {
    final rawImage = (json['imageBase64'] ?? '').toString().trim();
    return CustomBinder(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Custom Binder').toString(),
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
      updatedAtMs: (json['updatedAtMs'] as num?)?.toInt() ?? 0,
      imageBase64: rawImage.isEmpty ? null : rawImage,
    );
  }
}

class CustomBinderCardEntry {
  const CustomBinderCardEntry({
    required this.cardId,
    required this.name,
    required this.setId,
    required this.setName,
    required this.number,
    required this.updatedAtMs,
    this.imageUrl,
    this.largeImageUrl,
    this.setLogoUrl,
    this.normal = true,
    this.reverseHolo = false,
    this.holo = false,
    this.copies = 1,
  });

  final String cardId;
  final String name;
  final String setId;
  final String setName;
  final String number;
  final String? imageUrl;
  final String? largeImageUrl;
  final String? setLogoUrl;
  final bool normal;
  final bool reverseHolo;
  final bool holo;
  final int copies;
  final int updatedAtMs;

  CardOwnership get ownership => CardOwnership(
        normal: normal,
        reverseHolo: reverseHolo,
        holo: holo,
        copies: copies,
      );

  TcgCard toSummaryCard() {
    return TcgCard(
      id: cardId,
      name: name,
      setId: setId,
      setName: setName,
      number: number,
      types: const <String>[],
      imageUrl: imageUrl,
      largeImageUrl: largeImageUrl,
      setLogoUrl: setLogoUrl,
    );
  }

  CustomBinderCardEntry copyWith({
    String? name,
    String? setId,
    String? setName,
    String? number,
    String? imageUrl,
    String? largeImageUrl,
    String? setLogoUrl,
    bool? normal,
    bool? reverseHolo,
    bool? holo,
    int? copies,
    int? updatedAtMs,
  }) {
    return CustomBinderCardEntry(
      cardId: cardId,
      name: name ?? this.name,
      setId: setId ?? this.setId,
      setName: setName ?? this.setName,
      number: number ?? this.number,
      imageUrl: imageUrl ?? this.imageUrl,
      largeImageUrl: largeImageUrl ?? this.largeImageUrl,
      setLogoUrl: setLogoUrl ?? this.setLogoUrl,
      normal: normal ?? this.normal,
      reverseHolo: reverseHolo ?? this.reverseHolo,
      holo: holo ?? this.holo,
      copies: copies ?? this.copies,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  Map<String, dynamic> toJson() => {
        'cardId': cardId,
        'name': name,
        'setId': setId,
        'setName': setName,
        'number': number,
        if (imageUrl != null && imageUrl!.trim().isNotEmpty) 'imageUrl': imageUrl!.trim(),
        if (largeImageUrl != null && largeImageUrl!.trim().isNotEmpty) 'largeImageUrl': largeImageUrl!.trim(),
        if (setLogoUrl != null && setLogoUrl!.trim().isNotEmpty) 'setLogoUrl': setLogoUrl!.trim(),
        'normal': normal,
        'reverseHolo': reverseHolo,
        'holo': holo,
        'copies': copies,
        'updatedAtMs': updatedAtMs,
      };

  factory CustomBinderCardEntry.fromJson(Map<String, dynamic> json) {
    return CustomBinderCardEntry(
      cardId: (json['cardId'] ?? '').toString(),
      name: (json['name'] ?? 'Unknown Card').toString(),
      setId: (json['setId'] ?? '').toString(),
      setName: (json['setName'] ?? 'Unknown Set').toString(),
      number: (json['number'] ?? '').toString(),
      imageUrl: (json['imageUrl'] ?? '').toString().trim().isEmpty
          ? null
          : (json['imageUrl'] ?? '').toString().trim(),
      largeImageUrl: (json['largeImageUrl'] ?? '').toString().trim().isEmpty
          ? null
          : (json['largeImageUrl'] ?? '').toString().trim(),
      setLogoUrl: (json['setLogoUrl'] ?? '').toString().trim().isEmpty
          ? null
          : (json['setLogoUrl'] ?? '').toString().trim(),
      normal: json['normal'] != false,
      reverseHolo: json['reverseHolo'] == true,
      holo: json['holo'] == true,
      copies: math.max(1, (json['copies'] as num?)?.toInt() ?? 1),
      updatedAtMs: (json['updatedAtMs'] as num?)?.toInt() ?? 0,
    );
  }

  factory CustomBinderCardEntry.fromCard(
    TcgCard card, {
    CardOwnership ownership = const CardOwnership(normal: true, copies: 1),
    int? updatedAtMs,
  }) {
    final safeOwnership = ownership.effectiveCopies > 0
        ? ownership
        : const CardOwnership(normal: true, copies: 1);
    return CustomBinderCardEntry(
      cardId: card.id,
      name: card.name,
      setId: card.setId,
      setName: card.setName,
      number: card.number,
      imageUrl: card.imageUrl,
      largeImageUrl: card.largeImageUrl,
      setLogoUrl: card.setLogoUrl,
      normal: safeOwnership.normal || (!safeOwnership.reverseHolo && !safeOwnership.holo),
      reverseHolo: safeOwnership.reverseHolo,
      holo: safeOwnership.holo,
      copies: math.max(1, safeOwnership.effectiveCopies),
      updatedAtMs: updatedAtMs ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}

class LocalCustomBinderStore {
  static const String _bindersKey = 'custom_binders_v1';

  static String cardsStorageKeyForBinder(String binderId) => 'custom_binder_cards_$binderId';

  static Future<List<CustomBinder>> loadBinders() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_bindersKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <CustomBinder>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final binders = decoded
            .whereType<Map>()
            .map((item) => CustomBinder.fromJson(Map<String, dynamic>.from(item)))
            .where((binder) => binder.id.trim().isNotEmpty)
            .toList();
        binders.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
        return binders;
      }
    } catch (_) {}

    return const <CustomBinder>[];
  }

  static Future<CustomBinder?> loadBinder(String binderId) async {
    final binders = await loadBinders();
    for (final binder in binders) {
      if (binder.id == binderId) return binder;
    }
    return null;
  }

  static Future<void> _saveBinders(List<CustomBinder> binders) async {
    final prefs = await SharedPreferences.getInstance();
    final cleaned = binders.where((binder) => binder.id.trim().isNotEmpty).toList()
      ..sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
    if (cleaned.isEmpty) {
      await prefs.remove(_bindersKey);
    } else {
      await prefs.setString(
        _bindersKey,
        jsonEncode(cleaned.map((binder) => binder.toJson()).toList()),
      );
    }
    collectionRefreshNotifier.value++;
  }

  static Future<void> saveBinder(CustomBinder binder) async {
    final binders = await loadBinders();
    final next = <CustomBinder>[];
    var replaced = false;
    for (final existing in binders) {
      if (existing.id == binder.id) {
        next.add(binder);
        replaced = true;
      } else {
        next.add(existing);
      }
    }
    if (!replaced) {
      next.add(binder);
    }
    await _saveBinders(next);
  }

  static Future<void> deleteBinder(String binderId) async {
    final prefs = await SharedPreferences.getInstance();
    final binders = await loadBinders();
    await _saveBinders(binders.where((binder) => binder.id != binderId).toList());
    await prefs.remove(cardsStorageKeyForBinder(binderId));
    collectionRefreshNotifier.value++;
  }

  static Future<List<CustomBinderCardEntry>> loadCards(String binderId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(cardsStorageKeyForBinder(binderId));
    if (raw == null || raw.trim().isEmpty) {
      return const <CustomBinderCardEntry>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final cards = decoded
            .whereType<Map>()
            .map((item) => CustomBinderCardEntry.fromJson(Map<String, dynamic>.from(item)))
            .where((entry) => entry.cardId.trim().isNotEmpty && entry.copies > 0)
            .toList();
        cards.sort((a, b) {
          final nameCompare = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          if (nameCompare != 0) return nameCompare;
          return _compareCardNumbers(a.number, b.number);
        });
        return cards;
      }
    } catch (_) {}

    return const <CustomBinderCardEntry>[];
  }

  static Future<Map<String, CustomBinderCardEntry>> loadCardMap(String binderId) async {
    final cards = await loadCards(binderId);
    return {
      for (final entry in cards) entry.cardId: entry,
    };
  }

  static Future<void> saveCardMap(
    String binderId,
    Map<String, CustomBinderCardEntry> cardMap,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final cleaned = cardMap.values
        .where((entry) => entry.cardId.trim().isNotEmpty && entry.copies > 0)
        .toList()
      ..sort((a, b) {
        final nameCompare = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        if (nameCompare != 0) return nameCompare;
        return _compareCardNumbers(a.number, b.number);
      });

    if (cleaned.isEmpty) {
      await prefs.remove(cardsStorageKeyForBinder(binderId));
    } else {
      await prefs.setString(
        cardsStorageKeyForBinder(binderId),
        jsonEncode(cleaned.map((entry) => entry.toJson()).toList()),
      );
    }

    final binder = await loadBinder(binderId);
    if (binder != null) {
      await saveBinder(
        binder.copyWith(updatedAtMs: DateTime.now().millisecondsSinceEpoch),
      );
    } else {
      collectionRefreshNotifier.value++;
    }
  }

  static Future<int> cardCount(String binderId) async {
    final cards = await loadCards(binderId);
    return cards.length;
  }

  static Future<void> addCardToBinder({
    required String binderId,
    required TcgCard card,
    CardOwnership ownership = const CardOwnership(normal: true, copies: 1),
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final cardMap = await loadCardMap(binderId);
    final existing = cardMap[card.id];
    if (existing != null) {
      final existingOwnership = existing.ownership;
      cardMap[card.id] = existing.copyWith(
        normal: existingOwnership.normal || ownership.normal || (!ownership.reverseHolo && !ownership.holo),
        reverseHolo: existingOwnership.reverseHolo || ownership.reverseHolo,
        holo: existingOwnership.holo || ownership.holo,
        copies: existingOwnership.effectiveCopies + math.max(1, ownership.effectiveCopies),
        updatedAtMs: now,
      );
    } else {
      cardMap[card.id] = CustomBinderCardEntry.fromCard(
        card,
        ownership: ownership.effectiveCopies > 0
            ? ownership
            : const CardOwnership(normal: true, copies: 1),
        updatedAtMs: now,
      );
    }
    await saveCardMap(binderId, cardMap);
  }

  static Future<void> saveCardEntry({
    required String binderId,
    required CustomBinderCardEntry entry,
  }) async {
    final cardMap = await loadCardMap(binderId);
    if (entry.copies <= 0) {
      cardMap.remove(entry.cardId);
    } else {
      cardMap[entry.cardId] = entry;
    }
    await saveCardMap(binderId, cardMap);
  }

  static Future<void> removeCardFromBinder({
    required String binderId,
    required String cardId,
  }) async {
    final cardMap = await loadCardMap(binderId);
    cardMap.remove(cardId);
    await saveCardMap(binderId, cardMap);
  }
}

class _CustomBinderEditorValue {
  const _CustomBinderEditorValue({
    required this.name,
    this.imageBase64,
  });

  final String name;
  final String? imageBase64;
}

class PokemonHubApp extends StatelessWidget {
  const PokemonHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PocketDex',
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
            if (profile == null ||
                profile.username.trim().isEmpty ||
                !profile.hasDateOfBirth) {
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
  DateTime? _selectedDateOfBirth;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final initialDate = _selectedDateOfBirth ?? DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(now) ? now : initialDate,
      firstDate: DateTime(now.year - 120, 1, 1),
      lastDate: now,
      helpText: 'Select your date of birth',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B3A82)),
          ),
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) return;
    setState(() {
      _selectedDateOfBirth = _dateOnly(picked);
    });
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

    if (_isSignUp && _selectedDateOfBirth == null) {
      _showMessage('Please select your date of birth');
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
            'dateOfBirthMs': _selectedDateOfBirth!.millisecondsSinceEpoch,
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
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: _pickDateOfBirth,
                          borderRadius: BorderRadius.circular(18),
                          child: InputDecorator(
                            decoration: _authInputDecoration('Date of birth'),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedDateOfBirth == null
                                        ? 'Select your date of birth'
                                        : _formatDateOfBirth(_selectedDateOfBirth!),
                                    style: TextStyle(
                                      color: _selectedDateOfBirth == null
                                          ? Colors.white54
                                          : Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.calendar_today_outlined, color: Colors.white70, size: 20),
                              ],
                            ),
                          ),
                        ),
                        if (_selectedDateOfBirth != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _calculateAgeYears(_selectedDateOfBirth!) >= _kCommunityMinimumAge
                                ? 'You can access the Community page once your profile is complete.'
                                : 'Users under $_kCommunityMinimumAge cannot access the Community page.',
                            style: TextStyle(
                              color: _calculateAgeYears(_selectedDateOfBirth!) >= _kCommunityMinimumAge
                                  ? const Color(0xFFC8D4F0)
                                  : const Color(0xFFF7DE77),
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
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
                                            TextSpan(text: ' for PocketDex.'),
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

const String _kPokemonHubTermsAndConditions = '''PocketDex Terms & Conditions

Effective date: 17 April 2025

1. Acceptance of these terms
By creating an account or using PocketDex, you agree to these Terms & Conditions. If you do not agree, do not create an account or use the app.

2. Community use
PocketDex is intended for collectors to track cards, share wishlists, discuss the hobby, and connect with other users. You agree to use the app respectfully and lawfully.

3. Buying, selling, swapping, and arranging meetups
Any sale, swap, trade, payment, postage, meetup, or other arrangement made through the community area is strictly between the users involved. PocketDex does not verify users, inspect items, guarantee payment, guarantee delivery, or guarantee the condition, authenticity, legality, or value of any card or product. Use your own judgment and take appropriate safety precautions.

4. Acceptable behaviour
You must not post or send content that is abusive, threatening, discriminatory, sexually explicit, fraudulent, misleading, or unlawful. You must not harass other users, impersonate anyone, spam the community, or attempt to scam, phish, or manipulate others.

5. Images and content you upload
You are responsible for the text, images, and other content you upload or send through PocketDex. By posting content, you confirm that you have the right to share it and that it does not infringe another person's rights.

6. Account responsibility
You are responsible for keeping your login details secure and for activity that happens through your account. Tell the app owner promptly if you believe your account has been used without permission.

7. Data and visibility
Some information you add, such as your community posts, friend-visible wishlist, and friend-visible Pokédex data, may be shown to other users based on the app's social features. Do not upload anything you do not want shared within those features.

8. Availability and changes
PocketDex may be updated, changed, suspended, or removed at any time. Features may be added, changed, or discontinued without notice.

9. Termination
Accounts or content may be removed, limited, or suspended if a user breaks these terms or misuses the app or community features.

10. Liability
PocketDex is provided on an "as is" basis. To the fullest extent allowed by law, the app owner is not responsible for losses, damage, disputes, failed trades, payment problems, shipping issues, counterfeit items, meetups, or other issues arising from user activity or third-party services.

11. Children and safety
If a user is under the age required by local law to manage an online account, a parent or guardian should review and approve use of the app. Never share sensitive personal information publicly, and use extra caution when arranging in-person meetups.

12. Changes to these terms
These terms may be updated from time to time. Continued use of PocketDex after changes take effect means you accept the updated terms.

13. Contact
If you have questions, concerns, or need to report misuse, use the contact method provided by the app owner.

These terms are a practical in-app starter set and may need review to match your local laws, privacy wording, and how you run the app.''';

const String _kCommunityForumDisclaimer = '''Disclaimer: PocketDex and the creators of this app are not responsible for any sales, swaps, trades, payments, deliveries, meetups, item condition, authenticity, losses, disputes, or damages arising from community posts or arrangements made between users. All transactions and interactions are carried out entirely at the users’ own risk.''';

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
  bool _loadingProfileData = true;
  String? _profileImagePath;
  DateTime? _selectedDateOfBirth;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final results = await Future.wait<dynamic>([
      LocalProfileImageStore.loadForUser(widget.user.uid),
      UserProfileService.fetchProfile(widget.user.uid),
    ]);

    final imagePath = results[0] as String?;
    final profile = results[1] as AppUserProfile?;

    if (!mounted) return;
    setState(() {
      _profileImagePath = imagePath;
      if (_nameController.text.trim().isEmpty && profile != null && profile.username.trim().isNotEmpty) {
        _nameController.text = profile.username;
      }
      _selectedDateOfBirth = profile?.dateOfBirth;
      _loadingProfileData = false;
    });
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

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final initialDate = _selectedDateOfBirth ?? DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(now) ? now : initialDate,
      firstDate: DateTime(now.year - 120, 1, 1),
      lastDate: now,
      helpText: 'Select your date of birth',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B3A82)),
          ),
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) return;
    setState(() {
      _selectedDateOfBirth = _dateOnly(picked);
    });
  }

  Future<void> _saveProfile() async {
    final username = _nameController.text.trim();
    if (username.isEmpty) {
      _showMessage('Enter a trainer name');
      return;
    }

    if (_selectedDateOfBirth == null) {
      _showMessage('Please select your date of birth');
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await UserProfileService.upsertProfile(
        user: widget.user,
        username: username,
        dateOfBirthMs: _selectedDateOfBirth!.millisecondsSinceEpoch,
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

    if (_loadingProfileData) {
      return const _FullScreenLoader();
    }

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
                      const SizedBox(height: 8),
                      const Text(
                        'Your date of birth is required so the app can keep the Community page 18+.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                          height: 1.35,
                        ),
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
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _pickDateOfBirth,
                        borderRadius: BorderRadius.circular(18),
                        child: InputDecorator(
                          decoration: _authInputDecoration('Date of birth'),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedDateOfBirth == null
                                      ? 'Select your date of birth'
                                      : _formatDateOfBirth(_selectedDateOfBirth!),
                                  style: TextStyle(
                                    color: _selectedDateOfBirth == null ? Colors.white54 : Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const Icon(Icons.calendar_today_outlined, color: Colors.white70, size: 20),
                            ],
                          ),
                        ),
                      ),
                      if (_selectedDateOfBirth != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _calculateAgeYears(_selectedDateOfBirth!) >= _kCommunityMinimumAge
                              ? 'You can access the Community page once your profile is saved.'
                              : 'Users under $_kCommunityMinimumAge cannot access the Community page.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _calculateAgeYears(_selectedDateOfBirth!) >= _kCommunityMinimumAge
                                ? const Color(0xFFC8D4F0)
                                : const Color(0xFFF7DE77),
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
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

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
      if (!widget.profile.hasDateOfBirth) {
        _showMessage('Please complete your profile with your date of birth first.');
        return;
      }

      if (!widget.profile.isAdult) {
        _showMessage('Community is only available to users aged $_kCommunityMinimumAge or over.');
        return;
      }

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
        return 'PocketDex';
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
    required this.updatedAtMs,
    this.marketStatus = 'Available',
    this.askingPrice,
    this.askingCurrency = 'GBP',
    this.cardCondition = '',
    this.deliveryMethod = '',
    this.locationText = '',
    this.wantedTradeFor = '',
    this.lastBumpedAtMs,
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
  final int updatedAtMs;
  final String marketStatus;
  final double? askingPrice;
  final String askingCurrency;
  final String cardCondition;
  final String deliveryMethod;
  final String locationText;
  final String wantedTradeFor;
  final int? lastBumpedAtMs;
  final List<String> imageBase64List;
  final List<String> hiddenReplyIds;

  DateTime get createdAt => DateTime.fromMillisecondsSinceEpoch(createdAtMs);
  DateTime get updatedAt => DateTime.fromMillisecondsSinceEpoch(
        updatedAtMs > 0 ? updatedAtMs : createdAtMs,
      );
  DateTime? get lastBumpedAt =>
      lastBumpedAtMs == null || lastBumpedAtMs! <= 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lastBumpedAtMs!);
  bool get hasImages => imageBase64List.isNotEmpty;
  int get imageCount => imageBase64List.length;
  String? get primaryImageBase64 => hasImages ? imageBase64List.first : null;
  bool get isDiscussion => postType == 'Thread';
  bool get isMarketplace => !isDiscussion;
  bool get isForSale => postType == 'For Sale';
  bool get isSwap => postType == 'Swap';
  String get normalizedMarketStatus =>
      isMarketplace ? _normalizeCommunityMarketStatus(marketStatus) : 'Discussion';
  bool get hasPrice => askingPrice != null && askingPrice!.isFinite && askingPrice! > 0;
  String get askingCurrencyCode {
    final normalized = askingCurrency.trim().toUpperCase();
    if (CurrencySettings.supportedCurrencies.containsKey(normalized)) {
      return normalized;
    }
    return 'GBP';
  }

  String get formattedPrice =>
      hasPrice ? CurrencySettings.formatAmount(askingPrice, fromCurrency: askingCurrencyCode) : 'Price not set';
  int get lastActivityAtMs => math.max(
        math.max(createdAtMs, updatedAtMs),
        lastBumpedAtMs ?? 0,
      );

  String? get compactMarketplaceSummary {
    if (!isMarketplace) return null;
    final parts = <String>[];
    if (isForSale && hasPrice) {
      parts.add(formattedPrice);
    }
    if (cardCondition.trim().isNotEmpty) {
      parts.add(cardCondition.trim());
    }
    if (deliveryMethod.trim().isNotEmpty) {
      parts.add(deliveryMethod.trim());
    }
    if (locationText.trim().isNotEmpty) {
      parts.add(locationText.trim());
    }
    if (parts.isEmpty) return null;
    return parts.join(' • ');
  }

  Map<String, dynamic> toJson() => {
        'authorId': authorId,
        'authorName': authorName,
        'postType': postType,
        'title': title,
        'description': description,
        'contact': contact,
        'createdAtMs': createdAtMs,
        'updatedAtMs': updatedAtMs,
        'imageBase64List': imageBase64List,
        if (isMarketplace) 'marketStatus': normalizedMarketStatus,
        if (isForSale && hasPrice) 'askingPrice': askingPrice,
        if (isMarketplace) 'askingCurrency': askingCurrencyCode,
        if (isMarketplace && cardCondition.trim().isNotEmpty) 'cardCondition': cardCondition.trim(),
        if (isMarketplace && deliveryMethod.trim().isNotEmpty) 'deliveryMethod': deliveryMethod.trim(),
        if (isMarketplace && locationText.trim().isNotEmpty) 'locationText': locationText.trim(),
        if (isSwap && wantedTradeFor.trim().isNotEmpty) 'wantedTradeFor': wantedTradeFor.trim(),
        if (lastBumpedAtMs != null && lastBumpedAtMs! > 0) 'lastBumpedAtMs': lastBumpedAtMs,
        if (hiddenReplyIds.isNotEmpty) 'hiddenReplyIds': hiddenReplyIds,
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

    final postType = (json['postType'] ?? 'Swap').toString();
    final isMarketplace = postType != 'Thread';
    final rawPrice = (json['askingPrice'] as num?)?.toDouble();

    return CommunityPost(
      id: doc.id,
      authorId: (json['authorId'] ?? '').toString(),
      authorName: (json['authorName'] ?? 'Trainer').toString(),
      postType: postType,
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      contact: (json['contact'] ?? '').toString(),
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
      updatedAtMs: (json['updatedAtMs'] as num?)?.toInt() ?? ((json['createdAtMs'] as num?)?.toInt() ?? 0),
      marketStatus: isMarketplace
          ? _normalizeCommunityMarketStatus((json['marketStatus'] ?? 'Available').toString())
          : 'Discussion',
      askingPrice: rawPrice != null && rawPrice.isFinite && rawPrice > 0 ? rawPrice : null,
      askingCurrency: (json['askingCurrency'] ?? 'GBP').toString().toUpperCase(),
      cardCondition: isMarketplace ? (json['cardCondition'] ?? '').toString() : '',
      deliveryMethod: isMarketplace ? (json['deliveryMethod'] ?? '').toString() : '',
      locationText: isMarketplace ? (json['locationText'] ?? '').toString() : '',
      wantedTradeFor: postType == 'Swap' ? (json['wantedTradeFor'] ?? '').toString() : '',
      lastBumpedAtMs: (json['lastBumpedAtMs'] as num?)?.toInt(),
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
  static const int maxImagesPerPost = 10;
  static const int _maxImageBytes = 56 * 1024;
  static const int _maxDimension = 760;

  static Future<List<String>> pickAndEncodeMultiFromGallery({
    int limit = maxImagesPerPost,
  }) async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(
      imageQuality: 82,
      maxWidth: 1200,
      maxHeight: 1200,
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
      imageQuality: 82,
      maxWidth: 1200,
      maxHeight: 1200,
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

    while (encoded.length > _maxImageBytes && quality > 38) {
      quality -= 8;
      encoded = img.encodeJpg(current, quality: quality);
    }

    while (encoded.length > _maxImageBytes &&
        (current.width > 360 || current.height > 360)) {
      current = img.copyResize(
        current,
        width: current.width >= current.height
            ? math.max(360, (current.width * 0.82).round())
            : null,
        height: current.height > current.width
            ? math.max(360, (current.height * 0.82).round())
            : null,
        interpolation: img.Interpolation.average,
      );
      quality = math.min(quality, 66);
      encoded = img.encodeJpg(current, quality: quality);
      while (encoded.length > _maxImageBytes && quality > 34) {
        quality -= 6;
        encoded = img.encodeJpg(current, quality: quality);
      }
    }

    if (encoded.length > _maxImageBytes) {
      throw Exception(
        'This photo is still too large. Try cropping it tighter or choosing fewer photos.',
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


const List<String> _kCommunityMarketStatuses = <String>[
  'All',
  'Available',
  'Pending',
  'Sold',
  'Traded',
];

const List<String> _kCommunityCardConditions = <String>[
  'Mint',
  'Near Mint',
  'Excellent',
  'Good',
  'Played',
  'Damaged',
];

const List<String> _kCommunityDeliveryMethods = <String>[
  'Post',
  'Meetup',
  'Either',
];

String _normalizeCommunityMarketStatus(String? value) {
  final normalized = value?.trim().toLowerCase() ?? '';
  switch (normalized) {
    case 'pending':
      return 'Pending';
    case 'sold':
      return 'Sold';
    case 'traded':
      return 'Traded';
    case 'available':
    default:
      return 'Available';
  }
}

Color _communityPostAccentColor(CommunityPost post) {
  if (post.isDiscussion) return const Color(0xFF5B3FD6);
  if (post.isForSale) return const Color(0xFF8E1E2E);
  return const Color(0xFF0B6B5B);
}

Color _communityMarketStatusColor(String? status) {
  switch (_normalizeCommunityMarketStatus(status)) {
    case 'Pending':
      return const Color(0xFFF0A83A);
    case 'Sold':
      return const Color(0xFFB13B59);
    case 'Traded':
      return const Color(0xFF0B6B5B);
    case 'Available':
    default:
      return const Color(0xFF2D7EF7);
  }
}

IconData _communityMarketStatusIcon(String? status) {
  switch (_normalizeCommunityMarketStatus(status)) {
    case 'Pending':
      return Icons.schedule_outlined;
    case 'Sold':
      return Icons.check_circle_outline_rounded;
    case 'Traded':
      return Icons.swap_horiz_rounded;
    case 'Available':
    default:
      return Icons.storefront_outlined;
  }
}

String _communityMarketStatusLabel(CommunityPost post) {
  return post.isDiscussion ? 'Discussion' : post.normalizedMarketStatus;
}


enum _CommunityPostMenuAction { edit, available, pending, sold, traded, bump, delete }

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


DocumentReference<Map<String, dynamic>> _communityPrivateConversationRef(String conversationId) =>
    FirebaseFirestore.instance.collection('community_private_conversations').doc(conversationId);

DocumentReference<Map<String, dynamic>> _userCommunityPrivateConversationRef({
  required String ownerUid,
  required String conversationId,
}) =>
    FirebaseFirestore.instance
        .collection('users')
        .doc(ownerUid)
        .collection('community_private_conversations')
        .doc(conversationId);

Map<String, dynamic> _communityPrivateConversationData({
  required String currentUid,
  required String currentUserName,
  required String otherUserId,
  required String otherUserName,
  required String relatedPostId,
  required String relatedPostTitle,
  required int createdAtMs,
  required int updatedAtMs,
  required String lastMessage,
  required String lastSenderId,
}) {
  return <String, dynamic>{
    'participants': <String>[currentUid, otherUserId],
    'participantNames': <String, String>{
      currentUid: currentUserName,
      otherUserId: otherUserName,
    },
    'relatedPostId': relatedPostId,
    'relatedPostTitle': relatedPostTitle,
    'createdAtMs': createdAtMs,
    'updatedAtMs': updatedAtMs,
    'lastMessage': lastMessage,
    'lastSenderId': lastSenderId,
  };
}

Future<void> _syncCommunityPrivateConversation({
  required String conversationId,
  required String currentUid,
  required String currentUserName,
  required String otherUserId,
  required String otherUserName,
  required String relatedPostId,
  required String relatedPostTitle,
  required int createdAtMs,
  required int updatedAtMs,
  String lastMessage = '',
  String lastSenderId = '',
}) async {
  if (conversationId.trim().isEmpty ||
      currentUid.trim().isEmpty ||
      otherUserId.trim().isEmpty ||
      currentUid == otherUserId) {
    return;
  }

  final data = _communityPrivateConversationData(
    currentUid: currentUid,
    currentUserName: currentUserName,
    otherUserId: otherUserId,
    otherUserName: otherUserName,
    relatedPostId: relatedPostId,
    relatedPostTitle: relatedPostTitle,
    createdAtMs: createdAtMs,
    updatedAtMs: updatedAtMs,
    lastMessage: lastMessage,
    lastSenderId: lastSenderId,
  );

  final batch = FirebaseFirestore.instance.batch();
  batch.set(_communityPrivateConversationRef(conversationId), data, SetOptions(merge: true));
  batch.set(
    _userCommunityPrivateConversationRef(ownerUid: currentUid, conversationId: conversationId),
    data,
    SetOptions(merge: true),
  );
  batch.set(
    _userCommunityPrivateConversationRef(ownerUid: otherUserId, conversationId: conversationId),
    data,
    SetOptions(merge: true),
  );
  await batch.commit();
}

Future<void> _syncCommunityPrivateMessage({
  required String conversationId,
  required String currentUid,
  required String currentUserName,
  required String otherUserId,
  required String otherUserName,
  required String relatedPostId,
  required String relatedPostTitle,
  required CommunityPrivateMessage message,
}) async {
  if (conversationId.trim().isEmpty ||
      currentUid.trim().isEmpty ||
      otherUserId.trim().isEmpty ||
      currentUid == otherUserId) {
    return;
  }

  final conversationData = _communityPrivateConversationData(
    currentUid: currentUid,
    currentUserName: currentUserName,
    otherUserId: otherUserId,
    otherUserName: otherUserName,
    relatedPostId: relatedPostId,
    relatedPostTitle: relatedPostTitle,
    createdAtMs: message.createdAtMs,
    updatedAtMs: message.createdAtMs,
    lastMessage: message.message,
    lastSenderId: message.authorId,
  );

  final messageData = message.toJson();
  final sharedConversationRef = _communityPrivateConversationRef(conversationId);
  final currentConversationRef = _userCommunityPrivateConversationRef(
    ownerUid: currentUid,
    conversationId: conversationId,
  );
  final otherConversationRef = _userCommunityPrivateConversationRef(
    ownerUid: otherUserId,
    conversationId: conversationId,
  );

  final batch = FirebaseFirestore.instance.batch();
  batch.set(sharedConversationRef, conversationData, SetOptions(merge: true));
  batch.set(currentConversationRef, conversationData, SetOptions(merge: true));
  batch.set(otherConversationRef, conversationData, SetOptions(merge: true));
  batch.set(
    sharedConversationRef.collection('messages').doc(message.id),
    messageData,
    SetOptions(merge: true),
  );
  batch.set(
    currentConversationRef.collection('messages').doc(message.id),
    messageData,
    SetOptions(merge: true),
  );
  batch.set(
    otherConversationRef.collection('messages').doc(message.id),
    messageData,
    SetOptions(merge: true),
  );
  await batch.commit();
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
      _showThreadMessage('You need to be signed in to delete comments.');
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
        _showThreadMessage('Only the comment author or post owner can delete comments.');
        return;
      }
      _showThreadMessage('Comment deleted.');
    } on FirebaseException catch (error) {
      _showThreadMessage(error.message ?? 'Could not delete comment.');
    } catch (_) {
      _showThreadMessage('Could not delete comment.');
    }
  }

  Future<void> _openReplyMemberSheet({
    required CommunityReply reply,
    required CommunityPost livePost,
  }) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? widget.currentProfile.uid;
    final replyAuthorId = reply.authorId.trim();
    final replyAuthorName = reply.authorName.trim().isEmpty ? 'Trainer' : reply.authorName.trim();
    final canDelete = currentUid == reply.authorId || currentUid == livePost.authorId;
    final canAddFriend = replyAuthorId.isNotEmpty && replyAuthorId != currentUid;

    if (!canDelete && !canAddFriend) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF102754),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                Text(
                  replyAuthorName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose an action for this reply.',
                  style: TextStyle(
                    color: Color(0xFFC8D4F0),
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
                if (canAddFriend) ...[
                  const SizedBox(height: 16),
                  _FriendActionButton(
                    currentProfile: widget.currentProfile,
                    otherUserId: replyAuthorId,
                    otherUserName: replyAuthorName,
                  ),
                ],
                if (canDelete) ...[
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _deleteReply(reply);
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: const Color(0xFFB13B59),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text(
                      'Delete message',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showThreadMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _updateMarketStatus(CommunityPost livePost, String status) async {
    if (!livePost.isMarketplace) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      await _postRef.set(
        <String, dynamic>{
          'marketStatus': _normalizeCommunityMarketStatus(status),
          'updatedAtMs': now,
        },
        SetOptions(merge: true),
      );
      _showThreadMessage('Listing marked as ${_normalizeCommunityMarketStatus(status)}.');
    } catch (_) {
      _showThreadMessage('Could not update listing status.');
    }
  }

  Future<void> _bumpListing() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      await _postRef.set(
        <String, dynamic>{
          'lastBumpedAtMs': now,
          'updatedAtMs': now,
        },
        SetOptions(merge: true),
      );
      _showThreadMessage('Listing bumped.');
    } catch (_) {
      _showThreadMessage('Could not bump listing.');
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
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final canManageListing = currentUid != null && currentUid == livePost.authorId && livePost.isMarketplace;
    final accentColor = _communityPostAccentColor(livePost);

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
                          color: accentColor,
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
                      if (livePost.isMarketplace) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _communityMarketStatusColor(livePost.normalizedMarketStatus),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            livePost.normalizedMarketStatus,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
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
                              livePost.compactMarketplaceSummary ?? 'Replying to ${livePost.authorName}',
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
                          _CommunityMetaChip(
                            icon: livePost.isDiscussion
                                ? Icons.forum_outlined
                                : livePost.isForSale
                                    ? Icons.sell_outlined
                                    : Icons.swap_horiz_rounded,
                            label: livePost.isDiscussion ? 'Discussion' : livePost.postType,
                            color: accentColor,
                          ),
                          if (livePost.isMarketplace) ...[
                            const SizedBox(width: 8),
                            _CommunityMetaChip(
                              icon: _communityMarketStatusIcon(livePost.normalizedMarketStatus),
                              label: livePost.normalizedMarketStatus,
                              color: _communityMarketStatusColor(livePost.normalizedMarketStatus),
                            ),
                          ],
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
                      if (livePost.isMarketplace) ...[
                        _CommunityInfoRow(label: 'Status', value: livePost.normalizedMarketStatus),
                        if (livePost.isForSale)
                          _CommunityInfoRow(
                            label: 'Asking price',
                            value: livePost.hasPrice ? livePost.formattedPrice : 'Not added',
                          ),
                        if (livePost.cardCondition.trim().isNotEmpty)
                          _CommunityInfoRow(label: 'Condition', value: livePost.cardCondition.trim()),
                        if (livePost.deliveryMethod.trim().isNotEmpty)
                          _CommunityInfoRow(label: 'Delivery', value: livePost.deliveryMethod.trim()),
                        if (livePost.locationText.trim().isNotEmpty)
                          _CommunityInfoRow(label: 'Location', value: livePost.locationText.trim()),
                        if (livePost.isSwap && livePost.wantedTradeFor.trim().isNotEmpty)
                          _CommunityInfoRow(label: 'Wanted in trade', value: livePost.wantedTradeFor.trim()),
                      ],
                      _CommunityInfoRow(
                        label: 'Contact',
                        value: livePost.contact.isEmpty ? 'Not added' : livePost.contact,
                      ),
                      if (livePost.hasImages)
                        _CommunityInfoRow(
                          label: 'Photos',
                          value: _communityImageCountLabel(livePost.imageCount),
                        ),
                      if (livePost.lastBumpedAt != null)
                        _CommunityInfoRow(
                          label: 'Last bumped',
                          value: _formatDate(livePost.lastBumpedAt!),
                        ),
                      if (canManageListing) ...[
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: () => _updateMarketStatus(
                                livePost,
                                livePost.normalizedMarketStatus == 'Pending' ? 'Available' : 'Pending',
                              ),
                              icon: Icon(
                                livePost.normalizedMarketStatus == 'Pending'
                                    ? Icons.storefront_outlined
                                    : Icons.schedule_outlined,
                              ),
                              label: Text(
                                livePost.normalizedMarketStatus == 'Pending'
                                    ? 'Mark available'
                                    : 'Mark pending',
                              ),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: () => _updateMarketStatus(
                                livePost,
                                livePost.isForSale ? 'Sold' : 'Traded',
                              ),
                              icon: Icon(
                                livePost.isForSale
                                    ? Icons.check_circle_outline_rounded
                                    : Icons.swap_horiz_rounded,
                              ),
                              label: Text(livePost.isForSale ? 'Mark sold' : 'Mark traded'),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: _bumpListing,
                              icon: const Icon(Icons.north_rounded),
                              label: const Text('Bump'),
                            ),
                          ],
                        ),
                      ],
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
                    child: InkWell(
                      onTap: () => _openReplyMemberSheet(
                        reply: reply,
                        livePost: livePost,
                      ),
                      borderRadius: BorderRadius.circular(999),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                reply.authorName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFF7DE77),
                                  fontWeight: FontWeight.w800,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Color(0xFFF7DE77),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Color(0xFFF7DE77),
                              size: 18,
                            ),
                          ],
                        ),
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
                          color: Colors.white.withValues(alpha: 0.04),
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
                                        color: Colors.black.withValues(alpha: 0.58),
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
  String _marketStatusFilter = 'All';
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

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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

  bool get _hasActiveMarketplaceFilters =>
      _filter != 'All' || _marketStatusFilter != 'All';

  String get _marketplaceFilterSummary {
    final parts = <String>[];
    if (_filter != 'All') {
      parts.add(_filter);
    }
    if (_marketStatusFilter != 'All') {
      parts.add(_marketStatusFilter);
    }
    return parts.isEmpty ? 'Showing all marketplace listings' : 'Showing ${parts.join(' • ')}';
  }

  Future<void> _openMarketplaceFiltersSheet() async {
    var selectedType = _filter;
    var selectedStatus = _marketStatusFilter;

    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF102754),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
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
                      'Marketplace filters',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose the type of listings and status you want to see.',
                      style: TextStyle(
                        color: Color(0xFFC8D4F0),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Listing type',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _CommunityFilterChip(
                          label: 'All',
                          selected: selectedType == 'All',
                          minWidth: 82,
                          onTap: () => setSheetState(() => selectedType = 'All'),
                        ),
                        _CommunityFilterChip(
                          label: 'Swap',
                          selected: selectedType == 'Swap',
                          minWidth: 94,
                          onTap: () => setSheetState(() => selectedType = 'Swap'),
                        ),
                        _CommunityFilterChip(
                          label: 'For Sale',
                          selected: selectedType == 'For Sale',
                          minWidth: 118,
                          onTap: () => setSheetState(() => selectedType = 'For Sale'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Status',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _kCommunityMarketStatuses.map((status) {
                        return _CommunityFilterChip(
                          label: status,
                          selected: selectedStatus == status,
                          minWidth: status == 'Available' ? 118 : 96,
                          onTap: () => setSheetState(() => selectedStatus = status),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setSheetState(() {
                                selectedType = 'All';
                                selectedStatus = 'All';
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xFF3F5C96)),
                              minimumSize: const Size.fromHeight(50),
                            ),
                            child: const Text('Reset'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                            ),
                            child: const Text('Apply'),
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
    );

    if (applied == true && mounted) {
      setState(() {
        _filter = selectedType;
        _marketStatusFilter = selectedStatus;
      });
    }
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

  Future<void> _updateMarketStatus(CommunityPost post, String status) async {
    if (!post.isMarketplace) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      await FirebaseFirestore.instance.collection('community_posts').doc(post.id).set(
        <String, dynamic>{
          'marketStatus': _normalizeCommunityMarketStatus(status),
          'updatedAtMs': now,
        },
        SetOptions(merge: true),
      );
      _showMessage('${post.title} marked as ${_normalizeCommunityMarketStatus(status)}.');
    } catch (_) {
      _showMessage('Could not update listing status.');
    }
  }

  Future<void> _bumpPost(CommunityPost post) async {
    if (!post.isMarketplace) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      await FirebaseFirestore.instance.collection('community_posts').doc(post.id).set(
        <String, dynamic>{
          'lastBumpedAtMs': now,
          'updatedAtMs': now,
        },
        SetOptions(merge: true),
      );
      _showMessage('Listing bumped to the top of your latest activity view.');
    } catch (_) {
      _showMessage('Could not bump listing.');
    }
  }

  List<CommunityPost> _visiblePosts(List<CommunityPost> posts) {
    final sectionPosts = _section == 'Discussions'
        ? posts.where((post) => post.isDiscussion).toList()
        : posts.where((post) => post.isMarketplace).toList();

    Iterable<CommunityPost> filtered = sectionPosts;
    if (_section == 'Marketplace' && _filter != 'All') {
      filtered = filtered.where((post) => post.postType == _filter);
    }
    if (_section == 'Marketplace' && _marketStatusFilter != 'All') {
      filtered = filtered.where(
        (post) => post.normalizedMarketStatus == _marketStatusFilter,
      );
    }

    final visible = filtered.toList()
      ..sort((a, b) => b.lastActivityAtMs.compareTo(a.lastActivityAtMs));
    return visible;
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
      _showMessage('This post cannot be messaged right now.');
      return;
    }

    if (otherUserId == currentUser.uid) {
      _showMessage('This is your post. Open your inbox for existing chats.');
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final conversationId = _communityConversationIdForPost(
      postId: post.id,
      userAId: currentUser.uid,
      userBId: otherUserId,
    );

    try {
      await _syncCommunityPrivateConversation(
        conversationId: conversationId,
        currentUid: currentUser.uid,
        currentUserName: widget.profile.displayName,
        otherUserId: otherUserId,
        otherUserName: post.authorName,
        relatedPostId: post.id,
        relatedPostTitle: post.title,
        createdAtMs: now,
        updatedAtMs: now,
      );
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

  Future<void> _openCommunityMemberSheet(CommunityPost post) async {
    final otherUserId = post.authorId.trim();
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? widget.profile.uid;
    if (otherUserId.isEmpty || otherUserId == currentUid) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF102754),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                Text(
                  post.authorName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose an action for this community member.',
                  style: TextStyle(
                    color: Color(0xFFC8D4F0),
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _openPrivateMessageForPost(post);
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: const Color(0xFFF7DE77),
                    foregroundColor: Colors.black,
                  ),
                  icon: const Icon(Icons.mail_outline_rounded),
                  label: const Text(
                    'Send message',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 10),
                _FriendActionButton(
                  currentProfile: widget.profile,
                  otherUserId: post.authorId,
                  otherUserName: post.authorName,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard({required bool hasNewPosts}) {
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
            color: Colors.black.withValues(alpha: 0.14),
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
                    color: const Color(0xFFF7DE77).withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFF7DE77).withValues(alpha: 0.24)),
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
                      color: const Color(0xFFF7DE77).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFF7DE77).withValues(alpha: 0.28)),
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
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
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
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
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
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openMarketplaceFiltersSheet,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: _hasActiveMarketplaceFilters
                              ? const Color(0xFFF7DE77)
                              : Colors.white.withValues(alpha: 0.18),
                        ),
                        backgroundColor: Colors.white.withValues(alpha: 0.03),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: Icon(
                        _hasActiveMarketplaceFilters
                            ? Icons.filter_alt_rounded
                            : Icons.filter_list_rounded,
                        size: 18,
                        color: _hasActiveMarketplaceFilters
                            ? const Color(0xFFF7DE77)
                            : Colors.white,
                      ),
                      label: Text(
                        _hasActiveMarketplaceFilters ? 'Filters active' : 'Filter listings',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  if (_hasActiveMarketplaceFilters) ...[
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: () => setState(() {
                        _filter = 'All';
                        _marketStatusFilter = 'All';
                      }),
                      child: const Text('Clear'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _marketplaceFilterSummary,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_hasActiveMarketplaceFilters) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (_filter != 'All')
                            _CommunityActiveFilterPill(
                              label: _filter,
                              onRemove: () => setState(() => _filter = 'All'),
                            ),
                          if (_marketStatusFilter != 'All')
                            _CommunityActiveFilterPill(
                              label: _marketStatusFilter,
                              onRemove: () => setState(() => _marketStatusFilter = 'All'),
                            ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 4),
                      const Text(
                        'Tap Filter listings to narrow the marketplace by type or status.',
                        style: TextStyle(
                          color: Color(0xFFC8D4F0),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                ),
                child: const Text(
                  'Discussion threads stay separate from sale and swap listings so it is easier to chat, ask questions, and meet new collectors.',
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
                  return _buildHeaderCard(hasNewPosts: hasNewPosts);
                }

                if (posts.isEmpty) {
                  final emptyTitle = _section == 'Discussions'
                      ? 'No discussion threads yet'
                      : _marketStatusFilter == 'All'
                          ? 'No listings match this view yet'
                          : 'No ${_marketStatusFilter.toLowerCase()} listings yet';
                  final emptyMessage = _section == 'Discussions'
                      ? 'Start a thread to chat about cards, collecting, trades, and making friends.'
                      : 'Create a professional swap or sale listing with status, condition, and delivery details.';
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF102754),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                          emptyTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          emptyMessage,
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
                  onSetMarketStatus: post.authorId == currentUid
                      ? (status) => _updateMarketStatus(post, status)
                      : null,
                  onBump: post.authorId == currentUid && post.isMarketplace
                      ? () => _bumpPost(post)
                      : null,
                  onAuthorTap: post.authorId.trim().isEmpty || post.authorId == currentUid
                      ? null
                      : () => _openCommunityMemberSheet(post),
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
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                    : Colors.white.withValues(alpha: 0.14),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: const Color(0xFFF7DE77).withValues(alpha: 0.18),
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

class _CommunityActiveFilterPill extends StatelessWidget {
  const _CommunityActiveFilterPill({
    required this.label,
    required this.onRemove,
  });

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7DE77).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFF7DE77).withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFFFF2B3),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close,
              size: 15,
              color: Color(0xFFFFF2B3),
            ),
          ),
        ],
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
    this.onAuthorTap,
    this.onSetMarketStatus,
    this.onBump,
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
  final VoidCallback? onAuthorTap;
  final ValueChanged<String>? onSetMarketStatus;
  final VoidCallback? onBump;

  @override
  Widget build(BuildContext context) {
    final isDiscussion = post.isDiscussion;
    final accentColor = _communityPostAccentColor(post);
    final postIcon = isDiscussion
        ? Icons.forum_outlined
        : post.isForSale
            ? Icons.sell_outlined
            : Icons.swap_horiz_rounded;
    final canManageListing = canEdit && post.isMarketplace && onSetMarketStatus != null;

    void handleMenuAction(_CommunityPostMenuAction value) {
      switch (value) {
        case _CommunityPostMenuAction.edit:
          onEdit();
          break;
        case _CommunityPostMenuAction.available:
          onSetMarketStatus?.call('Available');
          break;
        case _CommunityPostMenuAction.pending:
          onSetMarketStatus?.call('Pending');
          break;
        case _CommunityPostMenuAction.sold:
          onSetMarketStatus?.call('Sold');
          break;
        case _CommunityPostMenuAction.traded:
          onSetMarketStatus?.call('Traded');
          break;
        case _CommunityPostMenuAction.bump:
          onBump?.call();
          break;
        case _CommunityPostMenuAction.delete:
          onDelete();
          break;
      }
    }

    List<PopupMenuEntry<_CommunityPostMenuAction>> buildMenuItems() {
      final items = <PopupMenuEntry<_CommunityPostMenuAction>>[
        const PopupMenuItem<_CommunityPostMenuAction>(
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
      ];

      if (canManageListing) {
        items.addAll([
          const PopupMenuDivider(),
          const PopupMenuItem<_CommunityPostMenuAction>(
            value: _CommunityPostMenuAction.available,
            child: Row(
              children: [
                Icon(Icons.storefront_outlined, color: Colors.lightBlueAccent),
                SizedBox(width: 10),
                Text(
                  'Mark available',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const PopupMenuItem<_CommunityPostMenuAction>(
            value: _CommunityPostMenuAction.pending,
            child: Row(
              children: [
                Icon(Icons.schedule_outlined, color: Color(0xFFF0A83A)),
                SizedBox(width: 10),
                Text(
                  'Mark pending',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          PopupMenuItem<_CommunityPostMenuAction>(
            value: post.isForSale ? _CommunityPostMenuAction.sold : _CommunityPostMenuAction.traded,
            child: Row(
              children: [
                Icon(
                  post.isForSale ? Icons.check_circle_outline_rounded : Icons.swap_horiz_rounded,
                  color: post.isForSale ? Colors.redAccent : const Color(0xFF54D39A),
                ),
                const SizedBox(width: 10),
                Text(
                  post.isForSale ? 'Mark sold' : 'Mark traded',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const PopupMenuItem<_CommunityPostMenuAction>(
            value: _CommunityPostMenuAction.bump,
            child: Row(
              children: [
                Icon(Icons.north_rounded, color: Color(0xFFF7DE77)),
                SizedBox(width: 10),
                Text(
                  'Bump listing',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ]);
      }

      items.addAll(const [
        PopupMenuDivider(),
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
      ]);
      return items;
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isNew
              ? const Color(0xFFF7DE77).withValues(alpha: 0.38)
              : Colors.white.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
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
                        color: Colors.black.withValues(alpha: 0.62),
                      ),
                    ),
                    if (post.isMarketplace)
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: _CommunityMetaChip(
                          icon: _communityMarketStatusIcon(post.normalizedMarketStatus),
                          label: post.normalizedMarketStatus,
                          color: _communityMarketStatusColor(post.normalizedMarketStatus),
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
                  padding: const EdgeInsets.all(16),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
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
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      isDiscussion ? 'Discussion' : post.postType,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    if (post.isMarketplace)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.18),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          post.normalizedMarketStatus,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    if (isNew) const _CommunityNewBadge(compact: true),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  post.compactMarketplaceSummary ?? _formatCommunityRelativeTime(post.createdAt),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
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
                            onSelected: handleMenuAction,
                            itemBuilder: (_) => buildMenuItems(),
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
                    if (post.isSwap && post.wantedTradeFor.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Wanted in trade',
                              style: TextStyle(
                                color: Color(0xFFF7DE77),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              post.wantedTradeFor.trim(),
                              style: const TextStyle(
                                color: Color(0xFFD8E3FB),
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _CommunitySecondaryChip(
                          icon: Icons.person_outline_rounded,
                          label: post.authorName,
                          onTap: onAuthorTap,
                        ),
                        _CommunitySecondaryChip(
                          icon: Icons.schedule_rounded,
                          label: _formatCommunityDate(post.createdAt).split('  ').first,
                        ),
                        if (post.isMarketplace)
                          _CommunitySecondaryChip(
                            icon: _communityMarketStatusIcon(post.normalizedMarketStatus),
                            label: post.normalizedMarketStatus,
                          ),
                        if (post.isForSale)
                          _CommunitySecondaryChip(
                            icon: Icons.sell_outlined,
                            label: post.hasPrice ? post.formattedPrice : 'Price not set',
                          ),
                        if (post.cardCondition.trim().isNotEmpty)
                          _CommunitySecondaryChip(
                            icon: Icons.verified_outlined,
                            label: post.cardCondition.trim(),
                          ),
                        if (post.deliveryMethod.trim().isNotEmpty)
                          _CommunitySecondaryChip(
                            icon: post.deliveryMethod == 'Meetup'
                                ? Icons.handshake_outlined
                                : Icons.local_shipping_outlined,
                            label: post.deliveryMethod.trim(),
                          ),
                        if (post.locationText.trim().isNotEmpty)
                          _CommunitySecondaryChip(
                            icon: Icons.place_outlined,
                            label: post.locationText.trim(),
                          ),
                        if (post.contact.trim().isNotEmpty || !isDiscussion)
                          _CommunitySecondaryChip(
                            icon: Icons.alternate_email_rounded,
                            label: post.contact.isEmpty ? 'No contact added' : post.contact,
                          ),
                      ],
                    ),
                    if (canManageListing) ...[
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () => onSetMarketStatus?.call(
                              post.normalizedMarketStatus == 'Pending' ? 'Available' : 'Pending',
                            ),
                            icon: Icon(
                              post.normalizedMarketStatus == 'Pending'
                                  ? Icons.storefront_outlined
                                  : Icons.schedule_outlined,
                            ),
                            label: Text(
                              post.normalizedMarketStatus == 'Pending'
                                  ? 'Mark available'
                                  : 'Mark pending',
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () => onSetMarketStatus?.call(
                              post.isForSale ? 'Sold' : 'Traded',
                            ),
                            icon: Icon(
                              post.isForSale
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.swap_horiz_rounded,
                            ),
                            label: Text(post.isForSale ? 'Mark sold' : 'Mark traded'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: onBump,
                            icon: const Icon(Icons.north_rounded),
                            label: const Text('Bump'),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onOpen,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
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
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
              style: TextStyle(
                color: onTap == null ? Colors.white70 : const Color(0xFFF7DE77),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return child;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: child,
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
                          color: Colors.black.withValues(alpha: 0.60),
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
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _wantedTradeForController = TextEditingController();

  String _postType = 'Swap';
  String _marketStatus = 'Available';
  String _askingCurrency = CurrencySettings.selectedCode;
  String _cardCondition = 'Near Mint';
  String _deliveryMethod = 'Post';
  bool _saving = false;
  bool _processingImages = false;
  List<String> _imageBase64List = <String>[];

  bool get _isEditing => widget.existingPost != null;
  bool get _isDiscussionPost => _postType == 'Thread';
  bool get _isMarketplacePost => !_isDiscussionPost;
  bool get _isForSale => _postType == 'For Sale';
  bool get _isSwap => _postType == 'Swap';

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
      _priceController.text = existingPost.hasPrice ? existingPost.askingPrice!.toStringAsFixed(2) : '';
      _locationController.text = existingPost.locationText;
      _wantedTradeForController.text = existingPost.wantedTradeFor;
      _marketStatus = existingPost.isMarketplace ? existingPost.normalizedMarketStatus : 'Available';
      _askingCurrency = existingPost.askingCurrencyCode;
      _cardCondition = existingPost.cardCondition.trim().isEmpty ? 'Near Mint' : existingPost.cardCondition.trim();
      _deliveryMethod = existingPost.deliveryMethod.trim().isEmpty ? 'Post' : existingPost.deliveryMethod.trim();
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
    _priceController.dispose();
    _locationController.dispose();
    _wantedTradeForController.dispose();
    super.dispose();
  }

  OutlineInputBorder get _fieldBorder => const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        borderSide: BorderSide(color: Color(0xFF3F5C96)),
      );

  InputDecoration _inputDecoration(String hintText, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFFAFC0E6)),
      filled: true,
      fillColor: const Color(0xFF16366E),
      border: _fieldBorder,
      enabledBorder: _fieldBorder,
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        borderSide: BorderSide(color: Color(0xFFF7DE77), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      suffixIcon: suffixIcon,
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  void _showComposerMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  double? _parsePrice() {
    final raw = _priceController.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    final parsed = double.tryParse(raw);
    if (parsed == null || !parsed.isFinite || parsed <= 0) {
      return null;
    }
    return parsed;
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
      final encoded = await CommunityImageCodec.pickAndEncodeSingle(ImageSource.camera);
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

  bool _imagesAreSafeToPublish() {
    const maxEncodedPayloadCharacters = 860 * 1024;
    final totalCharacters = _imageBase64List.fold<int>(
      0,
      (total, image) => total + image.length,
    );

    if (totalCharacters <= maxEncodedPayloadCharacters) {
      return true;
    }

    _showComposerMessage(
      'These photos are too large to publish together. Remove one or two photos, or crop them tighter.',
    );
    return false;
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final contact = _contactController.text.trim();

    if (title.isEmpty || description.isEmpty) {
      _showComposerMessage('Add a title and description');
      return;
    }

    final askingPrice = _parsePrice();
    if (_isForSale && askingPrice == null) {
      _showComposerMessage('Add a valid asking price for sale listings');
      return;
    }

    if (!_imagesAreSafeToPublish()) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (_isEditing) {
        final existingPost = widget.existingPost!;
        final updatedPost = CommunityPost(
          id: existingPost.id,
          authorId: existingPost.authorId,
          authorName: existingPost.authorName,
          postType: _postType,
          title: title,
          description: description,
          contact: contact,
          createdAtMs: existingPost.createdAtMs,
          updatedAtMs: now,
          marketStatus: _isMarketplacePost ? _marketStatus : 'Available',
          askingPrice: _isForSale ? askingPrice : null,
          askingCurrency: _isMarketplacePost ? _askingCurrency : CurrencySettings.selectedCode,
          cardCondition: _isMarketplacePost ? _cardCondition : '',
          deliveryMethod: _isMarketplacePost ? _deliveryMethod : '',
          locationText: _isMarketplacePost ? _locationController.text.trim() : '',
          wantedTradeFor: _isSwap ? _wantedTradeForController.text.trim() : '',
          lastBumpedAtMs: existingPost.lastBumpedAtMs,
          imageBase64List: _imageBase64List,
          hiddenReplyIds: existingPost.hiddenReplyIds,
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
          contact: contact,
          createdAtMs: now,
          updatedAtMs: now,
          marketStatus: _isMarketplacePost ? _marketStatus : 'Available',
          askingPrice: _isForSale ? askingPrice : null,
          askingCurrency: _isMarketplacePost ? _askingCurrency : CurrencySettings.selectedCode,
          cardCondition: _isMarketplacePost ? _cardCondition : '',
          deliveryMethod: _isMarketplacePost ? _deliveryMethod : '',
          locationText: _isMarketplacePost ? _locationController.text.trim() : '',
          wantedTradeFor: _isSwap ? _wantedTradeForController.text.trim() : '',
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
            : 'Edit marketplace listing'
        : _isDiscussionPost
            ? 'Start discussion thread'
            : 'Create marketplace listing';
    final sheetSubtitle = _isDiscussionPost
        ? 'Start a conversation where collectors can talk cards, share tips, and make friends.'
        : 'Create a more professional marketplace post with status, price, condition, delivery, and location details.';
    final titleHint = _isDiscussionPost
        ? 'Favourite modern sets right now?'
        : _isForSale
            ? 'Selling Charizard ex promo'
            : 'Looking to swap Charizard ex';
    final descriptionHint = _isDiscussionPost
        ? 'Kick off the discussion and let other collectors jump in.'
        : _isForSale
            ? 'List exactly what is included, the card condition, and any postage or meetup details.'
            : 'Write what you are offering, what you want back, and any condition notes.';
    final photoHelp = _isDiscussionPost
        ? 'Add up to 4 photos if you want, or leave this empty for a text-only discussion thread.'
        : 'Add up to 4 clear photos of the card, binder page, or sealed product. Camera adds one at a time and gallery can add several.';
    final submitLabel = _isEditing
        ? 'Save changes'
        : _isDiscussionPost
            ? 'Start thread'
            : 'Publish listing';

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
                      _sectionCard(
                        title: 'Post setup',
                        children: [
                          _fieldLabel('Post type'),
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
                            decoration: _inputDecoration('Choose a post type'),
                            items: const [
                              DropdownMenuItem(value: 'Swap', child: Text('Swap')),
                              DropdownMenuItem(value: 'For Sale', child: Text('For Sale')),
                              DropdownMenuItem(value: 'Thread', child: Text('Discussion Thread')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _postType = value;
                                  if (_postType == 'Thread') {
                                    _marketStatus = 'Available';
                                  }
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 14),
                          _fieldLabel('Title'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _titleController,
                            style: const TextStyle(color: Colors.white, fontSize: 17),
                            decoration: _inputDecoration(titleHint),
                          ),
                          const SizedBox(height: 14),
                          _fieldLabel('Description'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _descriptionController,
                            maxLines: 5,
                            style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.35),
                            decoration: _inputDecoration(descriptionHint),
                          ),
                          const SizedBox(height: 14),
                          _fieldLabel(_isDiscussionPost ? 'Contact info (optional)' : 'Contact info'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _contactController,
                            style: const TextStyle(color: Colors.white, fontSize: 17),
                            decoration: _inputDecoration(
                              _isDiscussionPost
                                  ? 'Instagram, Discord, or leave blank if you only want replies.'
                                  : 'Instagram, Discord, phone, or another contact method.',
                            ),
                          ),
                        ],
                      ),
                      if (_isMarketplacePost) ...[
                        const SizedBox(height: 14),
                        _sectionCard(
                          title: 'Marketplace details',
                          children: [
                            _fieldLabel('Listing status'),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _marketStatus,
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                              iconEnabledColor: const Color(0xFFE4ECFF),
                              dropdownColor: const Color(0xFF143163),
                              decoration: _inputDecoration('Status'),
                              items: _kCommunityMarketStatuses
                                  .where((status) => status != 'All')
                                  .map((status) => DropdownMenuItem(value: status, child: Text(status)))
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _marketStatus = value;
                                  });
                                }
                              },
                            ),
                            if (_isForSale) ...[
                              const SizedBox(height: 14),
                              _fieldLabel('Asking price'),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: _priceController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      style: const TextStyle(color: Colors.white, fontSize: 17),
                                      decoration: _inputDecoration('25.00'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: _askingCurrency,
                                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                                      iconEnabledColor: const Color(0xFFE4ECFF),
                                      dropdownColor: const Color(0xFF143163),
                                      decoration: _inputDecoration('Currency'),
                                      items: CurrencySettings.supportedCurrencies.values
                                          .map(
                                            (currency) => DropdownMenuItem(
                                              value: currency.code,
                                              child: Text(currency.code),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() {
                                            _askingCurrency = value;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 14),
                            _fieldLabel('Card condition'),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _cardCondition,
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                              iconEnabledColor: const Color(0xFFE4ECFF),
                              dropdownColor: const Color(0xFF143163),
                              decoration: _inputDecoration('Condition'),
                              items: _kCommunityCardConditions
                                  .map((condition) => DropdownMenuItem(value: condition, child: Text(condition)))
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _cardCondition = value;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 14),
                            _fieldLabel('Delivery method'),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _deliveryMethod,
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                              iconEnabledColor: const Color(0xFFE4ECFF),
                              dropdownColor: const Color(0xFF143163),
                              decoration: _inputDecoration('Delivery method'),
                              items: _kCommunityDeliveryMethods
                                  .map((delivery) => DropdownMenuItem(value: delivery, child: Text(delivery)))
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _deliveryMethod = value;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 14),
                            _fieldLabel('Location'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _locationController,
                              style: const TextStyle(color: Colors.white, fontSize: 17),
                              decoration: _inputDecoration('Manchester, collection point, or general area'),
                            ),
                            if (_isSwap) ...[
                              const SizedBox(height: 14),
                              _fieldLabel('Wanted in trade'),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _wantedTradeForController,
                                maxLines: 3,
                                style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.35),
                                decoration: _inputDecoration('151 hits, sealed product, vintage holos, or specific cards'),
                              ),
                            ],
                          ],
                        ),
                      ],
                      const SizedBox(height: 14),
                      _sectionCard(
                        title: 'Photos',
                        children: [
                          Row(
                            children: [
                              Text(
                                '${_imageBase64List.length}/${CommunityImageCodec.maxImagesPerPost}',
                                style: const TextStyle(
                                  color: Color(0xFFF7DE77),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _processingImages ? 'Processing...' : 'Ready',
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
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
                                          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
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
                                              color: Colors.black.withValues(alpha: 0.62),
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
                                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                              ),
                              child: Text(
                                photoHelp,
                                style: const TextStyle(
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
                                    side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
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
                                : 'Photos are compressed and stored directly in Firestore, so your marketplace listing works without Firebase Storage.',
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12),
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
              .collection('users')
              .doc(currentUid)
              .collection('community_private_conversations')
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

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? widget.currentProfile.uid;

  CollectionReference<Map<String, dynamic>> get _messagesRef => FirebaseFirestore.instance
      .collection('users')
      .doc(_currentUid)
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
      await _syncCommunityPrivateConversation(
        conversationId: widget.conversationId,
        currentUid: currentUser.uid,
        currentUserName: widget.currentProfile.displayName,
        otherUserId: widget.otherUserId,
        otherUserName: widget.otherUserName,
        relatedPostId: widget.relatedPostId,
        relatedPostTitle: widget.relatedPostTitle,
        createdAtMs: now,
        updatedAtMs: now,
      );
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _sending) return;

    setState(() {
      _sending = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not signed in');
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final doc = _messagesRef.doc();
      final privateMessage = CommunityPrivateMessage(
        id: doc.id,
        authorId: currentUser.uid,
        authorName: widget.currentProfile.displayName,
        message: message,
        createdAtMs: now,
      );
      await _syncCommunityPrivateMessage(
        conversationId: widget.conversationId,
        currentUid: currentUser.uid,
        currentUserName: widget.currentProfile.displayName,
        otherUserId: widget.otherUserId,
        otherUserName: widget.otherUserName,
        relatedPostId: widget.relatedPostId,
        relatedPostTitle: widget.relatedPostTitle,
        message: privateMessage,
      );
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
                              color: const Color(0xFFF7DE77).withValues(alpha: 0.14),
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
                              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
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
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => FriendTradeMatchesPage(
                                    currentProfile: currentProfile,
                                    friendUid: friend.uid,
                                    friendName: friend.username,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.handshake_outlined),
                            label: const Text('Trade matches'),
                          ),
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

class FriendTradeMatchEntry {
  const FriendTradeMatchEntry({
    required this.entry,
    required this.ownerCopies,
    required this.ownerIsFriend,
  });

  final WishlistEntry entry;
  final int ownerCopies;
  final bool ownerIsFriend;

  bool get hasLikelySpare => ownerCopies > 1;

  String get copiesLabel => '${ownerIsFriend ? 'They own' : 'You own'} x$ownerCopies';
}

class FriendTradeMatchSnapshot {
  const FriendTradeMatchSnapshot({
    required this.friendHasForYou,
    required this.youHaveForFriend,
    required this.yourWishlistCount,
    required this.friendWishlistCount,
    required this.yourOwnedCount,
    required this.friendOwnedCount,
  });

  final List<FriendTradeMatchEntry> friendHasForYou;
  final List<FriendTradeMatchEntry> youHaveForFriend;
  final int yourWishlistCount;
  final int friendWishlistCount;
  final int yourOwnedCount;
  final int friendOwnedCount;

  int get totalMatches => friendHasForYou.length + youHaveForFriend.length;
}

class FriendTradeMatchService {
  static Future<FriendTradeMatchSnapshot> loadMatches({
    required AppUserProfile currentProfile,
    required String friendUid,
  }) async {
    final results = await Future.wait<dynamic>([
      WishlistService.fetchWishlist(currentProfile.uid),
      WishlistService.fetchWishlist(friendUid),
      PokedexSyncService.fetchAllOwnedCards(currentProfile.uid),
      PokedexSyncService.fetchAllOwnedCards(friendUid),
    ]);

    final yourWishlist = results[0] as List<WishlistEntry>;
    final friendWishlist = results[1] as List<WishlistEntry>;
    final yourOwnedCards = results[2] as Map<String, CardOwnership>;
    final friendOwnedCards = results[3] as Map<String, CardOwnership>;

    final friendHasForYou = yourWishlist
        .where((entry) => (friendOwnedCards[entry.cardId]?.effectiveCopies ?? 0) > 0)
        .map(
          (entry) => FriendTradeMatchEntry(
            entry: entry,
            ownerCopies: friendOwnedCards[entry.cardId]?.effectiveCopies ?? 0,
            ownerIsFriend: true,
          ),
        )
        .toList()
      ..sort(_sortFriendTradeMatchEntries);

    final youHaveForFriend = friendWishlist
        .where((entry) => (yourOwnedCards[entry.cardId]?.effectiveCopies ?? 0) > 0)
        .map(
          (entry) => FriendTradeMatchEntry(
            entry: entry,
            ownerCopies: yourOwnedCards[entry.cardId]?.effectiveCopies ?? 0,
            ownerIsFriend: false,
          ),
        )
        .toList()
      ..sort(_sortFriendTradeMatchEntries);

    return FriendTradeMatchSnapshot(
      friendHasForYou: friendHasForYou,
      youHaveForFriend: youHaveForFriend,
      yourWishlistCount: yourWishlist.length,
      friendWishlistCount: friendWishlist.length,
      yourOwnedCount: yourOwnedCards.length,
      friendOwnedCount: friendOwnedCards.length,
    );
  }

  static int _sortFriendTradeMatchEntries(FriendTradeMatchEntry a, FriendTradeMatchEntry b) {
    final aPrice = a.entry.rawPrice ?? -1;
    final bPrice = b.entry.rawPrice ?? -1;
    if (aPrice != bPrice) {
      return bPrice.compareTo(aPrice);
    }
    return a.entry.name.toLowerCase().compareTo(b.entry.name.toLowerCase());
  }
}

class FriendTradeMatchesPage extends StatefulWidget {
  const FriendTradeMatchesPage({
    super.key,
    required this.currentProfile,
    required this.friendUid,
    required this.friendName,
  });

  final AppUserProfile currentProfile;
  final String friendUid;
  final String friendName;

  @override
  State<FriendTradeMatchesPage> createState() => _FriendTradeMatchesPageState();
}

class _FriendTradeMatchesPageState extends State<FriendTradeMatchesPage> {
  late Future<FriendTradeMatchSnapshot> _matchesFuture;
  bool _showLikelySpareOnly = false;

  @override
  void initState() {
    super.initState();
    _matchesFuture = _loadMatches();
  }

  Future<FriendTradeMatchSnapshot> _loadMatches() {
    return FriendTradeMatchService.loadMatches(
      currentProfile: widget.currentProfile,
      friendUid: widget.friendUid,
    );
  }

  Future<void> _refreshMatches() async {
    setState(() {
      _matchesFuture = _loadMatches();
    });
    await _matchesFuture;
  }

  Future<void> _openCard(WishlistEntry entry) async {
    try {
      final fullCard = await PokemonTcgService.fetchCardById(entry.cardId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CardDetailsPage(card: fullCard),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CardDetailsPage(card: entry.toSummaryCard()),
        ),
      );
    }
  }

  List<FriendTradeMatchEntry> _applyFilters(List<FriendTradeMatchEntry> items) {
    if (!_showLikelySpareOnly) return items;
    return items.where((item) => item.hasLikelySpare).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        title: Text('Trade matches with ${widget.friendName}'),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: FutureBuilder<FriendTradeMatchSnapshot>(
          future: _matchesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Could not load trade matches right now.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 15),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _refreshMatches,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final matches = snapshot.data ??
                const FriendTradeMatchSnapshot(
                  friendHasForYou: <FriendTradeMatchEntry>[],
                  youHaveForFriend: <FriendTradeMatchEntry>[],
                  yourWishlistCount: 0,
                  friendWishlistCount: 0,
                  yourOwnedCount: 0,
                  friendOwnedCount: 0,
                );
            final friendHasForYou = _applyFilters(matches.friendHasForYou);
            final youHaveForFriend = _applyFilters(matches.youHaveForFriend);
            final hasAnyVisibleMatches = friendHasForYou.isNotEmpty || youHaveForFriend.isNotEmpty;

            return RefreshIndicator(
              onRefresh: _refreshMatches,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                children: [
                  Card(
                    color: const Color(0xFF102754),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1D3D7A),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.handshake_outlined, color: Color(0xFFF7DE77)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Smart friend matching',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Based on wishlists and synced Pokédex cards for you and ${widget.friendName}.',
                                      style: const TextStyle(
                                        color: Color(0xFFC8D4F0),
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _CommunityMetaChip(
                                icon: Icons.favorite_outline_rounded,
                                label: 'Your wishlist ${matches.yourWishlistCount}',
                                color: const Color(0xFF355189),
                              ),
                              _CommunityMetaChip(
                                icon: Icons.favorite_outline_rounded,
                                label: '${widget.friendName} wishlist ${matches.friendWishlistCount}',
                                color: const Color(0xFF355189),
                              ),
                              _CommunityMetaChip(
                                icon: Icons.collections_bookmark_outlined,
                                label: 'Your cards ${matches.yourOwnedCount}',
                                color: const Color(0xFF2C7A5B),
                              ),
                              _CommunityMetaChip(
                                icon: Icons.collections_bookmark_outlined,
                                label: '${widget.friendName} cards ${matches.friendOwnedCount}',
                                color: const Color(0xFF2C7A5B),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          FilterChip(
                            selected: _showLikelySpareOnly,
                            label: const Text('Likely spare copies only'),
                            onSelected: (value) {
                              setState(() {
                                _showLikelySpareOnly = value;
                              });
                            },
                            avatar: const Icon(Icons.filter_alt_outlined, size: 18),
                            selectedColor: const Color(0xFFF7DE77),
                            checkmarkColor: Colors.black,
                            labelStyle: TextStyle(
                              color: _showLikelySpareOnly ? Colors.black : Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                            backgroundColor: const Color(0xFF16366E),
                            side: const BorderSide(color: Color(0xFF3F5C96)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FriendTradeMatchSection(
                    title: 'They have cards from your wishlist',
                    subtitle: 'Cards you want that ${widget.friendName} already owns.',
                    emptyMessage: _showLikelySpareOnly
                        ? '${widget.friendName} does not currently have any visible likely-spare matches for your wishlist.'
                        : '${widget.friendName} does not currently own any cards from your wishlist.',
                    items: friendHasForYou,
                    onTapEntry: _openCard,
                  ),
                  const SizedBox(height: 16),
                  _FriendTradeMatchSection(
                    title: 'You have cards from their wishlist',
                    subtitle: 'Cards ${widget.friendName} wants that already exist in your synced Pokédex.',
                    emptyMessage: _showLikelySpareOnly
                        ? 'You do not currently have any visible likely-spare matches for ${widget.friendName}. '
                            'Try turning the spare-only filter off.'
                        : "You do not currently own any cards from ${widget.friendName}'s wishlist.",
                    items: youHaveForFriend,
                    onTapEntry: _openCard,
                  ),
                  if (!hasAnyVisibleMatches) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: const Color(0xFF102754),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Trade matches will improve as both of you add cards to your wishlist and keep your Pokédex synced.',
                          style: TextStyle(
                            color: Color(0xFFD8E3FB),
                            height: 1.45,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FriendTradeMatchSection extends StatelessWidget {
  const _FriendTradeMatchSection({
    required this.title,
    required this.subtitle,
    required this.emptyMessage,
    required this.items,
    required this.onTapEntry,
  });

  final String title;
  final String subtitle;
  final String emptyMessage;
  final List<FriendTradeMatchEntry> items;
  final Future<void> Function(WishlistEntry entry) onTapEntry;

  @override
  Widget build(BuildContext context) {
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
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xFFC8D4F0),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            if (items.isEmpty)
              Text(
                emptyMessage,
                style: const TextStyle(color: Colors.white70, height: 1.45),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _FriendTradeMatchCard(
                    item: item,
                    onTap: () {
                      onTapEntry(item.entry);
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _FriendTradeMatchCard extends StatelessWidget {
  const _FriendTradeMatchCard({
    required this.item,
    required this.onTap,
  });

  final FriendTradeMatchEntry item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final entry = item.entry;
    return Material(
      color: const Color(0xFF16366E),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 64,
                  height: 88,
                  child: entry.imageUrl == null || entry.imageUrl!.isEmpty
                      ? Container(
                          color: const Color(0xFF0E2A5E),
                          child: const Icon(Icons.image_not_supported, color: Colors.white),
                        )
                      : Image.network(entry.imageUrl!, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      entry.setName,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Card #${entry.number}',
                      style: const TextStyle(color: Colors.white60),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _CommunityMetaChip(
                          icon: item.ownerIsFriend ? Icons.person_outline : Icons.inventory_2_outlined,
                          label: item.copiesLabel,
                          color: item.hasLikelySpare ? const Color(0xFF2C7A5B) : const Color(0xFF355189),
                        ),
                        if (item.hasLikelySpare)
                          const _CommunityMetaChip(
                            icon: Icons.auto_awesome_outlined,
                            label: 'Likely spare',
                            color: Color(0xFF6B4EFF),
                          ),
                      ],
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
              const Padding(
                padding: EdgeInsets.only(top: 26),
                child: Icon(Icons.chevron_right_rounded, color: Colors.white54),
              ),
            ],
          ),
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
                          child: _ResolvedSetLogo(
                            setId: set.id,
                            setName: set.name,
                            fallbackLogoUrl: set.logoUrl,
                            height: 64,
                            fit: BoxFit.contain,
                            textStyle: const TextStyle(
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
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Center(
                      child: _ResolvedSetLogo(
                        setId: set.id,
                        setName: set.name,
                        fallbackLogoUrl: set.logoUrl,
                        height: 64,
                        fit: BoxFit.contain,
                        textStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
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
  String _lastSearchKey = '';

  @override
  void initState() {
    super.initState();
    _futureResults = Future.value(const CardSearchResult());
  }

  Future<CardSearchResult> _buildSearchFuture(String query) {
    if (query.isEmpty) {
      return Future.value(const CardSearchResult());
    }

    if (_searchMode == _CardSearchMode.cards) {
      return PokemonTcgService.searchCardsOnlyResult(query);
    }

    return PokemonTcgService.searchSetsOnlyResult(query);
  }

  void _search() {
    final query = _controller.text.trim();
    final searchKey = '${_searchMode.name}::$query';
    if (searchKey == _lastSearchKey) return;
    _lastSearchKey = searchKey;

    setState(() {
      _futureResults = _buildSearchFuture(query);
    });

    if (query.isNotEmpty) {
      scrollToTop(animated: false);
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    if (value.trim().isEmpty) {
      _search();
      return;
    }
    _searchDebounce = Timer(_kCardSearchDebounce, _search);
  }

  void _setSearchMode(_CardSearchMode mode) {
    if (_searchMode == mode) return;
    _searchDebounce?.cancel();
    setState(() {
      _searchMode = mode;
      _controller.clear();
      _lastSearchKey = '';
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
                  child: _CardSearchResultCard(card: card),
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

enum _QuickScanVariant { normal, reverseHolo, holo }

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
  bool _scanSaveBusy = false;
  _QuickScanVariant _quickScanVariant = _QuickScanVariant.normal;
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

  CardOwnership get _selectedScanOwnership {
    switch (_quickScanVariant) {
      case _QuickScanVariant.reverseHolo:
        return const CardOwnership(reverseHolo: true, copies: 1);
      case _QuickScanVariant.holo:
        return const CardOwnership(holo: true, copies: 1);
      case _QuickScanVariant.normal:
        return const CardOwnership(normal: true, copies: 1);
    }
  }

  String get _selectedScanVariantLabel {
    switch (_quickScanVariant) {
      case _QuickScanVariant.reverseHolo:
        return 'Reverse Holo';
      case _QuickScanVariant.holo:
        return 'Holo';
      case _QuickScanVariant.normal:
        return 'Normal';
    }
  }

  Future<void> _saveConfirmedMatchToPokedex(TcgCard card) async {
    if (_scanSaveBusy) return;

    setState(() {
      _scanSaveBusy = true;
    });

    try {
      final ownershipByCardId = await LocalPokedexStore.loadSetOwnershipMap(card.setId);
      final existing = ownershipByCardId[card.id] ?? const CardOwnership();
      final selected = _selectedScanOwnership;

      ownershipByCardId[card.id] = existing.copyWith(
        normal: existing.normal || selected.normal,
        reverseHolo: existing.reverseHolo || selected.reverseHolo,
        holo: existing.holo || selected.holo,
        copies: existing.effectiveCopies + 1,
      );

      await LocalPokedexStore.saveSetOwnershipMap(card.setId, ownershipByCardId);
      await PokedexSyncService.syncCurrentSetForCurrentUser(card.setId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved to Set Pokédex as $_selectedScanVariantLabel '
            '(x${ownershipByCardId[card.id]!.effectiveCopies} total)',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save this card right now')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _scanSaveBusy = false;
        });
      }
    }
  }

  Future<void> _toggleScanResultWishlist(TcgCard card, bool isInWishlist) async {
    final ownerUid = FirebaseAuth.instance.currentUser?.uid;
    if (ownerUid == null || _scanSaveBusy) return;

    setState(() {
      _scanSaveBusy = true;
    });

    try {
      if (isInWishlist) {
        await WishlistService.removeCard(ownerUid: ownerUid, cardId: card.id);
      } else {
        await WishlistService.addCard(ownerUid: ownerUid, card: card);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isInWishlist ? 'Removed from wishlist' : 'Added to wishlist',
          ),
        ),
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
          _scanSaveBusy = false;
        });
      }
    }
  }

  Future<CardScanAnalysis> _buildVisionAnalysis(String imagePath) async {
    final vision = await _visionClient.scanImage(imagePath);

    final orderedResolved = <VisionResolvedCard>[];
    final seenIds = <String>{};

    void addResolved(VisionResolvedCard? card) {
      if (card == null) return;
      final id = card.id.trim();
      if (id.isEmpty) return;
      if (seenIds.add(id)) {
        orderedResolved.add(card);
      }
    }

    addResolved(vision.bestMatch);
    for (final card in vision.possibleMatches.take(7)) {
      addResolved(card);
    }

    Future<TcgCard> resolveCard(VisionResolvedCard card) async {
      try {
        return await PokemonTcgService.fetchCardById(card.id);
      } catch (_) {
        return _fallbackVisionCard(card);
      }
    }

    List<TcgCard> matches = <TcgCard>[];
    if (vision.exactConfirmed && vision.bestMatch != null) {
      matches = <TcgCard>[await resolveCard(vision.bestMatch!)];
    } else if (orderedResolved.isNotEmpty) {
      matches = await Future.wait<TcgCard>(
        orderedResolved.take(4).map(resolveCard),
      );
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

  Future<String?> _prepareScannerAnalysisImage(String imagePath) async {
    try {
      final sourceFile = File(imagePath);
      final sourceBytes = await sourceFile.readAsBytes();
      final decoded = img.decodeImage(sourceBytes);
      if (decoded == null) return null;

      var oriented = img.bakeOrientation(decoded);
      final longestSide = math.max(oriented.width, oriented.height);
      final shouldResize = longestSide > 1600;
      final shouldCompress = sourceBytes.lengthInBytes > 700 * 1024;

      if (!shouldResize && !shouldCompress) {
        return null;
      }

      if (shouldResize) {
        if (oriented.width >= oriented.height) {
          oriented = img.copyResize(oriented, width: 1600);
        } else {
          oriented = img.copyResize(oriented, height: 1600);
        }
      }

      final outputBytes = img.encodeJpg(oriented, quality: 86);
      if (!shouldResize && outputBytes.length >= sourceBytes.lengthInBytes) {
        return null;
      }

      final tempDir = await getTemporaryDirectory();
      final outputPath =
          '${tempDir.path}/scan_analysis_${DateTime.now().microsecondsSinceEpoch}.jpg';
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(outputBytes, flush: true);
      return outputPath;
    } catch (_) {
      return null;
    }
  }

  Future<CardScanAnalysis> _buildPreparedVisionAnalysis(String imagePath) async {
    final preparedPath = await _prepareScannerAnalysisImage(imagePath);
    final analysisPath = preparedPath ?? imagePath;

    try {
      return await _buildVisionAnalysis(analysisPath);
    } finally {
      if (preparedPath != null) {
        try {
          final file = File(preparedPath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}
      }
    }
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
      _quickScanVariant = _QuickScanVariant.normal;
      _scanSaveBusy = false;
      _scanning = true;
    });

    try {
      final analysis = await _buildPreparedVisionAnalysis(picked.path);
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
      _confirmedMatchId = null;
      _scanSaveBusy = false;
      _quickScanVariant = _QuickScanVariant.normal;
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
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
                        Colors.white.withValues(alpha: 0.09),
                        Colors.white.withValues(alpha: 0.025),
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
                        color: Colors.white.withValues(alpha: 0.03),
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
                            color: const Color(0xFFDA3C3C).withValues(alpha: 0.85),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            color: Colors.white.withValues(alpha: 0.92),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 62,
                  height: 5,
                  color: const Color(0xFF1E1E1E).withValues(alpha: 0.9),
                ),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAEAEA),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF1E1E1E).withValues(alpha: 0.9),
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
                        color: Colors.white.withValues(alpha: 0.08),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
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
                    color: const Color(0xFFF7DE77).withValues(alpha: 0.22),
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
                          color: Colors.white.withValues(alpha: 0.16),
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
                        color: Colors.black.withValues(alpha: 0.52),
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
                        color: Colors.black.withValues(alpha: 0.38),
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
                      color: Colors.black.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
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
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
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
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
        border: Border.all(color: const Color(0xFFF7DE77).withValues(alpha: 0.30)),
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

  Widget _buildQuickSaveFlowCard(TcgCard card) {
    Widget buildVariantChip({
      required _QuickScanVariant value,
      required String label,
    }) {
      final selected = _quickScanVariant == value;
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: _scanSaveBusy
            ? null
            : (_) {
                setState(() {
                  _quickScanVariant = value;
                });
              },
        backgroundColor: const Color(0xFF16366E),
        selectedColor: const Color(0xFFF7DE77),
        side: BorderSide(
          color: selected
              ? const Color(0xFFF7DE77)
              : Colors.white.withValues(alpha: 0.10),
        ),
        labelStyle: TextStyle(
          color: selected ? Colors.black : Colors.white,
          fontWeight: FontWeight.w700,
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
        child: StreamBuilder<bool>(
          stream: WishlistService.cardInWishlistStream(
            FirebaseAuth.instance.currentUser?.uid ?? '',
            card.id,
          ),
          builder: (context, snapshot) {
            final isInWishlist = snapshot.data ?? false;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quick save this scan',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose the finish, then save it straight to your collection or wishlist.',
                  style: const TextStyle(
                    color: Color(0xFFD8E3FB),
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Card finish',
                  style: TextStyle(
                    color: Color(0xFFF7DE77),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    buildVariantChip(
                      value: _QuickScanVariant.normal,
                      label: 'Normal',
                    ),
                    buildVariantChip(
                      value: _QuickScanVariant.reverseHolo,
                      label: 'Reverse Holo',
                    ),
                    buildVariantChip(
                      value: _QuickScanVariant.holo,
                      label: 'Holo',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _scanSaveBusy
                            ? null
                            : () => _saveConfirmedMatchToPokedex(card),
                        icon: _scanSaveBusy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.collections_bookmark_outlined),
                        label: const Text('Add to Set Pokédex'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFF7DE77),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _scanSaveBusy ? null : () => _addCardToCustomBinderFlow(context, card),
                    icon: const Icon(Icons.photo_album_outlined),
                    label: const Text('Add to Custom Binder'),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _scanSaveBusy
                            ? null
                            : () => _toggleScanResultWishlist(card, isInWishlist),
                        icon: Icon(
                          isInWishlist
                              ? Icons.favorite_rounded
                              : Icons.favorite_outline_rounded,
                        ),
                        label: Text(
                          isInWishlist
                              ? 'Remove from Wishlist'
                              : 'Add to Wishlist',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: const Color(0xFF16366E),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _scanSaveBusy ? null : _resetScanner,
                        icon: const Icon(Icons.replay_rounded),
                        label: const Text('Scan another'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: const Color(0xFF16366E),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _scanSaveBusy
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CardDetailsPage(card: card),
                              ),
                            );
                          },
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Open full card details'),
                  ),
                ),
              ],
            );
          },
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
        const SizedBox(height: 12),
        _buildQuickSaveFlowCard(primaryMatch),
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
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
                  Colors.white.withValues(alpha: 0.10),
                  Colors.white.withValues(alpha: 0.03),
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
                        color: Colors.white.withValues(alpha: 0.04),
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
                            color: const Color(0xFFDA3C3C).withValues(alpha: 0.85),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            color: Colors.white.withValues(alpha: 0.92),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 112,
                  height: 8,
                  color: const Color(0xFF1E1E1E).withValues(alpha: 0.9),
                ),
                Container(
                  width: 34,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAEAEA),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF1E1E1E).withValues(alpha: 0.9),
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
                        color: Colors.white.withValues(alpha: 0.08),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
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


class _CardSearchResultCard extends StatefulWidget {
  const _CardSearchResultCard({required this.card});

  final TcgCard card;

  @override
  State<_CardSearchResultCard> createState() => _CardSearchResultCardState();
}

class _CardSearchResultCardState extends State<_CardSearchResultCard> {
  bool _saving = false;

  Future<void> _quickAddToPokedex() async {
    if (_saving) return;

    setState(() {
      _saving = true;
    });

    try {
      final ownershipByCardId = await LocalPokedexStore.loadSetOwnershipMap(widget.card.setId);
      final existing = ownershipByCardId[widget.card.id] ?? const CardOwnership();

      ownershipByCardId[widget.card.id] = existing.copyWith(
        normal: true,
        copies: existing.effectiveCopies + 1,
      );

      await LocalPokedexStore.saveSetOwnershipMap(widget.card.setId, ownershipByCardId);
      await PokedexSyncService.syncCurrentSetForCurrentUser(widget.card.setId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added ${widget.card.name} to Set Pokédex '
            '(x${ownershipByCardId[widget.card.id]!.effectiveCopies} total)',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not add this card right now')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _openDetails() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CardDetailsPage(card: widget.card),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;

    return Card(
      color: const Color(0xFF102754),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          InkWell(
            onTap: _openDetails,
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
                      : _FastNetworkImage(
                          imageUrl: card.imageUrl!,
                          fit: BoxFit.cover,
                          cacheWidth: 220,
                          cacheHeight: 300,
                        ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 68, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                              ),
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
          Positioned(
            top: 12,
            right: 12,
            child: Tooltip(
              message: 'Quick add to Set Pokédex',
              child: Material(
                color: const Color(0xFFF7DE77),
                shape: const CircleBorder(),
                elevation: 1,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _saving ? null : _quickAddToPokedex,
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: Center(
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                              ),
                            )
                          : const Icon(
                              Icons.add_rounded,
                              color: Colors.black,
                              size: 26,
                            ),
                    ),
                  ),
                ),
              ),
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
          final cardsFuture = PokemonTcgService.fetchCardsBySet(set.id);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SearchSetDetailsPage(
                set: set,
                initialCardsFuture: cardsFuture,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: _ResolvedSetLogo(
                  setId: set.id,
                  setName: set.name,
                  fallbackLogoUrl: set.logoUrl,
                  height: 72,
                  fit: BoxFit.contain,
                  cacheWidth: 360,
                  cacheHeight: 144,
                  textStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
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
  const SearchSetDetailsPage({
    super.key,
    required this.set,
    this.initialCardsFuture,
  });

  final TcgSet set;
  final Future<List<TcgCard>>? initialCardsFuture;

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
    _cardsFuture = widget.initialCardsFuture ?? PokemonTcgService.fetchCardsBySet(widget.set.id);
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
      body: ListView(
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
                  Center(
                    child: _ResolvedSetLogo(
                      setId: widget.set.id,
                      setName: widget.set.name,
                      fallbackLogoUrl: widget.set.logoUrl,
                      height: 72,
                      fit: BoxFit.contain,
                      cacheWidth: 360,
                      cacheHeight: 144,
                      textStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
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
          if (!_loadedOwnership)
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
                        'Loading your saved card status...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            FutureBuilder<List<TcgCard>>(
              future: _cardsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Card(
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
                              'Loading set cards...',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Card(
                    color: const Color(0xFF5B1D28),
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
                final masterSetSlots = _buildMasterSetSlots(cards);

                if (cards.isEmpty) {
                  return Container(
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
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Showing ${masterSetSlots.length} master set slots from ${cards.length} printed cards.',
                        style: const TextStyle(
                          color: Color(0xFFD8E3FB),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: masterSetSlots.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.71,
                      ),
                      itemBuilder: (context, index) {
                        final slot = masterSetSlots[index];
                        final card = slot.card;
                        final ownership = _ownershipFor(card);

                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onLongPress: () async {
                            setState(() {
                              _ownershipByCardId[card.id] = slot.toggleOwnership(ownership);
                            });
                            await _saveOwnership();
                          },
                          onTap: () async {
                            final updatedOwnership = await Navigator.of(context).push<CardOwnership>(
                              MaterialPageRoute(
                                builder: (_) => SetCardDetailsPage(
                                  card: card,
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
                          child: _MasterSetSlotTile(
                            slot: slot,
                            ownership: ownership,
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          const SizedBox(height: 12),
          const Text(
            'Tap a card to open its details, or long-press a Normal, RH, or H slot to quickly toggle that exact master set slot.',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}


class MasterSetsPage extends StatefulWidget {
  const MasterSetsPage({super.key});

  @override
  State<MasterSetsPage> createState() => _MasterSetsPageState();
}

enum _MasterSetsViewMode {
  setPokedex,
  customBinders,
}

class _MasterSetsPageState extends State<MasterSetsPage> {
  late Future<List<TcgSet>> _futureSets;
  final Set<String> _trackedSetIds = <String>{};
  final Set<String> _nonEmptySetIds = <String>{};
  final Map<String, int> _savedCopyCountsBySetId = <String, int>{};
  bool _loadedCollectionState = false;
  bool _loadingCustomBinders = false;
  List<CustomBinder> _customBinders = <CustomBinder>[];
  final Map<String, int> _customBinderCounts = <String, int>{};
  _MasterSetsViewMode _viewMode = _MasterSetsViewMode.setPokedex;

  @override
  void initState() {
    super.initState();
    _futureSets = PokemonTcgService.fetchSets();
    _loadSetCollectionState();
    _loadCustomBinderState();
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

    try {
      await Future.wait<void>([
        _loadSetCollectionState(),
        _loadCustomBinderState(),
      ]).timeout(const Duration(seconds: 8));
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadedCollectionState = true;
          _loadingCustomBinders = false;
        });
      }
    }
  }

  Future<void> _loadSetCollectionState() async {
    final savedCopyCounts = await LocalPokedexStore.savedCopyCountsBySetId(
      cleanEmptySets: true,
    );
    final nonEmptySetIds = savedCopyCounts.entries
        .where((entry) => entry.value > 0)
        .map((entry) => entry.key)
        .toSet();

    _trackedSetIds
      ..clear()
      ..addAll(nonEmptySetIds);
    _nonEmptySetIds
      ..clear()
      ..addAll(nonEmptySetIds);
    _savedCopyCountsBySetId
      ..clear()
      ..addAll(savedCopyCounts);

    if (mounted) {
      setState(() {
        _loadedCollectionState = true;
      });
    }
  }

  Future<void> _loadCustomBinderState() async {
    if (mounted) {
      setState(() {
        _loadingCustomBinders = true;
      });
    }

    final binders = await LocalCustomBinderStore.loadBinders();
    final counts = <String, int>{};
    for (final binder in binders) {
      counts[binder.id] = await LocalCustomBinderStore.cardCount(binder.id);
    }

    if (!mounted) return;
    setState(() {
      _customBinders = binders;
      _customBinderCounts
        ..clear()
        ..addAll(counts);
      _loadingCustomBinders = false;
    });
  }

  bool _shouldShowSet(TcgSet set) {
    return (_savedCopyCountsBySetId[set.id] ?? 0) > 0;
  }

  Future<_CustomBinderEditorValue?> _showBinderEditor({CustomBinder? binder}) {
    return showModalBottomSheet<_CustomBinderEditorValue>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CustomBinderEditorSheet(binder: binder),
    );
  }

  Future<void> _createBinder() async {
    final value = await _showBinderEditor();
    if (value == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    await LocalCustomBinderStore.saveBinder(
      CustomBinder(
        id: _generateLocalDocumentId(),
        name: value.name,
        imageBase64: value.imageBase64,
        createdAtMs: now,
        updatedAtMs: now,
      ),
    );
    await _loadCustomBinderState();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${value.name} created')),
    );
  }

  Future<void> _editBinder(CustomBinder binder) async {
    final value = await _showBinderEditor(binder: binder);
    if (value == null) return;

    await LocalCustomBinderStore.saveBinder(
      binder.copyWith(
        name: value.name,
        imageBase64: value.imageBase64,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await _loadCustomBinderState();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${value.name} updated')),
    );
  }

  Future<void> _deleteBinder(CustomBinder binder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete binder?'),
          content: Text('Delete ${binder.name} and all cards inside it?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await LocalCustomBinderStore.deleteBinder(binder.id);
    await _loadCustomBinderState();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${binder.name} deleted')),
    );
  }

  Future<void> _removeSetFromMasterSets(TcgSet set) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove set from Master Sets?'),
          content: Text(
            'This will clear saved Pokédex data for ${set.name} on this device. '
            'Use this if the set is showing even though you have no cards saved in it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await LocalPokedexStore.clearSet(set.id);
    await PokedexSyncService.syncCurrentSetForCurrentUser(set.id);
    await _loadSetCollectionState();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${set.name} removed from Master Sets')),
    );
  }

  Widget _buildViewToggle() {
    Widget buildChip({
      required String label,
      required IconData icon,
      required _MasterSetsViewMode mode,
    }) {
      final selected = _viewMode == mode;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            setState(() {
              _viewMode = mode;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFF7DE77) : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? const Color(0xFFF7DE77) : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: selected ? Colors.black : Colors.white,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.black : Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          buildChip(
            label: 'Set Pokédex',
            icon: Icons.collections_bookmark_outlined,
            mode: _MasterSetsViewMode.setPokedex,
          ),
          const SizedBox(width: 10),
          buildChip(
            label: 'Custom Binders',
            icon: Icons.photo_album_outlined,
            mode: _MasterSetsViewMode.customBinders,
          ),
        ],
      ),
    );
  }

  Widget _buildSetPokedexView() {
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

        final visibleSets = allSets
            .where((set) => (_savedCopyCountsBySetId[set.id] ?? 0) > 0)
            .toList();

        return RefreshIndicator(
          onRefresh: refreshSets,
          child: visibleSets.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Card(
                        color: Color(0xFF102754),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Only sets with saved cards show here. Add a card to a set and it will appear here.',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No set Pokédex entries yet. Add a card to a set first and it will appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: visibleSets.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Card(
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
                      );
                    }

                    final set = visibleSets[index - 1];
                    return Card(
                      color: const Color(0xFF102754),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onLongPress: () => _removeSetFromMasterSets(set),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => SetPokedexPage(set: set),
                            ),
                          );
                          await _loadSetCollectionState();
                        },
                        child: Stack(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              alignment: Alignment.center,
                              constraints: const BoxConstraints(minHeight: 110),
                              child: _ResolvedSetLogo(
                                setId: set.id,
                                setName: set.name,
                                fallbackLogoUrl: set.logoUrl,
                                height: 64,
                                fit: BoxFit.contain,
                                textStyle: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Tooltip(
                                message: 'Remove from Master Sets',
                                child: IconButton(
                                  onPressed: () => _removeSetFromMasterSets(set),
                                  icon: const Icon(Icons.close_rounded),
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildCustomBindersView() {
    if (_loadingCustomBinders) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadCustomBinderState,
      child: _customBinders.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Card(
                  color: const Color(0xFF102754),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Create your own themed binders',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Make custom Pokédex binders for cards like every Charizard, all Pikachu cards, favourite promos, or any theme you want. You can rename each binder and upload a cover image too.',
                          style: TextStyle(color: Color(0xFFD8E3FB), height: 1.4),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _createBinder,
                            icon: const Icon(Icons.add_photo_alternate_outlined),
                            label: const Text('Create Custom Binder'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'No custom binders yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: _customBinders.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Card(
                    color: const Color(0xFF102754),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Custom binders let you group cards however you like, with your own name and cover image.',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: _createBinder,
                            icon: const Icon(Icons.add),
                            label: const Text('New'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final binder = _customBinders[index - 1];
                final count = _customBinderCounts[binder.id] ?? 0;
                return Card(
                  color: const Color(0xFF102754),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CustomBinderPage(binder: binder),
                        ),
                      );
                      await _loadCustomBinderState();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          _CustomBinderCover(
                            imageBase64: binder.imageBase64,
                            size: 88,
                            borderRadius: 18,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  binder.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  count == 1 ? '1 card saved' : '$count cards saved',
                                  style: const TextStyle(
                                    color: Color(0xFFD8E3FB),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Tap to open this custom binder.',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.60),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            color: const Color(0xFF102754),
                            iconColor: Colors.white,
                            onSelected: (value) async {
                              if (value == 'edit') {
                                await _editBinder(binder);
                              } else if (value == 'delete') {
                                await _deleteBinder(binder);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem<String>(
                                value: 'edit',
                                child: Text('Edit binder', style: TextStyle(color: Colors.white)),
                              ),
                              PopupMenuItem<String>(
                                value: 'delete',
                                child: Text('Delete binder', style: TextStyle(color: Colors.white)),
                              ),
                            ],
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildViewToggle(),
        Expanded(
          child: _viewMode == _MasterSetsViewMode.setPokedex
              ? _buildSetPokedexView()
              : _buildCustomBindersView(),
        ),
      ],
    );
  }
}

class _CustomBinderEditorSheet extends StatefulWidget {
  const _CustomBinderEditorSheet({this.binder});

  final CustomBinder? binder;

  @override
  State<_CustomBinderEditorSheet> createState() => _CustomBinderEditorSheetState();
}

class _CustomBinderEditorSheetState extends State<_CustomBinderEditorSheet> {
  late final TextEditingController _nameController;
  String? _imageBase64;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.binder?.name ?? '');
    _imageBase64 = widget.binder?.imageBase64;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final encoded = await CommunityImageCodec.pickAndEncodeSingle(ImageSource.gallery);
      if (encoded == null || !mounted) return;
      setState(() {
        _imageBase64 = encoded;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a binder name')),
      );
      return;
    }

    if (_saving) return;
    setState(() {
      _saving = true;
    });
    Navigator.of(context).pop(
      _CustomBinderEditorValue(
        name: name,
        imageBase64: _imageBase64,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Material(
      color: const Color(0xFF102754),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
          child: SingleChildScrollView(
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
                Text(
                  widget.binder == null ? 'Create Custom Binder' : 'Edit Custom Binder',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Give your binder a custom name and optionally upload a cover image, just like a real set page.',
                  style: TextStyle(
                    color: Color(0xFFD8E3FB),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: _CustomBinderCover(
                    imageBase64: _imageBase64,
                    size: 136,
                    borderRadius: 24,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.upload_outlined),
                        label: const Text('Upload Cover'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _imageBase64 == null
                            ? null
                            : () {
                                setState(() {
                                  _imageBase64 = null;
                                });
                              },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Remove Image'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Binder name',
                    labelStyle: const TextStyle(color: Color(0xFFC8D4F0)),
                    hintText: 'Every Charizard',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                    filled: true,
                    fillColor: const Color(0xFF16366E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submit,
                    child: Text(widget.binder == null ? 'Create Binder' : 'Save Binder'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomBinderCover extends StatelessWidget {
  const _CustomBinderCover({
    required this.imageBase64,
    this.size = 96,
    this.borderRadius = 20,
  });

  final String? imageBase64;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final bytes = CommunityImageCodec.decode(imageBase64);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: const LinearGradient(
          colors: [Color(0xFF21468B), Color(0xFF102754)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      clipBehavior: Clip.antiAlias,
      child: bytes == null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.photo_album_outlined, color: Color(0xFFF7DE77), size: 34),
                SizedBox(height: 8),
                Text(
                  'Custom\nBinder',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ],
            )
          : Image.memory(bytes, fit: BoxFit.cover),
    );
  }
}

class _CustomBinderPickerSheet extends StatefulWidget {
  const _CustomBinderPickerSheet({required this.card});

  final TcgCard card;

  @override
  State<_CustomBinderPickerSheet> createState() => _CustomBinderPickerSheetState();
}

class _CustomBinderPickerSheetState extends State<_CustomBinderPickerSheet> {
  List<CustomBinder> _binders = const <CustomBinder>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final binders = await LocalCustomBinderStore.loadBinders();
    if (!mounted) return;
    setState(() {
      _binders = binders;
      _loading = false;
    });
  }

  Future<void> _createBinder() async {
    final value = await showModalBottomSheet<_CustomBinderEditorValue>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CustomBinderEditorSheet(),
    );
    if (value == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final binder = CustomBinder(
      id: _generateLocalDocumentId(),
      name: value.name,
      imageBase64: value.imageBase64,
      createdAtMs: now,
      updatedAtMs: now,
    );
    await LocalCustomBinderStore.saveBinder(binder);
    if (!mounted) return;
    Navigator.of(context).pop(binder);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Material(
      color: const Color(0xFF102754),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
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
              Text(
                'Add ${widget.card.name} to a Custom Binder',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pick one of your custom binders, or create a new one now.',
                style: TextStyle(color: Color(0xFFD8E3FB), height: 1.4),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _createBinder,
                  icon: const Icon(Icons.add),
                  label: const Text('Create New Binder'),
                ),
              ),
              const SizedBox(height: 14),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_binders.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    'No custom binders yet. Create one above to get started.',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.48,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _binders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final binder = _binders[index];
                      return Card(
                        color: const Color(0xFF16366E),
                        child: ListTile(
                          onTap: () => Navigator.of(context).pop(binder),
                          leading: _CustomBinderCover(
                            imageBase64: binder.imageBase64,
                            size: 52,
                            borderRadius: 14,
                          ),
                          title: Text(
                            binder.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: const Text(
                            'Tap to add this card',
                            style: TextStyle(color: Color(0xFFD8E3FB)),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _addCardToCustomBinderFlow(BuildContext context, TcgCard card) async {
  final binder = await showModalBottomSheet<CustomBinder>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CustomBinderPickerSheet(card: card),
  );
  if (binder == null) return;

  await LocalCustomBinderStore.addCardToBinder(
    binderId: binder.id,
    card: card,
  );

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Added ${card.name} to ${binder.name}')),
  );
}

class CustomBinderPage extends StatefulWidget {
  const CustomBinderPage({super.key, required this.binder});

  final CustomBinder binder;

  @override
  State<CustomBinderPage> createState() => _CustomBinderPageState();
}

class _CustomBinderPageState extends State<CustomBinderPage> {
  late CustomBinder _binder;
  bool _loading = true;
  List<CustomBinderCardEntry> _cards = const <CustomBinderCardEntry>[];

  @override
  void initState() {
    super.initState();
    _binder = widget.binder;
    _load();
  }

  Future<void> _load() async {
    final binder = await LocalCustomBinderStore.loadBinder(_binder.id) ?? _binder;
    final cards = await LocalCustomBinderStore.loadCards(_binder.id);
    if (!mounted) return;
    setState(() {
      _binder = binder;
      _cards = cards;
      _loading = false;
    });
  }

  Future<void> _editBinder() async {
    final value = await showModalBottomSheet<_CustomBinderEditorValue>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CustomBinderEditorSheet(binder: _binder),
    );
    if (value == null) return;

    await LocalCustomBinderStore.saveBinder(
      _binder.copyWith(
        name: value.name,
        imageBase64: value.imageBase64,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await _load();
  }

  Future<void> _deleteBinder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete binder?'),
          content: Text('Delete ${_binder.name} and every card saved in it?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    await LocalCustomBinderStore.deleteBinder(_binder.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        title: Text(_binder.name),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _editBinder,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            onPressed: _deleteBinder,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: _load,
                child: _cards.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: [
                          Center(
                            child: _CustomBinderCover(
                              imageBase64: _binder.imageBase64,
                              size: 150,
                              borderRadius: 28,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            _binder.name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'No cards saved in this binder yet. Open any card and use Add to Custom Binder to start filling it.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
                          ),
                        ],
                      )
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Card(
                              color: const Color(0xFF102754),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    _CustomBinderCover(
                                      imageBase64: _binder.imageBase64,
                                      size: 80,
                                      borderRadius: 18,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _binder.name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            _cards.length == 1
                                                ? '1 card in this binder'
                                                : '${_cards.length} cards in this binder',
                                            style: const TextStyle(
                                              color: Color(0xFFD8E3FB),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _cards.length,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 6,
                              mainAxisSpacing: 6,
                              childAspectRatio: 0.76,
                            ),
                            itemBuilder: (context, index) {
                              final entry = _cards[index];
                              final card = entry.toSummaryCard();
                              return GestureDetector(
                                onTap: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => CustomBinderCardPage(
                                        binder: _binder,
                                        entry: entry,
                                      ),
                                    ),
                                  );
                                  await _load();
                                },
                                child: BinderCardTile(
                                  card: card,
                                  ownership: entry.ownership,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
              ),
            ),
    );
  }
}

class CustomBinderCardPage extends StatefulWidget {
  const CustomBinderCardPage({
    super.key,
    required this.binder,
    required this.entry,
  });

  final CustomBinder binder;
  final CustomBinderCardEntry entry;

  @override
  State<CustomBinderCardPage> createState() => _CustomBinderCardPageState();
}

class _CustomBinderCardPageState extends State<CustomBinderCardPage> {
  late bool normal;
  late bool reverseHolo;
  late bool holo;
  late int copies;
  bool _saving = false;
  bool _removing = false;

  TcgCard get _card => widget.entry.toSummaryCard();

  @override
  void initState() {
    super.initState();
    final ownership = widget.entry.ownership;
    normal = ownership.normal;
    reverseHolo = ownership.reverseHolo;
    holo = ownership.holo;
    copies = ownership.effectiveCopies;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
    });

    try {
      await LocalCustomBinderStore.saveCardEntry(
        binderId: widget.binder.id,
        entry: widget.entry.copyWith(
          normal: normal,
          reverseHolo: reverseHolo,
          holo: holo,
          copies: math.max(1, copies),
          updatedAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _remove() async {
    if (_removing) return;
    setState(() {
      _removing = true;
    });
    try {
      await LocalCustomBinderStore.removeCardFromBinder(
        binderId: widget.binder.id,
        cardId: widget.entry.cardId,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() {
          _removing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = _card;
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
                  Card(
                    color: const Color(0xFF102754),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          _CustomBinderCover(
                            imageBase64: widget.binder.imageBase64,
                            size: 62,
                            borderRadius: 16,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.binder.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Custom Binder',
                                  style: TextStyle(color: Color(0xFFD8E3FB)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _SetLogoTile(setId: card.setId, setName: card.setName, logoUrl: card.setLogoUrl),
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
                  _DetailTile(label: 'Set', value: card.setName),
                  _DetailTile(label: 'Card Number', value: card.number),
                  const SizedBox(height: 12),
                  Card(
                    color: const Color(0xFF102754),
                    child: Column(
                      children: [
                        SwitchListTile(
                          value: normal,
                          onChanged: (value) => setState(() => normal = value),
                          title: const Text('Normal', style: TextStyle(color: Colors.white)),
                        ),
                        const Divider(height: 1, color: Colors.white12),
                        SwitchListTile(
                          value: reverseHolo,
                          onChanged: (value) => setState(() => reverseHolo = value),
                          title: const Text('Reverse Holo', style: TextStyle(color: Colors.white)),
                        ),
                        const Divider(height: 1, color: Colors.white12),
                        SwitchListTile(
                          value: holo,
                          onChanged: (value) => setState(() => holo = value),
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
                            'Copies in Custom Binder',
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
                                  onPressed: copies > 1
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
                                  color: Colors.white.withValues(alpha: 0.08),
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
                                  onPressed: () {
                                    setState(() {
                                      copies++;
                                    });
                                  },
                                  child: const Text('+ Add'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _removing ? null : _remove,
                      icon: _removing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_outline),
                      label: const Text('Remove from Custom Binder'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save Changes'),
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


enum _MasterSetSlotKind {
  normal,
  reverseHolo,
  holo,
}

class _MasterSetCardSlot {
  const _MasterSetCardSlot({
    required this.card,
    required this.kind,
  });

  final TcgCard card;
  final _MasterSetSlotKind kind;

  String get shortLabel {
    switch (kind) {
      case _MasterSetSlotKind.normal:
        return 'N';
      case _MasterSetSlotKind.reverseHolo:
        return 'RH';
      case _MasterSetSlotKind.holo:
        return 'H';
    }
  }

  String get label {
    switch (kind) {
      case _MasterSetSlotKind.normal:
        return 'Normal';
      case _MasterSetSlotKind.reverseHolo:
        return 'Reverse Holo';
      case _MasterSetSlotKind.holo:
        return 'Holo';
    }
  }

  bool isOwned(CardOwnership ownership) {
    switch (kind) {
      case _MasterSetSlotKind.normal:
        return ownership.normal ||
            (ownership.effectiveCopies > 0 && !ownership.reverseHolo && !ownership.holo);
      case _MasterSetSlotKind.reverseHolo:
        return ownership.reverseHolo;
      case _MasterSetSlotKind.holo:
        return ownership.holo;
    }
  }

  CardOwnership tileOwnership(CardOwnership ownership) {
    if (!isOwned(ownership)) {
      return const CardOwnership();
    }

    switch (kind) {
      case _MasterSetSlotKind.normal:
        return const CardOwnership(normal: true, copies: 1);
      case _MasterSetSlotKind.reverseHolo:
        return const CardOwnership(reverseHolo: true, copies: 1);
      case _MasterSetSlotKind.holo:
        return const CardOwnership(holo: true, copies: 1);
    }
  }

  CardOwnership toggleOwnership(CardOwnership ownership) {
    final nextOwned = !isOwned(ownership);
    var normal = ownership.normal;
    var reverseHolo = ownership.reverseHolo;
    var holo = ownership.holo;
    var copies = ownership.effectiveCopies;

    switch (kind) {
      case _MasterSetSlotKind.normal:
        normal = nextOwned;
        break;
      case _MasterSetSlotKind.reverseHolo:
        reverseHolo = nextOwned;
        break;
      case _MasterSetSlotKind.holo:
        holo = nextOwned;
        break;
    }

    if (nextOwned && copies < 1) {
      copies = 1;
    }

    if (!normal && !reverseHolo && !holo) {
      copies = 0;
    }

    return CardOwnership(
      normal: normal,
      reverseHolo: reverseHolo,
      holo: holo,
      copies: copies,
    );
  }
}

bool _hasRawPriceLabel(TcgCard card, String text) {
  final needle = text.toLowerCase();
  return card.rawPriceBreakdown.keys.any((label) => label.toLowerCase().contains(needle));
}

bool _isSpecialMasterSetRarity(TcgCard card) {
  final rarity = (card.rarity ?? '').toLowerCase();
  return rarity.contains('illustration') ||
      rarity.contains('ultra') ||
      rarity.contains('secret') ||
      rarity.contains('hyper') ||
      rarity.contains('rainbow') ||
      rarity.contains('radiant') ||
      rarity.contains('amazing rare') ||
      rarity.contains('ace spec') ||
      rarity.contains('double rare') ||
      rarity.contains('rare holo v') ||
      rarity.contains('rare holo vmax') ||
      rarity.contains('rare holo vstar') ||
      rarity.contains('rare holo gx') ||
      rarity.contains('rare holo ex') ||
      rarity.contains('rare prime') ||
      rarity.contains('rare prism') ||
      rarity.contains('rare break');
}

bool _isReverseHoloEligibleRarity(TcgCard card) {
  final rarity = (card.rarity ?? '').toLowerCase().trim();
  if (rarity.isEmpty || _isSpecialMasterSetRarity(card)) return false;
  if (rarity.contains('common') || rarity.contains('uncommon')) return true;
  if (rarity == 'rare' || rarity == 'rare holo' || rarity == 'rare holo lv.x') return true;
  if (rarity.contains('rare holo') &&
      !rarity.contains(' v') &&
      !rarity.contains('vmax') &&
      !rarity.contains('vstar') &&
      !rarity.contains(' ex') &&
      !rarity.contains(' gx')) {
    return true;
  }
  return false;
}

bool _isHoloMasterSetRarity(TcgCard card) {
  final rarity = (card.rarity ?? '').toLowerCase();
  return _isSpecialMasterSetRarity(card) || rarity.contains('holo');
}

List<_MasterSetSlotKind> _availableMasterSetSlotKinds(TcgCard card) {
  final kinds = <_MasterSetSlotKind>[];

  void add(_MasterSetSlotKind kind) {
    if (!kinds.contains(kind)) {
      kinds.add(kind);
    }
  }

  final hasNormalPrice = _hasRawPriceLabel(card, 'normal market') ||
      _hasRawPriceLabel(card, '1st ed normal');
  final hasReversePrice = _hasRawPriceLabel(card, 'reverse holo');
  final hasHoloPrice = _hasRawPriceLabel(card, 'holofoil market') ||
      _hasRawPriceLabel(card, '1st ed holo') ||
      _hasRawPriceLabel(card, 'unlimited holo');

  final specialRarity = _isSpecialMasterSetRarity(card);
  final holoRarity = _isHoloMasterSetRarity(card);
  final reverseEligible = _isReverseHoloEligibleRarity(card);

  if (hasNormalPrice || (!hasHoloPrice && !specialRarity && !holoRarity)) {
    add(_MasterSetSlotKind.normal);
  }

  if (hasReversePrice || reverseEligible) {
    add(_MasterSetSlotKind.reverseHolo);
  }

  if (hasHoloPrice || holoRarity || specialRarity) {
    add(_MasterSetSlotKind.holo);
  }

  if (kinds.isEmpty) {
    add(_MasterSetSlotKind.normal);
  }

  kinds.sort((a, b) => a.index.compareTo(b.index));
  return kinds;
}

List<_MasterSetCardSlot> _buildMasterSetSlots(List<TcgCard> cards) {
  final slots = <_MasterSetCardSlot>[];
  final seen = <String>{};

  for (final card in cards) {
    for (final kind in _availableMasterSetSlotKinds(card)) {
      final key = '${card.id}_${kind.name}';
      if (seen.add(key)) {
        slots.add(_MasterSetCardSlot(card: card, kind: kind));
      }
    }
  }

  slots.sort((a, b) {
    final numberCompare = _compareCardNumbers(a.card.number, b.card.number);
    if (numberCompare != 0) return numberCompare;

    final nameCompare = a.card.name.toLowerCase().compareTo(b.card.name.toLowerCase());
    if (nameCompare != 0) return nameCompare;

    return a.kind.index.compareTo(b.kind.index);
  });

  return slots;
}

class _MasterSetSlotTile extends StatelessWidget {
  const _MasterSetSlotTile({
    required this.slot,
    required this.ownership,
  });

  final _MasterSetCardSlot slot;
  final CardOwnership ownership;

  @override
  Widget build(BuildContext context) {
    final slotOwned = slot.isOwned(ownership);

    return Stack(
      fit: StackFit.expand,
      children: [
        BinderCardTile(
          card: slot.card,
          ownership: slot.tileOwnership(ownership),
        ),
        Positioned(
          left: 6,
          bottom: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: slotOwned
                  ? const Color(0xFFF7DE77)
                  : Colors.black.withValues(alpha: 0.74),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: slotOwned
                    ? const Color(0xFFF7DE77)
                    : Colors.white.withValues(alpha: 0.22),
              ),
            ),
            child: Text(
              slot.shortLabel,
              style: TextStyle(
                color: slotOwned ? Colors.black : Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
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
  static const int _cardsPerPage = 9;

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
    await _updateOwnershipForCardId(card.id, ownership);
  }

  Future<void> _updateOwnershipForCardId(String cardId, CardOwnership ownership) async {
    setState(() {
      _ownershipByCardId[cardId] = ownership;
    });
    await _saveOwnership();
  }

  void _goToPokedexPage(int page, int totalPages) {
    setState(() {
      _currentPage = page.clamp(1, totalPages).toInt();
    });
  }

  void _handlePokedexPageSwipe(DragEndDetails details, int totalPages) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 250) return;

    if (velocity < 0 && _currentPage < totalPages) {
      _goToPokedexPage(_currentPage + 1, totalPages);
    } else if (velocity > 0 && _currentPage > 1) {
      _goToPokedexPage(_currentPage - 1, totalPages);
    }
  }

  int _pageForCardId(String cardId, List<_MasterSetCardSlot> visibleSlots) {
    final slotIndex = visibleSlots.indexWhere((slot) => slot.card.id == cardId);
    if (slotIndex < 0) return _currentPage;
    return (slotIndex ~/ _cardsPerPage) + 1;
  }

  Future<void> _openCardDetailsFromSlot({
    required List<TcgCard> visibleCards,
    required List<_MasterSetCardSlot> visibleSlots,
    required _MasterSetCardSlot slot,
  }) async {
    if (visibleCards.isEmpty) return;

    var currentIndex = visibleCards.indexWhere((card) => card.id == slot.card.id);
    if (currentIndex < 0) {
      currentIndex = 0;
    }

    while (mounted && currentIndex >= 0 && currentIndex < visibleCards.length) {
      final card = visibleCards[currentIndex];
      final result = await Navigator.of(context).push<dynamic>(
        MaterialPageRoute(
          builder: (_) => SetCardDetailsPage(
            card: card,
            ownership: _ownershipFor(card),
            navigationCards: visibleCards,
            navigationIndex: currentIndex,
          ),
        ),
      );

      if (!mounted) return;

      if (result is _SetCardDetailsResult) {
        await _updateOwnershipForCardId(result.cardId, result.ownership);

        final nextIndex = result.nextIndex;
        if (nextIndex != null && nextIndex >= 0 && nextIndex < visibleCards.length) {
          final nextCard = visibleCards[nextIndex];
          final totalPages = visibleSlots.isEmpty
              ? 1
              : ((visibleSlots.length - 1) ~/ _cardsPerPage) + 1;
          _goToPokedexPage(_pageForCardId(nextCard.id, visibleSlots), totalPages);
          currentIndex = nextIndex;
          continue;
        }
        break;
      }

      if (result is CardOwnership) {
        await _updateOwnership(card, result);
      }
      break;
    }
  }

  List<TcgCard> get _filteredCards {
    final list = _allCards.toList();
    list.sort((a, b) => _compareCardNumbers(a.number, b.number));
    return list;
  }

  Future<void> _showPagePicker({
    required int currentPage,
    required int totalPages,
  }) async {
    final pickedPage = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF102754),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
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
                  'Jump to page',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    itemCount: totalPages,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1.25,
                    ),
                    itemBuilder: (context, index) {
                      final page = index + 1;
                      final selected = page == currentPage;
                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => Navigator.of(context).pop(page),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected ? const Color(0xFFF7DE77) : const Color(0xFF16366E),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected ? const Color(0xFFF7DE77) : const Color(0xFF3F5C96),
                            ),
                          ),
                          child: Text(
                            page.toString(),
                            style: TextStyle(
                              color: selected ? Colors.black : Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (pickedPage == null || !mounted) return;
    setState(() {
      _currentPage = pickedPage.clamp(1, totalPages).toInt();
    });
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
          final visibleSlots = _buildMasterSetSlots(visibleCards);
          final ownedCount = visibleSlots
              .where((slot) => slot.isOwned(_ownershipFor(slot.card)))
              .length;
          final total = visibleSlots.length;
          final percent = total == 0 ? 0 : ((ownedCount / total) * 100).round();
          final cardsPerPage = _cardsPerPage;
          final totalPages = visibleSlots.isEmpty ? 1 : ((visibleSlots.length - 1) ~/ cardsPerPage) + 1;
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
          final endIndex = (startIndex + cardsPerPage).clamp(0, visibleSlots.length).toInt();
          final pageSlots = visibleSlots.sublist(startIndex, endIndex);

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
                          _ResolvedSetLogo(
                            setId: widget.set.id,
                            setName: widget.set.name,
                            fallbackLogoUrl: widget.set.logoUrl,
                            height: 64,
                            fit: BoxFit.contain,
                            textStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
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
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragEnd: (details) => _handlePokedexPageSwipe(details, totalPages),
                      child: pageSlots.isEmpty
                          ? const Center(
                              child: Text(
                                'No cards found in this set.',
                                style: TextStyle(color: Colors.white),
                              ),
                            )
                          : GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: pageSlots.length,
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 4,
                                mainAxisSpacing: 4,
                                childAspectRatio: 0.76,
                              ),
                              itemBuilder: (context, index) {
                                final slot = pageSlots[index];
                                final card = slot.card;
                                final ownership = _ownershipFor(card);
                                return GestureDetector(
                                  onLongPress: () async {
                                    await _updateOwnership(
                                      card,
                                      slot.toggleOwnership(ownership),
                                    );
                                  },
                                  onTap: () async {
                                    await _openCardDetailsFromSlot(
                                      visibleCards: visibleCards,
                                      visibleSlots: visibleSlots,
                                      slot: slot,
                                    );
                                  },
                                  child: _MasterSetSlotTile(
                                    slot: slot,
                                    ownership: ownership,
                                  ),
                                );
                              },
                            ),
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
                      InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: totalPages > 1
                            ? () => _showPagePicker(
                                  currentPage: safePage,
                                  totalPages: totalPages,
                                )
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$safePage / $totalPages',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Colors.white70,
                                size: 18,
                              ),
                            ],
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

class _SetCardDetailsResult {
  const _SetCardDetailsResult({
    required this.cardId,
    required this.ownership,
    this.nextIndex,
  });

  final String cardId;
  final CardOwnership ownership;
  final int? nextIndex;
}

class SetCardDetailsPage extends StatefulWidget {
  const SetCardDetailsPage({
    super.key,
    required this.card,
    required this.ownership,
    this.readOnly = false,
    this.ownerLabel,
    this.navigationCards,
    this.navigationIndex,
  });

  final TcgCard card;
  final CardOwnership ownership;
  final bool readOnly;
  final String? ownerLabel;
  final List<TcgCard>? navigationCards;
  final int? navigationIndex;

  @override
  State<SetCardDetailsPage> createState() => _SetCardDetailsPageState();
}

class _SetCardDetailsPageState extends State<SetCardDetailsPage> {
  late bool normal;
  late bool reverseHolo;
  late bool holo;
  late int copies;
  bool _setWishlistBusy = false;
  bool _cardDetailsActionsVisible = true;

  Future<void> _addToCustomBinder() async {
    await _addCardToCustomBinderFlow(context, widget.card);
  }

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

  bool get _hasCardNavigation {
    final cards = widget.navigationCards;
    final index = widget.navigationIndex;
    return cards != null && cards.isNotEmpty && index != null;
  }

  int get _navigationTotal => widget.navigationCards?.length ?? 0;

  int get _navigationPosition => (widget.navigationIndex ?? 0) + 1;

  bool get _canSwipeToPrevious => _hasCardNavigation && (widget.navigationIndex ?? 0) > 0;

  bool get _canSwipeToNext =>
      _hasCardNavigation && (widget.navigationIndex ?? 0) < _navigationTotal - 1;

  void _finishDetails({int? nextIndex}) {
    if (_hasCardNavigation) {
      Navigator.of(context).pop(
        _SetCardDetailsResult(
          cardId: widget.card.id,
          ownership: _currentOwnership,
          nextIndex: nextIndex,
        ),
      );
      return;
    }

    Navigator.of(context).pop(_currentOwnership);
  }

  void _handleCardDetailsSwipe(DragEndDetails details) {
    if (!_hasCardNavigation) return;

    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 250) return;

    if (velocity < 0 && _canSwipeToNext) {
      _finishDetails(nextIndex: (widget.navigationIndex ?? 0) + 1);
    } else if (velocity > 0 && _canSwipeToPrevious) {
      _finishDetails(nextIndex: (widget.navigationIndex ?? 0) - 1);
    }
  }

  void _toggleCardDetailsActionsPanel() {
    setState(() {
      _cardDetailsActionsVisible = !_cardDetailsActionsVisible;
    });
  }

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
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: _handleCardDetailsSwipe,
          child: Column(
            children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SetLogoTile(setId: card.setId, setName: card.setName, logoUrl: card.setLogoUrl),
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
                  _PriceLookupCard(card: card),
                  _GradedPricesButton(card: card),
                  if (_hasCardNavigation) ...[
                    const SizedBox(height: 12),
                    Card(
                      color: const Color(0xFF102754),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Icon(
                              Icons.keyboard_arrow_left_rounded,
                              color: _canSwipeToPrevious ? const Color(0xFFF7DE77) : Colors.white24,
                            ),
                            Expanded(
                              child: Text(
                                'Swipe left or right to move between cards ($_navigationPosition / $_navigationTotal).',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFFC8D4F0),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.keyboard_arrow_right_rounded,
                              color: _canSwipeToNext ? const Color(0xFFF7DE77) : Colors.white24,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
                                  color: Colors.white.withValues(alpha: 0.08),
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
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: !_cardDetailsActionsVisible ? _toggleCardDetailsActionsPanel : null,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _cardDetailsActionsVisible
                    ? Container(
                        key: const ValueKey('card_details_actions_open'),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF041B4A),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.22),
                              blurRadius: 12,
                              offset: const Offset(0, -4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: _toggleCardDetailsActionsPanel,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(28, 2, 28, 10),
                                child: Container(
                                  width: 44,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.28),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                            ),
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
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _addToCustomBinder,
                                icon: const Icon(Icons.photo_album_outlined),
                                label: const Text('Add to Custom Binder'),
                              ),
                            ),
                            if (!widget.readOnly) ...[
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: () {
                                    _finishDetails();
                                  },
                                  child: const Text('Save Card to Set Pokédex'),
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              'Tap the handle to hide actions',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.42),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        key: const ValueKey('card_details_actions_closed'),
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF041B4A),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 10,
                              offset: const Offset(0, -3),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 52,
                              height: 5,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7DE77),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tap to show wishlist, binder and save actions',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.68),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
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
                  _SetLogoTile(setId: card.setId, setName: widget.setName, logoUrl: card.setLogoUrl),
                  if (card.largeImageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(card.largeImageUrl!, height: 320),
                    ),
                  const SizedBox(height: 16),
                  _PriceLookupCard(card: card),
                  _GradedPricesButton(card: card),
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
                                  color: Colors.white.withValues(alpha: 0.08),
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
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
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
        color: Colors.white.withValues(alpha: 0.08),
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
                color: mid.withValues(alpha: 0.45 + (t * 0.25)),
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
                                  Container(color: Colors.black.withValues(alpha: 0.25)),
                              ],
                            ),
                    ),
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
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
                            color: hasShine ? const Color(0xFFF7DE77) : Colors.black.withValues(alpha: 0.72),
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
                                  Container(color: Colors.black.withValues(alpha: 0.25)),
                              ],
                            ),
                    ),
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
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
                            color: Colors.black.withValues(alpha: 0.72),
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
    if (!mounted) return;
    setState(() {
      _profileImagePath = imagePath;
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayLetter = widget.profile.displayName.isEmpty
        ? 'P'
        : widget.profile.displayName[0].toUpperCase();
    final imageFile = _profileImagePath != null ? File(_profileImagePath!) : null;
    final imageExists = imageFile != null && imageFile.existsSync();

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
        child: Container(
          width: 42,
          height: 42,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFF7DE77),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.75),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipOval(
            child: imageExists
                ? Image.file(
                    imageFile!,
                    fit: BoxFit.cover,
                    width: 42,
                    height: 42,
                    errorBuilder: (_, __, ___) => _ProfileInitialAvatar(
                      displayLetter: displayLetter,
                    ),
                  )
                : _ProfileInitialAvatar(displayLetter: displayLetter),
          ),
        ),
      ),
    );
  }
}

class _ProfileInitialAvatar extends StatelessWidget {
  const _ProfileInitialAvatar({required this.displayLetter});

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
                            'Tap to open card details, prices, and eBay sold checks',
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
  bool _searchCardActionsVisible = true;

  Future<void> _addToCustomBinder() async {
    await _addCardToCustomBinderFlow(context, widget.card);
  }

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

  void _toggleSearchCardActionsPanel() {
    setState(() {
      _searchCardActionsVisible = !_searchCardActionsVisible;
    });
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
                  _SetLogoTile(setId: card.setId, setName: card.setName, logoUrl: card.setLogoUrl),
                  if (card.largeImageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(card.largeImageUrl!, height: 320),
                    ),
                  const SizedBox(height: 16),
                  _PriceLookupCard(card: card),
                  _GradedPricesButton(card: card),
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
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: !_searchCardActionsVisible ? _toggleSearchCardActionsPanel : null,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _searchCardActionsVisible
                      ? Container(
                          key: const ValueKey('search_card_actions_open'),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF041B4A),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.22),
                                blurRadius: 12,
                                offset: const Offset(0, -4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                borderRadius: BorderRadius.circular(999),
                                onTap: _toggleSearchCardActionsPanel,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(28, 2, 28, 10),
                                  child: Container(
                                    width: 44,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.28),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                ),
                              ),
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
                                child: OutlinedButton.icon(
                                  onPressed: _addToCustomBinder,
                                  icon: const Icon(Icons.photo_album_outlined),
                                  label: const Text('Add to Custom Binder'),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: () async {
                                    final updatedOwnership =
                                        await Navigator.of(context).push<CardOwnership>(
                                      MaterialPageRoute(
                                        builder: (_) => SetCardDetailsPage(
                                          card: card,
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
                              const SizedBox(height: 4),
                              Text(
                                'Tap the handle to hide actions',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.42),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          key: const ValueKey('search_card_actions_closed'),
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF041B4A),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 10,
                                offset: const Offset(0, -3),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 52,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7DE77),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Tap to show wishlist, binder and Pokédex actions',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.68),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ResolvedSetLogo extends StatelessWidget {
  const _ResolvedSetLogo({
    required this.setId,
    required this.setName,
    required this.fallbackLogoUrl,
    required this.height,
    this.fit = BoxFit.contain,
    this.cacheWidth,
    this.cacheHeight,
    this.textStyle,
  });

  final String setId;
  final String setName;
  final String? fallbackLogoUrl;
  final double height;
  final BoxFit fit;
  final int? cacheWidth;
  final int? cacheHeight;
  final TextStyle? textStyle;

  Widget _buildTextFallback() {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Center(
        child: Text(
          setName,
          textAlign: TextAlign.center,
          style: textStyle ??
              const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }

  Widget _buildLogo(String logoUrl) {
    return SizedBox(
      height: height,
      child: _FastNetworkImage(
        imageUrl: logoUrl,
        fit: fit,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        errorChild: _buildTextFallback(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: PokemonTcgService.resolveSetLogoUrl(
        setId: setId,
        setName: setName,
        fallbackLogoUrl: fallbackLogoUrl,
      ),
      builder: (context, snapshot) {
        final resolvedLogoUrl = snapshot.data?.trim();

        if (resolvedLogoUrl != null && resolvedLogoUrl.isNotEmpty) {
          return _buildLogo(resolvedLogoUrl);
        }

        return _buildTextFallback();
      },
    );
  }
}

class _SetLogoTile extends StatelessWidget {
  const _SetLogoTile({
    required this.setId,
    required this.setName,
    required this.logoUrl,
  });

  final String setId;
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
          child: _ResolvedSetLogo(
            setId: setId,
            setName: setName,
            fallbackLogoUrl: logoUrl,
            height: 54,
          ),
        ),
      ),
    );
  }
}



class GradedPricesPage extends StatelessWidget {
  const GradedPricesPage({
    super.key,
    required this.card,
  });

  final TcgCard card;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        title: const Text('Graded Prices'),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SetLogoTile(setId: card.setId, setName: card.setName, logoUrl: card.setLogoUrl),
            Card(
              color: const Color(0xFF102754),
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (card.imageUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _FastNetworkImage(
                          imageUrl: card.imageUrl!,
                          fit: BoxFit.cover,
                          width: 72,
                          height: 100,
                          cacheWidth: 180,
                          cacheHeight: 252,
                        ),
                      )
                    else
                      Container(
                        width: 72,
                        height: 100,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E2A5E),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.image_not_supported,
                          color: Colors.white70,
                        ),
                      ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            card.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            card.setName,
                            style: const TextStyle(
                              color: Color(0xFFC8D4F0),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (card.number.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              '#${card.number}',
                              style: const TextStyle(color: Colors.white54),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _GradedPricesCard(card: card, gradedPrices: card.gradedPrices),
          ],
        ),
      ),
    );
  }
}

class _GradedPricesButton extends StatelessWidget {
  const _GradedPricesButton({
    required this.card,
  });

  final TcgCard card;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF102754),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Graded Prices',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Raw price stays on this page. Tap below to view graded price checks separately.',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => GradedPricesPage(card: card),
                    ),
                  );
                },
                icon: const Icon(Icons.workspace_premium_outlined),
                label: const Text('View Graded Prices'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceLookupCard extends StatelessWidget {
  const _PriceLookupCard({
    required this.card,
  });

  final TcgCard card;

  bool get _hasRawPrice => (card.rawPrice ?? 0) > 0;

  @override
  Widget build(BuildContext context) {
    final rawPriceText = _hasRawPrice
        ? _formatPrice(card.rawPrice, fromCurrency: card.rawPriceCurrency)
        : 'No live raw price found yet';

    return Card(
      color: const Color(0xFF102754),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Raw Price',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              rawPriceText,
              style: TextStyle(
                color: _hasRawPrice ? Colors.white : const Color(0xFFF7DE77),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _hasRawPrice
                  ? 'This is the live raw market estimate currently available for this card.'
                  : 'Some cards do not have a live API price. Use the eBay sold search below on the details page for a quick price check.',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openEbaySoldSearch(context: context, card: card),
                icon: const Icon(Icons.open_in_new),
                label: Text(
                  _hasRawPrice
                      ? 'Open Raw Sold eBay Results'
                      : 'Check Raw Sold eBay Results',
                ),
              ),
            ),
          ],
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

    final hasAnyLiveGradedPrice = gradedPrices.values.any((price) => price > 0);

    return Card(
      color: const Color(0xFF102754),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Graded Price Checks',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasAnyLiveGradedPrice
                  ? 'Live graded prices are shown where available. You can also open recent sold eBay results for each grade below.'
                  : 'No live graded prices were found for this card right now. Use the buttons below to check recent sold eBay results from this details page.',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
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

  bool get _hasPrice => price != null && price!.isFinite && price! > 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                _hasPrice
                    ? _formatPrice(price, fromCurrency: sourceCurrency)
                    : 'Check eBay',
                style: TextStyle(
                  color: _hasPrice ? Colors.white : const Color(0xFFF7DE77),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _hasPrice
                ? 'Open recent sold eBay results for this version.'
                : 'No live price found. Open recent sold eBay results for this version.',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Open eBay Sold'),
            ),
          ),
        ],
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

class _CollectorNumberQuery {
  const _CollectorNumberQuery({
    required this.cardNumber,
    required this.printedTotal,
  });

  final String cardNumber;
  final int printedTotal;
}

class PokemonTcgService {
  static const String _baseUrl = 'https://api.pokemontcg.io/v2';
  static final Map<String, List<TcgCard>> _cardSearchCache = <String, List<TcgCard>>{};
  static final Map<String, Future<List<TcgCard>>> _cardSearchInFlight =
      <String, Future<List<TcgCard>>>{};
  static final Map<String, List<TcgSet>> _setSearchCache = <String, List<TcgSet>>{};
  static final Map<String, Future<List<TcgSet>>> _setSearchInFlight =
      <String, Future<List<TcgSet>>>{};
  static final Map<String, List<TcgCard>> _setCardsCache = <String, List<TcgCard>>{};
  static final Map<String, Future<List<TcgCard>>> _setCardsInFlight =
      <String, Future<List<TcgCard>>>{};
  static final Map<String, TcgCard> _cardByIdCache = <String, TcgCard>{};
  static final Map<String, Future<TcgCard>> _cardByIdInFlight = <String, Future<TcgCard>>{};
  static final Map<String, TcgSet> _setByIdCache = <String, TcgSet>{};
  static final Map<String, Future<TcgSet?>> _setByIdInFlight =
      <String, Future<TcgSet?>>{};

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

  static _CollectorNumberQuery? _tryParseCollectorNumberQuery(String value) {
    final match = RegExp(r'^\s*([A-Za-z0-9]+)\s*/\s*(\d+)\s*$').firstMatch(value);
    if (match == null) return null;

    final cardNumber = match.group(1)?.trim() ?? '';
    final printedTotal = int.tryParse(match.group(2)?.trim() ?? '');
    if (cardNumber.isEmpty || printedTotal == null || printedTotal <= 0) {
      return null;
    }

    return _CollectorNumberQuery(
      cardNumber: cardNumber,
      printedTotal: printedTotal,
    );
  }

  static Future<List<TcgCard>> _searchExactCollectorNumber(
    _CollectorNumberQuery query,
  ) async {
    final normalizedRequestedNumber = _normalizeCollectorCardNumber(query.cardNumber);
    if (normalizedRequestedNumber.isEmpty) return const <TcgCard>[];

    final numberSearch = 'number:${_escapeTcgQueryValue(query.cardNumber)}';
    final cardsById = <String, TcgCard>{};
    var page = 1;

    while (true) {
      final uri = Uri.parse(
        '$_baseUrl/cards?q=$numberSearch&pageSize=250&page=$page&orderBy=-set.releaseDate,number',
      );
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final items = (data['data'] as List<dynamic>? ?? const []);
      if (items.isEmpty) break;

      for (final item in items) {
        if (item is! Map<String, dynamic>) continue;

        final rawNumber = (item['number'] ?? '').toString();
        if (_normalizeCollectorCardNumber(rawNumber) != normalizedRequestedNumber) {
          continue;
        }

        final set = (item['set'] as Map<String, dynamic>? ?? const <String, dynamic>{});
        final printedTotal = _readIntValue(set['printedTotal']);
        final total = _readIntValue(set['total']);
        if (printedTotal != query.printedTotal && total != query.printedTotal) {
          continue;
        }

        final card = TcgCard.fromJson(item);
        cardsById.putIfAbsent(card.id, () => card);
      }

      if (items.length < 250 || page >= 20) {
        break;
      }
      page++;
    }

    final cards = cardsById.values.toList()
      ..sort((a, b) {
        final setCompare = a.setName.toLowerCase().compareTo(b.setName.toLowerCase());
        if (setCompare != 0) return setCompare;
        return _compareCardNumbers(a.number, b.number);
      });

    return cards;
  }

  static int? _readIntValue(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString().trim());
  }

  static String _normalizeCollectorCardNumber(String value) {
    final cleaned = value
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '')
        .trim();
    if (cleaned.isEmpty) return '';

    final numeric = int.tryParse(cleaned);
    if (numeric != null) {
      return numeric.toString();
    }

    return cleaned.replaceFirstMapped(
      RegExp(r'^([a-z]+)0+(\d+)$'),
      (match) => '${match.group(1)}${int.tryParse(match.group(2) ?? '') ?? match.group(2)}',
    );
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
    final cacheKey = _normalizeApiSearchKey(cleanQuery);
    if (cacheKey.isEmpty) return const <TcgCard>[];

    final cachedCards = _cardSearchCache[cacheKey];
    if (cachedCards != null) {
      return List<TcgCard>.from(cachedCards);
    }

    final inFlightRequest = _cardSearchInFlight[cacheKey];
    if (inFlightRequest != null) {
      final cards = await inFlightRequest;
      return List<TcgCard>.from(cards);
    }

    final request = _searchCardsOnlyFromApi(cleanQuery);
    _cardSearchInFlight[cacheKey] = request;

    try {
      final cards = await request;
      _cardSearchCache[cacheKey] = List<TcgCard>.from(cards);
      return List<TcgCard>.from(cards);
    } finally {
      _cardSearchInFlight.remove(cacheKey);
    }
  }

  static Future<List<TcgCard>> _searchCardsOnlyFromApi(String cleanQuery) async {
    final exactCollectorNumber = _tryParseCollectorNumberQuery(cleanQuery);
    if (exactCollectorNumber != null) {
      return _searchExactCollectorNumber(exactCollectorNumber);
    }

    final terms = cleanQuery
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (terms.isEmpty) return const <TcgCard>[];

    final escapedTerms = terms.map(_escapeTcgQueryValue).toList();
    final cardSearch = escapedTerms.map((term) => 'name:*$term*').join(' AND ');
    final cardsById = <String, TcgCard>{};
    var page = 1;

    while (true) {
      final uri = Uri.parse(
        '$_baseUrl/cards?q=$cardSearch&pageSize=$_kFastCardSearchPageSize&page=$page&orderBy=name,number,set.releaseDate',
      );
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final items = (data['data'] as List<dynamic>? ?? const []);
      if (items.isEmpty) break;

      for (final item in items) {
        final card = TcgCard.fromJson(item as Map<String, dynamic>);
        cardsById.putIfAbsent(card.id, () => card);
      }

      if (items.length < _kFastCardSearchPageSize || page >= _kFastCardSearchMaxPages) {
        break;
      }
      page++;
    }

    final cards = cardsById.values.toList()
      ..sort((a, b) => _compareCardSearchResults(a, b, cleanQuery));
    return cards;
  }

  static Future<List<TcgSet>> searchSetsOnly(String query) async {
    final cleanQuery = query.trim();
    final cacheKey = _normalizeApiSearchKey(cleanQuery);
    if (cacheKey.isEmpty) return const <TcgSet>[];

    final cachedSets = _setSearchCache[cacheKey];
    if (cachedSets != null) {
      return List<TcgSet>.from(cachedSets);
    }

    final inFlightRequest = _setSearchInFlight[cacheKey];
    if (inFlightRequest != null) {
      final sets = await inFlightRequest;
      return List<TcgSet>.from(sets);
    }

    final request = _searchSetsOnlyFromApi(cleanQuery);
    _setSearchInFlight[cacheKey] = request;

    try {
      final sets = await request;
      _setSearchCache[cacheKey] = List<TcgSet>.from(sets);
      return List<TcgSet>.from(sets);
    } finally {
      _setSearchInFlight.remove(cacheKey);
    }
  }

  static Future<List<TcgSet>> _searchSetsOnlyFromApi(String cleanQuery) async {
    if (_tryParseCollectorNumberQuery(cleanQuery) != null) {
      return const <TcgSet>[];
    }

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

    Future<void> fetchSets(String setSearch, {int maxPages = _kFastSetSearchMaxPages}) async {
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

        if (items.length < 100 || page >= maxPages) break;
        page++;
      }
    }

    await fetchSets(exactPrefixSearch);
    if (setsById.isEmpty) {
      await fetchSets(broadSearch);
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

  static String _normalizeApiSearchKey(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static int _compareCardSearchResults(TcgCard a, TcgCard b, String query) {
    final scoreA = _scoreCardSearchResult(a, query);
    final scoreB = _scoreCardSearchResult(b, query);
    if (scoreA != scoreB) {
      return scoreB.compareTo(scoreA);
    }

    final nameCompare = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    if (nameCompare != 0) return nameCompare;

    final setCompare = a.setName.toLowerCase().compareTo(b.setName.toLowerCase());
    if (setCompare != 0) return setCompare;

    return _compareCardNumbers(a.number, b.number);
  }

  static int _scoreCardSearchResult(TcgCard card, String query) {
    final normalizedQuery = _normalizeSearchMatchText(query);
    final normalizedName = _normalizeSearchMatchText(card.name);
    if (normalizedQuery.isEmpty || normalizedName.isEmpty) return 0;

    if (normalizedName == normalizedQuery) return 700;
    if (normalizedName.startsWith(normalizedQuery)) return 620;
    if (normalizedName.contains(normalizedQuery)) return 500;

    final queryWords = normalizedQuery.split(' ').where((word) => word.isNotEmpty).toList();
    final nameWords = normalizedName.split(' ').where((word) => word.isNotEmpty).toList();
    var score = 0;
    for (final word in queryWords) {
      if (nameWords.any((nameWord) => nameWord == word)) {
        score += 130;
      } else if (nameWords.any((nameWord) => nameWord.startsWith(word))) {
        score += 100;
      } else if (normalizedName.contains(word)) {
        score += 45;
      }
    }

    if (_normalizeSearchMatchText(card.setName).contains(normalizedQuery)) {
      score += 10;
    }

    return score;
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
    final set = await _fetchSetById(setId);

    void addCards(Iterable<TcgCard> cards) {
      for (final card in cards) {
        if (card.id.trim().isEmpty && card.number.trim().isEmpty) continue;
        final key = card.id.trim().isNotEmpty ? card.id.trim() : _buildSetCardDedupKey(card);
        final existing = cardsByKey[key];
        if (existing == null || _preferCardForSetView(card, existing)) {
          cardsByKey[key] = card;
        }
      }
    }

    // Fast first pass: official set id. This is normally enough for the full set,
    // including illustration rares, ultra rares, and secret rares.
    addCards(
      await _fetchCardsForSetQuery(
        'set.id:$setId',
        orderBy: 'number',
        maxPages: 4,
      ),
    );

    final expectedTotal = set?.total ?? 0;
    final setNameFromApi = set?.name.trim() ?? '';
    final setNameFromCards = cardsByKey.values
        .map((card) => card.setName.trim())
        .firstWhere((name) => name.isNotEmpty, orElse: () => '');
    final setName = setNameFromApi.isNotEmpty ? setNameFromApi : setNameFromCards;

    // Only do the slower exact-name fallback if the set id result looks incomplete.
    // This keeps Master Sets fast while still rescuing special cards when needed.
    final needsFallbackByName =
        setName.isNotEmpty && (expectedTotal <= 0 || cardsByKey.length < expectedTotal);

    if (needsFallbackByName) {
      addCards(
        (await _fetchCardsForSetQuery(
          'set.name:"${_escapeTcgQueryValue(setName)}"',
          orderBy: 'number',
          maxPages: 4,
        )).where(
          (card) => _cardBelongsToRequestedSet(
            card: card,
            setId: setId,
            setName: setName,
          ),
        ),
      );
    }

    // Rare fallback is now deliberately small and only runs when the set still
    // looks incomplete. The previous version checked too many rarity searches and
    // made Master Sets feel slow.
    if (setName.isNotEmpty && expectedTotal > 0 && cardsByKey.length < expectedTotal) {
      final remainingGap = expectedTotal - cardsByKey.length;
      if (remainingGap <= 120) {
        final rarityCards = await Future.wait(
          _fastMasterSetRarityQueries.map(
            (rarityQuery) => _fetchCardsForSetQuery(
              'set.name:"${_escapeTcgQueryValue(setName)}" $rarityQuery',
              orderBy: 'number',
              maxPages: 2,
            ),
          ),
        );

        for (final batch in rarityCards) {
          addCards(
            batch.where(
              (card) => _cardBelongsToRequestedSet(
                card: card,
                setId: setId,
                setName: setName,
              ),
            ),
          );
        }
      }
    }

    // Final rescue: only fill a small number of missing numbers. If a set is
    // missing dozens of cards, individual lookups are too slow and usually means
    // the online database has not added those cards yet.
    await _fillMissingSetNumbers(
      cardsByKey: cardsByKey,
      setId: setId,
      setName: setName,
      expectedTotal: expectedTotal,
    );

    final allCards = cardsByKey.values.toList()
      ..sort((a, b) => _compareCardNumbers(a.number, b.number));

    _setCardsCache[setId] = List<TcgCard>.from(allCards);
    return allCards;
  }

  static const List<String> _fastMasterSetRarityQueries = <String>[
    'rarity:"Illustration Rare"',
    'rarity:"Special Illustration Rare"',
    'rarity:"Ultra Rare"',
    'rarity:"Hyper Rare"',
    'rarity:"Rare Secret"',
    'rarity:"Secret Rare"',
  ];

  static Future<TcgSet?> _fetchSetById(String setId) async {
    final normalizedSetId = setId.trim();
    if (normalizedSetId.isEmpty) return null;

    final cached = _setByIdCache[normalizedSetId];
    if (cached != null) return cached;

    final inFlight = _setByIdInFlight[normalizedSetId];
    if (inFlight != null) return inFlight;

    final request = () async {
      final uri = Uri.https('api.pokemontcg.io', '/v2/sets/$normalizedSetId');
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final set = TcgSet.fromJson(data['data'] as Map<String, dynamic>);
      _setByIdCache[normalizedSetId] = set;
      return set;
    }();

    _setByIdInFlight[normalizedSetId] = request;
    try {
      return await request;
    } finally {
      _setByIdInFlight.remove(normalizedSetId);
    }
  }

  static Future<String?> resolveSetLogoUrl({
    required String setId,
    required String setName,
    String? fallbackLogoUrl,
  }) async {
    final normalizedSetId = setId.trim();
    final fallback = fallbackLogoUrl?.trim();

    if (normalizedSetId.isEmpty) {
      return (fallback != null && fallback.isNotEmpty) ? fallback : null;
    }

    final set = await _fetchSetById(normalizedSetId);
    final resolved = set?.logoUrl?.trim();
    final resolvedSetName = (set?.name.trim().isNotEmpty ?? false) ? set!.name.trim() : setName.trim();

    final isGenericPromoLogo = _isGenericPromoLogoForSet(
      setId: normalizedSetId,
      setName: resolvedSetName,
      logoUrl: resolved ?? fallback,
    );

    if (isGenericPromoLogo) {
      final originalLogo = await _resolveOriginalLogoForPromoSet(
        setId: normalizedSetId,
        setName: resolvedSetName,
      );

      if (originalLogo != null && originalLogo.trim().isNotEmpty) {
        return originalLogo.trim();
      }

      // Do not return the generic PROMO / Black Star badge if we could not
      // resolve a proper base-set logo. The UI will show a plain text fallback
      // instead of the wrong promo sign.
      return null;
    }

    if (resolved != null && resolved.isNotEmpty) {
      return resolved;
    }

    return (fallback != null && fallback.isNotEmpty) ? fallback : null;
  }

  static bool _isGenericPromoLogoForSet({
    required String setId,
    required String setName,
    String? logoUrl,
  }) {
    final id = setId.toLowerCase().trim();
    final name = setName.toLowerCase().trim();
    final url = logoUrl?.toLowerCase().trim() ?? '';

    return name.contains('promo') ||
        name.contains('black star') ||
        id.endsWith('p') ||
        id.contains('promo') ||
        id.startsWith('svp') ||
        id.startsWith('swshp') ||
        id.startsWith('smp') ||
        id.startsWith('xyp') ||
        id.startsWith('bwp') ||
        id.startsWith('dpp') ||
        url.contains('/promo') ||
        url.contains('promo') ||
        url.contains('blackstar') ||
        url.contains('black-star');
  }

  static String? _knownOriginalSetIdForPromoSet({
    required String setId,
    required String setName,
  }) {
    final id = setId.toLowerCase().trim();
    final name = setName.toLowerCase().trim();

    // These promo sets use generic Black Star / Promo artwork in the API.
    // For the Master Sets page, show the matching original era/base-set logo.
    if (id.startsWith('svp') || name.contains('scarlet') && name.contains('violet')) {
      return 'sv1';
    }
    if (id.startsWith('swshp') || name.contains('sword') && name.contains('shield')) {
      return 'swsh1';
    }
    if (id.startsWith('smp') || name.contains('sun') && name.contains('moon')) {
      return 'sm1';
    }
    if (id.startsWith('xyp') || RegExp(r'\bxy\b').hasMatch(name)) {
      return 'xy1';
    }
    if (id.startsWith('bwp') || name.contains('black') && name.contains('white')) {
      return 'bw1';
    }
    if (id.startsWith('dpp') || name.contains('diamond') && name.contains('pearl')) {
      return 'dp1';
    }

    return null;
  }

  static String _baseSetNameFromPromoSetName(String setName) {
    return setName
        .replaceAll('&', ' ')
        .replaceAll(RegExp(r'\bblack\s+star\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\bpromos?\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\bpromo\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static Future<String?> _resolveOriginalLogoForPromoSet({
    required String setId,
    required String setName,
  }) async {
    final knownBaseSetId = _knownOriginalSetIdForPromoSet(
      setId: setId,
      setName: setName,
    );

    if (knownBaseSetId != null) {
      final knownBaseSet = await _fetchSetById(knownBaseSetId);
      final knownLogo = knownBaseSet?.logoUrl?.trim();
      if (knownLogo != null && knownLogo.isNotEmpty) {
        return knownLogo;
      }
    }

    final baseSetName = _baseSetNameFromPromoSetName(setName);
    if (baseSetName.isEmpty || baseSetName.toLowerCase() == setName.toLowerCase()) {
      return null;
    }

    final searchNames = <String>[
      baseSetName,
      setName
          .replaceAll(RegExp(r'\bblack\s+star\b', caseSensitive: false), ' ')
          .replaceAll(RegExp(r'\bpromos?\b', caseSensitive: false), ' ')
          .replaceAll(RegExp(r'\bpromo\b', caseSensitive: false), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim(),
    ]
        .where((value) => value.trim().isNotEmpty)
        .map((value) => value.trim())
        .toSet()
        .toList();

    final candidatesById = <String, TcgSet>{};
    for (final searchName in searchNames) {
      try {
        final results = await searchSetsOnly(searchName);
        for (final set in results) {
          candidatesById.putIfAbsent(set.id, () => set);
        }
      } catch (_) {
        // Keep trying any other search names.
      }
    }

    final candidates = candidatesById.values.toList();
    if (candidates.isEmpty) return null;

    final baseNormalized = _normalizeSearchMatchText(baseSetName);

    bool isGoodCandidate(TcgSet candidate) {
      final candidateLogo = candidate.logoUrl?.trim();
      if (candidateLogo == null || candidateLogo.isEmpty) return false;
      if (candidate.id.toLowerCase() == setId.toLowerCase()) return false;

      return !_isGenericPromoLogoForSet(
        setId: candidate.id,
        setName: candidate.name,
        logoUrl: candidate.logoUrl,
      );
    }

    TcgSet? exactMatch;
    for (final candidate in candidates) {
      if (!isGoodCandidate(candidate)) continue;
      if (_normalizeSearchMatchText(candidate.name) == baseNormalized) {
        exactMatch = candidate;
        break;
      }
    }

    if (exactMatch != null) return exactMatch.logoUrl;

    TcgSet? containsMatch;
    for (final candidate in candidates) {
      if (!isGoodCandidate(candidate)) continue;
      final candidateName = _normalizeSearchMatchText(candidate.name);
      if (candidateName.startsWith(baseNormalized) ||
          candidateName.contains(baseNormalized) ||
          baseNormalized.contains(candidateName)) {
        containsMatch = candidate;
        break;
      }
    }

    if (containsMatch != null) return containsMatch.logoUrl;

    for (final candidate in candidates) {
      if (isGoodCandidate(candidate)) {
        return candidate.logoUrl;
      }
    }

    return null;
  }


  static Future<List<TcgCard>> _fetchCardsForSetQuery(
    String query, {
    String orderBy = 'number',
    int maxPages = 4,
  }) async {
    const pageSize = 250;
    final cardsById = <String, TcgCard>{};
    var page = 1;

    while (true) {
      final uri = Uri.https('api.pokemontcg.io', '/v2/cards', {
        'q': query,
        'pageSize': '$pageSize',
        'page': '$page',
        'orderBy': orderBy,
      });

      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final items = (data['data'] as List<dynamic>? ?? const []);
      if (items.isEmpty) break;

      for (final item in items) {
        final card = TcgCard.fromJson(item as Map<String, dynamic>);
        cardsById.putIfAbsent(card.id, () => card);
      }

      if (items.length < pageSize || page >= maxPages) {
        break;
      }

      page++;
    }

    return cardsById.values.toList();
  }

  static bool _cardBelongsToRequestedSet({
    required TcgCard card,
    required String setId,
    required String setName,
  }) {
    if (card.setId.trim() == setId.trim()) return true;

    final requested = _normalizeSetNameForFullSetSearch(setName);
    final actual = _normalizeSetNameForFullSetSearch(card.setName);
    if (requested.isEmpty || actual.isEmpty) return false;

    return actual == requested;
  }

  static String _normalizeSetNameForFullSetSearch(String value) {
    return value
        .toLowerCase()
        .replaceAll('&', 'and')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static int _firstCardNumberAsInt(String value) {
    final match = RegExp(r'^0*(\d+)').firstMatch(value.trim());
    if (match == null) return 0;
    return int.tryParse(match.group(1) ?? '') ?? 0;
  }

  static Future<void> _fillMissingSetNumbers({
    required Map<String, TcgCard> cardsByKey,
    required String setId,
    required String setName,
    required int expectedTotal,
  }) async {
    if (expectedTotal <= 0 || expectedTotal > 600) return;

    final existingNumbers = <int>{
      for (final card in cardsByKey.values)
        if (_cardBelongsToRequestedSet(card: card, setId: setId, setName: setName))
          _firstCardNumberAsInt(card.number),
    }..remove(0);

    final missingNumbers = <int>[
      for (var number = 1; number <= expectedTotal; number++)
        if (!existingNumbers.contains(number)) number,
    ];

    if (missingNumbers.isEmpty) return;

    // Keep this small for speed. Large gaps are usually because the public card
    // database has not added the newest cards yet, and checking every number
    // individually makes the page very slow.
    final numbersToFetch = missingNumbers.take(18).toList();

    void addCards(Iterable<TcgCard> cards) {
      for (final card in cards) {
        if (!_cardBelongsToRequestedSet(card: card, setId: setId, setName: setName)) {
          continue;
        }

        final key = card.id.trim().isNotEmpty ? card.id.trim() : _buildSetCardDedupKey(card);
        final existing = cardsByKey[key];
        if (existing == null || _preferCardForSetView(card, existing)) {
          cardsByKey[key] = card;
        }
      }
    }

    final results = await Future.wait(
      numbersToFetch.map((number) => _fetchCardsForMissingSetNumber(
            setId: setId,
            setName: setName,
            number: number,
          )),
    );

    for (final cards in results) {
      addCards(cards);
    }
  }

  static Future<List<TcgCard>> _fetchCardsForMissingSetNumber({
    required String setId,
    required String setName,
    required int number,
  }) async {
    final cardsById = <String, TcgCard>{};

    Future<void> fetch(String query) async {
      final cards = await _fetchCardsForSetQuery(
        query,
        orderBy: 'number',
        maxPages: 1,
      );
      for (final card in cards) {
        cardsById.putIfAbsent(card.id, () => card);
      }
    }

    await fetch('set.id:$setId AND number:$number');

    if (setName.trim().isNotEmpty) {
      await fetch('set.name:"${_escapeTcgQueryValue(setName)}" AND number:$number');
      await fetch('set.name:"${_escapeTcgQueryValue(setName)}" AND number:${number.toString().padLeft(3, '0')}');
    }

    return cardsById.values.toList();
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
      if ((card.rarity ?? '').trim().isNotEmpty) value += 1;
      if (_isSpecialMasterSetRarity(card)) value += 3;
      return value;
    }

    return score(candidate) > score(existing);
  }

  static Future<TcgCard> fetchCardById(String cardId) async {
    final normalizedId = cardId.trim();
    if (normalizedId.isEmpty) {
      throw Exception('Missing card id');
    }

    final cached = _cardByIdCache[normalizedId];
    if (cached != null) {
      return cached;
    }

    final existingFuture = _cardByIdInFlight[normalizedId];
    if (existingFuture != null) {
      return existingFuture;
    }

    final future = () async {
      final uri = Uri.parse('$_baseUrl/cards/$normalizedId');
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final card = TcgCard.fromJson(data['data'] as Map<String, dynamic>);
      _cardByIdCache[normalizedId] = card;
      return card;
    }();

    _cardByIdInFlight[normalizedId] = future;
    try {
      return await future;
    } finally {
      _cardByIdInFlight.remove(normalizedId);
    }
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
  return Uri.https('www.ebay.co.uk', '/sch/i.html', {
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
