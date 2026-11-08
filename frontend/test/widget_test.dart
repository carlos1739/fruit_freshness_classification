import 'package:flutter_test/flutter_test.dart';

import 'package:fruit_freshness_frontend/main.dart';

void main() {
  testWidgets('shows upload and prediction sections', (tester) async {
    await tester.pumpWidget(const FruitFreshnessApp());

    expect(find.text('Cek Kesegaran Buah'), findsOneWidget);
    expect(find.text('1. Pilih gambar'), findsOneWidget);
    expect(find.text('2. Hasil prediksi'), findsOneWidget);
    expect(find.text('Coba contoh'), findsOneWidget);
    expect(find.text('Tentang model'), findsOneWidget);
    expect(find.textContaining('Tips:'), findsOneWidget);
    expect(
      find.text(
        'Hasil prediksi akan muncul di sini setelah gambar dianalisis.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('explains model input channels and normalization', (
    tester,
  ) async {
    await tester.pumpWidget(const FruitFreshnessApp());
    await tester.tap(find.text('Tentang model'));
    await tester.pumpAndSettle();

    expect(find.text('RGB, 3 kanal (bukan BGR)'), findsOneWidget);
    expect(find.text('Nilai piksel 0–1 (dibagi 255)'), findsOneWidget);
  });
}
