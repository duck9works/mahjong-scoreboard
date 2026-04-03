import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../model/models.dart';
import '../theme/mleague_theme.dart';
import 'animated_score.dart';

class SeatCard extends StatefulWidget {
  final Seat seat;
  final int points;
  final bool isRiichi;
  final bool isFuro;
  final bool isDealer;
  final String? assignedUserId;
  final String? iconDataUrl;
  final List<int>? scoreDeltaParts;
  final Duration scoreDeltaVisible;
  final bool scoreDeltaDismissOnTap;
  final int scoreDeltaDismissSignal;
  final bool scoreAnimateValue;
  final bool scoreShowDelta;
  final bool scoreShowPositiveSign;
  final bool scoreColorBySign;
  final String displayName;
  final VoidCallback? onRiichi;
  final VoidCallback? onFuro;

  const SeatCard({
    super.key,
    required this.seat,
    required this.points,
    required this.isRiichi,
    required this.isFuro,
    required this.isDealer,
    required this.assignedUserId,
    required this.iconDataUrl,
    required this.scoreDeltaParts,
    required this.scoreDeltaVisible,
    required this.scoreDeltaDismissOnTap,
    required this.scoreDeltaDismissSignal,
    required this.scoreAnimateValue,
    required this.scoreShowDelta,
    required this.scoreShowPositiveSign,
    required this.scoreColorBySign,
    required this.displayName,
    required this.onRiichi,
    required this.onFuro,
  });

  @override
  State<SeatCard> createState() => _SeatCardState();
}

