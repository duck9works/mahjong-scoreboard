import 'dart:async';

import 'package:flutter/material.dart';

import '../gateway/api_client.dart';
import '../gateway/room_gateway.dart';
import '../gateway/user_gateway.dart';
import '../model/models.dart';
import 'records_page.dart';
import 'rule_guide_page.dart';
import 'room_page.dart';
import 'user_manage_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _roomNameCtrl = TextEditingController();
  final _initialPointsCtrl = TextEditingController(text: '25000');

  final _api = ApiClient();
  late final _users = UserGateway(_api);
  late final _rooms = RoomGateway();

  GameType _createGameType = GameType.tonpu;
  int _createPlayerCount = 4;
  bool _createEnableKiriageMangan = true;
  bool _createKazoeAsYakuman = true;

  List<RoomSummary> _joinableRooms = [];
  RoomSummary? _selectedRoom;

  bool _busy = false;
  bool _loadingRooms = false;
  bool _debugMode = false;
  int _debugTapCount = 0;
  DateTime? _lastDebugTapAt;

  int _defaultInitialPointsForPlayerCount(int playerCount) {
    return playerCount == 3 ? 35000 : 25000;
  }

  void _onCreatePlayerCountChanged(int nextPlayerCount) {
    final currentText = _initialPointsCtrl.text.trim();
    final oldDefault = _defaultInitialPointsForPlayerCount(_createPlayerCount);
    final shouldReplaceWithDefault =
        currentText.isEmpty || int.tryParse(currentText) == oldDefault;
    final nextDefault = _defaultInitialPointsForPlayerCount(nextPlayerCount);

    setState(() {
      _createPlayerCount = nextPlayerCount;
      if (shouldReplaceWithDefault) {
        _initialPointsCtrl.text = '$nextDefault';
      }
    });
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadRooms());
  }

  @override
  void dispose() {
    _roomNameCtrl.dispose();
    _initialPointsCtrl.dispose();
    super.dispose();
  }

  void _onTitleTapped() {
    final now = DateTime.now();
    if (_lastDebugTapAt == null ||
        now.difference(_lastDebugTapAt!) > const Duration(seconds: 3)) {
      _debugTapCount = 0;
    }
    _lastDebugTapAt = now;
    _debugTapCount += 1;

    if (_debugTapCount < 5) {
      return;
    }

    _debugTapCount = 0;
    setState(() {
      _debugMode = !_debugMode;
    });
    _toast(_debugMode ? 'デバッグモードをONにしました' : 'デバッグモードをOFFにしました');
    unawaited(_loadRooms());
  }

  Future<void> _createRoom() async {
    final roomName = _roomNameCtrl.text.trim();
    final points = int.tryParse(_initialPointsCtrl.text.trim()) ??
        _defaultInitialPointsForPlayerCount(_createPlayerCount);

    if (roomName.isEmpty) {
      _toast('ルーム名を入力してください');
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final map = await _api.postJson('/api/rooms', {
        'roomName': roomName,
        'initialPoints': points,
        'playerCount': _createPlayerCount,
        'gameType': _createGameType.index,
        'rules': {
          'keepFu25': true,
          'enableKiriageMangan': _createEnableKiriageMangan,
          'kazoeAsYakuman': _createKazoeAsYakuman,
        },
      });
      final roomId = map['roomId'] as String;

      if (!mounted) {
        return;
      }

      _toast('ルームを作成しました');
      await _loadRooms(selectRoomId: roomId);
    } catch (e) {
      _toast('ルーム作成に失敗しました: $e');
    } finally {
      if (!mounted) {
        return;
      }

      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _loadRooms({String? selectRoomId}) async {
    if (_loadingRooms) {
      return;
    }

    setState(() {
      _loadingRooms = true;
    });

    try {
      final allRooms = await _rooms.getRooms();
      final rooms = _debugMode
          ? allRooms
          : allRooms.where((room) => !room.isFinished).toList();
      if (!mounted) {
        return;
      }

      RoomSummary? nextSelected;
      if (selectRoomId != null) {
        for (final room in rooms) {
          if (room.roomId == selectRoomId) {
            nextSelected = room;
            break;
          }
        }
      }

      nextSelected ??= () {
        final currentId = _selectedRoom?.roomId;
        if (currentId != null) {
          for (final room in rooms) {
            if (room.roomId == currentId) {
              return room;
            }
          }
        }
        return rooms.isEmpty ? null : rooms.first;
      }();

      setState(() {
        _joinableRooms = rooms;
        _selectedRoom = nextSelected;
      });
    } catch (e) {
      _toast('ルーム一覧の取得に失敗しました: $e');
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingRooms = false;
      });
    }
  }

  Future<void> _join() async {
    final selected = _selectedRoom;
    if (selected == null) {
      _toast('参加するルームを選択してください');
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      await _rooms.connect();
      final state = await _rooms.joinRoom(selected.roomId, selected.joinKey);

      if (!mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RoomPage(
            roomId: selected.roomId,
            joinKey: selected.joinKey,
            userId: null,
            displayName: null,
            roomGateway: _rooms,
            userGateway: _users,
            initialState: state,
          ),
        ),
      );

      if (!mounted) {
        return;
      }
      await _loadRooms();
    } catch (e) {
      _toast('参加に失敗しました: $e');
      await _loadRooms();
    } finally {
      if (!mounted) {
        return;
      }

      setState(() {
        _busy = false;
      });
    }
  }

  void _openUserManage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserManagePage(userGateway: _users),
      ),
    );
  }

  void _openRecords() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const RecordsPage(),
      ),
    );
  }

  void _openRuleGuide() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const RuleGuidePage(),
      ),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    String pad2(int x) => x.toString().padLeft(2, '0');
    return '${local.year}/${pad2(local.month)}/${pad2(local.day)} ${pad2(local.hour)}:${pad2(local.minute)}';
  }

  String _roomDetail(RoomSummary room) {
    final createdAt = room.createdAt;
    if (createdAt == null) {
      return '日時不明';
    }
    return _formatDateTime(createdAt);
  }

  Widget _roomLabel(RoomSummary room) {
    final roomName = room.isFinished ? '${room.roomName}（終局）' : room.roomName;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          roomName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          _roomDetail(room),
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.72),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onTitleTapped,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('麻雀スコア'),
              if (_debugMode) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: Colors.orange.withValues(alpha: 0.22),
                    border: Border.all(color: Colors.orangeAccent),
                  ),
                  child: const Text(
                    'DEBUG',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          IconButton(
            onPressed: _openUserManage,
            icon: const Icon(Icons.manage_accounts),
            tooltip: 'ユーザー管理',
          ),
          IconButton(
            onPressed: _openRecords,
            icon: const Icon(Icons.leaderboard),
            tooltip: '戦績一覧',
          ),
          IconButton(
            onPressed: _openRuleGuide,
            icon: const Icon(Icons.menu_book),
            tooltip: 'ルール・手引き',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('ルーム作成', [
            TextField(
              controller: _roomNameCtrl,
              decoration: const InputDecoration(labelText: 'ルーム名'),
            ),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment<int>(
                  value: 4,
                  label: Text('4麻'),
                ),
                ButtonSegment<int>(
                  value: 3,
                  label: Text('3麻'),
                ),
              ],
              selected: {_createPlayerCount},
              onSelectionChanged: _busy
                  ? null
                  : (selection) {
                      _onCreatePlayerCountChanged(selection.first);
                    },
            ),
            const SizedBox(height: 8),
            SegmentedButton<GameType>(
              segments: const [
                ButtonSegment<GameType>(
                  value: GameType.tonpu,
                  label: Text('東風'),
                ),
                ButtonSegment<GameType>(
                  value: GameType.hanchan,
                  label: Text('半荘'),
                ),
              ],
              selected: {_createGameType},
              onSelectionChanged: _busy
                  ? null
                  : (selection) {
                      setState(() {
                        _createGameType = selection.first;
                      });
                    },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _initialPointsCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText:
                    '持ち点（例: ${_defaultInitialPointsForPlayerCount(_createPlayerCount)}）',
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('切り上げ満貫'),
              subtitle: const Text('30符4翻・60符3翻を満貫扱い'),
              value: _createEnableKiriageMangan,
              onChanged: _busy
                  ? null
                  : (value) {
                      setState(() {
                        _createEnableKiriageMangan = value;
                      });
                    },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('数え役満'),
              subtitle: const Text('13翻以上を役満として扱う'),
              value: _createKazoeAsYakuman,
              onChanged: _busy
                  ? null
                  : (value) {
                      setState(() {
                        _createKazoeAsYakuman = value;
                      });
                    },
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy ? null : _createRoom,
              child: const Text('ルーム作成'),
            ),
          ]),
          const SizedBox(height: 16),
          _section('ルーム参加', [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _debugMode ? '全ルーム（デバッグ）' : '有効ルーム',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed:
                      (_busy || _loadingRooms) ? null : () => _loadRooms(),
                  icon: _loadingRooms
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  tooltip: '一覧更新',
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (_joinableRooms.isEmpty)
              Text(
                _loadingRooms
                    ? '読み込み中…'
                    : (_debugMode ? '表示できるルームはありません' : '参加できるルームはありません'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              )
            else
              DropdownButtonFormField<String>(
                isExpanded: true,
                itemHeight: null,
                value: _selectedRoom?.roomId,
                items: _joinableRooms
                    .map(
                      (room) => DropdownMenuItem<String>(
                        value: room.roomId,
                        child: _roomLabel(room),
                      ),
                    )
                    .toList(),
                selectedItemBuilder: (context) =>
                    _joinableRooms.map((room) => _roomLabel(room)).toList(),
                onChanged: (_busy || _loadingRooms)
                    ? null
                    : (roomId) {
                        if (roomId == null) {
                          return;
                        }
                        setState(() {
                          _selectedRoom = _joinableRooms
                              .firstWhere((room) => room.roomId == roomId);
                        });
                      },
                decoration: const InputDecoration(labelText: 'ルーム名を選択'),
              ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: (_busy || _loadingRooms || _selectedRoom == null)
                  ? null
                  : _join,
              child: const Text('参加'),
            ),
          ]),
          const SizedBox(height: 12),
          Text(
            'ユーザー作成・編集は右上の「ユーザー管理」から実行できます。',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}
