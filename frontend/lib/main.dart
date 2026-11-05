import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');
const _green = Color(0xFF176B4D);
const _ink = Color(0xFF20352D);
const _paper = Color(0xFFF6F8F3);

void main() {
  runApp(const FruitFreshnessApp());
}

class FruitFreshnessApp extends StatelessWidget {
  const FruitFreshnessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cek Kesegaran Buah',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _green,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: _paper,
        fontFamily: 'Roboto',
      ),
      home: const ClassifierPage(),
    );
  }
}

class Prediction {
  const Prediction({required this.label, required this.confidence});

  final String label;
  final double confidence;

  factory Prediction.fromJson(Map<String, dynamic> json) {
    final label = json['class_name'];
    final confidence = json['confidence'];
    if (label is! String || confidence is! num) {
      throw const FormatException('Format hasil prediksi tidak dikenali.');
    }
    return Prediction(label: label, confidence: confidence.toDouble());
  }
}

class _SelectedImage {
  const _SelectedImage({required this.file, required this.bytes});

  final PlatformFile file;
  final Uint8List bytes;
}

class ClassifierPage extends StatefulWidget {
  const ClassifierPage({super.key});

  @override
  State<ClassifierPage> createState() => _ClassifierPageState();
}

class _ClassifierPageState extends State<ClassifierPage> {
  _SelectedImage? _selectedImage;
  List<Prediction> _predictions = const [];
  String? _errorMessage;
  String? _modelName;
  double? _validationAccuracy;
  bool _isLoading = false;

  Uri get _predictionUri => _apiBaseUrl.isEmpty
      ? Uri.base.resolve('api/predict')
      : Uri.parse('$_apiBaseUrl/api/predict');

  Future<void> _pickImage() async {
    final file = await FilePicker.pickFile(type: FileType.image);
    if (file == null) return;

    final size = await file.length();
    if (size == null) {
      setState(() {
        _errorMessage = 'Gambar tidak dapat dibaca. Coba pilih file lain.';
      });
      return;
    }
    if (size > 10 * 1024 * 1024) {
      setState(() {
        _errorMessage = 'Ukuran gambar maksimal 10 MB.';
      });
      return;
    }
    final bytes = await file.readAsBytes();

    setState(() {
      _selectedImage = _SelectedImage(file: file, bytes: bytes);
      _predictions = const [];
      _errorMessage = null;
    });
  }

