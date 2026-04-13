import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class PlantPhotoService {
  PlantPhotoService._();

  static final ImagePicker _picker = ImagePicker();

  static Future<List<String>> pickAndStoreImages() async {
    final picked = await _picker.pickMultiImage(requestFullMetadata: false);
    if (picked.isEmpty) {
      return const [];
    }

    final photoDir = await _photoDirectory();
    final storedPaths = <String>[];
    for (final image in picked) {
      final storedFile = await _storedFileFor(image, photoDir);
      await image.saveTo(storedFile.path);
      storedPaths.add(storedFile.path);
    }
    return storedPaths;
  }

  static Future<void> deleteStoredPhoto(String path) async {
    try {
      final file = File(path);
      final photoDir = await _photoDirectory();
      if (!file.path.startsWith('${photoDir.path}${Platform.pathSeparator}')) {
        return;
      }
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best-effort cleanup only. A failed delete should not block editing.
    }
  }

  static Future<Directory> _photoDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}plant_photos');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<File> _storedFileFor(XFile source, Directory dir) async {
    final extension = _extensionFor(source);
    var counter = 0;
    while (true) {
      final suffix = counter == 0 ? '' : '_$counter';
      final filename =
          'plant_${DateTime.now().microsecondsSinceEpoch}$suffix$extension';
      final file = File('${dir.path}${Platform.pathSeparator}$filename');
      if (!await file.exists()) {
        return file;
      }
      counter += 1;
    }
  }

  static String _extensionFor(XFile source) {
    final path = source.path;
    final dot = path.lastIndexOf('.');
    if (dot >= 0 && dot < path.length - 1) {
      final raw = path.substring(dot).toLowerCase();
      final valid = RegExp(r'^\.[a-z0-9]{1,8}$').hasMatch(raw);
      if (valid) {
        return raw;
      }
    }
    final mimeType = source.mimeType?.toLowerCase();
    return switch (mimeType) {
      'image/png' => '.png',
      'image/webp' => '.webp',
      'image/gif' => '.gif',
      _ => '.jpg',
    };
  }
}
