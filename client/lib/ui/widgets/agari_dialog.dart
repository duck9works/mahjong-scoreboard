import 'package:flutter/material.dart';

import '../../model/models.dart';
import '../../util/score_calc.dart';

class AgariDialogResult {
  final Seat winnerSeat;
  final AgariMethod method;
  final Seat? ronLoserSeat;
  final int han;
  final int fu;

  AgariDialogResult({
    required this.winnerSeat,
    required this.method,
    required this.han,
    required this.fu,
    required this.ronLoserSeat,
  });
}

class AgariDialog extends StatefulWidget {
  final RoomState state;
  final Map<Seat, String> seatNames;
  final Map<Seat, String?> seatIcons;

  const AgariDialog({
    super.key,
    required this.state,
    required this.seatNames,
    required this.seatIcons,
  });

  @override
  State<AgariDialog> createState() => _AgariDialogState();
}

class _AgariDialogState extends State<AgariDialog> {
  Seat _winner = Seat.east;
  AgariMethod _method = AgariMethod.ron;
  Seat _ronLoser = Seat.south;
  int _han = 1;
  int _fu = 30;
  late final Map<Seat, ImageProvider?> _iconBySeat;

  List<Seat> get _activeSeats => widget.state.activeSeats;

  @override
  void initState() {
    super.initState();
    _iconBySeat = {
      for (final seat in _activeSeats)
        seat: _iconProvider(widget.seatIcons[seat]),
    };
  }

  List<int> _fuCandidates() {
    return ScoreCalc.fuCandidates(widget.state.rules);
  }

  List<Seat> _ronLoserCandidates(Seat winner) {
    return _activeSeats.where((s) => s != winner).toList();
  }

  void _normalizeRonLoserForWinner(Seat winner) {
    if (_ronLoser != winner) {
      return;
    }
    _ronLoser = _ronLoserCandidates(winner).first;
  }

  String _seatLabel(String prefix, Seat seat) {
    final name = widget.seatNames[seat] ?? '';
    if (name.isEmpty) {
      return '$prefix ${seatToJp(seat)}';
    }
    return '$prefix ${seatToJp(seat)}・$name';
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

  Widget _iconAvatar(Seat seat) {
    final provider = _iconBySeat[seat];
    return CircleAvatar(
      radius: 11,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      backgroundImage: provider,
      child: provider == null ? const Icon(Icons.person, size: 13) : null,
    );
  }

  Widget _seatRowLabel(String prefix, Seat seat) {
    return Row(
      children: [
        _iconAvatar(seat),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _seatLabel(prefix, seat),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _hanCategory(int han) {
    if (han >= 13) {
      return '役満';
    }
    if (han >= 11) {
      return '三倍満';
    }
    if (han >= 8) {
      return '倍満';
    }
    if (han >= 6) {
      return '跳満';
    }
    if (han >= 5) {
      return '満貫';
    }
    return '通常';
  }

  @override
  Widget build(BuildContext context) {
    if (!_activeSeats.contains(_winner)) {
      _winner = _activeSeats.first;
    }
    final fuList = _fuCandidates();
    final ronLosers = _ronLoserCandidates(_winner);

    if (!ronLosers.contains(_ronLoser)) {
      _ronLoser = ronLosers.first;
    }

    final preview = ScoreCalc.preview(
      state: widget.state,
      winnerSeat: _winner,
      method: _method,
      han: _han,
      fu: _fu,
      ronLoserSeat: _method == AgariMethod.ron ? _ronLoser : null,
    );

    return AlertDialog(
      title: const Text('和了入力', style: TextStyle(fontWeight: FontWeight.w900)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<Seat>(
              isExpanded: true,
              value: _winner,
              items: _activeSeats
                  .map((s) =>
                      DropdownMenuItem(value: s, child: _seatRowLabel('勝者', s)))
                  .toList(),
              selectedItemBuilder: (context) =>
                  _activeSeats.map((s) => _seatRowLabel('勝者', s)).toList(),
              onChanged: (v) {
                if (v == null) {
                  return;
                }
                setState(() {
                  _winner = v;
                  _normalizeRonLoserForWinner(v);
                });
              },
            ),
            const SizedBox(height: 10),
            SegmentedButton<AgariMethod>(
              segments: const [
                ButtonSegment(value: AgariMethod.ron, label: Text('ロン')),
                ButtonSegment(value: AgariMethod.tsumo, label: Text('ツモ')),
              ],
              selected: {_method},
              onSelectionChanged: (s) {
                setState(() {
                  _method = s.first;
                  _normalizeRonLoserForWinner(_winner);
                });
              },
            ),
            const SizedBox(height: 10),
            if (_method == AgariMethod.ron)
              DropdownButtonFormField<Seat>(
                isExpanded: true,
                value: _ronLoser,
                items: ronLosers
                    .map((s) => DropdownMenuItem(
                        value: s, child: _seatRowLabel('放銃', s)))
                    .toList(),
                selectedItemBuilder: (context) =>
                    ronLosers.map((s) => _seatRowLabel('放銃', s)).toList(),
                onChanged: (v) {
                  if (v == null) {
                    return;
                  }
                  setState(() {
                    _ronLoser = v;
                  });
                },
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _fu,
                    items: fuList
                        .map((v) =>
                            DropdownMenuItem(value: v, child: Text('$v 符')))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) {
                        return;
                      }
                      setState(() {
                        _fu = v;
                      });
                    },
                    decoration: const InputDecoration(labelText: '符'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _han,
                    items: List.generate(13, (i) => i + 1)
                        .map(
                          (v) => DropdownMenuItem(
                              value: v,
                              child: Text('$v 翻（${_hanCategory(v)}）')),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) {
                        return;
                      }
                      setState(() {
                        _han = v;
                      });
                    },
                    decoration: const InputDecoration(labelText: '翻'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('点数プレビュー',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(preview.title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  ...preview.lines.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('・$line'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '※ 本場/供託は自動反映されます',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () {
            final loser = _method == AgariMethod.ron ? _ronLoser : null;
            Navigator.of(context).pop(
              AgariDialogResult(
                winnerSeat: _winner,
                method: _method,
                han: _han,
                fu: _fu,
                ronLoserSeat: loser,
              ),
            );
          },
          child: const Text('確定'),
        ),
      ],
    );
  }
}
