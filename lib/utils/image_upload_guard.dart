import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

class PickedImageForUpload {
  const PickedImageForUpload({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
  });

  final String fileName;
  final String mimeType;
  final Uint8List bytes;

  String get base64String => base64Encode(bytes);
}

class ImageUploadGuard {
  static const Set<String> _allowedExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
  };

  static const int defaultMaxBytes = 5 * 1024 * 1024; // 5MB

  static Future<PickedImageForUpload?> pickImageOnly({
    required BuildContext context,
    ImageSource source = ImageSource.gallery,
    int maxBytes = defaultMaxBytes,
  }) async {
    final ImagePicker picker = ImagePicker();

    final XFile? pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 85,
    );

    if (pickedFile == null) return null;

    final String fileName = pickedFile.name;
    final String lowerName = fileName.toLowerCase();

    final String extension = lowerName.contains('.')
        ? lowerName.split('.').last
        : '';

    final Uint8List bytes = await pickedFile.readAsBytes();

    final String? mimeType = lookupMimeType(
      fileName,
      headerBytes: bytes.take(32).toList(),
    );

    final bool hasAllowedExtension = _allowedExtensions.contains(extension);
    final bool hasImageMimeType =
        mimeType != null && mimeType.startsWith('image/');
    final bool isSmallEnough = bytes.length <= maxBytes;

    if (!hasAllowedExtension || !hasImageMimeType) {
      if (!context.mounted) return null;

      _showMessage(
        context,
        'Please choose a picture only. Allowed types: JPG, PNG or WEBP.',
      );
      return null;
    }

    if (!isSmallEnough) {
      if (!context.mounted) return null;

      _showMessage(
        context,
        'That image is too large. Please choose an image under ${maxBytes ~/ (1024 * 1024)}MB.',
      );
      return null;
    }

    return PickedImageForUpload(
      fileName: fileName,
      mimeType: mimeType,
      bytes: bytes,
    );
  }

  static void _showMessage(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}