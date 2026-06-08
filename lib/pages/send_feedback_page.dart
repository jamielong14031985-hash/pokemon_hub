import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/app_user_profile.dart';

class SendFeedbackPage extends StatefulWidget {
  const SendFeedbackPage({
    super.key,
    this.profile,
  });

  final AppUserProfile? profile;

  @override
  State<SendFeedbackPage> createState() => _SendFeedbackPageState();
}

class _SendFeedbackPageState extends State<SendFeedbackPage> {
  static const Color _backgroundColor = Color(0xFF041B4A);
  static const Color _cardColor = Color(0xFF102754);
  static const Color _fieldColor = Color(0xFF16366E);
  static const Color _borderColor = Color(0xFF3F5C96);
  static const Color _goldColor = Color(0xFFF7DE77);
  static const Color _softTextColor = Color(0xFFC8D4F0);
  static const Color _successColor = Color(0xFF4ADE80);

  static const int _maxScreenshots = 4;
  static const int _maxImageBytes = 5 * 1024 * 1024;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _screenController = TextEditingController();
  final TextEditingController _tryingToDoController = TextEditingController();
  final TextEditingController _whatHappenedController = TextEditingController();
  final TextEditingController _expectedController = TextEditingController();
  final TextEditingController _stepsController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _deviceController = TextEditingController();
  final TextEditingController _versionController = TextEditingController();

  String _selectedType = 'Problem';
  String _selectedImpact = 'Something looks wrong';
  bool _submitting = false;

  final List<_PickedFeedbackImage> _images = <_PickedFeedbackImage>[];

  static const List<String> _feedbackTypes = <String>[
    'Problem',
    'App crash',
    'Looks wrong',
    'Confusing',
    'Price issue',
    'Card issue',
    'Map / shop issue',
    'Community issue',
    'Idea',
    'Other',
  ];

  static const List<String> _impactLevels = <String>[
    'Can’t use this feature',
    'Something is broken',
    'Something looks wrong',
    'It is confusing',
    'Small improvement',
  ];

  @override
  void initState() {
    super.initState();
    final email = widget.profile?.email.trim() ?? '';
    if (email.isNotEmpty) {
      _contactController.text = email;
    }
    _deviceController.text = defaultTargetPlatform.name;
  }

