import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/services/receipt_scan_service.dart';

/// Ambil foto struk via kamera/galeri → OCR on-device (ML Kit).
///
/// Data layer — import platform-specific diizinkan di sini.
/// Foto kamera (temp) dihapus setelah OCR; file galeri dibiarkan (milik user).
class ReceiptCapture {
  final ImagePicker _picker;

  ReceiptCapture([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  Future<ReceiptCaptureResult> captureAndRecognize() =>
      _recognize(ImageSource.camera);

  Future<ReceiptCaptureResult> pickFromGalleryAndRecognize() =>
      _recognize(ImageSource.gallery);

  /// Pilih file gambar dari file picker → OCR.
  Future<ReceiptCaptureResult> pickFileAndRecognize() async {
    final files = await FilePicker.pickFiles(
      type: FileType.image,
    );
    if (files.isEmpty) {
      return const ReceiptCaptureResult.cancelled();
    }
    final path = files.single.path;
    if (path == null) {
      return const ReceiptCaptureResult.cancelled();
    }
    return _recognizePath(path);
  }

  Future<ReceiptCaptureResult> _recognizePath(String path) async {
    try {
      final recognizer =
          TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognized;
      try {
        recognized = await recognizer
            .processImage(InputImage.fromFilePath(path));
      } finally {
        await recognizer.close();
      }
      final text = recognized.text.trim();
      if (text.isEmpty) {
        return const ReceiptCaptureResult.error(
          'Teks tidak terbaca dari file. Coba file lebih jelas.',
        );
      }
      return ReceiptCaptureResult.text(text, imagePath: path);
    } catch (_) {
      return const ReceiptCaptureResult.modelNotReady();
    }
  }

  Future<ReceiptCaptureResult> _recognize(ImageSource source) async {
    final XFile? file;
    try {
      file = await _picker.pickImage(source: source);
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
      return ReceiptCaptureResult.text(text, imagePath: file.path);
    } catch (_) {
      // Umumnya: model text-recognition ML Kit belum ter-download.
      return const ReceiptCaptureResult.modelNotReady();
    } finally {
      // Hanya hapus file temp kamera; file galeri milik user dibiarkan.
      if (source == ImageSource.camera) {
        try {
          await File(file.path).delete();
        } catch (_) {
          // Abaikan — file cache sistem akan dibersihkan OS.
        }
      }
    }
  }
}
