import 'package:flutter/material.dart';

// =============================================================================
// Lightweight in-house "rich text" for community posts.
//
// Posts are stored as plain TEXT in Supabase. Instead of pulling in a full
// rich-text-editor package, formatting is encoded with simple inline
// markers that the composer's toolbar inserts and this file parses back
// into styled spans:
//
//   **bold**       -> bold
//   _italic_       -> italic
//   ~underline~    -> underline
//   • at line start -> bullet point
//   ||spoiler||    -> blurred "tap to reveal" text
// =============================================================================

/// Strips all formatting markers for compact previews (feed cards),
/// replacing spoiler text with a placeholder so hidden content never
/// leaks into a preview.
String stripFormattingForPreview(String raw) {
  var text = raw.replaceAllMapped(
    RegExp(r'\|\|(.+?)\|\|', dotAll: true),
    (_) => '🙈 spoiler',
  );
  text = text.replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m.group(1)!);
  text = text.replaceAllMapped(RegExp(r'_(.+?)_'), (m) => m.group(1)!);
  text = text.replaceAllMapped(RegExp(r'~(.+?)~'), (m) => m.group(1)!);
  text = text.replaceAll(RegExp(r'^•\s?', multiLine: true), '');
  return text.replaceAll('\n', ' ').trim();
}

/// Renders post/comment content with bold/italic/underline/bullets and
/// tap-to-reveal spoilers.
///
/// Pass [maxLines] for a compact, unformatted preview (feed cards);
/// leave it `null` for the fully-formatted view (post detail screen).
class RichPostContent extends StatelessWidget {
  const RichPostContent({
    super.key,
    required this.content,
    required this.style,
    this.maxLines,
    this.spoilerColor = const Color(0xFF002117),
  });

  final String content;
  final TextStyle style;
  final int? maxLines;
  final Color spoilerColor;

  @override
  Widget build(BuildContext context) {
    if (maxLines != null) {
      return Text(
        stripFormattingForPreview(content),
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    final lines = content.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines) _buildLine(line),
      ],
    );
  }

  Widget _buildLine(String line) {
    final isBullet = line.startsWith('• ') || line.startsWith('•');
    final text = isBullet ? line.replaceFirst(RegExp(r'^•\s?'), '') : line;
    final spans = _parseSpoilers(text, style, spoilerColor);

    if (line.trim().isEmpty) {
      return const SizedBox(height: 6);
    }

    final richText = Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text.rich(TextSpan(children: spans)),
    );

    if (!isBullet) return richText;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1, right: 8),
            child: Text('•', style: style.copyWith(fontWeight: FontWeight.w800)),
          ),
          Expanded(child: Text.rich(TextSpan(children: spans))),
        ],
      ),
    );
  }
}

final _spoilerRegex = RegExp(r'\|\|(.+?)\|\|', dotAll: true);
final _inlineRegex = RegExp(r'\*\*(.+?)\*\*|_(.+?)_|~(.+?)~');

List<InlineSpan> _parseSpoilers(String text, TextStyle base, Color spoilerColor) {
  final spans = <InlineSpan>[];
  var lastEnd = 0;
  for (final match in _spoilerRegex.allMatches(text)) {
    if (match.start > lastEnd) {
      spans.addAll(_parseInline(text.substring(lastEnd, match.start), base));
    }
    spans.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: _SpoilerInline(
          text: match.group(1) ?? '',
          baseStyle: base,
          blurColor: spoilerColor,
        ),
      ),
    );
    lastEnd = match.end;
  }
  if (lastEnd < text.length) {
    spans.addAll(_parseInline(text.substring(lastEnd), base));
  }
  if (spans.isEmpty) spans.add(TextSpan(text: text, style: base));
  return spans;
}

List<InlineSpan> _parseInline(String text, TextStyle base) {
  final spans = <InlineSpan>[];
  var lastEnd = 0;
  for (final match in _inlineRegex.allMatches(text)) {
    if (match.start > lastEnd) {
      spans.add(TextSpan(text: text.substring(lastEnd, match.start), style: base));
    }
    if (match.group(1) != null) {
      spans.add(TextSpan(
        text: match.group(1),
        style: base.copyWith(fontWeight: FontWeight.w800),
      ));
    } else if (match.group(2) != null) {
      spans.add(TextSpan(
        text: match.group(2),
        style: base.copyWith(fontStyle: FontStyle.italic),
      ));
    } else if (match.group(3) != null) {
      spans.add(TextSpan(
        text: match.group(3),
        style: base.copyWith(decoration: TextDecoration.underline),
      ));
    }
    lastEnd = match.end;
  }
  if (lastEnd < text.length) {
    spans.add(TextSpan(text: text.substring(lastEnd), style: base));
  }
  if (spans.isEmpty) spans.add(TextSpan(text: text, style: base));
  return spans;
}

/// A spoiler-tagged run of text: redacted (blurred look) until tapped.
class _SpoilerInline extends StatefulWidget {
  const _SpoilerInline({
    required this.text,
    required this.baseStyle,
    required this.blurColor,
  });

  final String text;
  final TextStyle baseStyle;
  final Color blurColor;

  @override
  State<_SpoilerInline> createState() => _SpoilerInlineState();
}

class _SpoilerInlineState extends State<_SpoilerInline> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _revealed = !_revealed),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: _revealed ? Colors.transparent : widget.blurColor,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          widget.text,
          style: widget.baseStyle.copyWith(
            color: _revealed ? widget.baseStyle.color : Colors.transparent,
          ),
        ),
      ),
    );
  }
}
