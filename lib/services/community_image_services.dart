import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

class FirebaseImageStorageService {
  static const int _maxUploadImageBytes = 420 * 1024;
  static const int _maxUploadDimension = 1280;

  static const Set<String> _allowedImageExtensions = <String>{
    'jpg',
    'jpeg',
    'png',
    'webp',
  };

  static const Set<String> _allowedImageMimeTypes = <String>{
    'image/jpeg',
    'image/png',
    'image/webp',
  };

  static bool isRemoteRef(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return false;
    return trimmed.startsWith('https://') ||
        trimmed.startsWith('http://') ||
        trimmed.startsWith('gs://');
  }

  static String _safePathPart(String value, {String fallback = 'image'}) {
    final cleaned = value
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\-/]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'/+'), '/')
        .trim();
    return cleaned.isEmpty ? fallback : cleaned;
  }

  static String _extensionFromName(String value) {
    final cleanValue = value.trim().toLowerCase();
    if (!cleanValue.contains('.')) return '';
    return cleanValue.split('.').last;
  }

  static void _ensureAllowedImageBytes({
    required Uint8List bytes,
    required String path,
    String? fileName,
  }) {
    final nameForExtension = (fileName?.trim().isNotEmpty ?? false)
        ? fileName!.trim()
        : path.trim();

    final extension = _extensionFromName(nameForExtension);

    final mimeType = lookupMimeType(
      nameForExtension,
      headerBytes: bytes.take(64).toList(),
    );

    final hasAllowedExtension = _allowedImageExtensions.contains(extension);
    final hasAllowedMimeType =
        mimeType != null && _allowedImageMimeTypes.contains(mimeType);

    if (!hasAllowedExtension || !hasAllowedMimeType) {
      throw Exception('Please choose a JPG, PNG or WEBP picture only.');
    }
  }

  static Future<Uint8List> prepareJpegBytesForUpload(
    String path, {
    String? fileName,
    int maxBytes = _maxUploadImageBytes,
    int maxDimension = _maxUploadDimension,
  }) async {
    final bytes = await File(path).readAsBytes();

    _ensureAllowedImageBytes(
      bytes: bytes,
      path: path,
      fileName: fileName,
    );

    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Could not read this image.');
    }

    img.Image current = img.bakeOrientation(decoded);
    if (current.width > maxDimension || current.height > maxDimension) {
      current = img.copyResize(
        current,
        width: current.width >= current.height ? maxDimension : null,
        height: current.height > current.width ? maxDimension : null,
        interpolation: img.Interpolation.average,
      );
    }

    var quality = 86;
    List<int> encoded = img.encodeJpg(current, quality: quality);

    while (encoded.length > maxBytes && quality > 52) {
      quality -= 8;
      encoded = img.encodeJpg(current, quality: quality);
    }

    while (encoded.length > maxBytes &&
        (current.width > 640 || current.height > 640)) {
      current = img.copyResize(
        current,
        width: current.width >= current.height
            ? math.max(640, (current.width * 0.82).round())
            : null,
        height: current.height > current.width
            ? math.max(640, (current.height * 0.82).round())
            : null,
        interpolation: img.Interpolation.average,
      );
      quality = math.min(quality, 72);
      encoded = img.encodeJpg(current, quality: quality);
      while (encoded.length > maxBytes && quality > 44) {
        quality -= 6;
        encoded = img.encodeJpg(current, quality: quality);
      }
    }

    if (encoded.length > maxBytes) {
      throw Exception(
        'This photo is still too large. Try cropping it tighter or choosing a different photo.',
      );
    }

    return Uint8List.fromList(encoded);
  }

  static Future<String> uploadImageFile({
    required String path,
    required String folder,
    String? originalFileName,
    String fileNamePrefix = 'image',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('You need to be signed in to upload images.');
    }

    final uploadBytes = await prepareJpegBytesForUpload(
      path,
      fileName: originalFileName,
    );

    final safeFolder = _safePathPart(folder, fallback: 'community_images');
    final safePrefix =
        _safePathPart(fileNamePrefix, fallback: 'image').replaceAll('/', '_');

    final fileName = '${safePrefix}_${DateTime.now().microsecondsSinceEpoch}.jpg';

    final storageRef = FirebaseStorage.instance
        .ref()
        .child('$safeFolder/${user.uid}/$fileName');

    await storageRef.putData(
      uploadBytes,
      SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: <String, String>{
          'ownerUid': user.uid,
          'source': 'PocketChase',
          'originalFileName': originalFileName ?? '',
        },
      ),
    );

    return storageRef.getDownloadURL();
  }

  static Future<void> deleteByDownloadUrl(String? imageRef) async {
    final trimmed = imageRef?.trim() ?? '';
    if (!isRemoteRef(trimmed)) return;
    try {
      await FirebaseStorage.instance.refFromURL(trimmed).delete();
    } catch (_) {}
  }
}

class CommunityImageCodec {
  static const int maxImagesPerPost = 10;
  static const int _maxImageBytes = 56 * 1024;
  static const int _maxDimension = 760;

  static Future<List<String>> pickAndEncodeMultiFromGallery({
    int limit = maxImagesPerPost,
    String storageFolder = 'community_images',
  }) async {
    final picker = ImagePicker();

    final picked = await picker.pickMultiImage(
      imageQuality: 82,
      maxWidth: 1600,
      maxHeight: 1600,
    );

    if (picked.isEmpty) return const <String>[];

    final storedRefs = <String>[];

    for (final file in picked.take(limit)) {
      storedRefs.add(
        await storeFileForFirestore(
          file.path,
          originalFileName: file.name,
          storageFolder: storageFolder,
        ),
      );
    }

    return storedRefs;
  }

  static Future<String?> pickAndEncodeSingle(
    ImageSource source, {
    String storageFolder = 'community_images',
  }) async {
    final picker = ImagePicker();

    final picked = await picker.pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1600,
      maxHeight: 1600,
    );

    if (picked == null) return null;

    return storeFileForFirestore(
      picked.path,
      originalFileName: picked.name,
      storageFolder: storageFolder,
    );
  }

  static Future<String> storeFileForFirestore(
    String path, {
    String? originalFileName,
    String storageFolder = 'community_images',
    bool allowBase64Fallback = true,
  }) async {
    try {
      return await FirebaseImageStorageService.uploadImageFile(
        path: path,
        folder: storageFolder,
        originalFileName: originalFileName,
      );
    } catch (_) {
      if (!allowBase64Fallback) rethrow;

      return encodeFileAsBase64(
        path,
        originalFileName: originalFileName,
      );
    }
  }

  static Future<String> encodeFileAsBase64(
    String path, {
    String? originalFileName,
  }) async {
    final bytes = await File(path).readAsBytes();

    FirebaseImageStorageService._ensureAllowedImageBytes(
      bytes: bytes,
      path: path,
      fileName: originalFileName,
    );

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
    if (FirebaseImageStorageService.isRemoteRef(imageBase64)) return null;

    try {
      return base64Decode(imageBase64);
    } catch (_) {
      return null;
    }
  }
}