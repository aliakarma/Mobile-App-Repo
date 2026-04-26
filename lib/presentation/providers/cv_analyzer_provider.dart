import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/service_locator.dart';
import '../../core/error/app_exception.dart';
import '../../domain/models/cv_analysis.dart';
import '../../domain/usecases/analyze_cv_usecase.dart';

const int minCvWordCount = 100;
const int minOpportunityLength = 20;
const int maxPdfBytes = 8 * 1024 * 1024;

class CvAnalyzerViewState {
  const CvAnalyzerViewState({
    this.cvText = '',
    this.targetOpportunity = '',
    this.selectedCvPdfBytes,
    this.selectedCvPdfName,
    this.analysis,
    this.errorMessage,
    this.isSubmitting = false,
    this.isPickingPdf = false,
  });

  final String cvText;
  final String targetOpportunity;
  final Uint8List? selectedCvPdfBytes;
  final String? selectedCvPdfName;
  final CvAnalysis? analysis;
  final String? errorMessage;
  final bool isSubmitting;
  final bool isPickingPdf;

  int get cvWordCount {
    final trimmed = cvText.trim();
    if (trimmed.isEmpty) {
      return 0;
    }
    return trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  CvAnalyzerViewState copyWith({
    String? cvText,
    String? targetOpportunity,
    Uint8List? selectedCvPdfBytes,
    String? selectedCvPdfName,
    CvAnalysis? analysis,
    String? errorMessage,
    bool clearPdf = false,
    bool clearAnalysis = false,
    bool clearError = false,
    bool? isSubmitting,
    bool? isPickingPdf,
  }) {
    return CvAnalyzerViewState(
      cvText: cvText ?? this.cvText,
      targetOpportunity: targetOpportunity ?? this.targetOpportunity,
      selectedCvPdfBytes:
          clearPdf ? null : (selectedCvPdfBytes ?? this.selectedCvPdfBytes),
      selectedCvPdfName:
          clearPdf ? null : (selectedCvPdfName ?? this.selectedCvPdfName),
      analysis: clearAnalysis ? null : (analysis ?? this.analysis),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isPickingPdf: isPickingPdf ?? this.isPickingPdf,
    );
  }
}

final cvAnalyzerProvider =
    AsyncNotifierProvider<CvAnalyzerNotifier, CvAnalyzerViewState>(
  CvAnalyzerNotifier.new,
);

class CvAnalyzerNotifier extends AsyncNotifier<CvAnalyzerViewState> {
  late final AnalyzeCvUseCase _analyzeCvUseCase;

  @override
  Future<CvAnalyzerViewState> build() async {
    _analyzeCvUseCase = sl<AnalyzeCvUseCase>();
    return const CvAnalyzerViewState();
  }

  CvAnalyzerViewState get _current =>
      state.value ?? const CvAnalyzerViewState();

  void updateCvText(String value) {
    state = AsyncData(
      _current.copyWith(
        cvText: value,
        clearError: true,
      ),
    );
  }

  void updateTargetOpportunity(String value) {
    state = AsyncData(
      _current.copyWith(
        targetOpportunity: value,
        clearError: true,
      ),
    );
  }

  Future<void> pickCvPdf() async {
    state = AsyncData(_current.copyWith(isPickingPdf: true, clearError: true));

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        withData: false,
      );

      if (result == null || result.files.isEmpty) {
        state = AsyncData(_current.copyWith(isPickingPdf: false));
        return;
      }

      final file = result.files.single;
      final xFile = result.xFiles.isNotEmpty ? result.xFiles.single : null;
      final bytes =
          file.bytes ?? (xFile == null ? null : await xFile.readAsBytes());

      if (bytes == null || bytes.isEmpty) {
        state = AsyncData(
          _current.copyWith(
            isPickingPdf: false,
            errorMessage:
                'Unable to read PDF bytes. Please choose another file or paste CV text.',
          ),
        );
        return;
      }

      if (bytes.length > maxPdfBytes) {
        final sizeMb = (bytes.length / (1024 * 1024)).toStringAsFixed(1);
        state = AsyncData(
          _current.copyWith(
            isPickingPdf: false,
            errorMessage:
                'PDF is too large ($sizeMb MB). Please use a file under 8 MB.',
          ),
        );
        return;
      }

      state = AsyncData(
        _current.copyWith(
          selectedCvPdfBytes: bytes,
          selectedCvPdfName: file.name,
          isPickingPdf: false,
          clearError: true,
        ),
      );
    } catch (_) {
      state = AsyncData(
        _current.copyWith(
          isPickingPdf: false,
          errorMessage:
              'Could not open file picker. Please try again or paste CV text.',
        ),
      );
    }
  }

  void removeSelectedPdf() {
    state = AsyncData(
      _current.copyWith(
        clearPdf: true,
        clearError: true,
      ),
    );
  }

  Future<void> analyzeCv() async {
    final current = _current;

    final target = current.targetOpportunity.trim();
    if (target.length < minOpportunityLength) {
      state = AsyncData(
        current.copyWith(
          errorMessage: 'Please provide more detail about the opportunity.',
        ),
      );
      return;
    }

    final hasPdf = current.selectedCvPdfBytes != null;
    if (!hasPdf && current.cvWordCount < minCvWordCount) {
      state = AsyncData(
        current.copyWith(
          errorMessage: 'Minimum $minCvWordCount words required.',
        ),
      );
      return;
    }

    state = AsyncData(
      current.copyWith(
        isSubmitting: true,
        clearError: true,
        clearAnalysis: true,
      ),
    );

    try {
      final result = await _analyzeCvUseCase(
        AnalyzeCvParams(
          cvText: current.cvText.trim(),
          targetOpportunity: target,
          cvPdfBase64:
              hasPdf ? base64Encode(current.selectedCvPdfBytes!) : null,
          cvPdfFilename: current.selectedCvPdfName,
        ),
      );

      state = AsyncData(
        _current.copyWith(
          isSubmitting: false,
          analysis: result,
          clearError: true,
        ),
      );
    } on AppException catch (error) {
      state = AsyncData(
        _current.copyWith(
          isSubmitting: false,
          errorMessage: error.userMessage,
        ),
      );
    } catch (_) {
      state = AsyncData(
        _current.copyWith(
          isSubmitting: false,
          errorMessage:
              'CV analysis is currently unavailable. Please try again.',
        ),
      );
    }
  }
}
