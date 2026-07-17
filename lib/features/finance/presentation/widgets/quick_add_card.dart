import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';

class QuickAddCard extends StatefulWidget {
  const QuickAddCard({
    super.key,
    this.onSubmit,
    this.onVoiceTap,
    this.controller,
    this.isLoading = false,
    this.isRecording = false,
    this.isVoiceProcessing = false,
  });

  final ValueChanged<String>? onSubmit;
  final VoidCallback? onVoiceTap;
  final TextEditingController? controller;
  final bool isLoading;
  final bool isRecording;
  final bool isVoiceProcessing;

  @override
  State<QuickAddCard> createState() => _QuickAddCardState();
}

class _QuickAddCardState extends State<QuickAddCard> {
  static const _headlineFont = 'Manrope';
  static const _bodyFont = 'Hanken Grotesk';

  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = widget.controller ?? TextEditingController();
  }

  @override
  void dispose() {
    if (widget.controller == null) _textController.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.isLoading || widget.isRecording || widget.isVoiceProcessing) {
      return;
    }
    final text = _textController.text.trim();
    widget.onSubmit?.call(text);
  }

  @override
  Widget build(BuildContext context) {
    final themeColors = context.finFlowColors;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        Responsive.w(context, 20),
        Responsive.h(context, 20),
        Responsive.w(context, 20),
        Responsive.h(context, 22),
      ),
      decoration: BoxDecoration(
        color: themeColors.surface,
        borderRadius: BorderRadius.circular(Responsive.w(context, 24)),
        border: Border.all(color: const Color(0xFFE9EEEB)),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepEmerald.withValues(alpha: 0.06),
            blurRadius: Responsive.w(context, 16),
            offset: Offset(0, Responsive.h(context, 5)),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                size: Responsive.w(context, 22),
                color: AppColors.mediumGreen,
              ),
              SizedBox(width: Responsive.w(context, 9)),
              Text(
                'QUICK ADD',
                style: TextStyle(
                  fontFamily: _headlineFont,
                  fontSize: Responsive.sp(context, 16),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  color: themeColors.primaryText,
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.h(context, 16)),
          Container(
            height: Responsive.h(context, 64),
            padding: EdgeInsets.only(
              left: Responsive.w(context, 16),
              right: Responsive.w(context, 8),
            ),
            decoration: BoxDecoration(
              color: themeColors.elevatedSurface,
              borderRadius: BorderRadius.circular(Responsive.w(context, 16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('quick_add_text_field'),
                    controller: _textController,
                    enabled:
                        !widget.isLoading &&
                        !widget.isRecording &&
                        !widget.isVoiceProcessing,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    cursorColor: AppColors.mediumGreen,
                    style: TextStyle(
                      fontFamily: _bodyFont,
                      fontSize: Responsive.sp(context, 15),
                      color: themeColors.primaryText,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: themeColors.elevatedSurface,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        vertical: Responsive.h(context, 15),
                      ),
                      hintText: "Try 'Lunch 50k' or tap mic",
                      hintStyle: TextStyle(
                        fontFamily: _bodyFont,
                        fontSize: Responsive.sp(context, 14),
                        fontWeight: FontWeight.w400,
                        color: AppColors.mutedGray,
                      ),
                    ),
                  ),
                ),
                Material(
                  color: widget.isRecording
                      ? AppColors.coral.withValues(alpha: 0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    key: const Key('quick_add_voice_button'),
                    onTap: widget.isLoading || widget.isVoiceProcessing
                        ? null
                        : () => widget.onVoiceTap?.call(),
                    borderRadius: BorderRadius.circular(999),
                    child: Padding(
                      padding: EdgeInsets.all(Responsive.w(context, 10)),
                      child: widget.isVoiceProcessing
                          ? SizedBox(
                              width: Responsive.w(context, 21),
                              height: Responsive.w(context, 21),
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.mediumGreen,
                              ),
                            )
                          : Icon(
                              widget.isRecording
                                  ? Icons.stop_rounded
                                  : Icons.mic_none_rounded,
                              size: Responsive.w(context, 23),
                              color: widget.isRecording
                                  ? AppColors.coral
                                  : AppColors.mediumGreen,
                            ),
                    ),
                  ),
                ),
                SizedBox(width: Responsive.w(context, 3)),
                Material(
                  color: AppColors.primaryGreen,
                  borderRadius: BorderRadius.circular(
                    Responsive.w(context, 13),
                  ),
                  child: InkWell(
                    key: const Key('quick_add_submit_button'),
                    onTap:
                        widget.isLoading ||
                            widget.isRecording ||
                            widget.isVoiceProcessing
                        ? null
                        : _submit,
                    borderRadius: BorderRadius.circular(
                      Responsive.w(context, 13),
                    ),
                    child: SizedBox(
                      width: Responsive.w(context, 48),
                      height: Responsive.w(context, 48),
                      child: widget.isLoading
                          ? Center(
                              child: SizedBox(
                                width: Responsive.w(context, 20),
                                height: Responsive.w(context, 20),
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: AppColors.deepEmerald,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.bolt_rounded,
                              size: Responsive.w(context, 28),
                              color: AppColors.deepEmerald,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
