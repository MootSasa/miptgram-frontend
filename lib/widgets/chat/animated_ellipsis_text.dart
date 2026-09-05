import 'dart:async';
import 'package:flutter/material.dart';

/// AnimatedEllipsisText displays text and animates trailing ellipsis:
/// "." -> ".." -> "..." with a smooth timer, maintaining constant text width
/// to prevent jittering / layout shifts.
class AnimatedEllipsisText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextOverflow overflow;
  final TextAlign? textAlign;
  final int? maxLines;
  final bool animate;
  final Duration dotInterval;

  const AnimatedEllipsisText({
    Key? key,
    required this.text,
    this.style,
    this.overflow = TextOverflow.ellipsis,
    this.textAlign,
    this.maxLines,
    this.animate = true,
    this.dotInterval = const Duration(milliseconds: 400),
  }) : super(key: key);

  @override
  State<AnimatedEllipsisText> createState() => _AnimatedEllipsisTextState();
}

class _AnimatedEllipsisTextState extends State<AnimatedEllipsisText> {
  Timer? _timer;
  int _dotCount = 1;

  @override
  void initState() {
    super.initState();
    _checkTimer();
  }

  @override
  void didUpdateWidget(covariant AnimatedEllipsisText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.animate != widget.animate) {
      _checkTimer();
    }
  }

  bool get _hasEllipsis {
    final t = widget.text.trim();
    return t.endsWith('...') || t.endsWith('…');
  }

  void _checkTimer() {
    _timer?.cancel();
    _timer = null;
    if (_hasEllipsis && widget.animate) {
      _timer = Timer.periodic(widget.dotInterval, (_) {
        if (mounted) {
          setState(() {
            _dotCount = (_dotCount % 3) + 1;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rawText = widget.text;
    if (!_hasEllipsis) {
      return Text(
        rawText,
        style: widget.style,
        overflow: widget.overflow,
        textAlign: widget.textAlign,
        maxLines: widget.maxLines,
      );
    }

    String baseText = rawText.trim();
    if (baseText.endsWith('...')) {
      baseText = baseText.substring(0, baseText.length - 3);
    } else if (baseText.endsWith('…')) {
      baseText = baseText.substring(0, baseText.length - 1);
    }

    final int currentDots = widget.animate ? _dotCount : 3;
    final int emptyDots = 3 - currentDots;

    return Text.rich(
      TextSpan(
        style: widget.style,
        children: [
          TextSpan(text: baseText),
          TextSpan(text: '.' * currentDots),
          TextSpan(
            text: '.' * emptyDots,
            style: const TextStyle(color: Colors.transparent),
          ),
        ],
      ),
      overflow: widget.overflow,
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
    );
  }
}
