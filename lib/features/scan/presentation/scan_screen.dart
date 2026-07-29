import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:torch_light/torch_light.dart';

import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../finance/models/transaction_category.dart';
import '../models/scan_result_model.dart';
import '../services/receipt_scan_service.dart';

typedef ReceiptImagePicker = Future<XFile?> Function(ImageSource source);
typedef ReceiptFileParser = Future<ScanResultModel> Function(XFile file);
typedef ReceiptTorchAvailability = Future<bool> Function();
typedef ReceiptTorchAction = Future<void> Function();

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({
    super.key,
    this.embedded = false,
    this.imagePicker,
    this.receiptParser,
    this.torchAvailability,
    this.torchEnabler,
    this.torchDisabler,
  });

  /// Omits the page scaffold/header when Scan is shown inside Add Transaction.
  final bool embedded;

  /// Test seams for the platform picker and Supabase-backed parser.
  final ReceiptImagePicker? imagePicker;
  final ReceiptFileParser? receiptParser;
  final ReceiptTorchAvailability? torchAvailability;
  final ReceiptTorchAction? torchEnabler;
  final ReceiptTorchAction? torchDisabler;

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  static const _darkText = Color(0xFF093030);
  static const _scanGreen = Color(0xFF00C49A);

  final _picker = ImagePicker();
  XFile? _imageFile;
  Uint8List? _imageBytes;
  ScanResultModel? _result;
  String? _error;
  bool _isProcessing = false;
  bool _isTorchOn = false;
  bool _isTorchChanging = false;
  int _operationId = 0;

  @override
  void dispose() {
    _operationId++;
    if (_isTorchOn) {
      (widget.torchDisabler ?? TorchLight.disableTorch)().ignore();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      if (_result != null) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            Responsive.w(context, 20),
            Responsive.h(context, 18),
            Responsive.w(context, 20),
            Responsive.h(context, 36),
          ),
          child: _buildReviewBody(context, _result!),
        );
      }

      final mediaQuery = MediaQuery.of(context);
      final availableHeight =
          mediaQuery.size.height -
          mediaQuery.padding.vertical -
          Responsive.h(context, 64);
      return SizedBox(
        height: availableHeight.clamp(
          Responsive.h(context, 600),
          Responsive.h(context, 820),
        ),
        child: _buildCaptureBody(context),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FC),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: _result == null
                  ? _buildCaptureBody(context)
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        Responsive.w(context, 20),
                        Responsive.h(context, 18),
                        Responsive.w(context, 20),
                        Responsive.h(context, 36),
                      ),
                      child: _buildReviewBody(context, _result!),
                    ),
            ),
          ],
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
        Expanded(child: _buildCameraViewport(context)),
        _buildCaptureActions(context),
      ],
    );
  }

  Widget _buildCameraViewport(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var frameWidth = constraints.maxWidth * .87;
        var frameHeight = frameWidth * 4 / 3;
        if (frameHeight > constraints.maxHeight * .82) {
          frameHeight = constraints.maxHeight * .82;
          frameWidth = frameHeight * 3 / 4;
        }
        final frameRect = Rect.fromCenter(
          center: Offset(constraints.maxWidth / 2, constraints.maxHeight / 2),
          width: frameWidth,
          height: frameHeight,
        );

        return Stack(
          key: const Key('scan_image_preview'),
          fit: StackFit.expand,
          children: [
            if (_imageBytes == null)
              Image.asset(
                'assets/images/scan_receipt_camera_background.png',
                fit: BoxFit.cover,
                alignment: Alignment.center,
              )
            else
              Image.memory(
                _imageBytes!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: Colors.black,
                  child: Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  key: const Key('scan_camera_overlay'),
                  painter: _CameraOverlayPainter(frameRect: frameRect),
                ),
              ),
            ),
            Positioned.fromRect(
              rect: frameRect,
              child: ClipRRect(
                key: const Key('scan_viewfinder'),
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .4),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    if (!_isProcessing) const _AnimatedScanningLine(),
                    const IgnorePointer(
                      child: CustomPaint(painter: _ViewfinderCornersPainter()),
                    ),
                    Positioned(
                      left: Responsive.w(context, 16),
                      right: Responsive.w(context, 16),
                      bottom: Responsive.h(context, 38),
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: Responsive.w(context, 16),
                            vertical: Responsive.h(context, 8),
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: .55),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: .12),
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x42000000),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: Text(
                            'Place the receipt inside the frame',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: Responsive.sp(context, 12),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: frameRect.left - Responsive.w(context, 9),
              top: frameRect.top - Responsive.h(context, 27),
              child: _GlassControl(
                key: const Key('scan_flash_button'),
                isActive: _isTorchOn,
                isLoading: _isTorchChanging,
                onTap: _toggleTorch,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCaptureActions(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        Responsive.w(context, 24),
        Responsive.h(context, 20),
        Responsive.w(context, 24),
        Responsive.h(context, 18),
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isProcessing)
            _buildProcessingCard(context)
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _roundCaptureButton(
                  key: const Key('scan_gallery_button'),
                  context: context,
                  icon: Icons.image_outlined,
                  label: 'Gallery',
                  filled: false,
                  onPressed: () => _pickImage(ImageSource.gallery),
                ),
                SizedBox(width: Responsive.w(context, 42)),
                _roundCaptureButton(
                  key: const Key('scan_camera_button'),
                  context: context,
                  icon: Icons.photo_camera_outlined,
                  label: 'Capture',
                  onPressed: () => _pickImage(ImageSource.camera),
                ),
              ],
            ),
            if (_imageFile == null)
              Padding(
                padding: EdgeInsets.only(top: Responsive.h(context, 12)),
                child: Text(
                  'AI system will automatically analyze and add\n'
                  'transactions from your receipt.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.finFlowColors.secondaryText.withValues(
                      alpha: .75,
                    ),
                    fontSize: Responsive.sp(context, 11),
                    height: 1.3,
                  ),
                ),
              )
            else
              Padding(
                padding: EdgeInsets.only(top: Responsive.h(context, 12)),
                child: SizedBox(
                  width: double.infinity,
                  height: Responsive.h(context, 48),
                  child: ElevatedButton.icon(
                    key: const Key('scan_analyze_button'),
                    onPressed: _scanImage,
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text('Analyze receipt'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00513E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
          ],
          if (_error != null) _buildError(context),
        ],
      ),
    );
  }

  Widget _roundCaptureButton({
    required Key key,
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool filled = true,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        key: key,
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF00513E).withValues(alpha: .2),
                  width: 3,
                ),
              ),
              child: Container(
                width: Responsive.w(context, 64),
                height: Responsive.w(context, 64),
                decoration: BoxDecoration(
                  color: filled
                      ? const Color(0xFF00513E)
                      : const Color(0xFFE9F0EF),
                  shape: BoxShape.circle,
                  boxShadow: filled
                      ? const [
                          BoxShadow(
                            color: Color(0x2600513E),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  icon,
                  size: Responsive.w(context, 30),
                  color: filled ? Colors.white : const Color(0xFF00513E),
                ),
              ),
            ),
            SizedBox(height: Responsive.h(context, 5)),
            Text(
              label,
              style: TextStyle(
                color: context.finFlowColors.secondaryText,
                fontSize: Responsive.sp(context, 11),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
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
        color: _scanGreen.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _scanGreen.withValues(alpha: .25)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.fact_check_outlined, color: _scanGreen),
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

  Future<void> _toggleTorch() async {
    if (_isTorchChanging) return;
    setState(() => _isTorchChanging = true);

    try {
      final isAvailable =
          await (widget.torchAvailability ?? TorchLight.isTorchAvailable)();
      if (!isAvailable) {
        if (!mounted) return;
        setState(() {
          _isTorchChanging = false;
          _error = 'Flash is unavailable on this device.';
        });
        return;
      }

      if (_isTorchOn) {
        await (widget.torchDisabler ?? TorchLight.disableTorch)();
      } else {
        await (widget.torchEnabler ?? TorchLight.enableTorch)();
      }
      if (!mounted) return;
      setState(() {
        _isTorchOn = !_isTorchOn;
        _isTorchChanging = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isTorchChanging = false;
        _error = 'Could not control the flash. Please try again.';
      });
    }
  }

  Future<void> _disableTorchBeforeLeavingScanner() async {
    if (!_isTorchOn) return;
    try {
      await (widget.torchDisabler ?? TorchLight.disableTorch)();
    } catch (_) {
      // The camera picker may already own the camera; continue opening it.
    }
    if (mounted) {
      setState(() => _isTorchOn = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final operationId = ++_operationId;
    try {
      await _disableTorchBeforeLeavingScanner();
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
    await _disableTorchBeforeLeavingScanner();
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

class _AnimatedScanningLine extends StatefulWidget {
  const _AnimatedScanningLine();

  @override
  State<_AnimatedScanningLine> createState() => _AnimatedScanningLineState();
}

class _AnimatedScanningLineState extends State<_AnimatedScanningLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _position;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _position = Tween<double>(
      begin: .1,
      end: .9,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1), weight: 80),
      TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 10),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) => Align(
        alignment: Alignment(0, (_position.value * 2) - 1),
        child: Opacity(opacity: _opacity.value, child: child),
      ),
      child: Container(
        key: const Key('scan_animated_line'),
        height: 2,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.transparent, Color(0xFF00C49A), Colors.transparent],
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF00C49A),
              blurRadius: 15,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassControl extends StatelessWidget {
  const _GlassControl({
    super.key,
    required this.isActive,
    required this.isLoading,
    required this.onTap,
  });

  final bool isActive;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: isActive,
      label: isActive ? 'Turn flash off' : 'Turn flash on',
      child: Material(
        color: isActive
            ? const Color(0xFF00C49A)
            : Colors.white.withValues(alpha: .85),
        shape: const CircleBorder(),
        elevation: 5,
        shadowColor: Colors.black.withValues(alpha: .35),
        child: InkWell(
          onTap: isLoading ? null : onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: Responsive.w(context, 44),
            height: Responsive.w(context, 44),
            child: Center(
              child: isLoading
                  ? SizedBox.square(
                      dimension: Responsive.w(context, 18),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isActive
                            ? Colors.white
                            : const Color(0xFF1A1C1E),
                      ),
                    )
                  : Icon(
                      isActive
                          ? Icons.flash_on_rounded
                          : Icons.flash_off_rounded,
                      color: isActive ? Colors.white : const Color(0xFF1A1C1E),
                      size: 21,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CameraOverlayPainter extends CustomPainter {
  const _CameraOverlayPainter({required this.frameRect});

  final Rect frameRect;

  @override
  void paint(Canvas canvas, Size size) {
    final roundedFrame = RRect.fromRectAndRadius(
      frameRect,
      const Radius.circular(18),
    );
    final maskPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(roundedFrame);
    canvas.drawPath(
      maskPath,
      Paint()
        ..color = const Color(0xA6000000)
        ..style = PaintingStyle.fill,
    );

    canvas.drawRRect(
      roundedFrame,
      Paint()
        ..color = const Color(0x8A00C49A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawRRect(
      roundedFrame,
      Paint()
        ..color = Colors.white.withValues(alpha: .45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _CameraOverlayPainter oldDelegate) =>
      frameRect != oldDelegate.frameRect;
}

class _ViewfinderCornersPainter extends CustomPainter {
  const _ViewfinderCornersPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const cornerLength = 30.0;
    const radius = 17.0;
    final paint = Paint()
      ..color = const Color(0xFF00C49A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, cornerLength)
      ..lineTo(0, radius)
      ..quadraticBezierTo(0, 0, radius, 0)
      ..lineTo(cornerLength, 0)
      ..moveTo(size.width - cornerLength, 0)
      ..lineTo(size.width - radius, 0)
      ..quadraticBezierTo(size.width, 0, size.width, radius)
      ..lineTo(size.width, cornerLength)
      ..moveTo(size.width, size.height - cornerLength)
      ..lineTo(size.width, size.height - radius)
      ..quadraticBezierTo(
        size.width,
        size.height,
        size.width - radius,
        size.height,
      )
      ..lineTo(size.width - cornerLength, size.height)
      ..moveTo(cornerLength, size.height)
      ..lineTo(radius, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - radius)
      ..lineTo(0, size.height - cornerLength);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ViewfinderCornersPainter oldDelegate) => false;
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
