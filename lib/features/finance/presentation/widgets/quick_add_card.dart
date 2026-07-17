import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

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
  late final TextEditingController _textController;

  bool get _blocked =>
      widget.isLoading || widget.isRecording || widget.isVoiceProcessing;

  double _widthScale(BuildContext context) =>
      (MediaQuery.sizeOf(context).width / 393).clamp(0.85, 1.1);

  double _heightScale(BuildContext context) =>
      (MediaQuery.sizeOf(context).height / 852).clamp(0.8, 1.0);

  double _w(BuildContext context, double value) => value * _widthScale(context);

  double _h(BuildContext context, double value) =>
      value * _heightScale(context);

  double _sp(BuildContext context, double value) =>
      value * _widthScale(context);

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
    if (_blocked) return;
    widget.onSubmit?.call(_textController.text.trim());
  }

  String get _inputHint {
    if (widget.isRecording) return 'LISTENING FOR INPUT...';
    if (widget.isVoiceProcessing) return 'PROCESSING VOICE...';
    return 'TYPE A TRANSACTION...';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(
            _w(context, 22),
            _h(context, 30),
            _w(context, 22),
            _h(context, 26),
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFE9EDF3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x14006C46)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 38,
                color: Color(0xFF006C46),
              ),
              SizedBox(height: _h(context, 18)),
              Text(
                'Try "Lunch 50k" or tap\nmic',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: _sp(context, 19),
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: const Color(0xFF101418),
                ),
              ),
              SizedBox(height: _h(context, 26)),
              Material(
                color: widget.isRecording
                    ? AppColors.coral
                    : const Color(0xFF00EFAF),
                borderRadius: BorderRadius.circular(10),
                elevation: 5,
                shadowColor: const Color(0x3300A77A),
                child: InkWell(
                  key: const Key('quick_add_voice_button'),
                  onTap: widget.isLoading || widget.isVoiceProcessing
                      ? null
                      : widget.onVoiceTap,
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: _w(context, 72),
                    height: _w(context, 72),
                    child: widget.isVoiceProcessing
                        ? const Padding(
                            padding: EdgeInsets.all(22),
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Color(0xFF052224),
                            ),
                          )
                        : Icon(
                            widget.isRecording
                                ? Icons.stop_rounded
                                : Icons.mic_rounded,
                            color: const Color(0xFF052224),
                            size: _w(context, 29),
                          ),
                  ),
                ),
              ),
              SizedBox(height: _h(context, 16)),
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: _h(context, 54)),
                child: TextField(
                  key: const Key('quick_add_text_field'),
                  controller: _textController,
                  enabled: !_blocked,
                  minLines: 1,
                  maxLines: 3,
                  textAlign: TextAlign.center,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  cursorColor: const Color(0xFF006C46),
                  style: TextStyle(
                    fontFamily: 'Hanken Grotesk',
                    fontSize: _sp(context, 15),
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: const Color(0xFF10221D),
                  ),
                  decoration: InputDecoration(
                    hintText: _inputHint,
                    hintStyle: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: _sp(context, 10),
                      letterSpacing: 1.2,
                      color: const Color(0xFF354B44),
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: _w(context, 4),
                      vertical: _h(context, 8),
                    ),
                  ),
                ),
              ),
              SizedBox(height: _h(context, 5)),
              Text(
                'Example: “Coffee 45000 with friends”',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Hanken Grotesk',
                  fontSize: _sp(context, 12),
                  fontStyle: FontStyle.italic,
                  color: const Color(0xFF728078),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: _h(context, 20)),
        FilledButton(
          key: const Key('quick_add_submit_button'),
          onPressed: _blocked ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: const Color(0xFF002112),
            disabledBackgroundColor: AppColors.primaryGreen.withValues(
              alpha: 0.55,
            ),
            minimumSize: Size.fromHeight(_h(context, 54)),
            shape: const StadiumBorder(),
            elevation: 6,
            shadowColor: AppColors.primaryGreen.withValues(alpha: 0.35),
          ),
          child: widget.isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Color(0xFF002112),
                  ),
                )
              : const Text(
                  'Interpret & Save',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
        ),
      ],
    );
  }
}
