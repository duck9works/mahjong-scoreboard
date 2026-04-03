class UserProfile {
  final String userId;
  final String displayName;
  final String? iconDataUrl;
  final int riichiVoiceId;
  final bool isHidden;

  UserProfile({
    required this.userId,
    required this.displayName,
    required this.iconDataUrl,
    required this.riichiVoiceId,
    required this.isHidden,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: (json['userId'] as Map<String, dynamic>)['value'] as String,
      displayName: json['displayName'] as String,
      iconDataUrl: json['iconDataUrl'] as String?,
      riichiVoiceId: (json['riichiVoiceId'] as num?)?.toInt() ?? 0,
      isHidden: json['isHidden'] as bool? ?? false,
    );
  }
}

enum RoundWind {
  east,
  south,
}

String roundToJp(RoundWind w) {
  switch (w) {
    case RoundWind.east:
      return '東';
    case RoundWind.south:
      return '南';
  }
}

RoundWind roundFromInt(int v) {
  switch (v) {
    case 0:
      return RoundWind.east;
    case 1:
      return RoundWind.south;
    default:
      return RoundWind.east;
  }
}

enum GameType {
  tonpu,
  hanchan,
}

GameType gameTypeFromInt(int v) {
  switch (v) {
    case 0:
      return GameType.tonpu;
    case 1:
      return GameType.hanchan;
    default:
      return GameType.tonpu;
  }
}

String gameTypeToJp(GameType gameType) {
  switch (gameType) {
    case GameType.tonpu:
      return '東風';
    case GameType.hanchan:
      return '半荘';
  }
}

enum Seat {
  east,
  south,
  west,
  north,
}

int normalizePlayerCount(int value, {int fallback = 4}) {
  if (value == 3 || value == 4) {
    return value;
  }
  return fallback == 3 ? 3 : 4;
}

List<Seat> seatsForPlayerCount(int playerCount) {
  if (playerCount == 3) {
    return const [Seat.east, Seat.south, Seat.west];
  }
  return const [Seat.east, Seat.south, Seat.west, Seat.north];
}

int maxKyokuForPlayerCount(int playerCount) {
  return playerCount == 3 ? 3 : 4;
}

String playerCountToJp(int playerCount) {
  return playerCount == 3 ? '3麻' : '4麻';
}

String seatToJp(Seat seat) {
  switch (seat) {
    case Seat.east:
      return '東';
    case Seat.south:
      return '南';
    case Seat.west:
      return '西';
    case Seat.north:
      return '北';
  }
}

Seat seatFromInt(int v) {
  switch (v) {
    case 0:
      return Seat.east;
    case 1:
      return Seat.south;
    case 2:
      return Seat.west;
    case 3:
      return Seat.north;
    default:
      return Seat.east;
  }
}

class SeatState {
  final Seat seat;
  final int points;
  final String? assignedUserId;
  final bool isRiichi;
  final bool isFuro;

  SeatState({
    required this.seat,
    required this.points,
    required this.assignedUserId,
    required this.isRiichi,
    required this.isFuro,
  });

  factory SeatState.fromJson(Map<String, dynamic> json) {
    return SeatState(
      seat: seatFromInt(json['seat'] as int),
      points: json['points'] as int,
      assignedUserId: (json['assignedUserId']
          as Map<String, dynamic>?)?['value'] as String?,
      isRiichi: json['isRiichi'] as bool,
      isFuro: json['isFuro'] as bool? ?? false,
    );
  }
}

class RuleConfig {
  final bool keepFu25;
  final bool enableKiriageMangan;
  final bool kazoeAsYakuman;

  const RuleConfig({
    required this.keepFu25,
    required this.enableKiriageMangan,
    required this.kazoeAsYakuman,
  });

  factory RuleConfig.defaultConfig() {
    return const RuleConfig(
      keepFu25: true,
      enableKiriageMangan: true,
      kazoeAsYakuman: true,
    );
  }

