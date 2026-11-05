import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

class PickedImage {
  const PickedImage({
    required this.name,
    required this.bytes,
  });

  final String name;
  final Uint8List bytes;
}

Future<PickedImage?> pickImage() async {
  final file = await FilePicker.pickFile(type: FileType.image);
  if (file == null) return null;
  return PickedImage(name: file.name, bytes: await file.readAsBytes());
}
