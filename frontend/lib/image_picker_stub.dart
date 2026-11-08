import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

class PickedImage {
  const PickedImage({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

Future<PickedImage?> pickImage({bool captureFromCamera = false}) async {
  final file = await FilePicker.pickFile(type: FileType.image);
  if (file == null) return null;
  return PickedImage(name: file.name, bytes: await file.readAsBytes());
}

bool get cameraCaptureAvailable => false;

final Map<String, String> _storedValues = {};

Future<String?> readStoredValue(String key) async => _storedValues[key];

Future<void> writeStoredValue(String key, String value) async {
  _storedValues[key] = value;
}

Future<void> downloadTextFile(String filename, String content) async {
  throw UnsupportedError('Unduh laporan hanya tersedia pada aplikasi web.');
}
