import 'package:flutter/material.dart';

import '../../../../core/i18n/app_language.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../models/community_report_model.dart';
import '../../utils/rich_text_formatter.dart';

typedef CommunityReportSubmit =
    Future<CommunityReportSubmitResult> Function(
      CommunityReportReason reason,
      String? details,
    );

Future<void> showCommunityReportDialog({
  required BuildContext context,
  required CommunityReportTarget target,
  required String authorName,
  required String content,
  required CommunityReportSubmit onSubmit,
  String? authorAvatarUrl,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => CommunityReportDialog(
      target: target,
      authorName: authorName,
      authorAvatarUrl: authorAvatarUrl,
      content: content,
      onSubmit: onSubmit,
    ),
  );
}

class CommunityReportDialog extends StatefulWidget {
  const CommunityReportDialog({
    super.key,
    required this.target,
    required this.authorName,
    required this.content,
    required this.onSubmit,
    this.authorAvatarUrl,
  });

  final CommunityReportTarget target;
  final String authorName;
  final String? authorAvatarUrl;
  final String content;
  final CommunityReportSubmit onSubmit;

  @override
  State<CommunityReportDialog> createState() => _CommunityReportDialogState();
}

enum _ReportDialogState { form, submitted, alreadyReported }

class _CommunityReportDialogState extends State<CommunityReportDialog> {
  static const _emerald = Color(0xFF00785D);
  static const _mint = Color(0xFFE3F7EF);
  static const _coral = Color(0xFFE86B5D);
  static const _amber = Color(0xFFE5A820);

  final _detailsController = TextEditingController();
  CommunityReportReason? _reason;
  _ReportDialogState _state = _ReportDialogState.form;
  bool _submitting = false;
  String? _error;

