import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../model/models.dart';
import '../theme/mleague_theme.dart';
import 'seat_card.dart';

class Board extends StatefulWidget {
  final RoomState state;
  final int? renchan;
  final Map<Seat, String> seatNames;
  final Map<Seat, String?> seatIcons;
  final Map<Seat, List<int>> seatScoreDeltaParts;
  final Duration scoreDeltaVisible;
  final bool scoreDeltaDismissOnTap;
  final int scoreDeltaDismissSignal;
  final void Function(Seat seat)? onRiichi;
  final void Function(Seat seat)? onFuro;
  final int rotation;

  const Board({
    super.key,
    required this.state,
    required this.renchan,
    required this.seatNames,
    required this.seatIcons,
    required this.seatScoreDeltaParts,
    required this.scoreDeltaVisible,
    required this.scoreDeltaDismissOnTap,
    required this.scoreDeltaDismissSignal,
    required this.onRiichi,
    required this.onFuro,
    this.rotation = 0,
  });

  @override
  State<Board> createState() => _BoardState();
}

class _BoardState extends State<Board> {
  static const List<Seat> _baseOrder4 = [
    Seat.east,
    Seat.north,
    Seat.west,
    Seat.south,
  ];
  static const List<Seat> _baseOrder3 = [
    Seat.east,
    Seat.west,
    Seat.south,
  ];

  bool _showRelativePoints = false;

  List<Seat> get _activeSeats => widget.state.activeSeats;

  List<Seat> _orderedSeats() {
    final activeSet = _activeSeats.toSet();
    final base = _activeSeats.length == 3 ? _baseOrder3 : _baseOrder4;
    final ordered = base.where(activeSet.contains).toList();
    if (ordered.length == _activeSeats.length) {
      return ordered;
    }

    final sorted = [..._activeSeats]..sort((a, b) => a.index.compareTo(b.index));
    return sorted;
  }

  int _normalizedRotation(int rotation, int count) {
    if (count <= 0) {
      return 0;
    }
    return ((rotation % count) + count) % count;
  }

  Seat _seatAt(List<Seat> order, int pos) {
    final count = order.length;
    if (count == 0) {
      throw StateError('Seat order is empty.');
    }
    final r = _normalizedRotation(widget.rotation, count);
    return order[(pos - r + count) % count];
  }

  Seat _frontSeat(List<Seat> order) {
    if (order.isEmpty) {
      throw StateError('Seat order is empty.');
    }
    final frontIndex = order.length >= 3 ? 2 : 0;
    return _seatAt(order, frontIndex);
  }

  Map<Seat, int> _displayPointsBySeat(List<Seat> order) {
    final map = <Seat, int>{};

    if (!_showRelativePoints) {
      for (final seat in _activeSeats) {
        map[seat] = widget.state.seatState(seat).points;
      }
      return map;
    }

    final frontSeat = _frontSeat(order);
    final frontPoints = widget.state.seatState(frontSeat).points;

    for (final seat in _activeSeats) {
      map[seat] = widget.state.seatState(seat).points - frontPoints;
    }

    return map;
  }

