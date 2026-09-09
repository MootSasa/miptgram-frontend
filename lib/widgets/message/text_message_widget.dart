import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';
import '../../services/chat_service.dart';
import '../../services/glass_toast_service.dart';
import '../../utils/emoji_utils.dart';
import '../../utils/entity_parser.dart';
import 'code_block_widget.dart';
import 'collapsible_blockquote_widget.dart';
import 'spoiler_text_widget.dart';

// --- НАСТРОЙКИ СТИЛЯ ТЕКСТОВОГО СООБЩЕНИЯ ---
/// Прозрачность фона для инлайнового кода в темной теме.
const double _kInlineCodeDarkOpacity = 0.1;
/// Прозрачность фона для инлайнового кода в светлой теме.
const double _kInlineCodeLightOpacity = 0.12;
/// Стандартный размер шрифта сообщений.
const double _kMessageFontSize = 17.0;
// --------------------------------------------

/// Builder for code blocks using [CodeBlockWidget].
class CodeElementBuilder extends MarkdownElementBuilder {
  final BuildContext context;
  final bool isDark;
  final bool isMe;

  CodeElementBuilder(this.context, this.isDark, this.isMe);

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    // Check if this is a block code (has newline or language attribute from markdown parser)
    final bool isBlock = element.attributes['class'] != null || 
                         element.textContent.contains('\n');

    if (!isBlock) {
      // Inline code rendering - use textContent as-is (without backticks)
      final codeText = element.textContent;
      return GestureDetector(
        onTap: () {
          Clipboard.setData(ClipboardData(text: codeText));
          GlassToastService().show(context, 'Код скопирован', icon: Icons.check);
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Text(
            codeText,
            style: preferredStyle?.copyWith(
              fontFamily: 'monospace',
              backgroundColor: isDark 
                  ? Colors.white.withValues(alpha: _kInlineCodeDarkOpacity) 
                  : Colors.black.withValues(alpha: _kInlineCodeLightOpacity),
            ),
          ),
        ),
      );
    }

    // Block code: extract language and strip backticks from content
    final language = element.attributes['class']?.replaceFirst('language-', '');
    
    // Strip leading and trailing backticks from code content
    // The markdown parser sometimes includes ``` in textContent
    String code = element.textContent;
    if (code.startsWith('```')) {
      code = code.substring(3);
    }
    if (code.endsWith('```')) {
      code = code.substring(0, code.length - 3);
    }
    // Also strip language identifier if it's on the first line
    if (language != null && code.startsWith(language)) {
      code = code.substring(language.length);
    }
    code = code.trim();

    return CodeBlockWidget(
      code: code,
      language: language,
      isDark: isDark,
      isMe: isMe,
    );
  }
}

/// Custom block syntax for collapsible blockquotes: lines starting with **>
class CollapsibleBlockquoteBlockSyntax extends md.BlockSyntax {
  static final RegExp _pattern = RegExp(r'^[ ]{0,3}\*\*>[ ]?(.*)$');

  @override
  RegExp get pattern => _pattern;

  const CollapsibleBlockquoteBlockSyntax();

  @override
  List<md.Line> parseChildLines(md.BlockParser parser) {
    final childLines = <md.Line>[];

    while (!parser.isDone) {
      final currentLine = parser.current;
      final match = pattern.firstMatch(currentLine.content);
      if (match != null) {
        final markerStart = currentLine.content.indexOf('**>');
        int markerEnd = markerStart + 3;
        if (currentLine.content.length > markerEnd &&
            (currentLine.content[markerEnd] == ' ' || currentLine.content[markerEnd] == '\t')) {
          markerEnd++;
        }
        childLines.add(md.Line(currentLine.content.substring(markerEnd)));
        parser.advance();
        continue;
      }
      break;
    }

    return childLines;
  }

  @override
  md.Node parse(md.BlockParser parser) {
    final childLines = parseChildLines(parser);
    final children = md.BlockParser(childLines, parser.document).parseLines(
      parentSyntax: this,
    );
    final element = md.Element('blockquote', children);
    element.attributes['collapsed'] = 'true';
    return element;
  }
}

