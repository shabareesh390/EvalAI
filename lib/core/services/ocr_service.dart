import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
// Use an alias to avoid colliding with the PDF generation package!
import 'package:pdfx/pdfx.dart' as pdfx;

// ── Supported Languages ────────────────────────────────────────────────────
enum SupportedLanguage {
  english,
  hindi,
  chinese,
  japanese,
  korean,
  auto,
}

enum OcrConfidenceLevel {
  high,   // >85%
  medium, // 50-85%
  low,    // <50%
}

class OcrResult {
  final String extractedText;
  final double confidence;
  final OcrConfidenceLevel confidenceLevel;
  final String confidenceLabel;
  final List<String> textBlocks;
  final int totalPages;
  final SupportedLanguage detectedLanguage;

  OcrResult({
    required this.extractedText,
    required this.confidence,
    required this.confidenceLevel,
    required this.confidenceLabel,
    required this.textBlocks,
    this.totalPages = 1,
    this.detectedLanguage = SupportedLanguage.english,
  });
}

class OcrService {
  // ── Recognizers ────────────────────────────────────────────────────────
  final TextRecognizer _latinRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  final TextRecognizer _devanagiriRecognizer = TextRecognizer(
    script: TextRecognitionScript.devanagiri,
  );

  // ── Get recognizer for language ────────────────────────────────────────
  TextRecognizer _getRecognizer(SupportedLanguage language) {
    switch (language) {
      case SupportedLanguage.hindi:
        return TextRecognizer(script: TextRecognitionScript.devanagiri);
      case SupportedLanguage.chinese:
        return TextRecognizer(script: TextRecognitionScript.chinese);
      case SupportedLanguage.japanese:
        return TextRecognizer(script: TextRecognitionScript.japanese);
      case SupportedLanguage.korean:
        return TextRecognizer(script: TextRecognitionScript.korean);
      case SupportedLanguage.auto:
      case SupportedLanguage.english:
        return TextRecognizer(script: TextRecognitionScript.latin);
    }
  }

  // ── Extract text from image ────────────────────────────────────────────
  Future<OcrResult> extractTextFromImage(
      File imageFile, {
        SupportedLanguage language = SupportedLanguage.auto,
      }) async {
    String fullText = '';
    final allBlocks = <String>[];
    SupportedLanguage detectedLang = SupportedLanguage.english;

    if (language == SupportedLanguage.auto) {
      // Try Latin first
      final latinResult = await _extractWithRecognizer(
        _latinRecognizer,
        imageFile,
      );

      // Try Devanagiri
      final devanagiriResult = await _extractWithRecognizer(
        _devanagiriRecognizer,
        imageFile,
      );

      // Pick the one with more text
      if (devanagiriResult['text'].length > latinResult['text'].length) {
        fullText = devanagiriResult['text'];
        allBlocks.addAll(devanagiriResult['blocks']);
        detectedLang = SupportedLanguage.hindi;
      } else {
        fullText = latinResult['text'];
        allBlocks.addAll(latinResult['blocks']);
        detectedLang = SupportedLanguage.english;
      }
    } else {
      final recognizer = _getRecognizer(language);
      final result = await _extractWithRecognizer(recognizer, imageFile);
      fullText = result['text'];
      allBlocks.addAll(result['blocks']);
      detectedLang = language;
    }

    final confidence = _estimateConfidence(fullText, allBlocks);
    final confidenceLevel = _getConfidenceLevel(confidence);
    final confidenceLabel = _getConfidenceLabel(confidenceLevel);

    return OcrResult(
      extractedText: fullText,
      confidence: confidence,
      confidenceLevel: confidenceLevel,
      confidenceLabel: confidenceLabel,
      textBlocks: allBlocks,
      totalPages: 1,
      detectedLanguage: detectedLang,
    );
  }

