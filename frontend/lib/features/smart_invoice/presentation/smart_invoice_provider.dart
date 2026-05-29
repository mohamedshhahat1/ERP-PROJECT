import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/smart_invoice_repository.dart';

enum SmartInvoiceStatus { idle, uploading, extracting, done, error }

class SmartInvoiceState {
  final SmartInvoiceStatus status;
  final ExtractionResult? result;
  final String? errorMessage;
  final Uint8List? imageBytes;

  const SmartInvoiceState({
    this.status = SmartInvoiceStatus.idle,
    this.result,
    this.errorMessage,
    this.imageBytes,
  });

  SmartInvoiceState copyWith({
    SmartInvoiceStatus? status,
    ExtractionResult? result,
    String? errorMessage,
    Uint8List? imageBytes,
  }) {
    return SmartInvoiceState(
      status: status ?? this.status,
      result: result ?? this.result,
      errorMessage: errorMessage,
      imageBytes: imageBytes ?? this.imageBytes,
    );
  }
}

class SmartInvoiceNotifier extends StateNotifier<SmartInvoiceState> {
  final SmartInvoiceRepository _repository;

  SmartInvoiceNotifier(this._repository) : super(const SmartInvoiceState());

  Future<void> extractFromImage(Uint8List imageBytes, {String filename = 'photo.jpg'}) async {
    state = SmartInvoiceState(
      status: SmartInvoiceStatus.extracting,
      imageBytes: imageBytes,
    );

    try {
      final result = await _repository.extractFromImage(imageBytes, filename: filename);
      state = SmartInvoiceState(
        status: SmartInvoiceStatus.done,
        result: result,
        imageBytes: imageBytes,
      );
    } catch (e) {
      state = SmartInvoiceState(
        status: SmartInvoiceStatus.error,
        errorMessage: e.toString(),
        imageBytes: imageBytes,
      );
    }
  }

  void reset() {
    state = const SmartInvoiceState();
  }
}

final smartInvoiceProvider = StateNotifierProvider<SmartInvoiceNotifier, SmartInvoiceState>((ref) {
  final repository = ref.read(smartInvoiceRepositoryProvider);
  return SmartInvoiceNotifier(repository);
});