  factory RuleConfig.fromJson(Map<String, dynamic> json) {
    return RuleConfig(
      keepFu25: json['keepFu25'] as bool? ?? true,
      enableKiriageMangan: json['enableKiriageMangan'] as bool? ?? true,
      kazoeAsYakuman: json['kazoeAsYakuman'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'keepFu25': keepFu25,
      'enableKiriageMangan': enableKiriageMangan,
      'kazoeAsYakuman': kazoeAsYakuman,
    };
  }
}

class RoomState {
  final String roomName;
  final int initialPoints;
  final List<SeatState> seats;
  final Seat dealerSeat;
  final RoundWind roundWind;
  final int kyoku;
  final int honba;
  final int renchan;
  final int kyotaku;
  final GameType gameType;
  final int playerCount;
  final RuleConfig rules;
  final bool isFinished;
  final int version;

  RoomState({
    required this.roomName,
    required this.initialPoints,
    required this.seats,
    required this.dealerSeat,
    required this.roundWind,
    required this.kyoku,
    required this.honba,
    required this.renchan,
    required this.kyotaku,
    required this.gameType,
    required this.playerCount,
    required this.rules,
    required this.isFinished,
    required this.version,
  });

  factory RoomState.fromJson(Map<String, dynamic> json) {
    final seatsJson =
        (json['seats'] as List<dynamic>).cast<Map<String, dynamic>>();
    final seats = seatsJson.map((e) => SeatState.fromJson(e)).toList();
    final inferredPlayerCount = seats.length == 3 ? 3 : 4;
    final playerCount = normalizePlayerCount(
      (json['playerCount'] as num?)?.toInt() ?? inferredPlayerCount,
      fallback: inferredPlayerCount,
    );
    return RoomState(
      roomName: json['roomName'] as String? ?? '',
      initialPoints: (json['initialPoints'] as num?)?.toInt() ?? 25000,
      seats: seats,
      dealerSeat: seatFromInt(json['dealerSeat'] as int),
      roundWind: roundFromInt(json['roundWind'] as int),
      kyoku: json['kyoku'] as int,
      honba: json['honba'] as int,
      renchan: (json['renchan'] as num?)?.toInt() ?? 0,
      kyotaku: json['kyotaku'] as int,
      gameType: gameTypeFromInt((json['gameType'] as num?)?.toInt() ?? 0),
      playerCount: playerCount,
      rules: RuleConfig.fromJson(
        (json['rules'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      isFinished: json['isFinished'] as bool? ?? false,
      version: (json['version'] as num).toInt(),
    );
  }

  SeatState seatState(Seat seat) {
    return seats.firstWhere((x) => x.seat == seat);
  }

  List<Seat> get activeSeats {
    final sorted = seats.map((x) => x.seat).toSet().toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return sorted;
  }
}

enum RoomLogType {
  seatAssignment,
  riichi,
  agari,
  undo,
  scoreEdit,
  ryukyoku,
  gameTypeChange,
  rematch,
  furo,
}

RoomLogType logTypeFromInt(int v) {
  switch (v) {
    case 0:
      return RoomLogType.seatAssignment;
    case 1:
      return RoomLogType.riichi;
    case 2:
      return RoomLogType.agari;
    case 3:
      return RoomLogType.undo;
    case 4:
      return RoomLogType.scoreEdit;
    case 5:
      return RoomLogType.ryukyoku;
    case 6:
      return RoomLogType.gameTypeChange;
    case 7:
      return RoomLogType.rematch;
    case 8:
      return RoomLogType.furo;
    default:
      return RoomLogType.seatAssignment;
  }
}

class RoomSummary {
  final String roomId;
  final String roomName;
  final String joinKey;
  final bool isFinished;
  final DateTime? createdAt;

  const RoomSummary({
    required this.roomId,
    required this.roomName,
    required this.joinKey,
    required this.isFinished,
    required this.createdAt,
  });

  factory RoomSummary.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['createdAt'] as String?;
    return RoomSummary(
      roomId: json['roomId'] as String,
      roomName: json['roomName'] as String? ?? '',
      joinKey: json['joinKey'] as String,
      isFinished: json['isFinished'] as bool? ?? false,
      createdAt: createdAtRaw == null || createdAtRaw.isEmpty
          ? null
          : DateTime.tryParse(createdAtRaw),
    );
  }
}

class RoomLogEntry {
  final int seq;
  final DateTime at;
  final RoomLogType type;
  final String message;
  final Seat? actorSeat;
  final Seat? winnerSeat;
  final Seat? loserSeat;
  final AgariMethod? method;
  final int? han;
  final int? fu;
  final int? pointValue;
  final int? dealInPointValue;

  RoomLogEntry({
    required this.seq,
    required this.at,
    required this.type,
    required this.message,
    required this.actorSeat,
    required this.winnerSeat,
    required this.loserSeat,
    required this.method,
    required this.han,
    required this.fu,
    required this.pointValue,
    required this.dealInPointValue,
  });

  factory RoomLogEntry.fromJson(Map<String, dynamic> json) {
    Seat? parseSeat(dynamic source) {
      if (source is num) {
        return seatFromInt(source.toInt());
      }
      return null;
    }

    AgariMethod? parseMethod(dynamic source) {
      if (source is num) {
        final value = source.toInt();
        if (value == 0) {
          return AgariMethod.ron;
        }
        if (value == 1) {
          return AgariMethod.tsumo;
        }
      }
      return null;
    }

    return RoomLogEntry(
      seq: (json['seq'] as num).toInt(),
      at: DateTime.parse(json['at'] as String),
      type: logTypeFromInt(json['type'] as int),
      message: json['message'] as String,
      actorSeat: parseSeat(json['actorSeat']),
      winnerSeat: parseSeat(json['winnerSeat']),
      loserSeat: parseSeat(json['loserSeat']),
      method: parseMethod(json['method']),
      han: (json['han'] as num?)?.toInt(),
      fu: (json['fu'] as num?)?.toInt(),
      pointValue: (json['pointValue'] as num?)?.toInt(),
      dealInPointValue: (json['dealInPointValue'] as num?)?.toInt(),
    );
  }
}

class MatchParticipant {
  final Seat seat;
  final String? userId;
  final int finalPoints;

  const MatchParticipant({
    required this.seat,
    required this.userId,
    required this.finalPoints,
  });

  factory MatchParticipant.fromJson(Map<String, dynamic> json) {
    return MatchParticipant(
      seat: seatFromInt(json['seat'] as int),
      userId: (json['userId'] as Map<String, dynamic>?)?['value'] as String?,
      finalPoints: json['finalPoints'] as int,
    );
  }
}

class MatchRecord {
  final String matchId;
  final String roomId;
  final DateTime startedAt;
  final DateTime endedAt;
  final List<MatchParticipant> participants;
  final RoomState finalState;
  final List<RoomLogEntry> logs;

  const MatchRecord({
    required this.matchId,
    required this.roomId,
    required this.startedAt,
    required this.endedAt,
    required this.participants,
    required this.finalState,
    required this.logs,
  });

  factory MatchRecord.fromJson(Map<String, dynamic> json) {
    final participantsJson =
        (json['participants'] as List<dynamic>).cast<Map<String, dynamic>>();
    final logsJson =
        (json['logs'] as List<dynamic>).cast<Map<String, dynamic>>();

    return MatchRecord(
      matchId: json['matchId'] as String,
      roomId: json['roomId'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      endedAt: DateTime.parse(json['endedAt'] as String),
      participants:
          participantsJson.map((x) => MatchParticipant.fromJson(x)).toList(),
      finalState:
          RoomState.fromJson(json['finalState'] as Map<String, dynamic>),
      logs: logsJson.map((x) => RoomLogEntry.fromJson(x)).toList(),
    );
  }

  int get playerCount => finalState.playerCount;
}

enum AgariMethod {
  ron,
  tsumo,
}

String agariMethodToJp(AgariMethod m) {
  switch (m) {
    case AgariMethod.ron:
      return 'ロン';
    case AgariMethod.tsumo:
      return 'ツモ';
  }
}
