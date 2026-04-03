import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/mleague_theme.dart';

class AnimatedScore extends StatefulWidget {
  final int score;
  final List<int>? deltaParts;
  final String suffix;
  final Duration duration;
  final Duration deltaVisible;
  final Duration flashDuration;
  final bool dismissOnTap;
  final int dismissSignal;
  final TextStyle? textStyle;
  final TextStyle? deltaStyle;
  final bool animateValue;
  final bool showDelta;
  final bool showPositiveSign;
  final bool colorBySign;

  const AnimatedScore({
    super.key,
    required this.score,
    this.deltaParts,
    this.suffix = '',
    this.duration = const Duration(milliseconds: 450),
    this.deltaVisible = const Duration(seconds: 3),
    this.flashDuration = const Duration(milliseconds: 180),
    this.dismissOnTap = false,
    this.dismissSignal = 0,
    this.textStyle,
    this.deltaStyle,
    this.animateValue = true,
    this.showDelta = true,
    this.showPositiveSign = false,
    this.colorBySign = false,
  });

  @override
  State<AnimatedScore> createState() => _AnimatedScoreState();
}

class _AnimatedScoreState extends State<AnimatedScore> {
  int _prevScore = 0;
  List<int> _deltaParts = const [];
  bool _showDelta = false;
  bool _flash = false;
  Timer? _deltaTimer;
  Timer? _flashTimer;

  @override
  void initState() {
    super.initState();
    _prevScore = widget.score;
  }

  @override
  void didUpdateWidget(covariant AnimatedScore oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.dismissSignal != oldWidget.dismissSignal &&
        (widget.dismissOnTap || oldWidget.dismissOnTap)) {
      _hideDelta();
    }

    if (widget.animateValue != oldWidget.animateValue ||
        widget.showDelta != oldWidget.showDelta) {
      _deltaTimer?.cancel();
      _flashTimer?.cancel();
      _deltaParts = const [];
      _prevScore = widget.score;

      if (_showDelta || _flash) {
        setState(() {
          _showDelta = false;
          _flash = false;
        });
      }
      return;
    }

    if (!widget.animateValue || !widget.showDelta) {
      _deltaTimer?.cancel();
      _flashTimer?.cancel();
      _deltaParts = const [];
      _prevScore = widget.score;

      if (_showDelta || _flash) {
        setState(() {
          _showDelta = false;
          _flash = false;
        });
      }
      return;
    }

    if (widget.score == oldWidget.score) {
      return;
    }

    _deltaParts = widget.deltaParts == null || widget.deltaParts!.isEmpty
        ? [widget.score - oldWidget.score]
        : List<int>.from(widget.deltaParts!);
    _prevScore = oldWidget.score;

    _startDelta();
    _startFlash();
  }

  void _hideDelta() {
    _deltaTimer?.cancel();
    if (!_showDelta || !mounted) {
      return;
    }
    setState(() {
      _showDelta = false;
    });
  }

  void _startDelta() {
    _deltaTimer?.cancel();

    setState(() {
      _showDelta = true;
    });

    _deltaTimer = Timer(widget.deltaVisible, _hideDelta);
  }

  void _startFlash() {
    _flashTimer?.cancel();

    setState(() {
      _flash = true;
    });

    _flashTimer = Timer(widget.flashDuration, () {
      if (!mounted) {
        return;
      }

      setState(() {
        _flash = false;
      });
    });
  }

  @override
  void dispose() {
    _deltaTimer?.cancel();
    _flashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = widget.textStyle ??
        Theme.of(context).textTheme.titleLarge ??
        const TextStyle(fontSize: 22);

    final deltaStyle = widget.deltaStyle ??
        baseStyle.copyWith(
          fontSize: (baseStyle.fontSize ?? 22) * 0.8,
          fontWeight: FontWeight.w700,
        );

    final totalDelta = _deltaParts.fold<int>(0, (sum, value) => sum + value);
    final isPlus = totalDelta >= 0;

    const plusColor = MLeagueTheme.accentGreen;
    const minusColor = MLeagueTheme.danger;

    final flashColor = isPlus
        ? plusColor.withValues(alpha: 0.16)
        : minusColor.withValues(alpha: 0.16);

    final visibleParts = _deltaParts.where((x) => x != 0).toList();

    final scoreColor = widget.colorBySign
        ? (widget.score > 0
            ? plusColor
            : widget.score < 0
                ? minusColor
                : null)
        : null;

    final scoreStyle =
        scoreColor == null ? baseStyle : baseStyle.copyWith(color: scoreColor);

    String formatScore(int value) {
      final sign = widget.showPositiveSign && value > 0 ? '+' : '';
      return '$sign$value${widget.suffix}';
    }

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.centerRight,
      children: [
        AnimatedContainer(
          duration: widget.animateValue ? widget.flashDuration : Duration.zero,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: (widget.animateValue && _flash)
                ? flashColor
                : Colors.transparent,
          ),
          child: widget.animateValue
              ? TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: _prevScore.toDouble(),
                    end: widget.score.toDouble(),
                  ),
                  duration: widget.duration,
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Text(
                      formatScore(value.round()),
                      style: scoreStyle,
                      textAlign: TextAlign.right,
                    );
                  },
                )
              : Text(
                  formatScore(widget.score),
                  style: scoreStyle,
                  textAlign: TextAlign.right,
                ),
        ),
        Positioned(
          right: -6,
          top: -14,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: widget.showDelta && _showDelta ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 120),
              child: AnimatedSlide(
                offset: widget.showDelta && _showDelta
                    ? const Offset(0, -0.15)
                    : Offset.zero,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: MLeagueTheme.bg.withValues(alpha: 0.55),
                    border: Border.all(
                        color: MLeagueTheme.line.withValues(alpha: 0.85)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: visibleParts
                        .map(
                          (x) => Text(
                            x >= 0 ? '+$x' : '$x',
                            style: deltaStyle.copyWith(
                              color: x >= 0 ? plusColor : minusColor,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
