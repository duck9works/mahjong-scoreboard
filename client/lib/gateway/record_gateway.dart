import '../model/models.dart';
import 'api_client.dart';

class ManualRecordParticipantInput {
  final Seat seat;
  final String? userId;
  final int finalPoints;

  const ManualRecordParticipantInput({
    required this.seat,
    required this.userId,
    required this.finalPoints,
  });
}

class RecordGateway {
  final ApiClient _api;

  RecordGateway(this._api);

  Future<List<MatchRecord>> getRecords() async {
    final map = await _api.getJson('/api/records');
    final list = (map['records'] as List<dynamic>).cast<Map<String, dynamic>>();
    return list.map(MatchRecord.fromJson).toList();
  }

  Future<MatchRecord> finalizeRecord({
    required String roomId,
    required String joinKey,
  }) async {
    final encodedKey = Uri.encodeQueryComponent(joinKey);
    final map =
        await _api.postJson('/api/rooms/$roomId/records?key=$encodedKey', {});
    final record = map['record'] as Map<String, dynamic>;
    return MatchRecord.fromJson(record);
  }

  Future<MatchRecord> createManualRecord({
    required GameType gameType,
    required List<ManualRecordParticipantInput> participants,
    DateTime? startedAt,
    DateTime? endedAt,
  }) async {
    final body = <String, dynamic>{
      'gameType': gameType.index,
      'participants': participants
          .map(
            (participant) => {
              'seat': participant.seat.index,
              'userId': participant.userId == null
                  ? null
                  : {
                      'value': participant.userId,
                    },
              'finalPoints': participant.finalPoints,
            },
          )
          .toList(),
      if (startedAt != null) 'startedAt': startedAt.toUtc().toIso8601String(),
      if (endedAt != null) 'endedAt': endedAt.toUtc().toIso8601String(),
    };

    final map = await _api.postJson('/api/records', body);
    final record = map['record'] as Map<String, dynamic>;
    return MatchRecord.fromJson(record);
  }

  Future<MatchRecord> updateRecord({
    required String recordId,
    required GameType gameType,
    required List<ManualRecordParticipantInput> participants,
    DateTime? startedAt,
    DateTime? endedAt,
  }) async {
    final body = <String, dynamic>{
      'gameType': gameType.index,
      'participants': participants
          .map(
            (participant) => {
              'seat': participant.seat.index,
              'userId': participant.userId == null
                  ? null
                  : {
                      'value': participant.userId,
                    },
              'finalPoints': participant.finalPoints,
            },
          )
          .toList(),
      if (startedAt != null) 'startedAt': startedAt.toUtc().toIso8601String(),
      if (endedAt != null) 'endedAt': endedAt.toUtc().toIso8601String(),
    };

    final map = await _api.putJson('/api/records/$recordId', body);
    final record = map['record'] as Map<String, dynamic>;
    return MatchRecord.fromJson(record);
  }

  Future<void> deleteRecord(String recordId) async {
    await _api.deleteJson('/api/records/$recordId');
  }
}