  @override
  Widget build(BuildContext context) {
    final order = _orderedSeats();
    final displayPoints = _displayPointsBySeat(order);

    return LayoutBuilder(
      builder: (context, c) {
        final size = c.biggest.shortestSide;
        final largePhoneFactor =
            ((size - 340.0) / 120.0).clamp(0.0, 1.0).toDouble();
        final pad = (size * (0.016 - (0.003 * largePhoneFactor)))
            .clamp(3.0, 9.0)
            .toDouble();

        // On larger phones, allow mild corner overlap so seat cards can grow.
        final overlapAllowance = 0.24 * largePhoneFactor;
        final maxSeatWithoutOverlap =
            ((size - (pad * 2)) / (3 - overlapAllowance))
                .clamp(92.0, 248.0)
                .toDouble();

        final seatScaleBoost = 1 + (0.12 * largePhoneFactor);
        final seatWBase =
            (size * 0.31 * seatScaleBoost).clamp(92.0, 248.0).toDouble();
        final seatHBase =
            (size * 0.285 * seatScaleBoost).clamp(88.0, 236.0).toDouble();
        final seatW = math.min(seatWBase, maxSeatWithoutOverlap);
        final seatH = math.min(seatHBase, maxSeatWithoutOverlap);

        final centerSpaceW = size - (2 * (seatW + pad));
        final centerSpaceH = size - (2 * (seatH + pad));
        final centerPanelScale = 1 - (0.16 * largePhoneFactor);
        final centerPanelWBase =
            (size * 0.245 * centerPanelScale).clamp(72.0, 132.0).toDouble();
        final centerPanelHBase =
            (size * 0.34 * centerPanelScale).clamp(92.0, 176.0).toDouble();
        final centerPanelW =
            math.max(68.0, math.min(centerPanelWBase, centerSpaceW - 6));
        final centerPanelH =
            math.max(90.0, math.min(centerPanelHBase, centerSpaceH - 6));
        final compactCenter = centerPanelW < 96 || centerPanelH < 120;

        return SizedBox(
          width: size,
          height: size,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Theme.of(context).dividerColor),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [MLeagueTheme.bg, MLeagueTheme.panel],
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: CustomPaint(
                      painter: _BoardLinesPainter(
                          color: Theme.of(context).dividerColor),
                    ),
                  ),
                ),
                Positioned(
                  left: (size - centerPanelW) / 2,
                  top: (size - centerPanelH) / 2,
                  width: centerPanelW,
                  height: centerPanelH,
                  child: _centerStatusPanel(context, compact: compactCenter),
                ),
                ..._buildSeatLayouts(
                  size: size,
                  seatW: seatW,
                  seatH: seatH,
                  pad: pad,
                  order: order,
                  displayPoints: displayPoints,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildSeatLayouts({
    required double size,
    required double seatW,
    required double seatH,
    required double pad,
    required List<Seat> order,
    required Map<Seat, int> displayPoints,
  }) {
    if (order.length == 3) {
      final topLeftSeat = _seatAt(order, 0);
      final topRightSeat = _seatAt(order, 1);
      final bottomSeat = _seatAt(order, 2);

      return [
        _posSeat(
          left: pad,
          top: pad,
          width: seatW,
          height: seatH,
          seat: topLeftSeat,
          points: displayPoints[topLeftSeat] ?? 0,
        ),
        _posSeat(
          left: size - seatW - pad,
          top: pad,
          width: seatW,
          height: seatH,
          seat: topRightSeat,
          points: displayPoints[topRightSeat] ?? 0,
        ),
        _posSeat(
          left: (size - seatW) / 2,
          top: size - seatH - pad,
          width: seatW,
          height: seatH,
          seat: bottomSeat,
          points: displayPoints[bottomSeat] ?? 0,
        ),
      ];
    }

    final topSeat = _seatAt(order, 0);
    final rightSeat = _seatAt(order, 1);
    final bottomSeat = _seatAt(order, 2);
    final leftSeat = _seatAt(order, 3);

    return [
      _posSeat(
        left: (size - seatW) / 2,
        top: pad,
        width: seatW,
        height: seatH,
        seat: topSeat,
        points: displayPoints[topSeat] ?? 0,
      ),
      _posSeat(
        left: size - seatW - pad,
        top: (size - seatH) / 2,
        width: seatW,
        height: seatH,
        seat: rightSeat,
        points: displayPoints[rightSeat] ?? 0,
      ),
      _posSeat(
        left: (size - seatW) / 2,
        top: size - seatH - pad,
        width: seatW,
        height: seatH,
        seat: bottomSeat,
        points: displayPoints[bottomSeat] ?? 0,
      ),
      _posSeat(
        left: pad,
        top: (size - seatH) / 2,
        width: seatW,
        height: seatH,
        seat: leftSeat,
        points: displayPoints[leftSeat] ?? 0,
      ),
    ];
  }

  Widget _centerStatusPanel(BuildContext context, {required bool compact}) {
    final renchanText = widget.renchan?.toString() ?? '-';

    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 6 : 8,
        compact ? 6 : 8,
        compact ? 6 : 8,
        compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: MLeagueTheme.panel.withValues(alpha: 0.92),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: _centerStatTile(
              context: context,
              icon: Icons.layers_outlined,
              label: '本場',
              value: widget.state.honba.toString(),
              compact: compact,
            ),
          ),
          SizedBox(height: compact ? 3 : 4),
          Expanded(
            child: _centerStatTile(
              context: context,
              icon: Icons.account_balance_wallet_outlined,
              label: '供託',
              value: widget.state.kyotaku.toString(),
              compact: compact,
            ),
          ),
          SizedBox(height: compact ? 3 : 4),
          Expanded(
            child: _centerStatTile(
              context: context,
              icon: Icons.repeat,
              label: '連荘',
              value: renchanText,
              compact: compact,
            ),
          ),
          SizedBox(height: compact ? 4 : 6),
          SizedBox(
            width: double.infinity,
            height: compact ? 28 : 32,
            child: _centerToggleButton(context, compact: compact),
          ),
        ],
      ),
    );
  }

  Widget _centerStatTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required bool compact,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.8),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: compact ? 12 : 14,
            color: Colors.white.withValues(alpha: 0.8),
          ),
          SizedBox(width: compact ? 3 : 4),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 8.5 : 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: compact ? 12 : 15,
              fontWeight: FontWeight.w900,
              color: MLeagueTheme.accentGold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _centerToggleButton(BuildContext context, {required bool compact}) {
    final showRelative = _showRelativePoints;

    return FilledButton.tonal(
      onPressed: () {
        setState(() {
          _showRelativePoints = !_showRelativePoints;
        });
      },
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
        minimumSize: Size.zero,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            showRelative ? Icons.pin : Icons.compare_arrows,
            size: compact ? 12 : 14,
          ),
          SizedBox(width: compact ? 3 : 4),
          Text(
            showRelative ? 'SCORE' : 'DIFF',
            style: TextStyle(
              fontSize: compact ? 8 : 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _posSeat({
    required double left,
    required double top,
    required double width,
    required double height,
    required Seat seat,
    required int points,
  }) {
    final s = widget.state.seatState(seat);

    return Positioned(
      key: ValueKey(seat),
      left: left,
      top: top,
      width: width,
      height: height,
      child: SeatCard(
        seat: seat,
        points: points,
        isRiichi: s.isRiichi,
        isFuro: s.isFuro,
        isDealer: widget.state.dealerSeat == seat,
        assignedUserId: s.assignedUserId,
        displayName: widget.seatNames[seat] ?? '',
        iconDataUrl: widget.seatIcons[seat],
        scoreDeltaParts:
            _showRelativePoints ? null : widget.seatScoreDeltaParts[seat],
        scoreDeltaVisible: widget.scoreDeltaVisible,
        scoreDeltaDismissOnTap: widget.scoreDeltaDismissOnTap,
        scoreDeltaDismissSignal: widget.scoreDeltaDismissSignal,
        scoreAnimateValue: !_showRelativePoints,
        scoreShowDelta: !_showRelativePoints,
        scoreShowPositiveSign: _showRelativePoints,
        scoreColorBySign: _showRelativePoints,
        onRiichi: widget.onRiichi == null ? null : () => widget.onRiichi!(seat),
        onFuro: widget.onFuro == null ? null : () => widget.onFuro!(seat),
      ),
    );
  }
}

class _BoardLinesPainter extends CustomPainter {
  final Color color;

  _BoardLinesPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);

    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), p);
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), p);

    final r = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRRect(
        RRect.fromRectAndRadius(r.deflate(2), const Radius.circular(20)), p);
  }

  @override
  bool shouldRepaint(covariant _BoardLinesPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
