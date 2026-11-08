import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'image_picker.dart';

const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');
const _green = Color(0xFF176B4D);
const _ink = Color(0xFF20352D);
const _paper = Color(0xFFF6F8F3);
const _historyStorageKey = 'fruit_freshness_prediction_history';
const _maxHistoryEntries = 10;

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

  Map<String, Object> toJson() => {
    'class_name': label,
    'confidence': confidence,
  };

  factory Prediction.fromJson(Map<String, dynamic> json) {
    final label = json['class_name'];
    final confidence = json['confidence'];
    if (label is! String || confidence is! num) {
      throw const FormatException('Format hasil prediksi tidak dikenali.');
    }
    return Prediction(label: label, confidence: confidence.toDouble());
  }
}

class _HistoryEntry {
  const _HistoryEntry({
    required this.filename,
    required this.createdAt,
    required this.model,
    required this.predictions,
  });

  final String filename;
  final DateTime createdAt;
  final String model;
  final List<Prediction> predictions;

  Map<String, Object> toJson() => {
    'filename': filename,
    'created_at': createdAt.toIso8601String(),
    'model': model,
    'predictions': predictions
        .map((prediction) => prediction.toJson())
        .toList(),
  };

  factory _HistoryEntry.fromJson(Map<String, dynamic> json) {
    final filename = json['filename'];
    final createdAt = json['created_at'];
    final model = json['model'];
    final predictions = json['predictions'];
    if (filename is! String ||
        createdAt is! String ||
        model is! String ||
        predictions is! List) {
      throw const FormatException('Format riwayat prediksi tidak dikenali.');
    }
    return _HistoryEntry(
      filename: filename,
      createdAt: DateTime.parse(createdAt),
      model: model,
      predictions: predictions
          .map(
            (item) =>
                Prediction.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
    );
  }
}

class _SelectedImage {
  const _SelectedImage({required this.name, required this.bytes});

  final String name;
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
  bool? _apiOnline;
  bool _checkingApi = false;
  List<_HistoryEntry> _history = const [];

  Uri get _predictionUri => _apiBaseUrl.isEmpty
      ? Uri.base.resolve('api/predict')
      : Uri.parse('$_apiBaseUrl/api/predict');

  Uri get _healthUri => _apiBaseUrl.isEmpty
      ? Uri.base.resolve('api/health')
      : Uri.parse('$_apiBaseUrl/api/health');

  @override
  void initState() {
    super.initState();
    unawaited(_loadHistory());
    unawaited(_checkApiStatus());
  }

