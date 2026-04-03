import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:signalr_core/signalr_core.dart';

import '../config/app_config.dart';
import '../model/models.dart';
import 'api_client.dart';

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

class RoomGateway {
  final String baseUrl;
  final ApiClient _api;

  HubConnection? _conn;
  Future<void>? _connecting;
  Future<void>? _rejoining;

  String? _activeRoomId;
  String? _activeJoinKey;

  final List<void Function(RoomState)> _stateUpdatedHandlers = [];
  final List<void Function(List<RoomLogEntry>)> _logsUpdatedHandlers = [];

  final ValueNotifier<ConnectionStatus> connectionStatus =
      ValueNotifier(ConnectionStatus.disconnected);

  RoomGateway({String? baseUrl})
      : baseUrl = baseUrl ?? AppConfig.baseUrl,
        _api = ApiClient(baseUrl: baseUrl ?? AppConfig.baseUrl);

  Future<void> connect() async {
    await _ensureConnected();
  }

  HubConnection _buildConnection() {
    final conn = HubConnectionBuilder()
        .withUrl(
          '$baseUrl/hubs/room',
          HttpConnectionOptions(logging: (level, message) {}),
        )
        .withAutomaticReconnect()
        .build();

    conn.onclose((_) {
      if (!identical(_conn, conn)) {
        return;
      }
      connectionStatus.value = ConnectionStatus.disconnected;
    });

    conn.onreconnecting((_) {
      if (!identical(_conn, conn)) {
        return;
      }
      connectionStatus.value = ConnectionStatus.reconnecting;
    });

    conn.onreconnected((_) async {
      if (!identical(_conn, conn)) {
        return;
      }
      connectionStatus.value = ConnectionStatus.connected;
      await _rejoinActiveRoom();
    });

    conn.on('StateUpdated', (args) {
      if (args == null || args.isEmpty) {
        return;
      }
      final json = (args.first as Map).cast<String, dynamic>();
      final state = RoomState.fromJson(json);
      for (final handler
          in List<void Function(RoomState)>.from(_stateUpdatedHandlers)) {
        handler(state);
      }
    });

    conn.on('LogsUpdated', (args) {
      if (args == null || args.isEmpty) {
        return;
      }
      final list = (args.first as List<dynamic>)
          .cast<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      final parsed = list.map((e) => RoomLogEntry.fromJson(e)).toList();
      for (final handler in List<void Function(List<RoomLogEntry>)>.from(
          _logsUpdatedHandlers)) {
        handler(parsed);
      }
    });

    return conn;
  }

  Future<void> _ensureConnected() async {
    final conn = _conn;
    if (conn != null && conn.state == HubConnectionState.connected) {
      connectionStatus.value = ConnectionStatus.connected;
      return;
    }

    final running = _connecting;
    if (running != null) {
      await running;
      return;
    }

    final task = _ensureConnectedInner();
    _connecting = task;
    try {
      await task;
    } finally {
      if (identical(_connecting, task)) {
        _connecting = null;
      }
    }
  }

  Future<void> _ensureConnectedInner() async {
    _conn ??= _buildConnection();
    final conn = _conn!;

    if (conn.state == HubConnectionState.connected) {
      connectionStatus.value = ConnectionStatus.connected;
      return;
    }

    if (conn.state == HubConnectionState.connecting ||
        conn.state == HubConnectionState.reconnecting) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (conn.state == HubConnectionState.connected) {
        connectionStatus.value = ConnectionStatus.connected;
        return;
      }
    }

    connectionStatus.value = ConnectionStatus.connecting;
    if (conn.state != HubConnectionState.disconnected) {
      try {
        await conn.stop();
      } catch (_) {}
    }

