import 'package:flutter/material.dart';
import '../../model/models.dart';

class ScoreEditResult {
  final Map<Seat, int> pointsBySeat;

  const ScoreEditResult({required this.pointsBySeat});
}

class ScoreEditDialog extends StatefulWidget {
  final RoomState state;
  final Map<Seat, String> seatNames;

  const ScoreEditDialog({
    super.key,
    required this.state,
    required this.seatNames,
  });

  @override
  State<ScoreEditDialog> createState() => _ScoreEditDialogState();
}

class _ScoreEditDialogState extends State<ScoreEditDialog> {
  final _ctrls = <Seat, TextEditingController>{};
  String? _error;

  List<Seat> get _activeSeats => widget.state.activeSeats;

  @override
  void initState() {
    super.initState();
    for (final seat in _activeSeats) {
      _ctrls[seat] = TextEditingController(text: widget.state.seatState(seat).points.toString());
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  int _sumPoints() {
    var sum = 0;
    for (final seat in _activeSeats) {
      final v = int.tryParse(_ctrls[seat]!.text.trim());
      if (v == null) {
        continue;
      }
      sum += v;
    }
    return sum;
  }

  void _submit() {
    final map = <Seat, int>{};
    for (final seat in _activeSeats) {
      final text = _ctrls[seat]!.text.trim();
      final v = int.tryParse(text);
      if (v == null) {
        setState(() {
          _error = '${seatToJp(seat)} の点数が不正です';
        });
        return;
      }
      map[seat] = v;
    }

    Navigator.of(context).pop(ScoreEditResult(pointsBySeat: map));
  }

  @override
  Widget build(BuildContext context) {
    final sum = _sumPoints();

    return AlertDialog(
      title: const Text('点数修正', style: TextStyle(fontWeight: FontWeight.w900)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final seat in _activeSeats) ...[
              _seatRow(seat),
              const SizedBox(height: 10),
            ],
            Text(
              '合計: $sum 点',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontWeight: FontWeight.w700,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w800),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('適用'),
        ),
      ],
    );
  }

  Widget _seatRow(Seat seat) {
    final name = widget.seatNames[seat] ?? '';
    final label = name.isEmpty ? seatToJp(seat) : '${seatToJp(seat)}・$name';

    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: _ctrls[seat],
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            decoration: const InputDecoration(
              labelText: '点数',
            ),
            onChanged: (_) {
              if (_error != null) {
                setState(() {
                  _error = null;
                });
              }
              setState(() {});
            },
          ),
        ),
      ],
    );
  }
}