  @override
  void dispose() {
    _screenController.dispose();
    _tryingToDoController.dispose();
    _whatHappenedController.dispose();
    _expectedController.dispose();
    _stepsController.dispose();
    _contactController.dispose();
    _deviceController.dispose();
    _versionController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: _softTextColor),
      hintStyle: const TextStyle(color: Color(0xFFAFC0E6)),
      floatingLabelStyle: const TextStyle(
        color: _goldColor,
        fontWeight: FontWeight.w900,
      ),
      prefixIcon: icon == null ? null : Icon(icon, color: _softTextColor),
      filled: true,
      fillColor: _fieldColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _goldColor, width: 1.6),
      ),
    );
  }

  Future<void> _pickScreenshots() async {
    if (_submitting) return;

    final remaining = _maxScreenshots - _images.length;
    if (remaining <= 0) {
      _showMessage('You can add up to $_maxScreenshots screenshots.');
      return;
    }

    try {
      final picked = await _imagePicker.pickMultiImage(
        maxWidth: 1600,
        imageQuality: 82,
      );

      if (picked.isEmpty) return;

      final newImages = <_PickedFeedbackImage>[];

      for (final file in picked.take(remaining)) {
        final bytes = await file.readAsBytes();

        if (bytes.length > _maxImageBytes) {
          _showMessage('${file.name} is too large. Please choose an image under 5MB.');
          continue;
        }

        newImages.add(
          _PickedFeedbackImage(
            name: file.name.isEmpty
                ? 'screenshot_${DateTime.now().millisecondsSinceEpoch}.jpg'
                : file.name,
            bytes: bytes,
          ),
        );
      }

      if (newImages.isEmpty) return;

      if (!mounted) return;
      setState(() {
        _images.addAll(newImages);
      });
    } catch (error) {
      _showMessage('Could not add screenshots: $error');
    }
  }

  void _removeImage(int index) {
    if (index < 0 || index >= _images.length || _submitting) return;

    setState(() {
      _images.removeAt(index);
    });
  }

  bool _validateForm() {
    final screen = _screenController.text.trim();
    final trying = _tryingToDoController.text.trim();
    final happened = _whatHappenedController.text.trim();
    final device = _deviceController.text.trim();

    if (screen.isEmpty) {
      _showMessage('Please add which screen or page the problem is on.');
      return false;
    }

    if (trying.isEmpty) {
      _showMessage('Please say what you were trying to do.');
      return false;
    }

    if (happened.isEmpty) {
      _showMessage('Please explain what happened.');
      return false;
    }

    if (device.isEmpty) {
      _showMessage('Please add what device they are using.');
      return false;
    }

    return true;
  }

  Future<List<_UploadedFeedbackImage>> _uploadImages({
    required String userId,
    required String reportId,
  }) async {
    final uploaded = <_UploadedFeedbackImage>[];

    for (var index = 0; index < _images.length; index += 1) {
      final image = _images[index];
      final cleanName = image.name
          .replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_')
          .replaceAll(RegExp(r'_+'), '_');
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${index + 1}_$cleanName';
      final path = 'feedback_reports/$userId/$reportId/$fileName';
      final ref = _storage.ref(path);

      final contentType = _contentTypeForName(cleanName);

      await ref.putData(
        image.bytes,
        SettableMetadata(
          contentType: contentType,
          customMetadata: <String, String>{
            'userId': userId,
            'reportId': reportId,
            'app': 'PocketChase',
          },
        ),
      );

      final downloadUrl = await ref.getDownloadURL();

      uploaded.add(
        _UploadedFeedbackImage(
          url: downloadUrl,
          storagePath: path,
          fileName: cleanName,
          sizeBytes: image.bytes.length,
        ),
      );
    }

    return uploaded;
  }

  String _contentTypeForName(String name) {
    final lower = name.toLowerCase();

    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';

    return 'image/jpeg';
  }

  Future<void> _submitReport() async {
    if (_submitting) return;
    if (!_validateForm()) return;

    final profile = widget.profile;
    final userId = (profile?.uid.trim().isNotEmpty == true)
        ? profile!.uid.trim()
        : 'unknown_user';

    setState(() {
      _submitting = true;
    });

    final reportRef = _firestore.collection('feedback_reports').doc();

    try {
      final uploadedImages = await _uploadImages(
        userId: userId,
        reportId: reportRef.id,
      );

      await reportRef.set(<String, dynamic>{
        'app': 'PocketChase',
        'type': _selectedType,
        'impact': _selectedImpact,
        'screen': _screenController.text.trim(),
        'tryingToDo': _tryingToDoController.text.trim(),
        'whatHappened': _whatHappenedController.text.trim(),
        'expectedResult': _expectedController.text.trim(),
        'stepsToReproduce': _stepsController.text.trim(),
        'contactEmail': _contactController.text.trim(),
        'deviceUsed': _deviceController.text.trim(),
        'versionInfo': _versionController.text.trim(),
        'status': 'new',
        'adminNotes': '',
        'createdAt': FieldValue.serverTimestamp(),
        'createdAtMs': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
        'devicePlatform': defaultTargetPlatform.name,
        'imageCount': uploadedImages.length,
        'imageUrls': uploadedImages.map((image) => image.url).toList(),
        'imageStoragePaths':
            uploadedImages.map((image) => image.storagePath).toList(),
        'images': uploadedImages.map((image) => image.toJson()).toList(),
        'userId': userId,
        'userEmail': profile?.email ?? '',
        'username': profile?.username ?? '',
        'accountType': profile?.accountType ?? '',
      });

      if (!mounted) return;

      await _showSuccessDialog(reportRef.id);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) return;
      _showMessage('Could not send report: $error');
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _showSuccessDialog(String reportId) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _cardColor,
          title: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: _successColor),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Report sent',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Thanks — your report has been sent to the admins.\n\nReference: $reportId',
            style: const TextStyle(
              color: _softTextColor,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _goldColor,
                foregroundColor: _backgroundColor,
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Done',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _goldColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.feedback_outlined, color: _goldColor, size: 38),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Report a problem',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Answer a few quick questions and add screenshots so admins can see exactly what happened.',
                  style: TextStyle(
                    color: _softTextColor,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceSection({
    required String title,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              final isSelected = option == selected;
              return ChoiceChip(
                label: Text(option),
                selected: isSelected,
                backgroundColor: _fieldColor,
                selectedColor: _goldColor,
                side: BorderSide(
                  color: isSelected ? _goldColor : _borderColor,
                ),
                labelStyle: TextStyle(
                  color: isSelected ? _backgroundColor : Colors.white,
                  fontWeight: FontWeight.w900,
                ),
                onSelected: (_) => onSelected(option),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildScreenshotsSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Screenshots',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add up to 4 screenshots so admins can see the exact problem.',
            style: TextStyle(
              color: _softTextColor,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (_images.isNotEmpty) ...[
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _images.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.74,
              ),
              itemBuilder: (context, index) {
                return _ScreenshotPreviewTile(
                  image: _images[index],
                  onRemove: _submitting ? null : () => _removeImage(index),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed:
                  _submitting || _images.length >= _maxScreenshots
                      ? null
                      : _pickScreenshots,
              style: OutlinedButton.styleFrom(
                foregroundColor: _goldColor,
                side: const BorderSide(color: _goldColor),
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                _images.isEmpty
                    ? 'Add screenshots'
                    : 'Add more screenshots (${_images.length}/$_maxScreenshots)',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return FilledButton.icon(
      onPressed: _submitting ? null : _submitReport,
      style: FilledButton.styleFrom(
        backgroundColor: _goldColor,
        foregroundColor: _backgroundColor,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      icon: _submitting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.send_rounded),
      label: Text(
        _submitting ? 'Sending report...' : 'Send report to admins',
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Report a problem'),
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            _buildHeroCard(),
            const SizedBox(height: 14),
            _buildChoiceSection(
              title: 'What is this about?',
              options: _feedbackTypes,
              selected: _selectedType,
              onSelected: (value) {
                setState(() {
                  _selectedType = value;
                });
              },
            ),
            const SizedBox(height: 14),
            _buildChoiceSection(
              title: 'How bad is it?',
              options: _impactLevels,
              selected: _selectedImpact,
              onSelected: (value) {
                setState(() {
                  _selectedImpact = value;
                });
              },
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _screenController,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              cursorColor: _goldColor,
              decoration: _inputDecoration(
                label: 'Screen/page',
                hint: 'Example: Card details, Community, TCG Shop Map...',
                icon: Icons.screenshot_monitor_outlined,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _tryingToDoController,
              minLines: 2,
              maxLines: 4,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              cursorColor: _goldColor,
              decoration: _inputDecoration(
                label: 'What were you trying to do?',
                hint: 'Example: I was trying to add a reverse holo card...',
                icon: Icons.touch_app_outlined,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _whatHappenedController,
              minLines: 3,
              maxLines: 6,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              cursorColor: _goldColor,
              decoration: _inputDecoration(
                label: 'What happened?',
                hint: 'Explain the problem or what looked wrong.',
                icon: Icons.report_problem_outlined,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _expectedController,
              minLines: 2,
              maxLines: 5,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              cursorColor: _goldColor,
              decoration: _inputDecoration(
                label: 'What should have happened?',
                hint: 'Example: It should only add the normal version.',
                icon: Icons.check_circle_outline,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _stepsController,
              minLines: 3,
              maxLines: 7,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              cursorColor: _goldColor,
              decoration: _inputDecoration(
                label: 'Steps to repeat the problem',
                hint:
                    'Example: 1. Open Master Sets\n2. Tap Base Set\n3. Hold Weedle...',
                icon: Icons.format_list_numbered_outlined,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _contactController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              cursorColor: _goldColor,
              decoration: _inputDecoration(
                label: 'Contact email',
                hint: 'Optional, but useful if admins need more detail.',
                icon: Icons.alternate_email,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _deviceController,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              cursorColor: _goldColor,
              decoration: _inputDecoration(
                label: 'What device are you using?',
                hint: 'Example: Samsung S23, iPhone 14, iPad, Pixel 8...',
                icon: Icons.phone_android_outlined,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _versionController,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              cursorColor: _goldColor,
              decoration: _inputDecoration(
                label: 'What app / phone version?',
                hint: 'Example: Android 15, iOS 18, app version 1.0.4...',
                icon: Icons.info_outline,
              ),
            ),
            const SizedBox(height: 14),
            _buildScreenshotsSection(),
            const SizedBox(height: 18),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }
}

class _ScreenshotPreviewTile extends StatelessWidget {
  const _ScreenshotPreviewTile({
    required this.image,
    required this.onRemove,
  });

  final _PickedFeedbackImage image;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              image.bytes,
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _SendFeedbackPageState._borderColor),
            ),
          ),
        ),
        Positioned(
          right: 2,
          top: 2,
          child: InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 15,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PickedFeedbackImage {
  const _PickedFeedbackImage({
    required this.name,
    required this.bytes,
  });

  final String name;
  final Uint8List bytes;
}

class _UploadedFeedbackImage {
  const _UploadedFeedbackImage({
    required this.url,
    required this.storagePath,
    required this.fileName,
    required this.sizeBytes,
  });

  final String url;
  final String storagePath;
  final String fileName;
  final int sizeBytes;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'url': url,
      'storagePath': storagePath,
      'fileName': fileName,
      'sizeBytes': sizeBytes,
    };
  }
}
