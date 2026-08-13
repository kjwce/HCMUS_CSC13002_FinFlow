import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/i18n/app_language.dart';
import '../../models/quick_add_draft_model.dart';

const _darkBackground = Color(0xFF081C18);
const _darkSurface = Color(0xFF16352E);
const _darkRaisedSurface = Color(0xFF112622);
const _darkInputSurface = Color(0xFF0A241F);
const _darkBorder = Color(0xFF29483F);
const _darkText = Color(0xFFF4FBF8);
const _darkSecondaryText = Color(0xFFA9C1B9);
const _darkMutedText = Color(0xFF708D84);
const _darkAccent = Color(0xFF38D6AC);
const _darkButton = Color(0xFF006C53);
const _darkDanger = Color(0xFFFF6B70);
const _darkDangerBackground = Color(0xFF301314);

enum QuickAddDisplayState { idle, listening, processing, error, success }

class QuickAddCard extends StatefulWidget {
  const QuickAddCard({
    super.key,
    this.onSubmit,
    this.onVoiceTap,
    this.onRetry,
    this.onTypeInstead,
    this.onReview,
    this.controller,
    this.displayState,
    this.draft,
    this.errorMessage,
    this.isLoading = false,
    this.isRecording = false,
    this.isVoiceProcessing = false,
    this.voiceSoundLevel = 0,
  });

  final ValueChanged<String>? onSubmit;
  final VoidCallback? onVoiceTap;
  final VoidCallback? onRetry;
  final VoidCallback? onTypeInstead;
  final VoidCallback? onReview;
  final TextEditingController? controller;
  final QuickAddDisplayState? displayState;
  final QuickAddDraft? draft;
  final String? errorMessage;
  final bool isLoading;
  final bool isRecording;
  final bool isVoiceProcessing;
  final double voiceSoundLevel;

  @override
  State<QuickAddCard> createState() => _QuickAddCardState();
}