class _SeatCardState extends State<SeatCard> with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _spin;
  ImageProvider? _iconImage;

  @override
  void initState() {
    super.initState();
    _iconImage = _iconProvider(widget.iconDataUrl);

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    if (widget.isRiichi) {
      _pulse.repeat(reverse: true);
      _spin.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant SeatCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.iconDataUrl != widget.iconDataUrl) {
      _iconImage = _iconProvider(widget.iconDataUrl);
    }

    if (widget.isRiichi) {
      if (!_pulse.isAnimating) {
        _pulse.repeat(reverse: true);
      }
      if (!_spin.isAnimating) {
        _spin.repeat();
      }
      return;
    }

    if (_pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
    if (_spin.isAnimating) {
      _spin.stop();
      _spin.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seatJp = seatToJp(widget.seat);
    const dealerColor = MLeagueTheme.danger;

    return LayoutBuilder(
      builder: (context, constraints) {
        final heightScale = constraints.maxHeight / 176;
        final widthScale = constraints.maxWidth / 212;
        final baseScale =
            math.min(heightScale, widthScale).clamp(0.42, 1.0).toDouble();
        final largeCardFactor =
            ((constraints.maxWidth - 112.0) / 40.0).clamp(0.0, 1.0).toDouble();
        final scale = (baseScale * (1 + (0.14 * largeCardFactor)))
            .clamp(0.42, 1.08)
            .toDouble();
        double s(double value) => value * scale;

        final horizontalPad = s(10);
        final verticalPad = s(7);
        final rowGap = s(6);
        final gap = s(3);
        final avatarRadius = (s(19) * (1 + (0.42 * largeCardFactor)))
            .clamp(9.0, 28.0)
            .toDouble();
        final titleSize = s(16);
        final subtitleSize = s(12);
        final scoreSize = s(19);
        final buttonHeight = s(27).clamp(16.0, 30.0).toDouble();
        final buttonTextSize = s(11.5);
        final dealerLineHeight = s(3);
        final dealerLineBottom = s(5);

        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.0),
          ),
          child: AnimatedBuilder(
            animation: Listenable.merge([_pulse, _spin]),
            builder: (context, _) {
              return Container(
                padding: EdgeInsets.fromLTRB(
                  horizontalPad,
                  verticalPad,
                  horizontalPad,
                  verticalPad,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.isDealer) ...[
                      Container(
                        height: dealerLineHeight,
                        margin: EdgeInsets.only(bottom: dealerLineBottom),
                        decoration: BoxDecoration(
                          color: dealerColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ],
                    Row(
                      children: [
                        _avatar(avatarRadius),
                        SizedBox(width: rowGap),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    seatJp,
                                    style: TextStyle(
                                      fontSize: titleSize,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  if (widget.isDealer)
                                    Text(
                                      '（親）',
                                      style: TextStyle(
                                        fontSize: titleSize,
                                        fontWeight: FontWeight.w900,
                                        color: dealerColor,
                                      ),
                                    ),
                                  if (widget.isFuro) ...[
                                    SizedBox(width: s(6)),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: s(6),
                                        vertical: s(1.5),
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        color: Colors.white
                                            .withValues(alpha: 0.10),
                                        border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.35),
                                        ),
                                      ),
                                      child: Text(
                                        '鳴',
                                        style: TextStyle(
                                          fontSize: s(10),
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.displayName.isEmpty
                                    ? '（未割当）'
                                    : widget.displayName,
                                style: TextStyle(
                                  fontSize: subtitleSize,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: 0.75),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: gap),
                    Align(
                      alignment: Alignment.centerRight,
                      child: AnimatedScore(
                        score: widget.points,
                        deltaParts: widget.scoreDeltaParts,
                        deltaVisible: widget.scoreDeltaVisible,
                        dismissOnTap: widget.scoreDeltaDismissOnTap,
                        dismissSignal: widget.scoreDeltaDismissSignal,
                        animateValue: widget.scoreAnimateValue,
                        showDelta: widget.scoreShowDelta,
                        showPositiveSign: widget.scoreShowPositiveSign,
                        colorBySign: widget.scoreColorBySign,
                        suffix: ' 点',
                        textStyle: TextStyle(
                          fontSize: scoreSize,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    SizedBox(height: gap),
                    SizedBox(
                      height: buttonHeight,
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: (widget.isRiichi ||
                                      widget.isFuro ||
                                      widget.onRiichi == null)
                                  ? null
                                  : widget.onRiichi,
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(horizontal: s(6)),
                              ),
                              child: Text(
                                'リーチ',
                                style: TextStyle(
                                  fontSize: buttonTextSize,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: s(5)),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: (widget.isRiichi ||
                                      widget.isFuro ||
                                      widget.onFuro == null)
                                  ? null
                                  : widget.onFuro,
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(horizontal: s(6)),
                              ),
                              child: Text(
                                '鳴',
                                style: TextStyle(
                                  fontSize: buttonTextSize,
                                  fontWeight: FontWeight.w800,
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
            },
          ),
        );
      },
    );
  }

  Widget _avatar(double radius) {
    final base = CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      backgroundImage: _iconImage,
      child: _iconImage == null ? Icon(Icons.person, size: radius) : null,
    );

    if (!widget.isRiichi) {
      return base;
    }

    final colorA =
        MLeagueTheme.accentGold.withValues(alpha: 0.75 + 0.20 * _pulse.value);
    final colorB =
        MLeagueTheme.accentGreen.withValues(alpha: 0.45 + 0.35 * _pulse.value);

    final ringSize = (radius * 2) + 8;

    return SizedBox(
      width: ringSize,
      height: ringSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: _spin.value * math.pi * 2,
            child: SizedBox(
              width: ringSize,
              height: ringSize,
              child: _RiichiRing(colorA: colorA, colorB: colorB),
            ),
          ),
          base,
        ],
      ),
    );
  }

  ImageProvider? _iconProvider(String? dataUrl) {
    if (dataUrl == null || dataUrl.isEmpty) {
      return null;
    }
    try {
      final data = Uri.parse(dataUrl).data;
      if (data == null) {
        return null;
      }
      return MemoryImage(data.contentAsBytes());
    } catch (_) {
      return null;
    }
  }
}

class _RiichiRing extends StatelessWidget {
  final Color colorA;
  final Color colorB;

  const _RiichiRing({required this.colorA, required this.colorB});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RiichiRingPainter(colorA: colorA, colorB: colorB),
    );
  }
}

class _RiichiRingPainter extends CustomPainter {
  final Color colorA;
  final Color colorB;

  _RiichiRingPainter({required this.colorA, required this.colorB});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 1.5;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    paint.color = colorA;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      1.75,
      false,
      paint,
    );

    paint.color = colorB;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      1.25,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RiichiRingPainter oldDelegate) {
    return oldDelegate.colorA != colorA || oldDelegate.colorB != colorB;
  }
}