  bool get _isPost => widget.target == CommunityReportTarget.post;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  String _reasonLabel(CommunityReportReason reason) => switch (reason) {
    CommunityReportReason.spamOrMisleading => AppStrings.choose('Spam', 'Spam'),
    CommunityReportReason.scamOrFraud => AppStrings.choose(
      'Scam or fraud',
      'Lừa đảo hoặc gian lận',
    ),
    CommunityReportReason.harassmentOrHate => AppStrings.choose(
      'Harassment or hate',
      'Quấy rối hoặc thù ghét',
    ),
    CommunityReportReason.unsafeOrIllegal => AppStrings.choose(
      'Unsafe content',
      'Nội dung không an toàn',
    ),
    CommunityReportReason.privacyViolation => AppStrings.choose(
      'Privacy violation',
      'Vi phạm quyền riêng tư',
    ),
    CommunityReportReason.other => AppStrings.choose('Other', 'Khác'),
  };

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final details = _detailsController.text.trim();
      final result = await widget.onSubmit(
        reason,
        details.isEmpty ? null : details,
      );
      if (!mounted) return;
      setState(() {
        _state = result == CommunityReportSubmitResult.submitted
            ? _ReportDialogState.submitted
            : _ReportDialogState.alreadyReported;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = AppStrings.choose(
          'Could not submit the report. Please try again.',
          'Không thể gửi báo cáo. Vui lòng thử lại.',
        );
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.finFlowColors;
    return Dialog(
      backgroundColor: colors.dialogBackground,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: Responsive.w(context, 20),
        vertical: Responsive.h(context, 24),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 390,
          maxHeight: MediaQuery.sizeOf(context).height * .9,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _state == _ReportDialogState.form
              ? _buildForm(colors)
              : _buildResult(colors),
        ),
      ),
    );
  }

  Widget _buildForm(FinFlowColors colors) {
    return Column(
      key: const ValueKey('report-form'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              Responsive.w(context, 18),
              Responsive.h(context, 14),
              Responsive.w(context, 18),
              Responsive.h(context, 8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.outlined_flag_rounded,
                      size: Responsive.w(context, 20),
                      color: _coral,
                    ),
                    SizedBox(width: Responsive.w(context, 8)),
                    Expanded(
                      child: Text(
                        _isPost
                            ? AppStrings.choose(
                                'Report post',
                                'Báo cáo bài viết',
                              )
                            : AppStrings.choose(
                                'Report comment',
                                'Báo cáo bình luận',
                              ),
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: Responsive.sp(context, 17),
                          fontWeight: FontWeight.w600,
                          color: colors.primaryText,
                        ),
                      ),
                    ),
                    InkWell(
                      key: const Key('close-report-dialog'),
                      onTap: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: Responsive.w(context, 30),
                        height: Responsive.w(context, 30),
                        decoration: BoxDecoration(
                          color: colors.elevatedSurface,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: Responsive.w(context, 18),
                          color: colors.secondaryText,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: Responsive.h(context, 12)),
                _buildPreview(colors),
                SizedBox(height: Responsive.h(context, 14)),
                Text(
                  AppStrings.choose(
                    'Why are you reporting this?',
                    'Vì sao bạn báo cáo nội dung này?',
                  ),
                  style: TextStyle(
                    fontFamily: 'Hanken Grotesk',
                    fontSize: Responsive.sp(context, 12),
                    fontWeight: FontWeight.w700,
                    color: colors.primaryText,
                  ),
                ),
                SizedBox(height: Responsive.h(context, 6)),
                RadioGroup<CommunityReportReason>(
                  groupValue: _reason,
                  onChanged: (value) {
                    if (!_submitting) setState(() => _reason = value);
                  },
                  child: Column(
                    children: [
                      for (final reason in CommunityReportReason.values)
                        SizedBox(
                          height: Responsive.h(context, 36),
                          child: InkWell(
                            key: Key('report-reason-${reason.code}'),
                            onTap: _submitting
                                ? null
                                : () => setState(() => _reason = reason),
                            borderRadius: BorderRadius.circular(8),
                            child: Row(
                              children: [
                                Radio<CommunityReportReason>(
                                  value: reason,
                                  activeColor: _emerald,
                                  visualDensity: const VisualDensity(
                                    horizontal: -4,
                                    vertical: -4,
                                  ),
                                ),
                                SizedBox(width: Responsive.w(context, 8)),
                                Expanded(
                                  child: Text(
                                    _reasonLabel(reason),
                                    style: TextStyle(
                                      fontFamily: 'Hanken Grotesk',
                                      fontSize: Responsive.sp(context, 13),
                                      color: colors.primaryText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: Responsive.h(context, 12)),
                Text(
                  AppStrings.choose(
                    'Add details (Optional)',
                    'Thêm chi tiết (Không bắt buộc)',
                  ),
                  style: TextStyle(
                    fontFamily: 'Hanken Grotesk',
                    fontSize: Responsive.sp(context, 12),
                    fontWeight: FontWeight.w600,
                    color: colors.primaryText,
                  ),
                ),
                SizedBox(height: Responsive.h(context, 6)),
                TextField(
                  key: const Key('report-details-field'),
                  controller: _detailsController,
                  enabled: !_submitting,
                  minLines: 2,
                  maxLines: 3,
                  maxLength: 240,
                  decoration: InputDecoration(
                    hintText: AppStrings.choose(
                      'Provide any context that may help our moderation team.',
                      'Cung cấp thêm thông tin để hỗ trợ đội ngũ kiểm duyệt.',
                    ),
                    filled: true,
                    fillColor: colors.inputBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  SizedBox(height: Responsive.h(context, 6)),
                  Text(
                    _error!,
                    style: TextStyle(
                      fontFamily: 'Hanken Grotesk',
                      fontSize: Responsive.sp(context, 12),
                      color: colors.negativeAmount,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(
            Responsive.w(context, 18),
            Responsive.h(context, 12),
            Responsive.w(context, 18),
            Responsive.h(context, 14),
          ),
          decoration: BoxDecoration(
            color: colors.dialogBackground,
            border: Border(top: BorderSide(color: colors.divider)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: Responsive.w(context, 92),
                height: Responsive.h(context, 44),
                child: TextButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: Text(AppStrings.cancel),
                ),
              ),
              SizedBox(width: Responsive.w(context, 10)),
              SizedBox(
                width: Responsive.w(context, 166),
                height: Responsive.h(context, 44),
                child: FilledButton(
                  key: const Key('submit-report-button'),
                  onPressed: _reason == null || _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: _emerald,
                    disabledBackgroundColor: colors.disabled.withValues(
                      alpha: .32,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : Text(AppStrings.choose('Submit report', 'Gửi báo cáo')),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreview(FinFlowColors colors) {
    final avatar = widget.authorAvatarUrl?.trim();
    final initial = widget.authorName.trim().isEmpty
        ? '?'
        : widget.authorName.trim().characters.first.toUpperCase();
    final preview = stripFormattingForNotificationPreview(widget.content);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Responsive.w(context, 12)),
      decoration: BoxDecoration(
        color: colors.elevatedSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.divider),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: Responsive.w(context, 17),
            backgroundColor: _mint,
            backgroundImage: avatar != null && avatar.isNotEmpty
                ? NetworkImage(avatar)
                : null,
            child: avatar != null && avatar.isNotEmpty
                ? null
                : Text(
                    initial,
                    style: const TextStyle(
                      color: _emerald,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          SizedBox(width: Responsive.w(context, 10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.authorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: Responsive.sp(context, 12),
                    fontWeight: FontWeight.w700,
                    color: colors.primaryText,
                  ),
                ),
                SizedBox(height: Responsive.h(context, 2)),
                Text(
                  preview,
                  key: const Key('report-content-preview'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Hanken Grotesk',
                    fontSize: Responsive.sp(context, 11),
                    height: 1.25,
                    color: colors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(FinFlowColors colors) {
    final submitted = _state == _ReportDialogState.submitted;
    final color = submitted ? _emerald : _amber;
    return Padding(
      key: ValueKey(_state),
      padding: EdgeInsets.all(Responsive.w(context, 24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: Responsive.w(context, 52),
            height: Responsive.w(context, 52),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              submitted
                  ? Icons.check_circle_outline_rounded
                  : Icons.info_outline,
              color: color,
              size: Responsive.w(context, 28),
            ),
          ),
          SizedBox(height: Responsive.h(context, 16)),
          Text(
            submitted
                ? AppStrings.choose('Report submitted', 'Đã gửi báo cáo')
                : AppStrings.choose(
                    'You already reported this content',
                    'Bạn đã báo cáo nội dung này',
                  ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: Responsive.sp(context, 19),
              fontWeight: FontWeight.w700,
              color: colors.primaryText,
            ),
          ),
          SizedBox(height: Responsive.h(context, 8)),
          Text(
            submitted
                ? AppStrings.choose(
                    'Our moderation team will review it. Thank you for helping keep FinFlow safe.',
                    'Đội ngũ kiểm duyệt sẽ xem xét nội dung. Cảm ơn bạn đã giúp FinFlow an toàn hơn.',
                  )
                : AppStrings.choose(
                    'Your first report is still recorded and will be reviewed.',
                    'Báo cáo trước đó của bạn vẫn được ghi nhận và sẽ được xem xét.',
                  ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Hanken Grotesk',
              fontSize: Responsive.sp(context, 13),
              height: 1.4,
              color: colors.secondaryText,
            ),
          ),
          SizedBox(height: Responsive.h(context, 20)),
          SizedBox(
            width: double.infinity,
            height: Responsive.h(context, 46),
            child: FilledButton(
              key: const Key('close-report-result'),
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: _emerald,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                submitted
                    ? AppStrings.choose('Done', 'Xong')
                    : AppStrings.choose('Close', 'Đóng'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
