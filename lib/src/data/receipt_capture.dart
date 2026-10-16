import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/services/receipt_scan_service.dart';

/// Ambil foto struk via kamera → OCR on-device (ML Kit) (tiket 13).
///
/// Data layer — import platform-specific diizinkan di sini.
/// Foto dihapus setelah OCR: tidak disimpan permanen (privasi).
class ReceiptCapture {
  final ImagePicker _picker;

  ReceiptCapture([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  Future<ReceiptCaptureResult> captureAndRecognize() async {
    final XFile? file;
    try {
      file = await _picker.pickImage(source: ImageSource.camera);
    } catch (e) {
      return ReceiptCaptureResult.error('Kamera tidak bisa dibuka.');
    }
    if (file == null) {
      return const ReceiptCaptureResult.cancelled();
    }
    try {
      final recognizer =
          TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognized;
      try {
        recognized = await recognizer
            .processImage(InputImage.fromFilePath(file.path));
      } finally {
        await recognizer.close();
      }
      final text = recognized.text.trim();
      if (text.isEmpty) {
        return const ReceiptCaptureResult.error(
          'Teks tidak terbaca dari foto. Coba foto lebih jelas.',
        );
      }
      return ReceiptCaptureResult.text(text);
    } catch (_) {
      // Umumnya: model text-recognition ML Kit belum ter-download.
      return const ReceiptCaptureResult.modelNotReady();
    } finally {
      try {
        await File(file.path).delete();
      } catch (_) {
        // Abaikan — file cache sistem akan dibersihkan OS.
      }
    }
  }
}
