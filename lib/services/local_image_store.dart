import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
