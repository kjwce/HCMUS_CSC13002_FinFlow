import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../finance/models/transaction_category.dart';
import '../models/scan_result_model.dart';
import '../services/receipt_scan_service.dart';

typedef ReceiptImagePicker = Future<XFile?> Function(ImageSource source);
typedef ReceiptFileParser = Future<ScanResultModel> Function(XFile file);

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({
    super.key,
    this.embedded = false,
    this.imagePicker,
    this.receiptParser,
  });

  /// Omits the page scaffold/header when Scan is shown inside Add Transaction.
  final bool embedded;

  /// Test seams for the platform picker and Supabase-backed parser.
  final ReceiptImagePicker? imagePicker;
  final ReceiptFileParser? receiptParser;

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  static const _darkText = Color(0xFF093030);
  static const _blue = Color(0xFF3299FF);

  final _picker = ImagePicker();
  XFile? _imageFile;
  Uint8List? _imageBytes;
  ScanResultModel? _result;
  String? _error;
  bool _isProcessing = false;
  int _operationId = 0;

  @override
  void dispose() {
    _operationId++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scanner = Padding(
      padding: widget.embedded
          ? EdgeInsets.zero
          : EdgeInsets.fromLTRB(
              Responsive.w(context, 20),
              Responsive.h(context, 18),
              Responsive.w(context, 20),
              Responsive.h(context, 36),
            ),
      child: _result == null
          ? _buildCaptureBody(context)
          : _buildReviewBody(context, _result!),
    );

    if (widget.embedded) return scanner;

    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(children: [_buildHeader(context), scanner]),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        Responsive.w(context, 16),
        Responsive.h(context, 14),
        Responsive.w(context, 16),
        Responsive.h(context, 24),
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primaryGreen,
            AppColors.lightGreen,
            Color(0xFFF4FFF6),
          ],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(
        children: [
          IconButton.filled(
            key: const Key('scan_back_button'),
            onPressed: _handleBack,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _darkText,
            ),
            icon: const Icon(Icons.arrow_back),
          ),
          Expanded(
            child: Text(
              AppStrings.scanReceipt,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _darkText,
                fontSize: Responsive.sp(context, 20),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const NotificationBell(),
        ],
      ),
    );
  }

  Widget _buildCaptureBody(BuildContext context) {
    return Column(
      children: [
        _buildImagePreview(context),
        SizedBox(height: Responsive.h(context, 18)),
        if (_isProcessing)
          _buildProcessingCard(context)
        else ...[
          Text(
            AppStrings.scanDesc,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.finFlowColors.secondaryText,
              fontSize: Responsive.sp(context, 15),
            ),
          ),
          SizedBox(height: Responsive.h(context, 18)),
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  key: const Key('scan_camera_button'),
                  context: context,
                  icon: Icons.camera_alt_outlined,
                  label: 'Chụp ảnh',
                  onPressed: () => _pickImage(ImageSource.camera),
                ),
              ),
              SizedBox(width: Responsive.w(context, 12)),
              Expanded(
                child: _actionButton(
                  key: const Key('scan_gallery_button'),
                  context: context,
                  icon: Icons.photo_library_outlined,
                  label: 'Chọn ảnh',
                  filled: false,
                  onPressed: () => _pickImage(ImageSource.gallery),
                ),
              ),
            ],
          ),
          if (_imageFile != null) ...[
            SizedBox(height: Responsive.h(context, 14)),
            SizedBox(
              width: double.infinity,
              height: Responsive.h(context, 52),
              child: ElevatedButton.icon(
                key: const Key('scan_analyze_button'),
                onPressed: _scanImage,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Phân tích hóa đơn'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
          if (_error != null) _buildError(context),
        ],
      ],
    );
  }

  Widget _buildReviewBody(BuildContext context, ScanResultModel result) {
    final calculatedTotal = result.calculatedTotal;
    final hasMismatch =
        result.totalAmount > 0 && result.totalAmount != calculatedTotal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildImagePreview(context, compact: true),
        SizedBox(height: Responsive.h(context, 14)),
        Row(
          children: [
            Expanded(
              child: Text(
                result.merchantName?.trim().isNotEmpty == true
                    ? result.merchantName!
                    : 'Hóa đơn đã quét',
                key: const Key('scan_merchant_name'),
                style: TextStyle(
                  color: context.finFlowColors.primaryText,
                  fontSize: Responsive.sp(context, 19),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton.icon(
              key: const Key('scan_rescan_button'),
              onPressed: _resetScan,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Quét lại'),
            ),
          ],
        ),
        if (result.receiptDate != null)
          Text(
            _formatDate(result.receiptDate!),
            style: TextStyle(color: context.finFlowColors.secondaryText),
          ),
        SizedBox(height: Responsive.h(context, 14)),
        if (result.warnings.isNotEmpty || hasMismatch)
          _buildWarnings(context, result.warnings, hasMismatch),
        if (result.items.isEmpty)
          _buildEmptyItems(context)
        else
          ...List.generate(
            result.items.length,
            (index) => _buildItemCard(context, result.items[index], index),
          ),
        SizedBox(height: Responsive.h(context, 6)),
        _buildTotalCard(context, result, calculatedTotal),
        SizedBox(height: Responsive.h(context, 14)),
        _buildNextStepCard(context),
        if (_error != null) _buildError(context),
      ],
    );
  }

  Widget _buildImagePreview(BuildContext context, {bool compact = false}) {
    return Container(
      key: const Key('scan_image_preview'),
      width: double.infinity,
      height: Responsive.h(context, compact ? 120 : 240),
      decoration: BoxDecoration(
        color: context.finFlowColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primaryGreen.withValues(alpha: .2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: _imageBytes == null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: Responsive.w(context, compact ? 38 : 56),
                  color: AppColors.primaryGreen,
                ),
                SizedBox(height: Responsive.h(context, 8)),
                Text(
                  'Ảnh hóa đơn sẽ hiển thị ở đây',
                  style: TextStyle(color: context.finFlowColors.secondaryText),
                ),
              ],
            )
          : Image.memory(
              _imageBytes!,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Center(
                child: Icon(Icons.broken_image_outlined, size: 44),
              ),
            ),
    );
  }

  Widget _buildProcessingCard(BuildContext context) {
    return Container(
      key: const Key('scan_processing_card'),
      width: double.infinity,
      padding: EdgeInsets.all(Responsive.w(context, 20)),
      decoration: BoxDecoration(
        color: context.finFlowColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox.square(dimension: 22, child: CircularProgressIndicator()),
          SizedBox(width: 14),
          Flexible(child: Text('Gemini đang đọc hóa đơn...')),
        ],
      ),
    );
  }

  Widget _actionButton({
    required Key key,
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool filled = true,
  }) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    return SizedBox(
      height: Responsive.h(context, 52),
      child: filled
          ? ElevatedButton.icon(
              key: key,
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(label),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: _darkText,
                shape: shape,
              ),
            )
          : OutlinedButton.icon(
              key: key,
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(label),
              style: OutlinedButton.styleFrom(
                foregroundColor: _darkText,
                side: const BorderSide(color: AppColors.primaryGreen),
                shape: shape,
              ),
            ),
    );
  }

  Widget _buildItemCard(BuildContext context, ScannedItem item, int index) {
    final category = TransactionCategory.fromKey(item.category);
    return Card(
      key: Key('scan_item_$index'),
      margin: EdgeInsets.only(bottom: Responsive.h(context, 10)),
      elevation: 0,
      color: context.finFlowColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Responsive.w(context, 14),
          Responsive.h(context, 10),
          Responsive.w(context, 2),
          Responsive.h(context, 10),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: category.color.withValues(alpha: .16),
              child: Icon(category.icon, color: category.color),
            ),
            SizedBox(width: Responsive.w(context, 12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${AppStrings.categoryName(item.category)}${item.warning == null ? '' : ' • ${item.warning}'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.finFlowColors.secondaryText,
                      fontSize: Responsive.sp(context, 12),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatVnd(item.amount),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              key: Key('scan_item_menu_$index'),
              onSelected: (value) {
                if (value == 'edit') _editItem(index);
                if (value == 'delete') _deleteItem(index);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Sửa')),
                PopupMenuItem(value: 'delete', child: Text('Xóa')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarnings(
    BuildContext context,
    List<String> warnings,
    bool hasMismatch,
  ) {
    final messages = <String>{
      ...warnings.where((warning) => warning.trim().isNotEmpty),
      if (hasMismatch) 'Tổng các dòng chưa khớp với tổng hóa đơn.',
    };
    return Container(
      key: const Key('scan_warnings'),
      width: double.infinity,
      margin: EdgeInsets.only(bottom: Responsive.h(context, 12)),
      padding: EdgeInsets.all(Responsive.w(context, 12)),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: messages
            .map(
              (message) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('⚠ $message'),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _buildEmptyItems(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Responsive.w(context, 18)),
      margin: EdgeInsets.only(bottom: Responsive.h(context, 10)),
      decoration: BoxDecoration(
        color: context.finFlowColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        'Không còn khoản mục nào. Hãy quét lại hoặc giữ ít nhất một khoản.',
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTotalCard(
    BuildContext context,
    ScanResultModel result,
    int calculatedTotal,
  ) {
    return Container(
      key: const Key('scan_total_card'),
      width: double.infinity,
      padding: EdgeInsets.all(Responsive.w(context, 16)),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(child: Text('Tổng các khoản')),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _formatVnd(calculatedTotal),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (result.totalAmount > 0 && result.totalAmount != calculatedTotal)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Expanded(child: Text('Tổng trên hóa đơn')),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _formatVnd(result.totalAmount),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNextStepCard(BuildContext context) {
    return Container(
      key: const Key('scan_next_step_card'),
      width: double.infinity,
      padding: EdgeInsets.all(Responsive.w(context, 14)),
      decoration: BoxDecoration(
        color: _blue.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _blue.withValues(alpha: .25)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.fact_check_outlined, color: _blue),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Kiểm tra lại các khoản mục. Bước tiếp theo bạn sẽ chọn tài khoản và lưu giao dịch.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Container(
      key: const Key('scan_error'),
      width: double.infinity,
      margin: EdgeInsets.only(top: Responsive.h(context, 14)),
      padding: EdgeInsets.all(Responsive.w(context, 12)),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(_error!, style: const TextStyle(color: Colors.red)),
    );
  }

  Future<XFile?> _pickFromPlatform(ImageSource source) {
    return _picker.pickImage(
      source: source,
      maxWidth: 1800,
      maxHeight: 2600,
      imageQuality: 88,
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final operationId = ++_operationId;
    try {
      final file = await (widget.imagePicker ?? _pickFromPlatform)(source);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted || operationId != _operationId) return;
      setState(() {
        _imageFile = file;
        _imageBytes = bytes;
        _result = null;
        _error = null;
      });
    } on PlatformException catch (error) {
      if (!mounted || operationId != _operationId) return;
      setState(() => _error = _platformPickerMessage(error, source));
    } catch (_) {
      if (!mounted || operationId != _operationId) return;
      setState(() => _error = 'Không thể đọc ảnh. Vui lòng chọn ảnh khác.');
    }
  }

  Future<void> _scanImage() async {
    final file = _imageFile;
    if (file == null || _isProcessing) return;
    final operationId = ++_operationId;
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final result =
          await (widget.receiptParser ?? ReceiptScanService.instance.parseFile)(
            file,
          );
      if (!mounted || operationId != _operationId) return;
      setState(() {
        _result = result;
        _isProcessing = false;
      });
    } on ReceiptScanException catch (error) {
      if (!mounted || operationId != _operationId) return;
      setState(() {
        _isProcessing = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted || operationId != _operationId) return;
      setState(() {
        _isProcessing = false;
        _error = 'Không thể phân tích hóa đơn. Vui lòng thử lại.';
      });
    }
  }

  Future<void> _editItem(int index) async {
    final result = _result;
    if (result == null || index >= result.items.length) return;
    final edited = await showModalBottomSheet<ScannedItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ScannedItemEditor(item: result.items[index]),
    );
    if (!mounted || edited == null) return;
    final current = _result;
    if (current == null || index >= current.items.length) return;
    final items = [...current.items]..[index] = edited;
    setState(() {
      _result = current.copyWith(items: items);
      _error = null;
    });
  }

  void _deleteItem(int index) {
    final result = _result;
    if (result == null || index >= result.items.length) return;
    final items = [...result.items]..removeAt(index);
    setState(() {
      _result = result.copyWith(items: items);
      _error = items.isEmpty
          ? 'Hóa đơn cần ít nhất một khoản mục trước khi lưu.'
          : null;
    });
  }

  void _handleBack() {
    if (_result != null || _imageFile != null) {
      _resetScan();
      return;
    }
    Navigator.of(context).maybePop();
  }

  void _resetScan() {
    _operationId++;
    setState(() {
      _imageFile = null;
      _imageBytes = null;
      _result = null;
      _error = null;
      _isProcessing = false;
    });
  }

  static String _platformPickerMessage(
    PlatformException error,
    ImageSource source,
  ) {
    final denied =
        error.code.contains('denied') ||
        error.code.contains('permission') ||
        error.code.contains('access');
    if (denied) {
      return source == ImageSource.camera
          ? 'FinFlow chưa được cấp quyền camera.'
          : 'FinFlow chưa được cấp quyền truy cập thư viện ảnh.';
    }
    return 'Không thể mở ${source == ImageSource.camera ? 'camera' : 'thư viện ảnh'}. Vui lòng thử lại.';
  }

  static String _formatVnd(int amount) {
    final digits = amount.abs().toString();
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) buffer.write('.');
      buffer.write(digits[index]);
    }
    return '$buffer VND';
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _ScannedItemEditor extends StatefulWidget {
  const _ScannedItemEditor({required this.item});

  final ScannedItem item;

  @override
  State<_ScannedItemEditor> createState() => _ScannedItemEditorState();
}

class _ScannedItemEditorState extends State<_ScannedItemEditor> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late String _category;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
    _amountController = TextEditingController(
      text: widget.item.amount.toString(),
    );
    _category = TransactionCategory.fromKey(widget.item.category).key;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chỉnh sửa khoản mục',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('scan_edit_name'),
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Tên món/dịch vụ'),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('scan_edit_amount'),
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Số tiền VND'),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            key: const Key('scan_edit_category'),
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Danh mục'),
            items: TransactionCategory.all
                .map(
                  (category) => DropdownMenuItem(
                    value: category.key,
                    child: Text(AppStrings.categoryName(category.key)),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) setState(() => _category = value);
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              key: const Key('scan_edit_save'),
              onPressed: _save,
              child: const Text('Lưu thay đổi'),
            ),
          ),
        ],
      ),
    );
  }

  void _save() {
    final name = _nameController.text.trim();
    final amount = int.tryParse(
      _amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
    );
    if (name.isEmpty || amount == null || amount <= 0) {
      setState(() => _error = 'Vui lòng nhập tên và số tiền hợp lệ.');
      return;
    }
    Navigator.of(context).pop(
      widget.item.copyWith(name: name, amount: amount, category: _category),
    );
  }
}
