import '../services/community_image_services.dart';

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

String _firstNonEmptyString(List<dynamic> values) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return '';
}

String _cleanAccountType(dynamic value) {
  final text = (value ?? '').toString().trim().toLowerCase();
  if (text == 'business') return 'business';
  return 'personal';
}

class AppUserProfile {
  const AppUserProfile({
    required this.uid,
    required this.email,
    required this.username,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.accountType = 'personal',
    this.businessProfileCreated = false,
    this.dateOfBirthMs,
    this.profileImageBase64,
  });

  final String uid;
  final String email;
  final String username;
  final int createdAtMs;
  final int updatedAtMs;
  final String accountType;
  final bool businessProfileCreated;
  final int? dateOfBirthMs;
  final String? profileImageBase64;

  String get displayName => username.trim().isEmpty ? 'Trainer' : username.trim();

  bool get hasProfileImage =>
      profileImageBase64 != null && profileImageBase64!.trim().isNotEmpty;

  bool get hasDateOfBirth => dateOfBirthMs != null && dateOfBirthMs! > 0;

  DateTime? get dateOfBirth =>
      hasDateOfBirth ? DateTime.fromMillisecondsSinceEpoch(dateOfBirthMs!) : null;

  int? get ageYears => dateOfBirth == null ? null : _calculateAgeYears(dateOfBirth!);

  bool get isAdult => (ageYears ?? -1) >= _kCommunityMinimumAge;

  bool get isBusinessAccount => accountType == 'business';

  bool get isPersonalAccount => !isBusinessAccount;

  String get accountTypeLabel => isBusinessAccount ? 'Business' : 'Personal';

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'username': username,
        'createdAtMs': createdAtMs,
        'updatedAtMs': updatedAtMs,
        'accountType': isBusinessAccount ? 'business' : 'personal',
        'businessProfileCreated': businessProfileCreated,
        if (dateOfBirthMs != null) 'dateOfBirthMs': dateOfBirthMs,
        if (hasProfileImage) 'profileImageRef': profileImageBase64!.trim(),
        if (hasProfileImage &&
            !FirebaseImageStorageService.isRemoteRef(profileImageBase64))
          'profileImageBase64': profileImageBase64!.trim(),
      };

  factory AppUserProfile.fromMap(Map<String, dynamic> json) {
    final profileImageRef = _firstNonEmptyString([
      json['profileImageRef'],
      json['profileImageUrl'],
      json['profileImageBase64'],
    ]);

    return AppUserProfile(
      uid: (json['uid'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
      updatedAtMs: (json['updatedAtMs'] as num?)?.toInt() ?? 0,
      accountType: _cleanAccountType(json['accountType']),
      businessProfileCreated: json['businessProfileCreated'] == true,
      dateOfBirthMs: (json['dateOfBirthMs'] as num?)?.toInt(),
      profileImageBase64: profileImageRef.isEmpty ? null : profileImageRef,
    );
  }
}
