import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../data/smart_invoice_repository.dart';
import 'smart_invoice_provider.dart';

class SmartInvoicePage extends ConsumerStatefulWidget {
  const SmartInvoicePage({super.key});

  @override
  ConsumerState<SmartInvoicePage> createState() => _SmartInvoicePageState();
}

class _SmartInvoicePageState extends ConsumerState<SmartInvoicePage> {
  final _customerNameController = TextEditingController();
  final _notesController = TextEditingController();
  List<_EditableItem> _editableItems = [];

  @override
  void dispose() {
    _customerNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.bytes != null) {
        ref.read(smartInvoiceProvider.notifier).extractFromImage(
          file.bytes!,
          filename: file.name,
        );
      }
    }
  }

  void _populateEditableItems(ExtractionResult result) {
    _customerNameController.text = result.customerName ?? '';
    _notesController.text = result.notes ?? '';
    _editableItems = result.items.map((item) => _EditableItem(
      productNameController: TextEditingController(text: item.productName),
      quantityController: TextEditingController(text: item.quantity.toString()),
      unitType: item.unitType,
      unitPriceController: TextEditingController(text: item.unitPrice.toString()),
      notesController: TextEditingController(text: item.notes ?? ''),
    )).toList();
  }

  void _addItem() {
    setState(() {
      _editableItems.add(_EditableItem(
        productNameController: TextEditingController(),
        quantityController: TextEditingController(text: '1'),
        unitType: 'meter',
        unitPriceController: TextEditingController(text: '0'),
        notesController: TextEditingController(),
      ));
    });
  }

  void _removeItem(int index) {
    setState(() {
      _editableItems[index].dispose();
      _editableItems.removeAt(index);
    });
  }

  double get _total {
    double sum = 0;
    for (final item in _editableItems) {
      final qty = double.tryParse(item.quantityController.text) ?? 0;
      final price = double.tryParse(item.unitPriceController.text) ?? 0;
      sum += qty * price;
    }
    return sum;
  }

  void _createInvoice() {
    // Navigate to sales page - the user can create the invoice from there
    // In a full implementation, this would pass pre-filled data
    context.go('/sales');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invoice data ready. Create a new sale with the extracted items.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(smartInvoiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // When extraction is done, populate editable items once
    if (state.status == SmartInvoiceStatus.done && state.result != null && _editableItems.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _populateEditableItems(state.result!);
        });
      });
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(isDark),
            const SizedBox(height: 24),
            if (state.status == SmartInvoiceStatus.idle) _buildUploadArea(isDark),
            if (state.status == SmartInvoiceStatus.extracting) _buildLoadingState(isDark),
            if (state.status == SmartInvoiceStatus.error) _buildErrorState(state, isDark),
            if (state.status == SmartInvoiceStatus.done && state.result != null) _buildResultsView(state, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.document_scanner_rounded, color: AppColors.primary, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Smart Invoice',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Upload a photo of an order to auto-create an invoice',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUploadArea(bool isDark) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        child: InkWell(
          onTap: _pickImage,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 40),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.4),
                width: 2,
                strokeAlign: BorderSide.strokeAlignCenter,
              ),
              color: isDark ? AppColors.darkSurface : AppColors.surface,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_a_photo_rounded, size: 48, color: AppColors.primary),
                ),
                const SizedBox(height: 24),
                Text(
                  'Upload Invoice Photo',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Take a photo or select an image of a handwritten/printed order',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('Choose Image'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Supports JPEG, PNG, GIF, WebP (max 20MB)',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Text(
              'Analyzing Invoice...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            // AI Pipeline Timeline
            _buildPipelineTimeline(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildPipelineTimeline(bool isDark) {
    final steps = ref.watch(smartInvoiceProvider).pipelineSteps;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: steps.map((step) {
        final icon = step.completed
            ? const Icon(Icons.check_circle, color: AppColors.success, size: 22)
            : step.active
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                : step.failed
                    ? const Icon(Icons.error, color: AppColors.error, size: 22)
                    : Icon(Icons.circle_outlined, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary.withOpacity(0.4), size: 22);

        final textColor = step.completed
            ? AppColors.success
            : step.active
                ? (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)
                : step.failed
                    ? AppColors.error
                    : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary.withOpacity(0.5));

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              icon,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.labelAr,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: step.active ? FontWeight.w600 : FontWeight.w400,
                        color: textColor,
                      ),
                    ),
                    if (step.detail != null)
                      Text(
                        step.detail!,
                        style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildErrorState(SmartInvoiceState state, bool isDark) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Extraction Failed',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.errorMessage ?? 'An unknown error occurred',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(smartInvoiceProvider.notifier).reset();
                setState(() {
                  _editableItems.clear();
                });
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsView(SmartInvoiceState state, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Confidence badge and actions row
        Row(
          children: [
            _buildConfidenceBadge(state.result!.confidence, isDark),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () {
                ref.read(smartInvoiceProvider.notifier).reset();
                setState(() {
                  _editableItems.clear();
                  _customerNameController.clear();
                  _notesController.clear();
                });
              },
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
              label: const Text('Try Another Photo'),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Customer name
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Customer Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _customerNameController,
                decoration: const InputDecoration(
                  labelText: 'Customer Name',
                  prefixIcon: Icon(Icons.person_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Items table
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Extracted Items',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_editableItems.length} items',
                      style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add Item'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_editableItems.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No items extracted. Add items manually or try a clearer photo.',
                      style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                    ),
                  ),
                )
              else
                _buildItemsTable(isDark),
              const SizedBox(height: 16),
              // Total row
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Total: ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      _total.toStringAsFixed(2),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Action buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(
              onPressed: () {
                ref.read(smartInvoiceProvider.notifier).reset();
                setState(() {
                  _editableItems.clear();
                  _customerNameController.clear();
                  _notesController.clear();
                });
              },
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _editableItems.isNotEmpty ? _createInvoice : null,
              icon: const Icon(Icons.receipt_long_rounded),
              label: const Text('Create Invoice'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildItemsTable(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 16,
        columns: const [
          DataColumn(label: Text('Product')),
          DataColumn(label: Text('Qty')),
          DataColumn(label: Text('Unit')),
          DataColumn(label: Text('Price')),
          DataColumn(label: Text('Total')),
          DataColumn(label: Text('')),
        ],
        rows: List.generate(_editableItems.length, (index) {
          final item = _editableItems[index];
          final qty = double.tryParse(item.quantityController.text) ?? 0;
          final price = double.tryParse(item.unitPriceController.text) ?? 0;
          final lineTotal = qty * price;

          return DataRow(cells: [
            DataCell(SizedBox(
              width: 200,
              child: TextField(
                controller: item.productNameController,
                decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                style: const TextStyle(fontSize: 13),
                onChanged: (_) => setState(() {}),
              ),
            )),
            DataCell(SizedBox(
              width: 70,
              child: TextField(
                controller: item.quantityController,
                decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 13),
                onChanged: (_) => setState(() {}),
              ),
            )),
            DataCell(DropdownButton<String>(
              value: item.unitType,
              underline: const SizedBox(),
              isDense: true,
              style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
              items: const [
                DropdownMenuItem(value: 'meter', child: Text('Meter')),
                DropdownMenuItem(value: 'piece', child: Text('Piece')),
                DropdownMenuItem(value: 'carton', child: Text('Carton')),
              ],
              onChanged: (value) {
                setState(() {
                  item.unitType = value ?? 'meter';
                });
              },
            )),
            DataCell(SizedBox(
              width: 80,
              child: TextField(
                controller: item.unitPriceController,
                decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 13),
                onChanged: (_) => setState(() {}),
              ),
            )),
            DataCell(Text(
              lineTotal.toStringAsFixed(2),
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            )),
            DataCell(IconButton(
              onPressed: () => _removeItem(index),
              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
              tooltip: 'Remove item',
            )),
          ]);
        }),
      ),
    );
  }

  Widget _buildConfidenceBadge(String confidence, bool isDark) {
    Color color;
    IconData icon;
    String label;

    switch (confidence) {
      case 'high':
        color = AppColors.success;
        icon = Icons.check_circle_rounded;
        label = 'High Confidence';
        break;
      case 'medium':
        color = AppColors.warning;
        icon = Icons.info_rounded;
        label = 'Medium Confidence';
        break;
      default:
        color = AppColors.error;
        icon = Icons.warning_rounded;
        label = 'Low Confidence - Please Review';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color)),
        ],
      ),
    );
  }
}

class _EditableItem {
  final TextEditingController productNameController;
  final TextEditingController quantityController;
  String unitType;
  final TextEditingController unitPriceController;
  final TextEditingController notesController;

  _EditableItem({
    required this.productNameController,
    required this.quantityController,
    required this.unitType,
    required this.unitPriceController,
    required this.notesController,
  });

  void dispose() {
    productNameController.dispose();
    quantityController.dispose();
    unitPriceController.dispose();
    notesController.dispose();
  }
}