  // ── Extract with specific recognizer ──────────────────────────────────
  Future<Map<String, dynamic>> _extractWithRecognizer(
      TextRecognizer recognizer,
      File imageFile,
      ) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognized = await recognizer.processImage(inputImage);
      return {
        'text': recognized.text,
        'blocks': recognized.blocks.map((b) => b.text).toList(),
      };
    } catch (e) {
      debugPrint('OCR error: $e');
      return {'text': '', 'blocks': <String>[]};
    }
  }

  // ── Extract text from PDF ──────────────────────────────────────────────
  Future<OcrResult> extractTextFromPdf(
      File pdfFile, {
        SupportedLanguage language = SupportedLanguage.auto,
      }) async {
    final allText = StringBuffer();
    final allBlocks = <String>[];
    SupportedLanguage detectedLang = SupportedLanguage.english;
    int totalPages = 0;

    try {
      // USING THE pdfx ALIAS HERE 👇
      final document = await pdfx.PdfDocument.openFile(pdfFile.path);
      totalPages = document.pagesCount;

      for (int pageNum = 1; pageNum <= totalPages; pageNum++) {
        final page = await document.getPage(pageNum);

        // USING THE pdfx ALIAS HERE 👇
        final pageImage = await page.render(
          width: page.width * 2,
          height: page.height * 2,
          format: pdfx.PdfPageImageFormat.jpeg,
          quality: 95,
        );

        await page.close();

        if (pageImage?.bytes != null) {
          final tempFile = File(
            '${pdfFile.parent.path}/temp_page_$pageNum.jpg',
          );
          await tempFile.writeAsBytes(pageImage!.bytes);

          final pageResult = await extractTextFromImage(
            tempFile,
            language: language,
          );

          allText.write('--- Page $pageNum ---\n');
          allText.write(pageResult.extractedText);
          allText.write('\n\n');
          allBlocks.addAll(pageResult.textBlocks);

          if (pageNum == 1) {
            detectedLang = pageResult.detectedLanguage;
          }

          await tempFile.delete();
        }
      }

      await document.close();
    } catch (e) {
      debugPrint('PDF extraction error: $e');
    }

    final fullText = allText.toString();
    final confidence = _estimateConfidence(fullText, allBlocks);

    return OcrResult(
      extractedText: fullText,
      confidence: confidence,
      confidenceLevel: _getConfidenceLevel(confidence),
      confidenceLabel: _getConfidenceLabel(_getConfidenceLevel(confidence)),
      textBlocks: allBlocks,
      totalPages: totalPages,
      detectedLanguage: detectedLang,
    );
  }

  // ── Auto detect file type ──────────────────────────────────────────────
  Future<OcrResult> extractText(
      File file, {
        SupportedLanguage language = SupportedLanguage.auto,
      }) async {
    final extension = file.path.split('.').last.toLowerCase();
    if (extension == 'pdf') {
      return extractTextFromPdf(file, language: language);
    } else {
      return extractTextFromImage(file, language: language);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────
  double _estimateConfidence(String text, List<String> blocks) {
    if (text.isEmpty) return 0.0;
    final totalChars = text.length;
    final readableChars =
        text.replaceAll(RegExp(r'[^\w\s]'), '').length;
    if (totalChars == 0) return 0.0;
    double confidence = (readableChars / totalChars) * 100;
    if (blocks.length > 3) confidence = (confidence + 10).clamp(0, 100);
    if (text.trim().length < 50) {
      confidence = (confidence - 20).clamp(0, 100);
    }
    return confidence;
  }

  OcrConfidenceLevel _getConfidenceLevel(double confidence) {
    if (confidence >= 85) return OcrConfidenceLevel.high;
    if (confidence >= 50) return OcrConfidenceLevel.medium;
    return OcrConfidenceLevel.low;
  }

  String _getConfidenceLabel(OcrConfidenceLevel level) {
    switch (level) {
      case OcrConfidenceLevel.high:
        return 'AUTO EVALUATION';
      case OcrConfidenceLevel.medium:
        return 'REVIEW RECOMMENDED';
      case OcrConfidenceLevel.low:
        return 'MANUAL EVALUATION REQUIRED';
    }
  }

  static String getLanguageName(SupportedLanguage language) {
    switch (language) {
      case SupportedLanguage.english:  return 'English';
      case SupportedLanguage.hindi:    return 'Hindi';
      case SupportedLanguage.chinese:  return 'Chinese';
      case SupportedLanguage.japanese: return 'Japanese';
      case SupportedLanguage.korean:   return 'Korean';
      case SupportedLanguage.auto:     return 'Auto Detect';
    }
  }

  // ── Dispose ───────────────────────────────────────────────────────────
  void dispose() {
    _latinRecognizer.close();
    _devanagiriRecognizer.close();
  }
}