  Future<void> _predict() async {
    final image = _selectedImage;
    if (image == null) {
      setState(() {
        _errorMessage = 'Pilih gambar buah terlebih dahulu.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _predictions = const [];
    });

    try {
      final request = http.MultipartRequest('POST', _predictionUri)
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            image.bytes,
            filename: image.file.name,
          ),
        );
      final streamed = await request.send().timeout(
            const Duration(minutes: 2),
          );
      final response = await http.Response.fromStream(streamed);
      final decoded = jsonDecode(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = decoded is Map<String, dynamic>
            ? decoded['detail']
            : null;
        throw _ApiException(
          detail is String ? detail : 'Prediksi gagal (${response.statusCode}).',
        );
      }
      if (decoded is! Map<String, dynamic> ||
          decoded['top_predictions'] is! List) {
        throw const FormatException('Respons prediksi dari server tidak valid.');
      }

      final results = (decoded['top_predictions'] as List)
          .map(
            (item) => Prediction.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
      final accuracy = decoded['validation_accuracy'];

      if (!mounted) return;
      setState(() {
        _predictions = results;
        _modelName = decoded['model'] as String?;
        _validationAccuracy =
            accuracy is num ? accuracy.toDouble() : null;
      });
    } on TimeoutException {
      _setError('Server terlalu lama merespons. Coba lagi sebentar lagi.');
    } on http.ClientException {
      _setError('Tidak dapat terhubung ke server prediksi.');
    } on FormatException catch (error) {
      _setError(error.message);
    } on _ApiException catch (error) {
      _setError(error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setError(String message) {
    if (mounted) setState(() => _errorMessage = message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 28),
                  _buildModelNotice(),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 680;
                      final uploadPanel = _buildUploadPanel();
                      final resultPanel = _buildResultPanel();
                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: uploadPanel),
                            const SizedBox(width: 20),
                            Expanded(child: resultPanel),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          uploadPanel,
                          const SizedBox(height: 20),
                          resultPanel,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Hasil model adalah prediksi eksperimental, bukan '
                    'jaminan keamanan atau kelayakan konsumsi buah.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFE2F1E8),
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Icon(Icons.eco_rounded, color: _green, size: 36),
        ),
        const SizedBox(height: 16),
        const Text(
          'Cek Kesegaran Buah',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _ink,
            fontSize: 30,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Unggah foto buah untuk melihat prediksi jenis dan kondisinya.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54, fontSize: 15, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildModelNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5DF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF2D99F)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Color(0xFF8A5A00)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Demo penelitian: checkpoint yang tersedia adalah MLP baseline '
              'dengan akurasi validasi 58,95%. Prediksi masih dapat keliru.',
              style: TextStyle(color: Color(0xFF654300), height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadPanel() {
    return _panel(
      title: '1. Pilih gambar',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _isLoading ? null : _pickImage,
            child: Container(
              height: 270,
              decoration: BoxDecoration(
                color: _paper,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDCE5DE)),
              ),
              child: _selectedImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.memory(
                        _selectedImage!.bytes,
                        fit: BoxFit.contain,
                      ),
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 48,
                          color: _green,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Ketuk untuk memilih foto',
                          style: TextStyle(
                            color: _ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'JPG, PNG, atau format gambar lain · maks. 10 MB',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                      ],
                    ),
            ),
          ),
          if (_selectedImage != null) ...[
            const SizedBox(height: 10),
            Text(
              _selectedImage!.file.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isLoading
                ? null
                : _selectedImage == null
                    ? _pickImage
                    : _predict,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _selectedImage == null
                        ? Icons.upload_rounded
                        : Icons.auto_awesome,
                  ),
            label: Text(
              _isLoading
                  ? 'Sedang menganalisis...'
                  : _selectedImage == null
                      ? 'Pilih foto'
                      : 'Analisis gambar',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _green,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultPanel() {
    return _panel(
      title: '2. Hasil prediksi',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 72),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_errorMessage != null)
            _buildMessage(
              icon: Icons.error_outline,
              color: const Color(0xFFB3261E),
              message: _errorMessage!,
            )
          else if (_predictions.isNotEmpty) ...[
            Text(
              _modelName ?? 'Model klasifikasi',
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
            if (_validationAccuracy != null) ...[
              const SizedBox(height: 4),
              Text(
                'Akurasi validasi model: '
                '${(_validationAccuracy! * 100).toStringAsFixed(2)}%',
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
            const SizedBox(height: 18),
            for (var index = 0; index < _predictions.length; index++)
              _buildPredictionRow(_predictions[index], index),
          ] else
            _buildMessage(
              icon: Icons.search_rounded,
              color: _green,
              message:
                  'Hasil prediksi akan muncul di sini setelah gambar dianalisis.',
            ),
        ],
      ),
    );
  }

  Widget _buildPredictionRow(Prediction prediction, int index) {
    final percentage = prediction.confidence.clamp(0.0, 1.0);
    final isFresh = prediction.label.toLowerCase().contains('segar');
    final color = isFresh ? _green : const Color(0xFFB56B18);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  prediction.label,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${(percentage * 100).toStringAsFixed(1)}%',
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 8,
              backgroundColor: const Color(0xFFE9EEE9),
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required Color color,
    required String message,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 12),
      child: Column(
        children: [
          Icon(icon, size: 38, color: color),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _panel({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0B20352D),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ApiException implements Exception {
  const _ApiException(this.message);

  final String message;
}