/// Builder for Markdown blockquotes using [CollapsibleBlockquoteWidget].
class BlockquoteElementBuilder extends MarkdownElementBuilder {
  final BuildContext context;
  final bool isDark;
  final bool isMe;

  BlockquoteElementBuilder(this.context, this.isDark, this.isMe);

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final rawText = element.textContent.trim();
    if (rawText.isEmpty) return null;

    final bool isCollapsible = element.attributes['collapsed'] == 'true' ||
        rawText.startsWith('collapse:') ||
        rawText.startsWith('**>');

    final text = rawText
        .replaceFirst(RegExp(r'^(?:collapse:|\*\*>\s?)\s*'), '');

    return CollapsibleBlockquoteWidget(
      text: text,
      isCollapsible: isCollapsible,
      initialExpanded: false,
      isDark: isDark,
      isMe: isMe,
    );
  }
}

/// Builder for LaTeX formulas using [Math].
class MathElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final text = element.textContent;
    if (text.isEmpty) return null;

    bool isDisplayMode = text.startsWith(r'$$') && text.endsWith(r'$$');
    final math = isDisplayMode
        ? text.substring(2, text.length - 2).trim()
        : text.substring(1, text.length - 1).trim();

    return Math.tex(
      math,
      mathStyle: isDisplayMode ? MathStyle.display : MathStyle.text,
      textStyle: preferredStyle?.copyWith(
        color: Colors.teal,
        fontStyle: FontStyle.italic,
      ),
      onErrorFallback: (err) => Text(
        text,
        style: const TextStyle(color: Colors.red),
      ),
    );
  }
}

/// Custom syntax for LaTeX formulas: $...$ and $$...$$
class MathInlineSyntax extends md.InlineSyntax {
  MathInlineSyntax() : super(r'(\$\$[\s\S]*?\$\$)|(\$[\s\S]*?\$)');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final element = md.Element.text('latex', match.group(0)!);
    parser.addNode(element);
    return true;
  }
}

/// Custom syntax for inline checkboxes: [ ] and [x]
class CheckboxInlineSyntax extends md.InlineSyntax {
  CheckboxInlineSyntax() : super(r'(\[ \]|\[x\])');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final isChecked = match.group(0)!.contains('x');
    final element = md.Element.text('checkbox', isChecked ? 'checked' : 'unchecked');
    parser.addNode(element);
    return true;
  }
}

/// Custom syntax for Apple Emojis
class EmojiInlineSyntax extends md.InlineSyntax {
  EmojiInlineSyntax() : super(EmojiUtils.emojiRegex.pattern);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final element = md.Element.text('emoji', match.group(0)!);
    parser.addNode(element);
    return true;
  }
}

/// Builder for inline checkboxes using real Material Checkbox widget.
class CheckboxElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final isChecked = element.textContent == 'checked';
    
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Checkbox(
          value: isChecked,
          onChanged: null,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

/// Builder for Apple Emojis using CDN.
class EmojiElementBuilder extends MarkdownElementBuilder {
  final double fontSize;
  EmojiElementBuilder({required this.fontSize});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    // We now use the font fallback, but we can still use images for better look in chat
    // or just let the font handle it. Let's keep images for chat bubbles 
    // as they look better (retina quality) and use font for input.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1.0),
      child: EmojiUtils.appleEmoji(
        element.textContent,
        size: fontSize * 1,
        fallbackStyle: preferredStyle?.copyWith(
          fontFamily: 'AppleEmoji',
        ),
      ),
    );
  }
}

/// Custom syntax for spoilers: ||...||
class SpoilerInlineSyntax extends md.InlineSyntax {
  SpoilerInlineSyntax() : super(r'\|\|([\s\S]+?)\|\|');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final element = md.Element.text('spoiler', match.group(1)!);
    parser.addNode(element);
    return true;
  }
}

/// Builder for spoilers using [SpoilerTextWidget].
class SpoilerElementBuilder extends MarkdownElementBuilder {
  final TextStyle? preferredStyle;

