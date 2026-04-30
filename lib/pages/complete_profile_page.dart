import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/app_user_profile.dart';
import '../services/local_image_store.dart';
import '../services/user_profile_service.dart';
import '../utils/date_helpers.dart';
import '../widgets/full_screen_loader.dart';

const int _kCommunityMinimumAge = 18;

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
      _selectedDateOfBirth = dateOnly(picked);
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
    final existingImageFile = imageFile != null && imageFile.existsSync() ? imageFile : null;
    final imageExists = existingImageFile != null;

    if (_loadingProfileData) {
      return const FullScreenLoader();
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
                                backgroundImage: existingImageFile != null ? FileImage(existingImageFile) : null,
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
                                      : formatDateOfBirth(_selectedDateOfBirth!),
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
                          calculateAgeYears(_selectedDateOfBirth!) >= _kCommunityMinimumAge
                              ? 'You can access the Community page once your profile is saved.'
                              : 'Users under $_kCommunityMinimumAge cannot access the Community page.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: calculateAgeYears(_selectedDateOfBirth!) >= _kCommunityMinimumAge
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