    await conn.start();
    connectionStatus.value = ConnectionStatus.connected;
    await _rejoinActiveRoom();
  }

  void onStateUpdated(void Function(RoomState) handler) {
    _stateUpdatedHandlers.add(handler);
  }

  void onLogsUpdated(void Function(List<RoomLogEntry>) handler) {
    _logsUpdatedHandlers.add(handler);
  }

  Future<Map<String, dynamic>> _invokeResult(
    String method, {
    List<Object?> args = const [],
    bool retryOnFailure = true,
  }) async {
    await _ensureConnected();

    try {
      final raw = await _conn!.invoke(method, args: args);
      return (raw as Map).cast<String, dynamic>();
    } catch (_) {
      if (!retryOnFailure) {
        rethrow;
      }
      await reconnect();
      final raw = await _conn!.invoke(method, args: args);
      return (raw as Map).cast<String, dynamic>();
    }
  }

  RoomState _stateFromResult(
      Map<String, dynamic> result, String fallbackError) {
    if (result['isSuccess'] != true) {
      final err = (result['error'] as Map<String, dynamic>?)?['message'];
      throw Exception(err ?? fallbackError);
    }
    final value = (result['value'] as Map).cast<String, dynamic>();
    return RoomState.fromJson((value['state'] as Map).cast<String, dynamic>());
  }

  Future<RoomState> _joinRoomCore(
    String roomId,
    String joinKey, {
    required bool retryOnFailure,
  }) async {
    final result = await _invokeResult(
      'JoinRoom',
      args: [roomId, joinKey],
      retryOnFailure: retryOnFailure,
    );
    return _stateFromResult(result, 'JoinRoom failed');
  }

  Future<RoomState> _joinRoomOnCurrentConnection(
    String roomId,
    String joinKey,
  ) async {
    final raw = await _conn!.invoke('JoinRoom', args: [roomId, joinKey]);
    final result = (raw as Map).cast<String, dynamic>();
    return _stateFromResult(result, 'JoinRoom failed');
  }

  Future<void> _rejoinActiveRoom() async {
    final roomId = _activeRoomId;
    final joinKey = _activeJoinKey;
    if (roomId == null || joinKey == null) {
      return;
    }

    final running = _rejoining;
    if (running != null) {
      await running;
      return;
    }

    final task = () async {
      final conn = _conn;
      if (conn == null || conn.state != HubConnectionState.connected) {
        return;
      }
      try {
        final state = await _joinRoomOnCurrentConnection(roomId, joinKey);
        for (final handler
            in List<void Function(RoomState)>.from(_stateUpdatedHandlers)) {
          handler(state);
        }
      } catch (_) {
        // Keep connection alive even if room rejoin fails.
      }
    }();

    _rejoining = task;
    try {
      await task;
    } finally {
      if (identical(_rejoining, task)) {
        _rejoining = null;
      }
    }
  }

  Future<RoomState> joinRoom(String roomId, String joinKey) async {
    final state = await _joinRoomCore(
      roomId,
      joinKey,
      retryOnFailure: true,
    );
    _activeRoomId = roomId;
    _activeJoinKey = joinKey;
    return state;
  }

  Future<List<RoomSummary>> getRooms() async {
    final map = await _api.getJson('/api/rooms');
    final list = (map['rooms'] as List<dynamic>).cast<Map<String, dynamic>>();
    return list.map(RoomSummary.fromJson).toList();
  }

  Future<RoomState> setSeat(
    String roomId,
    String joinKey,
    Seat seat,
    String? userId,
    int expectedVersion,
  ) async {
    final input = {
      'seat': seat.index,
      'userId': userId == null ? null : {'value': userId},
      'expectedVersion': expectedVersion,
    };

    final result =
        await _invokeResult('SetSeat', args: [roomId, joinKey, input]);
    return _stateFromResult(result, 'SetSeat failed');
  }

  Future<RoomState> setSeats(
    String roomId,
    String joinKey,
    Map<Seat, String?> assignmentBySeat,
    int expectedVersion,
  ) async {
    final assignments = assignmentBySeat.entries
        .map((e) => {
              'seat': e.key.index,
              'userId': e.value == null ? null : {'value': e.value},
            })
        .toList();

    final input = {
      'assignments': assignments,
      'expectedVersion': expectedVersion,
    };

    final result =
        await _invokeResult('SetSeats', args: [roomId, joinKey, input]);
    return _stateFromResult(result, 'SetSeats failed');
  }

  Future<RoomState> setGameType(
    String roomId,
    String joinKey,
    GameType gameType,
    int expectedVersion,
  ) async {
    final input = {
      'gameType': gameType.index,
      'expectedVersion': expectedVersion,
    };

    final result =
        await _invokeResult('SetGameType', args: [roomId, joinKey, input]);
    return _stateFromResult(result, 'SetGameType failed');
  }

  Future<RoomState> editScores(
    String roomId,
    String joinKey,
    Map<Seat, int> pointsBySeat,
    int expectedVersion,
  ) async {
    final seats = pointsBySeat.entries
        .map((e) => {
              'seat': e.key.index,
              'points': e.value,
            })
        .toList();

    final input = {
      'seats': seats,
      'expectedVersion': expectedVersion,
    };

    final result =
        await _invokeResult('EditScores', args: [roomId, joinKey, input]);
    return _stateFromResult(result, 'EditScores failed');
  }

  Future<RoomState> declareRiichi(
    String roomId,
    String joinKey,
    Seat seat,
    int expectedVersion,
  ) async {
    final input = {'seat': seat.index, 'expectedVersion': expectedVersion};

    final result =
        await _invokeResult('DeclareRiichi', args: [roomId, joinKey, input]);
    return _stateFromResult(result, 'DeclareRiichi failed');
  }

  Future<RoomState> declareFuro(
    String roomId,
    String joinKey,
    Seat seat,
    int expectedVersion,
  ) async {
    final input = {'seat': seat.index, 'expectedVersion': expectedVersion};

    final result =
        await _invokeResult('DeclareFuro', args: [roomId, joinKey, input]);
    return _stateFromResult(result, 'DeclareFuro failed');
  }

  Future<RoomState> enterAgari({
    required String roomId,
    required String joinKey,
    required Seat winnerSeat,
    required AgariMethod method,
    required int han,
    required int fu,
    Seat? ronLoserSeat,
    required int expectedVersion,
  }) async {
    final input = {
      'winnerSeat': winnerSeat.index,
      'method': method == AgariMethod.ron ? 0 : 1,
      'ronLoserSeat': ronLoserSeat?.index,
      'han': han,
      'fu': fu,
      'yakumanMultiplier': 0,
      'expectedVersion': expectedVersion,
    };

    final result =
        await _invokeResult('EnterAgari', args: [roomId, joinKey, input]);
    return _stateFromResult(result, 'EnterAgari failed');
  }

  Future<RoomState> enterRyukyoku({
    required String roomId,
    required String joinKey,
    required List<Seat> tenpaiSeats,
    required int expectedVersion,
  }) async {
    final input = {
      'tenpaiSeats': tenpaiSeats.map((x) => x.index).toList(),
      'expectedVersion': expectedVersion,
    };

    final result =
        await _invokeResult('EnterRyukyoku', args: [roomId, joinKey, input]);
    return _stateFromResult(result, 'EnterRyukyoku failed');
  }

  Future<RoomState> undo(
    String roomId,
    String joinKey,
    int expectedVersion,
  ) async {
    final input = {'expectedVersion': expectedVersion};
    final result = await _invokeResult('Undo', args: [roomId, joinKey, input]);
    return _stateFromResult(result, 'Undo failed');
  }

  Future<RoomState> rematch(
    String roomId,
    String joinKey,
    int expectedVersion,
  ) async {
    final input = {'expectedVersion': expectedVersion};
    final result =
        await _invokeResult('Rematch', args: [roomId, joinKey, input]);
    return _stateFromResult(result, 'Rematch failed');
  }

  Future<void> closeRoom(String roomId, String joinKey) async {
    if (_activeRoomId == roomId && _activeJoinKey == joinKey) {
      _activeRoomId = null;
      _activeJoinKey = null;
    }

    final encodedKey = Uri.encodeQueryComponent(joinKey);
    await _api.deleteJson('/api/rooms/$roomId?key=$encodedKey');
    await disconnect();
  }

  Future<void> disconnect() async {
    final conn = _conn;
    _conn = null;
    _connecting = null;
    _rejoining = null;

    if (conn == null) {
      connectionStatus.value = ConnectionStatus.disconnected;
      return;
    }

    try {
      await conn.stop();
    } finally {
      connectionStatus.value = ConnectionStatus.disconnected;
    }
  }

  Future<void> reconnect() async {
    connectionStatus.value = ConnectionStatus.connecting;

    final old = _conn;
    _conn = _buildConnection();
    _connecting = null;
    _rejoining = null;

    if (old != null) {
      try {
        await old.stop();
      } catch (_) {}
    }

    try {
      await _conn!.start();
      connectionStatus.value = ConnectionStatus.connected;
      await _rejoinActiveRoom();
    } catch (_) {
      connectionStatus.value = ConnectionStatus.disconnected;
      rethrow;
    }
  }
}