class _QuickAddCardState extends State<QuickAddCard>
    with SingleTickerProviderStateMixin {
  static const _emerald = Color(0xFF006C53);
  static const _brightMint = Color(0xFF00CFA3);
  static const _ink = Color(0xFF09221B);
  static const _muted = Color(0xFF5D6E67);
  static List<String> get _examples => AppStrings.isVietnamese
      ? const [
          'Ví dụ: “Cà phê với bạn 45 nghìn”',
          'Ví dụ: “Ăn trưa 50 nghìn bằng tiền mặt”',
          'Ví dụ: “Mua sắm 600 nghìn bằng chuyển khoản”',
          'Ví dụ: “Lương 10 triệu bằng chuyển khoản”',
          'Ví dụ: “Taxi 80 nghìn bằng tiền mặt”',
        ]
      : const [
          'Example: “Coffee 45k with friends”',
          'Example: “Lunch 50k paid in cash”',
          'Example: “Shopping 600k by transfer”',
          'Example: “Salary 10 million by transfer”',
          'Example: “Taxi 80k paid in cash”',
        ];

  late final TextEditingController _textController;
  late final AnimationController _ambientController;
  final _inputFocusNode = FocusNode();
  Timer? _exampleTimer;
  Timer? _listeningTimer;
  var _exampleIndex = 0;
  var _listeningSeconds = 0;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _surface => _isDark ? _darkSurface : Colors.white;
  Color get _raisedSurface =>
      _isDark ? _darkRaisedSurface : const Color(0xFFF2F4F3);
  Color get _inputSurface => _isDark ? _darkInputSurface : Colors.white;
  Color get _primaryText => _isDark ? _darkText : _ink;
  Color get _secondaryText => _isDark ? _darkSecondaryText : _muted;
  Color get _mutedText => _isDark ? _darkMutedText : const Color(0xFF88958F);
  Color get _border => _isDark ? _darkBorder : const Color(0xFFDCE7E2);
  Color get _accent => _isDark ? _darkAccent : _brightMint;

  QuickAddDisplayState get _state =>
      widget.displayState ??
      (widget.isLoading || widget.isVoiceProcessing
          ? QuickAddDisplayState.processing
          : widget.isRecording
          ? QuickAddDisplayState.listening
          : QuickAddDisplayState.idle);

  double _widthScale(BuildContext context) =>
      (MediaQuery.sizeOf(context).width / 393).clamp(0.85, 1.1);

  double _heightScale(BuildContext context) =>
      (MediaQuery.sizeOf(context).height / 852).clamp(0.78, 1.0);

  double _w(BuildContext context, double value) => value * _widthScale(context);
  double _h(BuildContext context, double value) =>
      value * _heightScale(context);
  double _sp(BuildContext context, double value) =>
      value * _widthScale(context);

  @override
  void initState() {
    super.initState();
    _textController = widget.controller ?? TextEditingController();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat();
    _exampleTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || _state != QuickAddDisplayState.idle) return;
      setState(() => _exampleIndex = (_exampleIndex + 1) % _examples.length);
    });
    if (_state == QuickAddDisplayState.listening) _startListeningTimer();
  }

  @override
  void didUpdateWidget(covariant QuickAddCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldState =
        oldWidget.displayState ??
        (oldWidget.isLoading || oldWidget.isVoiceProcessing
            ? QuickAddDisplayState.processing
            : oldWidget.isRecording
            ? QuickAddDisplayState.listening
            : QuickAddDisplayState.idle);
    if (oldState == _state) return;
    if (_state == QuickAddDisplayState.listening) {
      _startListeningTimer();
    } else {
      _listeningTimer?.cancel();
      _listeningSeconds = 0;
    }
  }

  void _startListeningTimer() {
    _listeningTimer?.cancel();
    _listeningSeconds = 0;
    _listeningTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _listeningSeconds++);
    });
  }

  @override
  void dispose() {
    _exampleTimer?.cancel();
    _listeningTimer?.cancel();
    _ambientController.dispose();
    _inputFocusNode.dispose();
    if (widget.controller == null) _textController.dispose();
    super.dispose();
  }

  void _submit() => widget.onSubmit?.call(_textController.text.trim());

  void _typeInstead() {
    widget.onTypeInstead?.call();
    Future<void>.delayed(const Duration(milliseconds: 180), () {
      if (mounted) _inputFocusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    if (disableAnimations && _ambientController.isAnimating) {
      _ambientController.stop();
    } else if (!disableAnimations && !_ambientController.isAnimating) {
      _ambientController.repeat();
    }
    return AnimatedSwitcher(
      duration: disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(.035, .02),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: switch (_state) {
        QuickAddDisplayState.idle => _buildIdle(),
        QuickAddDisplayState.listening => _buildListening(),
        QuickAddDisplayState.processing => _buildProcessing(),
        QuickAddDisplayState.error => _buildError(),
        QuickAddDisplayState.success => _buildSuccess(),
      },
    );
  }

  Widget _buildIdle() {
    return Column(
      key: const ValueKey(QuickAddDisplayState.idle),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _whiteCard(
          padding: EdgeInsets.fromLTRB(
            _w(context, 22),
            _h(context, 24),
            _w(context, 22),
            _h(context, 24),
          ),
          child: Column(
            children: [
              _AnimatedWaveBadge(animation: _ambientController),
              SizedBox(height: _h(context, 18)),
              Text(
                AppStrings.choose(
                  'Add a Transaction by\nVoice',
                  'Thêm giao dịch bằng\ngiọng nói',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: _sp(context, 20),
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: _primaryText,
                ),
              ),
              SizedBox(height: _h(context, 10)),
              Text(
                AppStrings.choose(
                  'Say something like “Lunch 50 thousand”',
                  'Hãy nói, ví dụ “Ăn trưa 50 nghìn”',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Hanken Grotesk',
                  fontSize: _sp(context, 12),
                  fontStyle: FontStyle.italic,
                  color: _secondaryText,
                ),
              ),
              SizedBox(height: _h(context, 20)),
              _VoiceOrb(
                animation: _ambientController,
                mode: _VoiceOrbMode.idle,
                onTap: widget.onVoiceTap,
                buttonKey: const Key('quick_add_voice_button'),
              ),
              SizedBox(height: _h(context, 16)),
              Text(
                AppStrings.choose('TAP TO START', 'CHẠM ĐỂ BẮT ĐẦU'),
                style: TextStyle(
                  fontFamily: 'Hanken Grotesk',
                  fontSize: _sp(context, 10),
                  fontWeight: FontWeight.w700,
                  letterSpacing: .8,
                  color: _isDark ? _darkAccent : _emerald,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: _h(context, 14)),
        Text(
          AppStrings.choose('Or type a transaction', 'Hoặc nhập giao dịch'),
          style: TextStyle(
            fontFamily: 'Hanken Grotesk',
            fontSize: _sp(context, 11),
            color: _primaryText,
          ),
        ),
        SizedBox(height: _h(context, 6)),
        _buildTextInput(showSend: false, managedFocus: true),
        SizedBox(height: _h(context, 8)),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(
            _examples[_exampleIndex],
            key: ValueKey(_exampleIndex),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Hanken Grotesk',
              fontSize: _sp(context, 11),
              fontStyle: FontStyle.italic,
              color: _secondaryText,
            ),
          ),
        ),
        SizedBox(height: _h(context, 14)),
        _primaryButton(
          key: const Key('quick_add_submit_button'),
          label: AppStrings.choose(
            'Interpret Transaction',
            'Phân tích giao dịch',
          ),
          onPressed: _submit,
        ),
      ],
    );
  }

  Widget _buildListening() {
    final minutes = (_listeningSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_listeningSeconds % 60).toString().padLeft(2, '0');
    final transcript = _textController.text.trim();
    return Column(
      key: const ValueKey(QuickAddDisplayState.listening),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: _h(context, 4)),
        Text(
          AppStrings.choose('Listening…', 'Đang nghe…'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: _sp(context, 20),
            fontWeight: FontWeight.w700,
            color: _primaryText,
          ),
        ),
        SizedBox(height: _h(context, 8)),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Text(
            transcript.isEmpty
                ? AppStrings.choose('Speak naturally', 'Hãy nói tự nhiên')
                : '“$transcript”',
            key: ValueKey(transcript),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Hanken Grotesk',
              fontSize: _sp(context, 12),
              color: _secondaryText,
            ),
          ),
        ),
        SizedBox(height: _h(context, 24)),
        _VoiceOrb(
          animation: _ambientController,
          mode: _VoiceOrbMode.listening,
          onTap: null,
        ),
        SizedBox(height: _h(context, 24)),
        _whiteCard(
          padding: EdgeInsets.symmetric(
            horizontal: _w(context, 18),
            vertical: _h(context, 18),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _VoiceWaveform(
                      isListening: true,
                      soundLevel: widget.voiceSoundLevel,
                      height: _h(context, 58),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _raisedSurface,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '$minutes:$seconds',
                      style: TextStyle(
                        fontFamily: 'Hanken Grotesk',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _secondaryText,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: _h(context, 12)),
              Material(
                color: const Color(0xFFC51620),
                shape: const CircleBorder(),
                elevation: 5,
                child: InkWell(
                  key: const Key('quick_add_voice_button'),
                  customBorder: const CircleBorder(),
                  onTap: widget.onVoiceTap,
                  child: const SizedBox.square(
                    dimension: 52,
                    child: Icon(
                      Icons.stop_rounded,
                      color: Colors.white,
                      size: 25,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox.shrink(key: Key('quick_add_submit_button')),
      ],
    );
  }

  Widget _buildProcessing() {
    return Column(
      key: const ValueKey(QuickAddDisplayState.processing),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _whiteCard(
          padding: EdgeInsets.symmetric(
            horizontal: _w(context, 24),
            vertical: _h(context, 44),
          ),
          child: Column(
            children: [
              SizedBox(
                width: _w(context, 132),
                height: _w(context, 132),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: _accent,
                        backgroundColor: _isDark
                            ? _darkBorder
                            : const Color(0xFFDDF3EB),
                      ),
                    ),
                    Material(
                      key: const Key('quick_add_voice_button'),
                      color: _isDark ? _darkButton : _emerald,
                      shape: const CircleBorder(),
                      elevation: 6,
                      child: SizedBox.square(
                        dimension: _w(context, 72),
                        child: const Icon(
                          Icons.graphic_eq_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: _h(context, 54)),
              Text(
                AppStrings.choose(
                  'Refining data points…',
                  'Đang hoàn thiện dữ liệu…',
                ),
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: _sp(context, 16),
                  fontWeight: FontWeight.w600,
                  color: _isDark ? _darkSecondaryText : _emerald,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: _h(context, 72)),
        _primaryButton(
          key: const Key('quick_add_submit_button'),
          label: AppStrings.choose(
            'Interpret Transaction ϟ',
            'Phân tích giao dịch ϟ',
          ),
          onPressed: null,
        ),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      key: const ValueKey(QuickAddDisplayState.error),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _whiteCard(
          padding: EdgeInsets.fromLTRB(
            _w(context, 20),
            _h(context, 34),
            _w(context, 20),
            _h(context, 28),
          ),
          child: Column(
            children: [
              _ErrorIndicator(animation: _ambientController),
              SizedBox(height: _h(context, 28)),
              Text(
                AppStrings.choose(
                  'We couldn’t understand that.',
                  'Chúng tôi chưa hiểu nội dung đó.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: _sp(context, 18),
                  fontWeight: FontWeight.w700,
                  color: _isDark ? _darkDanger : _ink,
                ),
              ),
              SizedBox(height: _h(context, 12)),
              Text(
                widget.errorMessage ??
                    AppStrings.choose(
                      'The connection might be weak, or the background was a bit too noisy for us.',
                      'Kết nối có thể yếu hoặc môi trường xung quanh hơi ồn.',
                    ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Hanken Grotesk',
                  fontSize: _sp(context, 12),
                  height: 1.45,
                  color: _secondaryText,
                ),
              ),
              SizedBox(height: _h(context, 22)),
              OutlinedButton(
                onPressed: widget.onRetry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _accent,
                  side: BorderSide(color: _accent, width: 1.5),
                  minimumSize: Size.fromHeight(_h(context, 48)),
                  shape: const StadiumBorder(),
                ),
                child: Text(AppStrings.choose('Try Again', 'Thử lại')),
              ),
              TextButton(
                onPressed: _typeInstead,
                style: TextButton.styleFrom(foregroundColor: _secondaryText),
                child: Text(AppStrings.choose('Type Instead', 'Nhập thủ công')),
              ),
            ],
          ),
        ),
        SizedBox(height: _h(context, 16)),
        _buildTextInput(showSend: true, managedFocus: false),
        const SizedBox.shrink(key: Key('quick_add_submit_button')),
      ],
    );
  }

  Widget _buildSuccess() {
    return Column(
      key: const ValueKey(QuickAddDisplayState.success),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _whiteCard(
          padding: EdgeInsets.fromLTRB(
            _w(context, 20),
            _h(context, 28),
            _w(context, 20),
            _h(context, 26),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SuccessIndicator(animation: _ambientController),
              SizedBox(height: _h(context, 22)),
              Text(
                AppStrings.choose('We heard', 'Nội dung đã nghe'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: _sp(context, 20),
                  fontWeight: FontWeight.w700,
                  color: _isDark ? _darkAccent : _emerald,
                ),
              ),
              SizedBox(height: _h(context, 8)),
              Text(
                AppStrings.choose(
                  'Check what you said and edit anything that looks wrong.',
                  'Kiểm tra nội dung đã nói và sửa thông tin chưa đúng.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Hanken Grotesk',
                  fontSize: _sp(context, 12),
                  color: _secondaryText,
                ),
              ),
              SizedBox(height: _h(context, 20)),
              TextField(
                key: const Key('quick_add_success_text_field'),
                controller: _textController,
                focusNode: _inputFocusNode,
                minLines: 2,
                maxLines: 4,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                style: TextStyle(
                  fontFamily: 'Hanken Grotesk',
                  fontSize: _sp(context, 16),
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  color: _primaryText,
                ),
                decoration: InputDecoration(
                  hintText: AppStrings.choose(
                    'Your voice transcript',
                    'Nội dung giọng nói',
                  ),
                  suffixIcon: Icon(
                    Icons.edit_rounded,
                    color: _isDark ? _darkAccent : _emerald,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: _isDark
                      ? _darkInputSurface
                      : const Color(0xFFF7FAF8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: _border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: _border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: _accent, width: 1.5),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: _w(context, 16),
                    vertical: _h(context, 16),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: _h(context, 22)),
        _primaryButton(
          key: const Key('quick_add_submit_button'),
          label: AppStrings.choose('Review & Save', 'Kiểm tra và lưu'),
          onPressed: widget.draft == null ? null : widget.onReview,
        ),
        SizedBox(height: _h(context, 8)),
      ],
    );
  }

  Widget _buildTextInput({required bool showSend, required bool managedFocus}) {
    return Material(
      color: _inputSurface,
      borderRadius: BorderRadius.circular(14),
      elevation: _isDark ? 0 : 1,
      shadowColor: const Color(0x1F004F3B),
      child: TextField(
        key: const Key('quick_add_text_field'),
        controller: _textController,
        focusNode: managedFocus ? _inputFocusNode : null,
        minLines: 1,
        maxLines: 3,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        style: TextStyle(
          fontFamily: 'Hanken Grotesk',
          fontSize: _sp(context, 14),
          fontWeight: FontWeight.w500,
          color: _primaryText,
        ),
        decoration: InputDecoration(
          hintText: AppStrings.choose(
            'Describe your transaction…',
            'Mô tả giao dịch của bạn…',
          ),
          hintStyle: TextStyle(
            fontFamily: 'Hanken Grotesk',
            fontSize: _sp(context, 12),
            color: _mutedText,
          ),
          prefixIcon: Icon(
            Icons.edit_note_rounded,
            size: 21,
            color: _secondaryText,
          ),
          suffixIcon: showSend
              ? IconButton.filled(
                  onPressed: _submit,
                  style: IconButton.styleFrom(
                    backgroundColor: _isDark ? _darkButton : _emerald,
                  ),
                  icon: Icon(
                    Icons.send_rounded,
                    color: _isDark ? _darkAccent : Colors.white,
                    size: 18,
                  ),
                )
              : null,
          filled: true,
          fillColor: _inputSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _accent, width: 1.5),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: _w(context, 12),
            vertical: _h(context, 14),
          ),
        ),
      ),
    );
  }

  Widget _primaryButton({
    required Key key,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return FilledButton(
      key: key,
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: _isDark ? _darkButton : _emerald,
        foregroundColor: Colors.white,
        disabledBackgroundColor: (_isDark ? _darkButton : _emerald).withValues(
          alpha: .48,
        ),
        disabledForegroundColor: Colors.white.withValues(alpha: .8),
        minimumSize: Size.fromHeight(_h(context, 52)),
        shape: const StadiumBorder(),
        elevation: _isDark || onPressed == null ? 0 : 5,
        shadowColor: _isDark
            ? Colors.transparent
            : _emerald.withValues(alpha: .28),
        textStyle: TextStyle(
          fontFamily: 'Manrope',
          fontSize: _sp(context, 14),
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Text(label),
    );
  }

  Widget _whiteCard({required EdgeInsets padding, required Widget child}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _isDark ? _darkBorder : const Color(0x1F006C53),
        ),
        boxShadow: _isDark
            ? const []
            : const [
                BoxShadow(
                  color: Color(0x10004F3B),
                  blurRadius: 18,
                  offset: Offset(0, 7),
                ),
              ],
      ),
      child: child,
    );
  }
}

class _AnimatedWaveBadge extends StatelessWidget {
  const _AnimatedWaveBadge({required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      key: const Key('quick_add_voice_waveform'),
      animation: animation,
      builder: (_, _) {
        final phase = animation.value * math.pi * 2;
        final breathe = 1 + (.035 * (1 + math.sin(phase)) / 2);
        return Transform.scale(
          scale: breathe,
          child: Container(
            width: 46,
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? _darkInputSurface : const Color(0xFFDDF3EB),
              borderRadius: BorderRadius.circular(12),
              border: isDark ? Border.all(color: _darkBorder) : null,
              boxShadow: isDark
                  ? const []
                  : [
                      BoxShadow(
                        color: const Color(0xFF00CFA3).withValues(
                          alpha: .12 + (.07 * math.sin(phase).abs()),
                        ),
                        blurRadius: 14,
                      ),
                    ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(5, (index) {
                final wave =
                    .5 + (.5 * math.sin(phase - (index * math.pi / 2.7)));
                final envelope = index == 2
                    ? 1.0
                    : (index == 1 || index == 3 ? .78 : .56);
                return Container(
                  width: 3.5,
                  height: 7 + (18 * wave * envelope),
                  decoration: BoxDecoration(
                    color: isDark ? _darkAccent : const Color(0xFF007A5E),
                    borderRadius: BorderRadius.circular(99),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }
}

enum _VoiceOrbMode { idle, listening }

class _VoiceOrb extends StatelessWidget {
  const _VoiceOrb({
    required this.animation,
    required this.mode,
    required this.onTap,
    this.buttonKey,
  });

  final Animation<double> animation;
  final _VoiceOrbMode mode;
  final VoidCallback? onTap;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    final listening = mode == _VoiceOrbMode.listening;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = listening ? 214.0 : 174.0;
    return AnimatedBuilder(
      animation: animation,
      builder: (_, _) {
        final phase = animation.value * math.pi * 2;
        return SizedBox.square(
          dimension: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (var index = 0; index < 4; index++)
                Transform.scale(
                  scale:
                      1 +
                      (.025 * math.sin(phase - (index * math.pi / 3)).abs()),
                  child: Container(
                    width: size - (index * (listening ? 29 : 27)),
                    height: size - (index * (listening ? 29 : 27)),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: listening
                          ? Colors.transparent
                          : (isDark ? _darkAccent : const Color(0xFF006C53))
                                .withValues(alpha: .07 + (index * .045)),
                      border: listening
                          ? Border.all(
                              color:
                                  (isDark
                                          ? _darkAccent
                                          : const Color(0xFF00CFA3))
                                      .withValues(alpha: .3 + (index * .1)),
                            )
                          : null,
                    ),
                  ),
                ),
              Material(
                color: listening
                    ? (isDark ? _darkAccent : const Color(0xFF00CFA3))
                    : (isDark ? _darkButton : const Color(0xFF007A5E)),
                shape: const CircleBorder(),
                elevation: isDark ? 0 : 7,
                shadowColor: isDark
                    ? Colors.transparent
                    : const Color(0x50006C53),
                child: InkWell(
                  key: buttonKey,
                  customBorder: const CircleBorder(),
                  onTap: onTap,
                  child: SizedBox.square(
                    dimension: listening ? 94 : 66,
                    child: Icon(
                      Icons.mic_rounded,
                      color: isDark && listening
                          ? _darkBackground
                          : Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ErrorIndicator extends StatelessWidget {
  const _ErrorIndicator({required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: .7, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutBack,
      builder: (_, entrance, child) =>
          Transform.scale(scale: entrance, child: child),
      child: AnimatedBuilder(
        animation: animation,
        builder: (_, _) {
          final pulse = animation.value;
          return SizedBox.square(
            dimension: 108,
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (var index = 0; index < 2; index++)
                  Transform.scale(
                    scale: .84 + (((pulse + (index * .32)) % 1) * .3),
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              (isDark ? _darkDanger : const Color(0xFFEF9A9A))
                                  .withValues(
                                    alpha:
                                        (1 - ((pulse + (index * .32)) % 1)) *
                                        .42,
                                  ),
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: isDark
                        ? _darkDangerBackground
                        : const Color(0xFFB3261E),
                    shape: BoxShape.circle,
                    border: isDark ? Border.all(color: _darkDanger) : null,
                    boxShadow: isDark
                        ? const []
                        : const [
                            BoxShadow(
                              color: Color(0x36B3261E),
                              blurRadius: 14,
                              offset: Offset(0, 5),
                            ),
                          ],
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: isDark ? _darkDanger : Colors.white,
                    size: 34,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SuccessIndicator extends StatelessWidget {
  const _SuccessIndicator({required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: .72, end: 1),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutBack,
      builder: (_, value, child) => Transform.scale(scale: value, child: child),
      child: AnimatedBuilder(
        animation: animation,
        builder: (_, _) {
          final phase = animation.value * math.pi * 2;
          return SizedBox.square(
            dimension: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (var index = 0; index < 3; index++)
                  Transform.scale(
                    scale:
                        1 +
                        (.018 * math.sin(phase - (index * math.pi / 3)).abs()),
                    child: Container(
                      width: 140 - (index * 20),
                      height: 140 - (index * 20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              (isDark ? _darkAccent : const Color(0xFF00CFA3))
                                  .withValues(alpha: .16 + (index * .08)),
                        ),
                      ),
                    ),
                  ),
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: isDark ? _darkButton : const Color(0xFF006C53),
                    shape: BoxShape.circle,
                    boxShadow: isDark
                        ? const []
                        : const [
                            BoxShadow(
                              color: Color(0x38006C53),
                              blurRadius: 16,
                              offset: Offset(0, 6),
                            ),
                          ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _VoiceWaveform extends StatefulWidget {
  const _VoiceWaveform({
    required this.isListening,
    required this.soundLevel,
    required this.height,
  });

  final bool isListening;
  final double soundLevel;
  final double height;

  @override
  State<_VoiceWaveform> createState() => _VoiceWaveformState();
}

class _VoiceWaveformState extends State<_VoiceWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  var _minimumLevel = double.infinity;
  var _maximumLevel = double.negativeInfinity;
  var _energy = .25;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant _VoiceWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isListening) {
      _energy = .25;
      _minimumLevel = double.infinity;
      _maximumLevel = double.negativeInfinity;
      return;
    }
    if (widget.soundLevel == oldWidget.soundLevel) return;
    _minimumLevel = math.min(_minimumLevel, widget.soundLevel);
    _maximumLevel = math.max(_maximumLevel, widget.soundLevel);
    final range = _maximumLevel - _minimumLevel;
    final normalized = range > .25
        ? ((widget.soundLevel - _minimumLevel) / range).clamp(0.0, 1.0)
        : (widget.soundLevel.abs() / 10).clamp(0.0, 1.0);
    final target = .18 + (normalized * .82);
    _energy = (_energy * .58) + (target * .42);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RepaintBoundary(
      key: const Key('quick_add_voice_waveform'),
      child: SizedBox(
        width: double.infinity,
        height: widget.height,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, _) => CustomPaint(
            painter: _WaveformPainter(
              phase: _controller.value * math.pi * 2,
              energy: widget.isListening ? _energy : .25,
              isListening: widget.isListening,
              color: isDark ? _darkAccent : const Color(0xFF00CFA3),
            ),
          ),
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({
    required this.phase,
    required this.energy,
    required this.isListening,
    required this.color,
  });

  static const _barCount = 17;
  final double phase;
  final double energy;
  final bool isListening;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const barWidth = 4.0;
    const gap = 3.5;
    final totalWidth = (_barCount * barWidth) + ((_barCount - 1) * gap);
    final startX = math.max(0.0, (size.width - totalWidth) / 2);
    final centerY = size.height / 2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round;

    for (var index = 0; index < _barCount; index++) {
      final delayedWave = .5 + (.5 * math.sin(phase - (index * math.pi / 4.5)));
      final envelope =
          .58 + (.42 * math.sin((index + 1) * math.pi / (_barCount + 1)));
      final activeEnergy = .22 + (energy * (.34 + (.66 * delayedWave)));
      final barEnergy = isListening ? activeEnergy : .35;
      final height = 5 + ((size.height - 9) * barEnergy * envelope);
      final x = startX + (index * (barWidth + gap)) + (barWidth / 2);
      if (x > size.width) break;
      canvas.drawLine(
        Offset(x, centerY - (height / 2)),
        Offset(x, centerY + (height / 2)),
        paint..color = color.withValues(alpha: .6 + (.4 * envelope)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      phase != oldDelegate.phase ||
      energy != oldDelegate.energy ||
      isListening != oldDelegate.isListening ||
      color != oldDelegate.color;
}
