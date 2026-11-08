// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:html' as html;

class PickedImage {
  const PickedImage({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

bool get cameraCaptureAvailable => true;

Future<PickedImage?> pickImage({bool captureFromCamera = false}) async {
  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..multiple = false
    ..style.display = 'none';
  if (captureFromCamera) input.setAttribute('capture', 'environment');
  html.document.body?.append(input);

  try {
    input.click();
    await input.onChange.first;
    final file = input.files?.isNotEmpty == true ? input.files!.first : null;
    if (file == null) return null;

    final reader = html.FileReader();
    final load = reader.onLoad.first;
    reader.readAsDataUrl(file);
    await load;
    final result = reader.result;
    if (result is! String) {
      throw StateError('Browser tidak dapat membaca gambar.');
    }
    final separator = result.indexOf(',');
    if (separator < 0) {
      throw StateError('Format data gambar tidak dikenali.');
    }
    return PickedImage(
      name: file.name,
      bytes: Uint8List.fromList(base64Decode(result.substring(separator + 1))),
    );
  } finally {
    input.remove();
  }
}

Future<String?> readStoredValue(String key) async =>
    html.window.localStorage[key];

Future<void> writeStoredValue(String key, String value) async {
  html.window.localStorage[key] = value;
}

Future<void> downloadTextFile(String filename, String content) async {
  final blob = html.Blob([
    Uint8List.fromList(utf8.encode(content)),
  ], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  try {
    final link = html.AnchorElement(href: url)
      ..download = filename
      ..style.display = 'none';
    html.document.body?.append(link);
    link.click();
    link.remove();
  } finally {
    html.Url.revokeObjectUrl(url);
  }
}
