import 'package:flutter/material.dart';

import '../../model/models.dart';

class SeatAssignSheet extends StatefulWidget {
  final RoomState state;
  final List<UserProfile> users;
  final Future<void> Function(Map<Seat, String?> assignmentBySeat) onApply;

  const SeatAssignSheet({
    super.key,
    required this.state,
    required this.users,
    required this.onApply,
  });

  @override
  State<SeatAssignSheet> createState() => _SeatAssignSheetState();
}

class _SeatAssignSheetState extends State<SeatAssignSheet> {
  bool _busy = false;
  String? _errorText;
  late final Map<Seat, String?> _selectedBySeat;
  late final Map<String, ImageProvider?> _iconByUserId;
  List<Seat> get _activeSeats => widget.state.activeSeats;

  @override
  void initState() {
    super.initState();
    final selectableUserIds = widget.users.map((u) => u.userId).toSet();
    String? normalizeSelectedUserId(String? userId) {
      if (userId == null || userId.isEmpty) {
        return null;
      }
      if (selectableUserIds.contains(userId)) {
        return userId;
      }
      return null;
    }

    _selectedBySeat = {
      for (final seat in _activeSeats)
        seat: normalizeSelectedUserId(
            widget.state.seatState(seat).assignedUserId),
    };
    _iconByUserId = {
      for (final user in widget.users)
        user.userId: _iconProvider(user.iconDataUrl),
    };
  }

  Future<void> _apply() async {
    final usedByUserId = <String, Seat>{};
    for (final entry in _selectedBySeat.entries) {
      final userId = entry.value;
      if (userId == null || userId.isEmpty) {
        continue;
      }
      final existingSeat = usedByUserId[userId];
      if (existingSeat != null) {
        setState(() {
          _errorText =
              '同じユーザーを複数席に割り当てています: ${seatToJp(existingSeat)} と ${seatToJp(entry.key)}';
        });
        return;
      }
      usedByUserId[userId] = entry.key;
    }

    setState(() {
      _busy = true;
      _errorText = null;
    });

    try {
      await widget.onApply(Map<Seat, String?>.from(_selectedBySeat));
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = '席割当の更新に失敗しました: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  void _clear() {
    setState(() {
      for (final seat in _activeSeats) {
        _selectedBySeat[seat] = null;
      }
      _errorText = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (context, controller) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '席割当（一括）',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                    ),
                    TextButton(
                      onPressed: _busy ? null : _clear,
                      child: const Text('全クリア'),
                    ),
                    IconButton(
                      onPressed:
                          _busy ? null : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: ListView(
                    controller: controller,
                    children: [
                      for (final seat in _activeSeats) ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  '${seatToJp(seat)} の席',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String?>(
                                  value: _selectedBySeat[seat],
                                  items: [
                                    const DropdownMenuItem<String?>(
                                      value: null,
                                      child: _UserRowLabel(
                                        name: '未割当',
                                        icon: Icon(Icons.person_off_outlined,
                                            size: 18),
                                      ),
                                    ),
                                    ...widget.users.map(
                                      (u) => DropdownMenuItem<String?>(
                                        value: u.userId,
                                        child: _UserRowLabel(
                                          name: u.displayName,
                                          icon: _iconAvatar(
                                              _iconByUserId[u.userId]),
                                        ),
                                      ),
                                    ),
                                  ],
                                  selectedItemBuilder: (context) => [
                                    const _UserRowLabel(
                                      name: '未割当',
                                      icon: Icon(Icons.person_off_outlined,
                                          size: 18),
                                    ),
                                    ...widget.users.map(
                                      (u) => _UserRowLabel(
                                        name: u.displayName,
                                        icon: _iconAvatar(
                                            _iconByUserId[u.userId]),
                                      ),
                                    ),
                                  ],
                                  onChanged: _busy
                                      ? null
                                      : (value) {
                                          setState(() {
                                            _selectedBySeat[seat] = value;
                                            _errorText = null;
                                          });
                                        },
                                  decoration: const InputDecoration(
                                    labelText: 'ユーザー',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (_errorText != null) ...[
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _apply,
                    icon: const Icon(Icons.done_all),
                    label: Text(_busy ? '反映中…' : '一括反映'),
                  ),
                ),
              ],
            ),
          );
        },
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

  Widget _iconAvatar(ImageProvider? provider) {
    return CircleAvatar(
      radius: 11,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      backgroundImage: provider,
      child: provider == null ? const Icon(Icons.person, size: 13) : null,
    );
  }
}

class _UserRowLabel extends StatelessWidget {
  final String name;
  final Widget icon;

  const _UserRowLabel({
    required this.name,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        icon,
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
