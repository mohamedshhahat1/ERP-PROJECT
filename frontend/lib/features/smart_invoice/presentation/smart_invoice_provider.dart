import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/smart_invoice_repository.dart';

enum SmartInvoiceStatus { idle, uploading, extracting, done, error }

enum PipelineStep {
  duplicateCheck,
  ocrExtraction,
  aiParsing,
  quantityNormalization,
  productMatching,
  semanticMatching,
  ready,
}

class PipelineStepStatus {
  final PipelineStep step;
  final String label;
  final String labelAr;
  final bool completed;
  final bool active;
  final bool failed;
  final String? detail;

  const PipelineStepStatus({
    required this.step,
    required this.label,
    required this.labelAr,
    this.completed = false,
    this.active = false,
    this.failed = false,
    this.detail,
  });

  PipelineStepStatus copyWith({bool? completed, bool? active, bool? failed, String? detail}) {
    return PipelineStepStatus(
      step: step,
      label: label,
      labelAr: labelAr,
      completed: completed ?? this.completed,
      active: active ?? this.active,
      failed: failed ?? this.failed,
      detail: detail ?? this.detail,
    );
  }
}

class SmartInvoiceState {
  final SmartInvoiceStatus status;
  final ExtractionResult? result;
  final String? errorMessage;
  final Uint8List? imageBytes;
  final List<PipelineStepStatus> pipelineSteps;

  SmartInvoiceState({
    this.status = SmartInvoiceStatus.idle,
    this.result,
    this.errorMessage,
    this.imageBytes,
    List<PipelineStepStatus>? pipelineSteps,
  }) : pipelineSteps = pipelineSteps ?? _defaultSteps();

  static List<PipelineStepStatus> _defaultSteps() => [
    const PipelineStepStatus(step: PipelineStep.duplicateCheck, label: 'Duplicate Check', labelAr: 'فحص التكرار'),
    const PipelineStepStatus(step: PipelineStep.ocrExtraction, label: 'Text Extraction (OCR)', labelAr: 'استخراج النص'),
    const PipelineStepStatus(step: PipelineStep.aiParsing, label: 'AI Parsing', labelAr: 'تحليل البيانات بالذكاء'),
    const PipelineStepStatus(step: PipelineStep.quantityNormalization, label: 'Quantity Normalization', labelAr: 'معالجة الكميات'),
    const PipelineStepStatus(step: PipelineStep.productMatching, label: 'Product Matching', labelAr: 'مطابقة المنتجات'),
    const PipelineStepStatus(step: PipelineStep.semanticMatching, label: 'Smart Matching', labelAr: 'المطابقة الذكية'),
    const PipelineStepStatus(step: PipelineStep.ready, label: 'Ready for Review', labelAr: 'جاهز للمراجعة'),
  ];

  SmartInvoiceState copyWith({
    SmartInvoiceStatus? status,
    ExtractionResult? result,
    String? errorMessage,
    Uint8List? imageBytes,
    List<PipelineStepStatus>? pipelineSteps,
  }) {
    return SmartInvoiceState(
      status: status ?? this.status,
      result: result ?? this.result,
      errorMessage: errorMessage,
      imageBytes: imageBytes ?? this.imageBytes,
      pipelineSteps: pipelineSteps ?? this.pipelineSteps,
    );
  }
}

class SmartInvoiceNotifier extends StateNotifier<SmartInvoiceState> {
  final SmartInvoiceRepository _repository;

  SmartInvoiceNotifier(this._repository) : super(SmartInvoiceState());

  Future<void> extractFromImage(Uint8List imageBytes, {String filename = 'photo.jpg'}) async {
    // Reset and start pipeline
    state = SmartInvoiceState(
      status: SmartInvoiceStatus.extracting,
      imageBytes: imageBytes,
    );

    // Simulate step progression (actual work happens server-side)
    await _advanceStep(PipelineStep.duplicateCheck, duration: 300);
    await _advanceStep(PipelineStep.ocrExtraction, duration: 500);
    await _advanceStep(PipelineStep.aiParsing, duration: 400);

    try {
      final result = await _repository.extractFromImage(imageBytes, filename: filename);

      // Mark remaining steps based on result
      await _advanceStep(PipelineStep.quantityNormalization, duration: 200);
      await _advanceStep(PipelineStep.productMatching, duration: 200,
          detail: '${result.items.where((i) => i.productId != null).length}/${result.items.length} matched');
      await _advanceStep(PipelineStep.semanticMatching, duration: 200);
      await _completeStep(PipelineStep.ready, detail: '${result.items.length} items found');

      state = state.copyWith(
        status: SmartInvoiceStatus.done,
        result: result,
      );
    } catch (e) {
      _failCurrentStep(e.toString());
      state = state.copyWith(
        status: SmartInvoiceStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> _advanceStep(PipelineStep step, {int duration = 300, String? detail}) async {
    final steps = [...state.pipelineSteps];
    final idx = steps.indexWhere((s) => s.step == step);
    if (idx < 0) return;

    // Mark previous as completed
    for (int i = 0; i < idx; i++) {
      steps[i] = steps[i].copyWith(completed: true, active: false);
    }
    // Mark current as active
    steps[idx] = steps[idx].copyWith(active: true, completed: false, detail: detail);
    state = state.copyWith(pipelineSteps: steps);

    await Future.delayed(Duration(milliseconds: duration));

    // Mark as completed
    steps[idx] = steps[idx].copyWith(active: false, completed: true, detail: detail);
    state = state.copyWith(pipelineSteps: steps);
  }

  Future<void> _completeStep(PipelineStep step, {String? detail}) async {
    final steps = [...state.pipelineSteps];
    final idx = steps.indexWhere((s) => s.step == step);
    if (idx < 0) return;
    steps[idx] = steps[idx].copyWith(active: false, completed: true, detail: detail);
    state = state.copyWith(pipelineSteps: steps);
  }

  void _failCurrentStep(String error) {
    final steps = [...state.pipelineSteps];
    final activeIdx = steps.indexWhere((s) => s.active);
    if (activeIdx >= 0) {
      steps[activeIdx] = steps[activeIdx].copyWith(active: false, failed: true, detail: error);
      state = state.copyWith(pipelineSteps: steps);
    }
  }

  void reset() {
    state = SmartInvoiceState();
  }
}

final smartInvoiceProvider = StateNotifierProvider<SmartInvoiceNotifier, SmartInvoiceState>((ref) {
  final repository = ref.read(smartInvoiceRepositoryProvider);
  return SmartInvoiceNotifier(repository);
});