  Future<void> _loadHistory() async {
    try {
      final saved = await readStoredValue(_historyStorageKey);
      if (saved == null || saved.isEmpty) return;
      final decoded = jsonDecode(saved);
      if (decoded is! List) {
        throw const FormatException('Data riwayat harus berupa daftar.');
      }
      final entries = decoded
          .map(
            (item) =>
                _HistoryEntry.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .take(_maxHistoryEntries)
          .toList();
      if (mounted) setState(() => _history = entries);
    } on Object catch (error) {
      _showSnackBar('Riwayat gagal dibaca: $error');
    }
  }

  Future<void> _persistHistory() async {
    try {
      await writeStoredValue(
        _historyStorageKey,
        jsonEncode(_history.map((entry) => entry.toJson()).toList()),
      );
    } on Object catch (error) {
      _showSnackBar('Riwayat gagal disimpan: $error');
    }
  }

  Future<void> _checkApiStatus() async {
    if (mounted) setState(() => _checkingApi = true);
    try {
      final response = await http
          .get(_healthUri)
          .timeout(const Duration(seconds: 8));
      final body = jsonDecode(response.body);
      final online =
          response.statusCode == 200 &&
          body is Map<String, dynamic> &&
          body['status'] == 'ok';
      if (mounted) setState(() => _apiOnline = online);
    } on Object {
      if (mounted) setState(() => _apiOnline = false);
    } finally {
      if (mounted) setState(() => _checkingApi = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickImage({bool captureFromCamera = false}) async {
    try {
      final file = await pickImage(captureFromCamera: captureFromCamera);
      if (file == null) return;
      final size = file.bytes.length;
      if (size > 10 * 1024 * 1024) {
        _setError('Ukuran gambar maksimal 10 MB.');
        return;
      }
      final bytes = file.bytes;
      if (bytes.isEmpty) {
        _setError(
          'Gambar tidak dapat dibaca. Coba pilih file JPG atau PNG lain.',
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        _selectedImage = _SelectedImage(name: file.name, bytes: bytes);
        _predictions = const [];
        _errorMessage = null;
      });
    } on Object catch (error) {
      _setError('Gagal memilih gambar: $error');
    }
  }

  Future<void> _useDemoImage() async {
    try {
      final data = await rootBundle.load('assets/demo_fresh_apple.jpg');
      if (!mounted) return;
      setState(() {
        _selectedImage = _SelectedImage(
          name: 'Contoh dataset - apel segar',
          bytes: data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          ),
        );
        _predictions = const [];
        _errorMessage = null;
      });
      await _predict();
    } on Object catch (error) {
      _setError('Gambar contoh tidak dapat dimuat: $error');
    }
  }

  void _resetCurrent() {
    setState(() {
      _selectedImage = null;
      _predictions = const [];
      _errorMessage = null;
      _modelName = null;
      _validationAccuracy = null;
    });
  }

  Future<void> _downloadReport() async {
    if (_predictions.isEmpty || _selectedImage == null) {
      _showSnackBar('Analisis gambar terlebih dahulu untuk mengunduh laporan.');
      return;
    }
    String csvValue(String value) => '"${value.replaceAll('"', '""')}"';
    final generatedAt = DateTime.now();
    final lines = <String>[
      'waktu,nama_file,model,akurasi_validasi,peringkat,label,confidence',
    ];
    for (var index = 0; index < _predictions.length; index++) {
      final prediction = _predictions[index];
      lines.add(
        [
          csvValue(generatedAt.toIso8601String()),
          csvValue(_selectedImage!.name),
          csvValue(_modelName ?? 'Model klasifikasi'),
          _validationAccuracy?.toStringAsFixed(4) ?? '',
          '${index + 1}',
          csvValue(prediction.label),
          prediction.confidence.toStringAsFixed(6),
        ].join(','),
      );
    }
    final filename =
        'hasil-prediksi-${generatedAt.toIso8601String().replaceAll(':', '-').split('.').first}.csv';
    try {
      await downloadTextFile(filename, '\uFEFF${lines.join('\r\n')}');
    } on Object catch (error) {
      _showSnackBar('Laporan gagal diunduh: $error');
    }
  }

  void _showAboutModel() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tentang model'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _InfoLine(
                label: 'Arsitektur',
                value: 'MobileNetV2 transfer learning',
              ),
              _InfoLine(label: 'Ukuran input', value: '224 × 224 piksel'),
              _InfoLine(
                label: 'Kanal warna',
                value: 'RGB, 3 kanal (bukan BGR)',
              ),
              _InfoLine(
                label: 'Normalisasi',
                value: 'Nilai piksel 0–1 (dibagi 255)',
              ),
              _InfoLine(
                label: 'Kelas',
                value: '16 kelas: 8 jenis buah, segar/busuk',
              ),
              _InfoLine(
                label: 'Akurasi validasi',
                value: '94,53% pada eksperimen tercatat',
              ),
              SizedBox(height: 12),
              Text(
                'Model hanya dilatih dengan kelas buah. Gambar non-buah tetap '
                'dapat memperoleh label buah, jadi hasil bukan pemeriksaan '
                'keamanan pangan.',
                style: TextStyle(height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _showHistory() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Expanded(child: Text('Riwayat prediksi')),
            if (_history.isNotEmpty)
              IconButton(
                tooltip: 'Hapus semua riwayat',
                onPressed: () {
                  setState(() => _history = const []);
                  unawaited(_persistHistory());
                  Navigator.of(dialogContext).pop();
                },
                icon: const Icon(Icons.delete_outline),
              ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: _history.isEmpty
              ? const Text('Belum ada hasil prediksi tersimpan.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: _history.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final entry = _history[index];
                    final top = entry.predictions.isEmpty
                        ? null
                        : entry.predictions.first;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        child: Icon(Icons.image_outlined),
                      ),
                      title: Text(
                        entry.filename,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${_formatDate(entry.createdAt)}'
                        '${top == null ? '' : '\n${top.label} · ${(top.confidence * 100).toStringAsFixed(1)}%'}',
                      ),
                      isThreeLine: top != null,
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    final date =
        '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
    final time =
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    return '$date $time';
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
            filename: image.name,
          ),
        );
      final streamed = await request.send().timeout(const Duration(minutes: 2));
      final response = await http.Response.fromStream(streamed);
      final decoded = jsonDecode(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = decoded is Map<String, dynamic>
            ? decoded['detail']
            : null;
        throw _ApiException(
          detail is String
              ? detail
              : 'Prediksi gagal (${response.statusCode}).',
        );
      }
      if (decoded is! Map<String, dynamic> ||
          decoded['top_predictions'] is! List) {
        throw const FormatException(
          'Respons prediksi dari server tidak valid.',
        );
      }

      final results = (decoded['top_predictions'] as List)
          .map(
            (item) =>
                Prediction.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
      final accuracy = decoded['validation_accuracy'];

      if (!mounted) return;
      setState(() {
        _predictions = results;
        _modelName = decoded['model'] as String?;
        _validationAccuracy = accuracy is num ? accuracy.toDouble() : null;
      });
      final historyEntry = _HistoryEntry(
        filename: image.name,
        createdAt: DateTime.now(),
        model: _modelName ?? 'Model klasifikasi',
        predictions: results,
      );
      setState(() {
        _history = [
          historyEntry,
          ..._history,
        ].take(_maxHistoryEntries).toList();
      });
      await _persistHistory();
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
                  const SizedBox(height: 16),
                  _buildToolbar(),
                  const SizedBox(height: 28),
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

  Widget _buildToolbar() {
    final statusColor = _apiOnline == true
        ? _green
        : _apiOnline == false
        ? const Color(0xFFB3261E)
        : Colors.black54;
    final statusText = _checkingApi
        ? 'Memeriksa API'
        : _apiOnline == true
        ? 'API online'
        : _apiOnline == false
        ? 'API offline'
        : 'Status API belum diketahui';
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        Chip(
          avatar: _checkingApi
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(Icons.circle, size: 12, color: statusColor),
          label: Text(statusText),
          visualDensity: VisualDensity.compact,
        ),
        IconButton.outlined(
          tooltip: 'Periksa status API',
          onPressed: _checkingApi ? null : _checkApiStatus,
          icon: const Icon(Icons.refresh),
        ),
        OutlinedButton.icon(
          onPressed: _isLoading ? null : _useDemoImage,
          icon: const Icon(Icons.science_outlined),
          label: const Text('Coba contoh'),
        ),
        OutlinedButton.icon(
          onPressed: _showAboutModel,
          icon: const Icon(Icons.info_outline),
          label: const Text('Tentang model'),
        ),
        OutlinedButton.icon(
          onPressed: _showHistory,
          icon: const Icon(Icons.history),
          label: Text('Riwayat (${_history.length})'),
        ),
      ],
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
              _selectedImage!.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
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
              ),
              if (cameraCaptureAvailable) ...[
                const SizedBox(width: 4),
                IconButton.outlined(
                  tooltip: 'Ambil foto dengan kamera',
                  onPressed: _isLoading
                      ? null
                      : () => _pickImage(captureFromCamera: true),
                  icon: const Icon(Icons.camera_alt_outlined),
                ),
              ],
              if (_selectedImage != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Reset gambar',
                  onPressed: _isLoading ? null : _resetCurrent,
                  icon: const Icon(Icons.close),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE2F1E8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline, color: _green),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tips: foto buah dengan jelas, pencahayaan cukup, dan '
                    'buah memenuhi sebagian besar gambar. Hasil tetap berupa '
                    'prediksi model.',
                    style: TextStyle(color: _ink, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultPanel() {
    return _panel(
      title: '2. Hasil prediksi',
      child: SizedBox(
        height: _predictions.isEmpty ? 340 : null,
        child: Column(
          mainAxisAlignment: _predictions.isEmpty
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
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
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _downloadReport,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Unduh laporan CSV'),
                ),
              ),
            ] else
              _buildMessage(
                icon: Icons.search_rounded,
                color: _green,
                message: 'Hasil prediksi akan muncul di sini setelah gambar dianalisis.',
              ),
          ],
        ),
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
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
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

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: Colors.black54)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(color: _ink, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
