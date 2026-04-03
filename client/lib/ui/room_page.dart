import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../gateway/api_client.dart';
import '../gateway/record_gateway.dart';
import '../gateway/room_gateway.dart';
import '../gateway/user_gateway.dart';
import '../model/models.dart';
import '../util/riichi_voice.dart';
import '../util/uma_oka.dart';
import 'records_page.dart';
import 'rule_guide_page.dart';
import 'theme/mleague_theme.dart';
import 'user_manage_page.dart';
import 'widgets/agari_dialog.dart';
import 'widgets/board.dart';
import 'widgets/log_sheet.dart';
import 'widgets/ryukyoku_dialog.dart';
import 'widgets/score_edit_dialog.dart';
import 'widgets/seat_assign_sheet.dart';

class RoomPage extends StatefulWidget {
  final String roomId;
  final String joinKey;
  final String? userId;
  final String? displayName;
  final RoomGateway roomGateway;
  final UserGateway userGateway;
  final RoomState initialState;

  const RoomPage({
    super.key,
    required this.roomId,
    required this.joinKey,
    required this.userId,
    required this.displayName,
    required this.roomGateway,
    required this.userGateway,
    required this.initialState,
  });

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> with WidgetsBindingObserver {
  static const Duration _defaultScoreDeltaVisible = Duration(seconds: 3);
  static const Duration _agariScoreDeltaVisible = Duration(seconds: 30);
  static const Duration _stateSyncInterval = Duration(seconds: 5);

  final _riichiVoice = RiichiVoicePlayer();
  final _records = RecordGateway(ApiClient());

  late RoomState _state;
  List<RoomLogEntry> _logs = [];
  List<UserProfile> _users = [];
  Map<String, String> _userIdToName = {};
  Map<String, UserProfile> _userIdToUser = {};
  Map<Seat, List<int>> _scoreDeltaPartsBySeat = {};
  List<_ScoreTimelinePoint> _scoreTimeline = [];
  Duration _scoreDeltaVisible = _defaultScoreDeltaVisible;
  bool _scoreDeltaDismissOnTap = false;
  int _scoreDeltaDismissSignal = 0;
  Timer? _scoreDeltaDismissTimer;
  Timer? _stateSyncTimer;
  bool _stateSyncInFlight = false;

  bool _busy = false;
  bool _savingRecord = false;
  bool _recordSaved = false;
  bool _loadingDialogData = false;
  int _seatRotation = 0;

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
    _initializeScoreTimeline(_state);
    WidgetsBinding.instance.addObserver(this);

    widget.roomGateway.onStateUpdated((next) async {
      final previous = _state;
      if (!mounted) {
        return;
      }

      _maybePlayRiichiVoice(previous, next);
      setState(() {
        _applyState(previous, next);
      });
      await _refreshSeatNames();
    });

    widget.roomGateway.onLogsUpdated((logs) {
      if (!mounted) {
        return;
      }
      setState(() {
        _logs = logs;
      });
    });

    Future.microtask(() async {
      await _refreshSeatNames();
    });
    _startStateSyncTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scoreDeltaDismissTimer?.cancel();
    _stateSyncTimer?.cancel();
    _riichiVoice.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncStateAfterResume());
    }
  }

  void _startStateSyncTimer() {
    _stateSyncTimer?.cancel();
    _stateSyncTimer = Timer.periodic(_stateSyncInterval, (_) {
      unawaited(_syncStateIfVisible());
    });
  }

  bool _isRoomPageVisible() {
    final route = ModalRoute.of(context);
    final isCurrentRoute = route?.isCurrent ?? true;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final isResumed =
        lifecycle == null || lifecycle == AppLifecycleState.resumed;
    return mounted && isCurrentRoute && isResumed;
  }

  Future<void> _syncStateAfterResume() async {
    if (!_isRoomPageVisible() || _busy || _stateSyncInFlight) {
      return;
    }

    final status = widget.roomGateway.connectionStatus.value;
    if (status == ConnectionStatus.connected) {
      await _syncRoomStateFromServer();
      return;
    }

    await _resumeReconnect();
  }

  Future<void> _syncStateIfVisible() async {
    if (!_isRoomPageVisible() || _busy || _stateSyncInFlight) {
      return;
    }

    final status = widget.roomGateway.connectionStatus.value;
    if (status == ConnectionStatus.connected) {
      await _syncRoomStateFromServer();
      return;
    }

    if (status == ConnectionStatus.disconnected) {
      await _resumeReconnect();
    }
  }

  Future<void> _syncRoomStateFromServer() async {
    if (_stateSyncInFlight) {
      return;
    }

    _stateSyncInFlight = true;
    try {
      final previous = _state;
      final next =
          await widget.roomGateway.joinRoom(widget.roomId, widget.joinKey);
      if (!mounted || next.version == previous.version) {
        return;
      }

      setState(() {
        _applyState(previous, next);
      });
      await _refreshSeatNames();
    } catch (_) {
      // Ignore transient sync failures in background polling.
    } finally {
      _stateSyncInFlight = false;
    }
  }

  void _applyState(RoomState previous, RoomState next) {
    if (_hasScoreDelta(previous, next)) {
      _applyScoreDeltaDisplayMode(
          _resolveScoreDeltaDisplayMode(previous, next));
    }
    if (_isRematchTransition(previous, next)) {
      _initializeScoreTimeline(next);
    } else {
      _appendScoreTimeline(previous, next);
    }
    _state = next;
    _scoreDeltaPartsBySeat = _buildScoreDeltaParts(previous, next);
    if (!next.isFinished) {
      _recordSaved = false;
    }
  }

  void _initializeScoreTimeline(RoomState state) {
    final initialPointsBySeat = _initialPointsBySeat(state);
    final currentPointsBySeat = _pointsBySeat(state);

    _scoreTimeline = [
      _ScoreTimelinePoint(pointsBySeat: initialPointsBySeat),
    ];

    if (!_samePointMap(initialPointsBySeat, currentPointsBySeat)) {
      _scoreTimeline.add(
        _ScoreTimelinePoint(pointsBySeat: currentPointsBySeat),
      );
    }
  }

  void _appendScoreTimeline(RoomState previous, RoomState next) {
    final scoreChanged = _hasScoreDelta(previous, next);
    final shouldAppend =
        (scoreChanged && !_isRiichiScoreDelta(previous, next)) ||
            (next.isFinished && !previous.isFinished);
    if (!shouldAppend) {
      return;
    }

    if (_scoreTimeline.isEmpty) {
      _initializeScoreTimeline(previous);
    }

    final nextPointsBySeat = _pointsBySeat(next);
    if (_samePointMap(_scoreTimeline.last.pointsBySeat, nextPointsBySeat)) {
      return;
    }

    _scoreTimeline = [
      ..._scoreTimeline,
      _ScoreTimelinePoint(pointsBySeat: nextPointsBySeat),
    ];
  }

  List<Seat> _activeSeats(RoomState state) => state.activeSeats;

  List<Seat> _seatUnion(RoomState a, RoomState b) {
    final seatsA = _activeSeats(a).toSet();
    final seatsB = _activeSeats(b).toSet();
    final seats = seatsA.intersection(seatsB).toList()
      ..sort((x, y) => x.index.compareTo(y.index));
    if (seats.isEmpty) {
      seats.addAll(_activeSeats(b));
    }
    return seats;
  }

  bool _isRematchTransition(RoomState previous, RoomState next) {
    if (!previous.isFinished || next.isFinished) {
      return false;
    }

    if (next.roundWind != RoundWind.east ||
        next.kyoku != 1 ||
        next.dealerSeat != Seat.east ||
        next.honba != 0 ||
        next.renchan != 0 ||
        next.kyotaku != 0) {
      return false;
    }

    for (final seat in _activeSeats(next)) {
      if (next.seatState(seat).points != next.initialPoints) {
        return false;
      }
    }
    return true;
  }

  Map<Seat, int> _initialPointsBySeat(RoomState state) {
    final map = <Seat, int>{};
    for (final seat in _activeSeats(state)) {
      map[seat] = state.initialPoints;
    }
    return map;
  }

  Map<Seat, int> _pointsBySeat(RoomState state) {
    final map = <Seat, int>{};
    for (final seatState in state.seats) {
      map[seatState.seat] = seatState.points;
    }
    return map;
  }

  bool _samePointMap(Map<Seat, int> a, Map<Seat, int> b) {
    final seats = <Seat>{...a.keys, ...b.keys};
    for (final seat in seats) {
      if ((a[seat] ?? 0) != (b[seat] ?? 0)) {
        return false;
      }
    }
    return true;
  }

  List<_ScoreTimelinePoint> _timelineForDisplay() {
    if (_scoreTimeline.isNotEmpty) {
      return _scoreTimeline;
    }

    final initialPointsBySeat = _initialPointsBySeat(_state);
    final currentPointsBySeat = _pointsBySeat(_state);
    if (_samePointMap(initialPointsBySeat, currentPointsBySeat)) {
      return [
        _ScoreTimelinePoint(pointsBySeat: currentPointsBySeat),
      ];
    }

    return [
      _ScoreTimelinePoint(pointsBySeat: initialPointsBySeat),
      _ScoreTimelinePoint(pointsBySeat: currentPointsBySeat),
    ];
  }

  _ScoreDeltaDisplayMode _resolveScoreDeltaDisplayMode(
      RoomState previous, RoomState next) {
    if (!_hasScoreDelta(previous, next)) {
      return const _ScoreDeltaDisplayMode(
        visible: _defaultScoreDeltaVisible,
        dismissOnTap: false,
      );
    }

    if (_isRiichiScoreDelta(previous, next)) {
      return const _ScoreDeltaDisplayMode(
        visible: _defaultScoreDeltaVisible,
        dismissOnTap: false,
      );
    }

    return const _ScoreDeltaDisplayMode(
      visible: _agariScoreDeltaVisible,
      dismissOnTap: true,
    );
  }

  void _applyScoreDeltaDisplayMode(_ScoreDeltaDisplayMode mode) {
    _scoreDeltaDismissTimer?.cancel();
    _scoreDeltaVisible = mode.visible;
    _scoreDeltaDismissOnTap = mode.dismissOnTap;
    if (!mode.dismissOnTap) {
      return;
    }

    _scoreDeltaDismissTimer = Timer(mode.visible, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _scoreDeltaDismissOnTap = false;
      });
    });
  }

  bool _hasScoreDelta(RoomState previous, RoomState next) {
    for (final seat in _seatUnion(previous, next)) {
      final delta =
          next.seatState(seat).points - previous.seatState(seat).points;
      if (delta != 0) {
        return true;
      }
    }
    return false;
  }

  bool _isRiichiScoreDelta(RoomState previous, RoomState next) {
    Seat? changedSeat;
    var changedDelta = 0;

    for (final seat in _seatUnion(previous, next)) {
      final delta =
          next.seatState(seat).points - previous.seatState(seat).points;
      if (delta == 0) {
        continue;
      }
      if (changedSeat != null) {
        return false;
      }
      changedSeat = seat;
      changedDelta = delta;
    }

    if (changedSeat == null || changedDelta != -1000) {
      return false;
    }

    final before = previous.seatState(changedSeat).isRiichi;
    final after = next.seatState(changedSeat).isRiichi;
    if (before || !after) {
      return false;
    }

    return next.kyotaku == previous.kyotaku + 1;
  }

  void _dismissScoreDelta() {
    if (!_scoreDeltaDismissOnTap) {
      return;
    }

    _scoreDeltaDismissTimer?.cancel();
    setState(() {
      _scoreDeltaDismissOnTap = false;
      _scoreDeltaDismissSignal++;
    });
  }

  String _connStatusText(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return '接続済み';
      case ConnectionStatus.connecting:
        return '接続中...';
      case ConnectionStatus.reconnecting:
        return '再接続中...';
      case ConnectionStatus.disconnected:
        return '切断';
    }
  }

  Future<void> _reconnect() async {
    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final previous = _state;
      await widget.roomGateway.reconnect();
      final next =
          await widget.roomGateway.joinRoom(widget.roomId, widget.joinKey);
      if (!mounted) {
        return;
      }
      setState(() {
        _applyState(previous, next);
      });
      await _refreshSeatNames();
      _toast('再接続しました');
    } catch (e) {
      _toast('再接続に失敗しました: $e');
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _resumeReconnect() async {
    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final previous = _state;
      await widget.roomGateway.reconnect();
      final next =
          await widget.roomGateway.joinRoom(widget.roomId, widget.joinKey);
      if (!mounted) {
        return;
      }
      setState(() {
        _applyState(previous, next);
      });
      await _refreshSeatNames();
    } catch (_) {
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _refreshSeatNames() async {
    try {
      final users = await widget.userGateway.getUsers();
      final visibleUsers = users.where((user) => !user.isHidden).toList();
      final nameMap = <String, String>{};
      final userMap = <String, UserProfile>{};
      for (final user in visibleUsers) {
        nameMap[user.userId] = user.displayName;
        userMap[user.userId] = user;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _users = visibleUsers;
        _userIdToName = nameMap;
        _userIdToUser = userMap;
      });
    } catch (_) {}
  }

  Map<Seat, String> _seatNamesFromState() {
    final map = <Seat, String>{};
    for (final seatState in _state.seats) {
      final userId = seatState.assignedUserId;
      if (userId == null) {
        map[seatState.seat] = '';
      } else {
        map[seatState.seat] = _userIdToName[userId] ?? '';
      }
    }
    return map;
  }

  Map<Seat, String?> _seatIconsFromState() {
    final map = <Seat, String?>{};
    for (final seatState in _state.seats) {
      final userId = seatState.assignedUserId;
      if (userId == null) {
        map[seatState.seat] = null;
      } else {
        map[seatState.seat] = _userIdToUser[userId]?.iconDataUrl;
      }
    }
    return map;
  }

  Map<Seat, List<int>> _buildScoreDeltaParts(
      RoomState previous, RoomState next) {
    final map = <Seat, List<int>>{};
    final seats = _seatUnion(previous, next);

    for (final seat in seats) {
      final delta =
          next.seatState(seat).points - previous.seatState(seat).points;
      if (delta != 0) {
        map[seat] = [delta];
      }
    }

    final kyotakuAward = previous.kyotaku * 1000;
    if (kyotakuAward <= 0 || next.kyotaku != 0) {
      return map;
    }

    Seat? winner;
    var winnerDelta = 0;
    for (final seat in seats) {
      final delta =
          next.seatState(seat).points - previous.seatState(seat).points;
      if (delta > winnerDelta) {
        winnerDelta = delta;
        winner = seat;
      }
    }

    if (winner == null || winnerDelta <= 0 || winnerDelta < kyotakuAward) {
      return map;
    }

    final directDelta = winnerDelta - kyotakuAward;
    final parts = <int>[kyotakuAward];
    if (directDelta != 0) {
      parts.add(directDelta);
    }
    map[winner] = parts;

    return map;
  }

  void _maybePlayRiichiVoice(RoomState previous, RoomState next) {
    for (final seat in _seatUnion(previous, next)) {
      final before = previous.seatState(seat).isRiichi;
      final after = next.seatState(seat).isRiichi;
      if (before || !after) {
        continue;
      }

      final userId = next.seatState(seat).assignedUserId;
      if (userId == null) {
        return;
      }

      final voiceId = _userIdToUser[userId]?.riichiVoiceId ?? 0;
      _riichiVoice.play(voiceId);
      return;
    }
  }

  Future<void> _declareRiichi(Seat seat) async {
    if (_busy || _state.isFinished) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final previous = _state;
      final next = await widget.roomGateway.declareRiichi(
        widget.roomId,
        widget.joinKey,
        seat,
        _state.version,
      );
      if (!mounted) {
        return;
      }
      _maybePlayRiichiVoice(previous, next);
      setState(() {
        _applyState(previous, next);
      });
    } catch (e) {
      await _handleActionError('リーチ', e);
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _declareFuro(Seat seat) async {
    if (_busy || _state.isFinished) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final previous = _state;
      final next = await widget.roomGateway.declareFuro(
        widget.roomId,
        widget.joinKey,
        seat,
        _state.version,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _applyState(previous, next);
      });
    } catch (e) {
      await _handleActionError('鳴き', e);
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _undo() async {
    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final previous = _state;
      final next = await widget.roomGateway
          .undo(widget.roomId, widget.joinKey, _state.version);
      if (!mounted) {
        return;
      }
      setState(() {
        _applyState(previous, next);
      });
    } catch (e) {
      await _handleActionError('Undo', e);
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _openAgari() async {
    if (_state.isFinished || _busy) {
      return;
    }

    final result = await showDialog<AgariDialogResult>(
      context: context,
      builder: (_) => AgariDialog(
        state: _state,
        seatNames: _seatNamesFromState(),
        seatIcons: _seatIconsFromState(),
      ),
    );
    if (result == null || _busy) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final previous = _state;
      final next = await widget.roomGateway.enterAgari(
        roomId: widget.roomId,
        joinKey: widget.joinKey,
        winnerSeat: result.winnerSeat,
        method: result.method,
        han: result.han,
        fu: result.fu,
        ronLoserSeat: result.ronLoserSeat,
        expectedVersion: _state.version,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _applyState(previous, next);
      });
    } catch (e) {
      await _handleActionError('和了', e);
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _openRyukyoku() async {
    if (_state.isFinished || _busy) {
      return;
    }

    final result = await showDialog<RyukyokuDialogResult>(
      context: context,
      builder: (_) => RyukyokuDialog(
        state: _state,
        seatNames: _seatNamesFromState(),
      ),
    );
    if (result == null || _busy) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final previous = _state;
      final next = await widget.roomGateway.enterRyukyoku(
        roomId: widget.roomId,
        joinKey: widget.joinKey,
        tenpaiSeats: result.tenpaiSeats,
        expectedVersion: _state.version,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _applyState(previous, next);
      });
    } catch (e) {
      await _handleActionError('流局', e);
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _changeGameType(
    GameType gameType, {
    bool allowWhenFinished = false,
  }) async {
    if (_busy ||
        (!allowWhenFinished && _state.isFinished) ||
        _state.gameType == gameType) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final previous = _state;
      final next = await widget.roomGateway.setGameType(
        widget.roomId,
        widget.joinKey,
        gameType,
        _state.version,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _applyState(previous, next);
      });
      _toast('ゲームタイプを${gameTypeToJp(gameType)}に変更しました');
    } catch (e) {
      await _handleActionError('ゲームタイプ変更', e);
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _openGameTypeSelector() async {
    if (_busy || _state.isFinished) {
      return;
    }

    await showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flag),
              title: const Text('東風戦で終了（ここまで）'),
              subtitle: const Text('半荘戦から東風戦には戻せません'),
              enabled: _state.gameType != GameType.tonpu,
              onTap: _state.gameType == GameType.tonpu
                  ? null
                  : () async {
                      Navigator.of(context).pop();
                      await _changeGameType(GameType.tonpu);
                    },
            ),
            ListTile(
              leading: const Icon(Icons.nightlight_round),
              title: const Text('半荘戦にする（南入）'),
              subtitle: const Text('東風戦の続きから南入します'),
              enabled: _state.gameType != GameType.hanchan,
              onTap: _state.gameType == GameType.hanchan
                  ? null
                  : () async {
                      Navigator.of(context).pop();
                      await _changeGameType(GameType.hanchan);
                    },
            ),
          ],
        ),
      ),
    );
  }

  void _openLogs() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => LogSheet(logs: _logs),
    );
  }

  void _openUserManage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserManagePage(userGateway: widget.userGateway),
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

  Future<void> _closeRoom() async {
    if (_busy) {
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ルーム終了'),
        content: Text(
          _state.isFinished && !_recordSaved
              ? '成績保存が未実行です。このままルームを終了しますか？'
              : 'このルームを終了しますか？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('終了する'),
          ),
        ],
      ),
    );

    if (confirm != true || _busy) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      await widget.roomGateway.closeRoom(widget.roomId, widget.joinKey);
      if (!mounted) {
        return;
      }
      _toast('ルームを終了しました');
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      _toast('ルーム終了に失敗しました: $e');
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _openSeatAssign() async {
    if (_busy || _loadingDialogData) {
      return;
    }

    setState(() {
      _loadingDialogData = true;
    });
    try {
      await _refreshSeatNames();
    } finally {
      if (mounted) {
        setState(() {
          _loadingDialogData = false;
        });
      }
    }
    if (!mounted) {
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SeatAssignSheet(
        state: _state,
        users: _users,
        onApply: _applySeatAssignment,
      ),
    );
  }

  Future<void> _openScoreEdit() async {
    if (_busy || _loadingDialogData) {
      return;
    }

    setState(() {
      _loadingDialogData = true;
    });
    try {
      await _refreshSeatNames();
    } finally {
      if (mounted) {
        setState(() {
          _loadingDialogData = false;
        });
      }
    }
    if (!mounted) {
      return;
    }

    final result = await showDialog<ScoreEditResult>(
      context: context,
      builder: (_) => ScoreEditDialog(
        state: _state,
        seatNames: _seatNamesFromState(),
      ),
    );
    if (result == null || _busy) {
      return;
    }
    await _applyScoreEdit(result.pointsBySeat);
  }

  Future<void> _applyScoreEdit(Map<Seat, int> pointsBySeat) async {
    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final previous = _state;
      final next = await widget.roomGateway.editScores(
        widget.roomId,
        widget.joinKey,
        pointsBySeat,
        _state.version,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _applyState(previous, next);
      });
    } catch (e) {
      await _handleActionError('点数修正', e);
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _applySeatAssignment(Map<Seat, String?> assignmentBySeat) async {
    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final previous = _state;
      final next = await widget.roomGateway.setSeats(
        widget.roomId,
        widget.joinKey,
        assignmentBySeat,
        _state.version,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _applyState(previous, next);
      });
      await _refreshSeatNames();
    } catch (e) {
      if (_isVersionMismatch(e)) {
        try {
          await _resync();
        } catch (e2) {
          throw Exception('同期に失敗: $e2');
        }
        throw Exception('更新競合が発生したため、最新状態に同期しました。もう一度お試しください。');
      }
      rethrow;
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
      });
    }
  }

  bool _isVersionMismatch(Object e) {
    final msg = e.toString();
    return msg.contains('Version mismatch') || msg.contains('VersionMismatch');
  }

  Future<void> _resync() async {
    final previous = _state;
    final next =
        await widget.roomGateway.joinRoom(widget.roomId, widget.joinKey);
    if (!mounted) {
      return;
    }
    setState(() {
      _applyState(previous, next);
    });
    await _refreshSeatNames();
  }

  Future<void> _handleActionError(String action, Object e) async {
    if (_isVersionMismatch(e)) {
      try {
        await _resync();
        _toast('競合を解消し、最新状態に同期しました');
      } catch (e2) {
        _toast('同期に失敗: $e2');
      }
      return;
    }

    _toast('$action 失敗: $e');
  }

  Future<void> _saveRecord() async {
    if (!_state.isFinished || _savingRecord || _recordSaved) {
      return;
    }

    setState(() {
      _savingRecord = true;
    });

    try {
      await _records.finalizeRecord(
        roomId: widget.roomId,
        joinKey: widget.joinKey,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _recordSaved = true;
      });
      _toast('対局記録を保存しました');
    } catch (e) {
      _toast('対局記録の保存に失敗しました: $e');
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _savingRecord = false;
      });
    }
  }

  Future<void> _rematch() async {
    if (!_state.isFinished || _busy || _savingRecord) {
      return;
    }

    if (!_recordSaved) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('再戦確認'),
          content: const Text('成績保存が未実行です。このまま再戦を開始しますか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('再戦する'),
            ),
          ],
        ),
      );

      if (confirm != true) {
        return;
      }
    }

    setState(() {
      _busy = true;
    });

    try {
      final previous = _state;
      final next = await widget.roomGateway.rematch(
        widget.roomId,
        widget.joinKey,
        _state.version,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _applyState(previous, next);
      });
      _toast('再戦を開始しました');
    } catch (e) {
      await _handleActionError('再戦', e);
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
      });
    }
  }

  void _rotateSeats([int delta = 1]) {
    final seatCount = _activeSeats(_state).length;
    if (seatCount <= 1) {
      return;
    }
    setState(() {
      _seatRotation = (_seatRotation + delta) % seatCount;
    });
  }

  Widget _seatRotateActionIcon() {
    return const SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Icon(Icons.event_seat_outlined, size: 16),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Icon(Icons.rotate_right, size: 15),
          ),
        ],
      ),
    );
  }

  List<_RankEntry> _rankEntries(Map<Seat, String> seatNames) {
    final list = _state.seats
        .map(
          (s) => _RankEntry(
            seat: s.seat,
            name: seatNames[s.seat]?.trim().isNotEmpty == true
                ? seatNames[s.seat]!.trim()
                : '${seatToJp(s.seat)}家',
            points: s.points,
          ),
        )
        .toList()
      ..sort((a, b) {
        final pointComp = b.points.compareTo(a.points);
        if (pointComp != 0) {
          return pointComp;
        }
        return a.seat.index.compareTo(b.seat.index);
      });
    return list;
  }

  Color _rankColor(int rank) {
    switch (rank) {
      case 1:
        return MLeagueTheme.accentGold;
      case 2:
        return Colors.white.withValues(alpha: 0.9);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return Colors.white.withValues(alpha: 0.7);
    }
  }

  Color _resultColor(double value) {
    return value >= 0 ? MLeagueTheme.accentGreen : MLeagueTheme.danger;
  }

  double _umaOkaResult({
    required int points,
    required int rank,
  }) {
    return UmaOkaRule.result(
      finalPoints: points,
      rank: rank,
      playerCount: _state.playerCount,
    );
  }

  Color _seatTrendColor(Seat seat) {
    switch (seat) {
      case Seat.east:
        return const Color(0xFFFF4D4F);
      case Seat.south:
        return const Color(0xFFFFC53D);
      case Seat.west:
        return const Color(0xFF95DE64);
      case Seat.north:
        return const Color(0xFFFF9C6E);
    }
  }

  String _seatDisplayName(Map<Seat, String> seatNames, Seat seat) {
    final name = seatNames[seat]?.trim() ?? '';
    return name.isNotEmpty ? name : seatToJp(seat);
  }

  List<RoomLogEntry> _logsForCurrentMatch() {
    final lastRematchIndex =
        _logs.lastIndexWhere((log) => log.type == RoomLogType.rematch);
    if (lastRematchIndex < 0) {
      return _logs;
    }
    final startIndex = lastRematchIndex + 1;
    if (startIndex >= _logs.length) {
      return const <RoomLogEntry>[];
    }
    return _logs.sublist(startIndex);
  }

  _CurrentMatchLogSummary _currentMatchLogSummary() {
    final riichiBySeat = <Seat, int>{};
    final agariBySeat = <Seat, int>{};
    final dealInBySeat = <Seat, int>{};

    void increment(Map<Seat, int> source, Seat seat) {
      source[seat] = (source[seat] ?? 0) + 1;
    }

    for (final log in _logsForCurrentMatch()) {
      if (log.type == RoomLogType.riichi) {
        final seat = log.actorSeat ?? _seatFromMessagePrefix(log.message);
        if (seat != null) {
          increment(riichiBySeat, seat);
        }
        continue;
      }

      if (log.type != RoomLogType.agari) {
        continue;
      }

      final winnerSeat = log.winnerSeat ?? _seatFromMessagePrefix(log.message);
      if (winnerSeat != null) {
        increment(agariBySeat, winnerSeat);
      }
      if (log.loserSeat != null) {
        increment(dealInBySeat, log.loserSeat!);
      }
    }

    return _CurrentMatchLogSummary(
      riichiBySeat: riichiBySeat,
      agariBySeat: agariBySeat,
      dealInBySeat: dealInBySeat,
    );
  }

  Seat? _seatFromMessagePrefix(String message) {
    final trimmed = message.trimLeft();
    for (final seat in Seat.values) {
      if (trimmed.startsWith(seatToJp(seat))) {
        return seat;
      }
    }
    return null;
  }

  String _formatPoints(int value) {
    final sign = value < 0 ? '-' : '';
    final abs = value.abs().toString();
    final withComma = abs.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
    return '$sign$withComma';
  }

  Widget _trendLegendItem({
    required Color color,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _matchStatBadge(String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _finalRankingPanel({
    required Map<Seat, String> seatNames,
    required bool canOperate,
  }) {
    final rankings = _rankEntries(seatNames);
    final logSummary = _currentMatchLogSummary();
    final timeline = _timelineForDisplay();
    final trendEventCount = math.max(0, timeline.length - 1);
    final canRematch = canOperate && !_savingRecord;
    final canSaveRecord = canOperate && !_savingRecord && !_recordSaved;
    final canEnterSouth = canSaveRecord && _state.gameType == GameType.tonpu;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MLeagueTheme.line),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MLeagueTheme.panel, MLeagueTheme.bg],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'Final Result',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              Text(
                'Trend $trendEventCount',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: _ScoreTrendChart(
              timeline: timeline,
              colorForSeat: _seatTrendColor,
              formatPoints: _formatPoints,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final entry in rankings)
                _trendLegendItem(
                  color: _seatTrendColor(entry.seat),
                  label: _seatDisplayName(seatNames, entry.seat),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '最終順位',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < rankings.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: _rankColor(index + 1).withValues(alpha: 0.18),
                      border: Border.all(
                          color: _rankColor(index + 1).withValues(alpha: 0.7)),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: _rankColor(index + 1),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      rankings[index].name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _formatPoints(rankings[index].points),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    UmaOkaRule.format(
                      _umaOkaResult(
                        points: rankings[index].points,
                        rank: index + 1,
                      ),
                    ),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: _resultColor(
                        _umaOkaResult(
                          points: rankings[index].points,
                          rank: index + 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          const Text(
            '対局スタッツ',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          for (final entry in rankings)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _matchStatBadge(
                        '和了',
                        logSummary.agariBySeat[entry.seat] ?? 0,
                      ),
                      _matchStatBadge(
                        '放銃',
                        logSummary.dealInBySeat[entry.seat] ?? 0,
                      ),
                      _matchStatBadge(
                        'リーチ',
                        logSummary.riichiBySeat[entry.seat] ?? 0,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text(
            UmaOkaRule.labelForPlayerCount(_state.playerCount),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.65),
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 8),
          if (canEnterSouth) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _changeGameType(
                  GameType.hanchan,
                  allowWhenFinished: true,
                ),
                icon: const Icon(Icons.nightlight_round),
                label: const Text('半荘戦にする（南入）'),
              ),
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: canRematch ? _rematch : null,
              icon: const Icon(Icons.replay),
              label: const Text('再戦する（東1から）'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: canSaveRecord ? _saveRecord : null,
              icon: Icon(_recordSaved ? Icons.check_circle : Icons.save),
              label: Text(
                _recordSaved ? '成績保存済み' : (_savingRecord ? '保存中...' : '成績を保存'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final seatNames = _seatNamesFromState();
    final seatIcons = _seatIconsFromState();

    return ValueListenableBuilder<ConnectionStatus>(
      valueListenable: widget.roomGateway.connectionStatus,
      builder: (context, status, _) {
        final isUiLocked = _busy || _loadingDialogData;
        final canOperate = !isUiLocked && status == ConnectionStatus.connected;
        final canScoreActions = canOperate && !_state.isFinished;

        return Stack(
          children: [
            Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => _dismissScoreDelta(),
              child: Scaffold(
                appBar: AppBar(
                  title: Text('${roundToJp(_state.roundWind)}${_state.kyoku}局'),
                  centerTitle: true,
                  actions: [
                    IconButton(
                      onPressed: canScoreActions ? _openGameTypeSelector : null,
                      icon: const Icon(Icons.tune),
                      tooltip: 'ゲーム変更',
                    ),
                    IconButton(
                      onPressed: _rotateSeats,
                      icon: _seatRotateActionIcon(),
                      tooltip: '席表示回転',
                    ),
                    IconButton(
                      onPressed: isUiLocked ? null : _reconnect,
                      icon: const Icon(Icons.wifi),
                      tooltip: '再接続',
                    ),
                    IconButton(
                      onPressed: isUiLocked ? null : _refreshSeatNames,
                      icon: const Icon(Icons.refresh),
                      tooltip: '更新',
                    ),
                    IconButton(
                      onPressed: isUiLocked ? null : _openRecords,
                      icon: const Icon(Icons.leaderboard),
                      tooltip: '成績一覧',
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'メニュー',
                      onSelected: (value) {
                        if (value == 'users') {
                          _openUserManage();
                          return;
                        }
                        if (value == 'records') {
                          _openRecords();
                          return;
                        }
                        if (value == 'guide') {
                          _openRuleGuide();
                          return;
                        }
                        if (value == 'close') {
                          _closeRoom();
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem<String>(
                          value: 'users',
                          child: Text('ユーザー管理'),
                        ),
                        PopupMenuItem<String>(
                          value: 'records',
                          child: Text('成績一覧'),
                        ),
                        PopupMenuItem<String>(
                          value: 'guide',
                          child: Text('ルール・手引き'),
                        ),
                        PopupMenuItem<String>(
                          value: 'close',
                          child: Text('ルーム終了'),
                        ),
                      ],
                    ),
                  ],
                ),
                body: SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            _infoChip('ゲーム', gameTypeToJp(_state.gameType)),
                            _infoChip(
                                '人数', playerCountToJp(_state.playerCount)),
                            _infoChip(
                                '切り上げ',
                                _state.rules.enableKiriageMangan
                                    ? 'ON'
                                    : 'OFF'),
                            _infoChip('数え役満',
                                _state.rules.kazoeAsYakuman ? 'ON' : 'OFF'),
                            _infoChip('通信', _connStatusText(status)),
                            if (_state.isFinished) _infoChip('終了', '済み'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _state.isFinished
                            ? SingleChildScrollView(
                                child: _finalRankingPanel(
                                  seatNames: seatNames,
                                  canOperate: canOperate,
                                ),
                              )
                            : Center(
                                child: Board(
                                  state: _state,
                                  renchan: _state.renchan,
                                  seatNames: seatNames,
                                  seatIcons: seatIcons,
                                  seatScoreDeltaParts: _scoreDeltaPartsBySeat,
                                  scoreDeltaVisible: _scoreDeltaVisible,
                                  scoreDeltaDismissOnTap:
                                      _scoreDeltaDismissOnTap,
                                  scoreDeltaDismissSignal:
                                      _scoreDeltaDismissSignal,
                                  rotation: _seatRotation,
                                  onRiichi:
                                      canScoreActions ? _declareRiichi : null,
                                  onFuro: canScoreActions ? _declareFuro : null,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                bottomNavigationBar: SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      border: Border(
                          top: BorderSide(
                              color: Theme.of(context).dividerColor)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: canScoreActions ? _openAgari : null,
                                icon: const Icon(Icons.flash_on),
                                label: const Text('和了（ロン/ツモ）'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed:
                                    canScoreActions ? _openRyukyoku : null,
                                icon: const Icon(Icons.filter_none),
                                label: const Text('流局'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: canOperate ? _undo : null,
                                icon: const Icon(Icons.undo),
                                label: const Text('Undo'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _openLogs,
                                icon: const Icon(Icons.receipt_long),
                                label: const Text('ログ'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: canOperate ? _openSeatAssign : null,
                                icon: const Icon(Icons.event_seat),
                                label: const Text('席割り当て'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: canOperate ? _openScoreEdit : null,
                                icon: const Icon(Icons.edit),
                                label: const Text('点数修正'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_loadingDialogData) ...[
              const Positioned.fill(
                child: ModalBarrier(
                  dismissible: false,
                  color: Color(0x66000000),
                ),
              ),
              const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'データを読み込み中…',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _infoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankEntry {
  final Seat seat;
  final String name;
  final int points;

  const _RankEntry({
    required this.seat,
    required this.name,
    required this.points,
  });
}

class _CurrentMatchLogSummary {
  final Map<Seat, int> riichiBySeat;
  final Map<Seat, int> agariBySeat;
  final Map<Seat, int> dealInBySeat;

  const _CurrentMatchLogSummary({
    required this.riichiBySeat,
    required this.agariBySeat,
    required this.dealInBySeat,
  });
}

class _ScoreDeltaDisplayMode {
  final Duration visible;
  final bool dismissOnTap;

  const _ScoreDeltaDisplayMode({
    required this.visible,
    required this.dismissOnTap,
  });
}

class _ScoreTimelinePoint {
  final Map<Seat, int> pointsBySeat;

  const _ScoreTimelinePoint({
    required this.pointsBySeat,
  });

  int pointsOf(Seat seat) => pointsBySeat[seat] ?? 0;
}

class _ScoreTrendChart extends StatelessWidget {
  final List<_ScoreTimelinePoint> timeline;
  final Color Function(Seat seat) colorForSeat;
  final String Function(int points) formatPoints;

  const _ScoreTrendChart({
    required this.timeline,
    required this.colorForSeat,
    required this.formatPoints,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ScoreTrendChartPainter(
        timeline: timeline,
        colorForSeat: colorForSeat,
        formatPoints: formatPoints,
        gridColor: Colors.white.withValues(alpha: 0.12),
        axisColor: Colors.white.withValues(alpha: 0.3),
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.78),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _ScoreTrendChartPainter extends CustomPainter {
  final List<_ScoreTimelinePoint> timeline;
  final Color Function(Seat seat) colorForSeat;
  final String Function(int points) formatPoints;
  final Color gridColor;
  final Color axisColor;
  final TextStyle labelStyle;

  const _ScoreTrendChartPainter({
    required this.timeline,
    required this.colorForSeat,
    required this.formatPoints,
    required this.gridColor,
    required this.axisColor,
    required this.labelStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    const leftPad = 52.0;
    const topPad = 10.0;
    const rightPad = 10.0;
    const bottomPad = 24.0;

    final plotRect = Rect.fromLTWH(
      leftPad,
      topPad,
      size.width - leftPad - rightPad,
      size.height - topPad - bottomPad,
    );
    if (plotRect.width <= 0 || plotRect.height <= 0) {
      return;
    }

    final points = timeline.isNotEmpty
        ? timeline
        : [
            const _ScoreTimelinePoint(pointsBySeat: {}),
          ];
    final seats = <Seat>{
      for (final point in points) ...point.pointsBySeat.keys,
    }.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    if (seats.isEmpty) {
      seats.add(Seat.east);
    }

    final scoreValues = <int>[
      for (final point in points)
        for (final seat in seats) point.pointsOf(seat),
    ];

    var minScore = scoreValues.reduce(math.min);
    var maxScore = scoreValues.reduce(math.max);
    if (minScore == maxScore) {
      minScore -= 1000;
      maxScore += 1000;
    }

    final scoreSpan = maxScore - minScore;
    final yPadding = math.max(1000, (scoreSpan * 0.08).round());
    final chartMin = minScore - yPadding;
    final chartMax = maxScore + yPadding;
    final chartSpan = math.max(1, chartMax - chartMin);

    double xAt(int index) {
      if (points.length <= 1) {
        return plotRect.center.dx;
      }
      return plotRect.left + (plotRect.width * index / (points.length - 1));
    }

    double yFor(int score) {
      final ratio = (score - chartMin) / chartSpan;
      return plotRect.bottom - (plotRect.height * ratio);
    }

    final axisPaint = Paint()
      ..color = axisColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRect(plotRect, axisPaint);

    const horizontalLineCount = 4;
    for (var i = 0; i <= horizontalLineCount; i++) {
      final ratio = i / horizontalLineCount;
      final y = plotRect.top + (plotRect.height * ratio);
      canvas.drawLine(
        Offset(plotRect.left, y),
        Offset(plotRect.right, y),
        gridPaint,
      );

      final labelValue = chartMax - ((chartMax - chartMin) * ratio).round();
      _paintText(
        canvas,
        formatPoints(labelValue),
        Offset(plotRect.left - 6, y),
        align: TextAlign.right,
      );
    }

    for (var i = 0; i < points.length; i++) {
      final x = xAt(i);
      canvas.drawLine(
        Offset(x, plotRect.top),
        Offset(x, plotRect.bottom),
        gridPaint,
      );
    }

    final labelStride = points.length <= 10 ? 1 : (points.length / 10).ceil();
    for (var i = 0; i < points.length; i++) {
      if (i != 0 && i != points.length - 1 && i % labelStride != 0) {
        continue;
      }

      final x = xAt(i);
      _paintText(
        canvas,
        i == 0 ? 'Start' : '$i',
        Offset(x, plotRect.bottom + 8),
        align: TextAlign.center,
        centerY: false,
      );
    }

    for (final seat in seats) {
      final color = colorForSeat(seat);
      final linePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;
      final dotPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      if (points.length == 1) {
        canvas.drawCircle(
          Offset(plotRect.center.dx, yFor(points.first.pointsOf(seat))),
          3.6,
          dotPaint,
        );
        continue;
      }

      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final offset = Offset(xAt(i), yFor(points[i].pointsOf(seat)));
        if (i == 0) {
          path.moveTo(offset.dx, offset.dy);
        } else {
          path.lineTo(offset.dx, offset.dy);
        }
      }
      canvas.drawPath(path, linePaint);

      final lastOffset = Offset(
        xAt(points.length - 1),
        yFor(points.last.pointsOf(seat)),
      );
      canvas.drawCircle(lastOffset, 4.0, dotPaint);
      canvas.drawCircle(
        lastOffset,
        6.2,
        Paint()
          ..color = color.withValues(alpha: 0.22)
          ..style = PaintingStyle.fill,
      );
    }
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset offset, {
    TextAlign align = TextAlign.left,
    bool centerY = true,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: 1,
    )..layout();

    var dx = offset.dx;
    if (align == TextAlign.right) {
      dx -= painter.width;
    } else if (align == TextAlign.center) {
      dx -= painter.width / 2;
    }
    final dy = centerY ? offset.dy - (painter.height / 2) : offset.dy;

    painter.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _ScoreTrendChartPainter oldDelegate) {
    return oldDelegate.timeline != timeline ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.labelStyle != labelStyle;
  }
}
