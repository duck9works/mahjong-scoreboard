import 'package:flutter/material.dart';

import '../../model/models.dart';

class RyukyokuDialogResult {
  final List<Seat> tenpaiSeats;

  const RyukyokuDialogResult({
    required this.tenpaiSeats,
  });
}

class RyukyokuDialog extends StatefulWidget {
  final RoomState state;
  final Map<Seat, String> seatNames;

  const RyukyokuDialog({
    super.key,
    required this.state,
    required this.seatNames,
  });

  @override
  State<RyukyokuDialog> createState() => _RyukyokuDialogState();
}

class _RyukyokuDialogState extends State<RyukyokuDialog> {
  late final Set<Seat> _tenpaiSeats;

  List<Seat> get _activeSeats => widget.state.activeSeats;

  @override
  void initState() {
    super.initState();
    _tenpaiSeats = <Seat>{};
  }

  String _seatLabel(Seat seat) {
    final name = widget.seatNames[seat] ?? '';
    if (name.isEmpty) {
      return seatToJp(seat);
    }
    return '${seatToJp(seat)} ・ $name';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        '流局入力',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('テンパイ者を選択してください（複数選択可）'),
            const SizedBox(height: 10),
            for (final seat in _activeSeats)
              CheckboxListTile(
                value: _tenpaiSeats.contains(seat),
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _tenpaiSeats.add(seat);
                    } else {
                      _tenpaiSeats.remove(seat);
                    }
                  });
                },
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(_seatLabel(seat)),
              ),
            const SizedBox(height: 8),
            Text(
              '※ テンパイ0人/${widget.state.playerCount}人はノーテン罰符なし',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
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
            final tenpai = [..._tenpaiSeats]
              ..sort((a, b) => a.index.compareTo(b.index));
            Navigator.of(context).pop(
              RyukyokuDialogResult(tenpaiSeats: tenpai),
            );
          },
          child: const Text('確定'),
        ),
      ],
    );
  }
}
