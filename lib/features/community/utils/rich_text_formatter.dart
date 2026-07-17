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
//   *italic*       -> italic
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
  text = text.replaceAllMapped(
    RegExp(r'\*([^*]+?)\*', dotAll: true),
    (m) => m.group(1)!,
  );
  text = text.replaceAllMapped(RegExp(r'~(.+?)~'), (m) => m.group(1)!);
  text = text.replaceAll(RegExp(r'^•\s?', multiLine: true), '');
  return text.replaceAll('\n', ' ').trim();
}

/// Produces a defensive plain-text preview for notification history.
/// Legacy posts can contain incomplete marker pairs from older composers, so
/// notification previews remove any formatting controls left after parsing.
String stripFormattingForNotificationPreview(String raw) {
  var text = stripFormattingForPreview(raw);
  text = text.replaceAll(RegExp(r'[\*~]'), '');
  text = text.replaceAll('||', '');
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Renders post/comment content with bold/italic/underline/bullets and
/// tap-to-reveal spoilers.
///
/// [maxLines] only limits the visible lines. Formatting is rendered in both
/// feed previews and the full post detail so the storage markers never leak
/// into the UI.
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
    return Text.rich(
      TextSpan(
        style: style,
        children: _parseSpoilers(content, style, spoilerColor),
      ),
      maxLines: maxLines,
      overflow: maxLines == null ? TextOverflow.clip : TextOverflow.ellipsis,
    );
  }
}

final _spoilerRegex = RegExp(r'\|\|(.+?)\|\|', dotAll: true);

/// Text controller that previews the community's lightweight Markdown while
/// preserving the raw marker text used for storage and cursor offsets.
class MarkdownEditingController extends TextEditingController {
  MarkdownEditingController({super.text});

  Set<String> activeFormatsAt(int offset) {
    var bold = false;
    var italic = false;
    var underline = false;
    var i = 0;
    final limit = offset.clamp(0, text.length);
    while (i < limit) {
      if (text[i] == '*') {
        var count = 0;
        while (i + count < limit && text[i + count] == '*') {
          count++;
        }
        final triples = count ~/ 3;
        if (triples.isOdd) {
          bold = !bold;
          italic = !italic;
        }
        final remainder = count % 3;
        if (remainder == 2) bold = !bold;
        if (remainder == 1) italic = !italic;
        i += count;
        continue;
      }
      if (text[i] == '~') {
        underline = !underline;
      }
      i++;
    }
    return {if (bold) 'bold', if (italic) 'italic', if (underline) 'underline'};
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final spans = <InlineSpan>[];
    final hidden = base.copyWith(color: Colors.transparent, fontSize: 0);
    var i = 0;
    while (i < text.length) {
      if (text[i] == '*' || text[i] == '~') {
        spans.add(TextSpan(text: text[i], style: hidden));
        i++;
        continue;
      }
      final start = i;
      while (i < text.length && text[i] != '*' && text[i] != '~') {
        i++;
      }
      final formats = activeFormatsAt(start);
      spans.add(
        TextSpan(
          text: text.substring(start, i),
          style: base.copyWith(
            fontWeight: formats.contains('bold') ? FontWeight.w800 : null,
            fontStyle: formats.contains('italic') ? FontStyle.italic : null,
            decoration: formats.contains('underline')
                ? TextDecoration.underline
                : null,
          ),
        ),
      );
    }
    return TextSpan(style: base, children: spans);
  }
}

List<InlineSpan> _parseSpoilers(
  String text,
  TextStyle base,
  Color spoilerColor,
) {
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
  final starCount = '*'.allMatches(text).length;
  final tildeCount = '~'.allMatches(text).length;
  final parseStars = starCount.isEven;
  final parseTildes = tildeCount.isEven;
  var bold = false;
  var italic = false;
  var underline = false;
  var index = 0;
  var textStart = 0;

  void addText(int end) {
    if (end <= textStart) return;
    spans.add(
      TextSpan(
        text: text.substring(textStart, end),
        style: base.copyWith(
          fontWeight: bold ? FontWeight.w800 : base.fontWeight,
          fontStyle: italic ? FontStyle.italic : base.fontStyle,
          decoration: underline ? TextDecoration.underline : base.decoration,
        ),
      ),
    );
  }

  while (index < text.length) {
    if (parseStars && text[index] == '*') {
      addText(index);
      var count = 0;
      while (index + count < text.length && text[index + count] == '*') {
        count++;
      }

      if ((count ~/ 3).isOdd) {
        bold = !bold;
        italic = !italic;
      }
      final remainder = count % 3;
      if (remainder == 2) bold = !bold;
      if (remainder == 1) italic = !italic;
      index += count;
      textStart = index;
      continue;
    }

    if (parseTildes && text[index] == '~') {
      addText(index);
      underline = !underline;
      index++;
      textStart = index;
      continue;
    }
    index++;
  }

  addText(text.length);
  if (spans.isEmpty && text.isNotEmpty) {
    spans.add(TextSpan(text: text, style: base));
  }
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
