import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

final smartInvoiceRepositoryProvider = Provider<SmartInvoiceRepository>((ref) {
  return SmartInvoiceRepository(ref.read(dioProvider));
});

class ExtractedItem {
  final String productName;
  final double quantity;
  final String unitType;
  final double unitPrice;
  final String? notes;

  ExtractedItem({
    required this.productName,
    required this.quantity,
    required this.unitType,
    required this.unitPrice,
    this.notes,
  });

  factory ExtractedItem.fromJson(Map<String, dynamic> json) => ExtractedItem(
    productName: json['product_name'] ?? '',
    quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
    unitType: json['unit_type'] ?? 'meter',
    unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
    notes: json['notes'],
  );

  double get total => quantity * unitPrice;

  ExtractedItem copyWith({
    String? productName,
    double? quantity,
    String? unitType,
    double? unitPrice,
    String? notes,
  }) {
    return ExtractedItem(
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitType: unitType ?? this.unitType,
      unitPrice: unitPrice ?? this.unitPrice,
      notes: notes ?? this.notes,
    );
  }
}

class ExtractionResult {
  final String? customerName;
  final List<ExtractedItem> items;
  final String? notes;
  final String confidence;

  ExtractionResult({
    this.customerName,
    required this.items,
    this.notes,
    required this.confidence,
  });

  factory ExtractionResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return ExtractionResult(
      customerName: data['customer_name'],
      items: (data['items'] as List? ?? []).map((e) => ExtractedItem.fromJson(e as Map<String, dynamic>)).toList(),
      notes: data['notes'],
      confidence: data['confidence'] ?? 'low',
    );
  }

  double get total => items.fold(0, (sum, item) => sum + item.total);
}

class SmartInvoiceRepository {
  final Dio _dio;
  SmartInvoiceRepository(this._dio);

  Future<ExtractionResult> extractFromImage(Uint8List imageBytes, {String filename = 'photo.jpg'}) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(imageBytes, filename: filename),
      'language': 'ar',
    });

    final response = await _dio.post(
      '/smart-invoice/extract',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
        receiveTimeout: const Duration(minutes: 2),
      ),
    );

    return ExtractionResult.fromJson(response.data);
  }
}
