import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  StorageService() : _uuid = const Uuid();

  final Uuid _uuid;

  Future<File> saveImage(File source) async {
    final directory = await _imageDirectory();
    final extension = p.extension(source.path).isEmpty
        ? '.jpg'
        : p.extension(source.path);
    final file = File(p.join(directory.path, '${_uuid.v4()}$extension'));
    return source.copy(file.path);
  }

  Future<void> deleteImage(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<Directory> _imageDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(base.path, 'thing_images'));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }
}