  SpoilerElementBuilder(this.preferredStyle);

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    return SpoilerTextWidget.text(
      text: element.textContent,
      style: preferredStyle ?? this.preferredStyle,
    );
  }
}

/// Custom syntax for underline: __...__ or --...-- or <u>...</u>
class UnderlineInlineSyntax extends md.InlineSyntax {
  UnderlineInlineSyntax() : super(r'(?:__|\-\-|<u>)([\s\S]+?)(?:__|\-\-|</u>)');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final element = md.Element.text('underline', match.group(1)!);
    parser.addNode(element);
    return true;
  }
}

/// Builder for underline text.
class UnderlineElementBuilder extends MarkdownElementBuilder {
  final TextStyle? baseStyle;

  UnderlineElementBuilder([this.baseStyle]);

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final effectiveStyle = parentStyle ?? preferredStyle ?? baseStyle ?? DefaultTextStyle.of(context).style;
    return Text(
      element.textContent,
      style: effectiveStyle.copyWith(
        decoration: TextDecoration.underline,
        decorationColor: effectiveStyle.color,
        decorationThickness: 1.5,
      ),
    );
  }

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final effectiveStyle = preferredStyle ?? baseStyle;
    return Text(
      element.textContent,
      style: effectiveStyle?.copyWith(
        decoration: TextDecoration.underline,
        decorationColor: effectiveStyle.color,
        decorationThickness: 1.5,
      ) ?? const TextStyle(decoration: TextDecoration.underline),
    );
  }
}

/// Виджет для отображения текстового сообщения с Markdown-подсветкой.
///
/// Использует [flutter_markdown] для рендеринга и [CodeBlockWidget] для блоков кода.
class TextMessageWidget extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final bool isMe;
  final List<MessageEntity>? entities;

  const TextMessageWidget({
    Key? key,
    required this.text,
    this.style,
    this.isMe = false,
    this.entities,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final markdownData = (entities != null && entities!.isNotEmpty)
        ? EntityParser.toMarkdown(text, entities!)
        : text;

    return MarkdownBody(
      data: markdownData.trimRight(),
      selectable: false,
      shrinkWrap: true,
      softLineBreak: true, // Позволяет делать перенос строки одним нажатием Enter
      extensionSet: md.ExtensionSet(
        [
          const CollapsibleBlockquoteBlockSyntax(),
          ...md.ExtensionSet.gitHubFlavored.blockSyntaxes,
        ],
        [
          UnderlineInlineSyntax(),
          MathInlineSyntax(),
          CheckboxInlineSyntax(),
          EmojiInlineSyntax(),
          SpoilerInlineSyntax(),
          ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
        ],
      ),
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: (style ?? Theme.of(context).textTheme.bodyMedium)?.copyWith(
          fontSize: style?.fontSize ?? _kMessageFontSize,
          height: 1.4,
        ),
        pPadding: EdgeInsets.zero,
        blockSpacing: 0,
        listBulletPadding: const EdgeInsets.only(right: 4),
        code: TextStyle(
          fontFamily: 'monospace',
          fontSize: (style?.fontSize ?? _kMessageFontSize) * 0.9,
          height: 1.4,
          backgroundColor: isDark 
              ? Colors.white.withValues(alpha: _kInlineCodeDarkOpacity) 
              : Colors.black.withValues(alpha: _kInlineCodeLightOpacity),
        ),
        codeblockDecoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        codeblockPadding: EdgeInsets.zero,
        blockquoteDecoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        blockquotePadding: EdgeInsets.zero,
      ),
      builders: {
        'code': CodeElementBuilder(context, isDark, isMe),
        'blockquote': BlockquoteElementBuilder(context, isDark, isMe),
        'latex': MathElementBuilder(),
        'checkbox': CheckboxElementBuilder(),
        'emoji': EmojiElementBuilder(fontSize: style?.fontSize ?? _kMessageFontSize),
        'spoiler': SpoilerElementBuilder(style),
        'underline': UnderlineElementBuilder(style),
      },
      onTapLink: (text, href, title) async {
        if (href != null) {
          final url = Uri.parse(href);
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          }
        }
      },
    );
  }
}

