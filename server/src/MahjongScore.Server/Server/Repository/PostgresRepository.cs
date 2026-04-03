#nullable enable
using System.Data;
using System.Text.Json;
using MahjongScore.Domain;
using Npgsql;
using NpgsqlTypes;

namespace MahjongScore.Server.Repository;

public sealed class PostgresDatabase
{
    private readonly string _connectionString;

    public PostgresDatabase(string connectionString)
    {
        _connectionString = connectionString;
    }

    public NpgsqlConnection OpenConnection()
    {
        var connection = new NpgsqlConnection(_connectionString);
        connection.Open();
        return connection;
    }
}

public sealed class PostgresUserRepository : IUserRepository
{
    private readonly PostgresDatabase _database;

    public PostgresUserRepository(PostgresDatabase database)
    {
        _database = database;
    }

    public UserSnapshot Create(string displayName)
    {
        if (string.IsNullOrWhiteSpace(displayName))
        {
            throw new ArgumentException("Display name is required.", nameof(displayName));
        }

        var trimmed = displayName.Trim();
        var userId = new UserId(Guid.NewGuid());
        var riichiVoiceId = Random.Shared.Next(0, 8);

        using var connection = _database.OpenConnection();
        using var command = connection.CreateCommand();
        command.CommandText = """
                              INSERT INTO users (user_id, display_name, icon_data_url, riichi_voice_id, is_hidden)
                              VALUES (@userId, @displayName, @iconDataUrl, @riichiVoiceId, @isHidden);
                              """;
        command.Parameters.AddWithValue("userId", userId.Value);
        command.Parameters.AddWithValue("displayName", trimmed);
        command.Parameters.Add(new NpgsqlParameter("iconDataUrl", NpgsqlDbType.Text) { Value = DBNull.Value });
        command.Parameters.AddWithValue("riichiVoiceId", riichiVoiceId);
        command.Parameters.AddWithValue("isHidden", false);
        command.ExecuteNonQuery();

        return new UserSnapshot
        {
            User = new UserProfile
            {
                UserId = userId,
                DisplayName = trimmed,
                IconDataUrl = null,
                RiichiVoiceId = riichiVoiceId,
                IsHidden = false,
            },
        };
    }

    public UserSnapshot? Get(UserId id)
    {
        using var connection = _database.OpenConnection();
        using var command = connection.CreateCommand();
        command.CommandText = """
                              SELECT user_id, display_name, icon_data_url, riichi_voice_id, is_hidden
                              FROM users
                              WHERE user_id = @userId;
                              """;
        command.Parameters.AddWithValue("userId", id.Value);

        using var reader = command.ExecuteReader();
        if (!reader.Read())
        {
            return null;
        }

        return new UserSnapshot
        {
            User = new UserProfile
            {
                UserId = new UserId(reader.GetGuid(0)),
                DisplayName = reader.GetString(1),
                IconDataUrl = reader.IsDBNull(2) ? null : reader.GetString(2),
                RiichiVoiceId = reader.GetInt32(3),
                IsHidden = reader.GetBoolean(4),
            },
        };
    }

    public IReadOnlyList<UserSnapshot> GetAll()
    {
        using var connection = _database.OpenConnection();
        using var command = connection.CreateCommand();
        command.CommandText = """
                              SELECT user_id, display_name, icon_data_url, riichi_voice_id, is_hidden
                              FROM users
                              ORDER BY created_at ASC, user_id ASC;
                              """;

        using var reader = command.ExecuteReader();
        var users = new List<UserSnapshot>();

        while (reader.Read())
        {
            users.Add(new UserSnapshot
            {
                User = new UserProfile
                {
                    UserId = new UserId(reader.GetGuid(0)),
                    DisplayName = reader.GetString(1),
                    IconDataUrl = reader.IsDBNull(2) ? null : reader.GetString(2),
                    RiichiVoiceId = reader.GetInt32(3),
                    IsHidden = reader.GetBoolean(4),
                },
            });
        }

        return users;
    }

    public bool TryUpdate(UserId id, Func<UserSnapshot, UserSnapshot> update, out UserSnapshot? updated)
    {
        updated = null;

        using var connection = _database.OpenConnection();
        using var transaction = connection.BeginTransaction(IsolationLevel.ReadCommitted);

        using var getCommand = connection.CreateCommand();
        getCommand.Transaction = transaction;
        getCommand.CommandText = """
                                 SELECT user_id, display_name, icon_data_url, riichi_voice_id, is_hidden
                                 FROM users
                                 WHERE user_id = @userId
                                 FOR UPDATE;
                                 """;
        getCommand.Parameters.AddWithValue("userId", id.Value);

        using var reader = getCommand.ExecuteReader();
        if (!reader.Read())
        {
            return false;
        }

        var current = new UserSnapshot
        {
            User = new UserProfile
            {
                UserId = new UserId(reader.GetGuid(0)),
                DisplayName = reader.GetString(1),
                IconDataUrl = reader.IsDBNull(2) ? null : reader.GetString(2),
                RiichiVoiceId = reader.GetInt32(3),
                IsHidden = reader.GetBoolean(4),
            },
        };

        reader.Close();

        var next = update(current);
        var displayName = next.User.DisplayName?.Trim() ?? string.Empty;
        if (string.IsNullOrWhiteSpace(displayName))
        {
            throw new ArgumentException("Display name is required.", nameof(update));
        }

        var iconDataUrl = string.IsNullOrWhiteSpace(next.User.IconDataUrl) ? null : next.User.IconDataUrl.Trim();
        var riichiVoiceId = next.User.RiichiVoiceId;
        var isHidden = next.User.IsHidden;

        using var updateCommand = connection.CreateCommand();
        updateCommand.Transaction = transaction;
        updateCommand.CommandText = """
                                    UPDATE users
                                    SET display_name = @displayName,
                                        icon_data_url = @iconDataUrl,
                                        riichi_voice_id = @riichiVoiceId,
                                        is_hidden = @isHidden
                                    WHERE user_id = @userId;
                                    """;
        updateCommand.Parameters.AddWithValue("displayName", displayName);
        updateCommand.Parameters.Add(new NpgsqlParameter("iconDataUrl", NpgsqlDbType.Text) { Value = (object?)iconDataUrl ?? DBNull.Value });
        updateCommand.Parameters.AddWithValue("riichiVoiceId", riichiVoiceId);
        updateCommand.Parameters.AddWithValue("isHidden", isHidden);
        updateCommand.Parameters.AddWithValue("userId", id.Value);

        var affected = updateCommand.ExecuteNonQuery();
        if (affected != 1)
        {
            return false;
        }

        transaction.Commit();

        updated = new UserSnapshot
        {
            User = new UserProfile
            {
                UserId = id,
                DisplayName = displayName,
                IconDataUrl = iconDataUrl,
                RiichiVoiceId = riichiVoiceId,
                IsHidden = isHidden,
            },
        };
        return true;
    }
}

public sealed class PostgresRoomRepository : IRoomRepository
{
    private static readonly JsonSerializerOptions JsonOptions = new();

    private readonly PostgresDatabase _database;

    private sealed record RoomHistoryEntry
    {
        public required RoomState State { get; init; }
        public required int LogsCount { get; init; }
    }

    private sealed class RoomRecord
    {
        public required string RoomId { get; init; }
        public required string JoinKey { get; init; }
        public required DateTimeOffset CreatedAt { get; init; }
        public required RoomState State { get; set; }
        public required List<RoomLogEntry> Logs { get; set; }
        public required List<RoomHistoryEntry> History { get; set; }
        public required long Seq { get; set; }
    }

    public PostgresRoomRepository(PostgresDatabase database)
    {
        _database = database;
    }

    public RoomSnapshot? Get(string roomId)
    {
        using var connection = _database.OpenConnection();
        return GetRoom(connection, null, roomId, forUpdate: false) is { } record
            ? ToSnapshot(record)
            : null;
    }

    public IReadOnlyList<RoomSnapshot> GetAll()
    {
        using var connection = _database.OpenConnection();
        using var command = connection.CreateCommand();
        command.CommandText = """
                              SELECT room_id, join_key, state_json::text, logs_json::text, history_json::text, created_at, seq
                              FROM rooms
                              ORDER BY room_id ASC;
                              """;

        using var reader = command.ExecuteReader();
        var rooms = new List<RoomSnapshot>();
        while (reader.Read())
        {
            var record = new RoomRecord
            {
                RoomId = reader.GetString(0),
                JoinKey = reader.GetString(1),
                State = Deserialize<RoomState>(reader.GetString(2), "room state"),
                Logs = Deserialize<List<RoomLogEntry>>(reader.GetString(3), "room logs"),
                History = Deserialize<List<RoomHistoryEntry>>(reader.GetString(4), "room history"),
                CreatedAt = reader.GetFieldValue<DateTimeOffset>(5),
                Seq = reader.GetInt64(6),
            };
            rooms.Add(ToSnapshot(record));
        }

        return rooms;
    }

    public void Create(RoomSnapshot snapshot)
    {
        var seq = snapshot.Logs.Count == 0 ? 0 : snapshot.Logs.Max(x => x.Seq);

        using var connection = _database.OpenConnection();
        using var command = connection.CreateCommand();
        command.CommandText = """
                              INSERT INTO rooms (room_id, join_key, state_json, logs_json, history_json, seq, created_at)
                              VALUES (@roomId, @joinKey, @stateJson, @logsJson, @historyJson, @seq, @createdAt);
                              """;
        command.Parameters.AddWithValue("roomId", snapshot.RoomId);
        command.Parameters.AddWithValue("joinKey", snapshot.JoinKey);
        command.Parameters.Add(new NpgsqlParameter("stateJson", NpgsqlDbType.Jsonb) { Value = Serialize(snapshot.State) });
        command.Parameters.Add(new NpgsqlParameter("logsJson", NpgsqlDbType.Jsonb) { Value = Serialize(snapshot.Logs) });
        command.Parameters.Add(new NpgsqlParameter("historyJson", NpgsqlDbType.Jsonb) { Value = Serialize(Array.Empty<RoomHistoryEntry>()) });
        command.Parameters.AddWithValue("seq", seq);
        command.Parameters.AddWithValue("createdAt", snapshot.CreatedAt ?? DateTimeOffset.UtcNow);

        try
        {
            command.ExecuteNonQuery();
        }
        catch (PostgresException ex) when (ex.SqlState == PostgresErrorCodes.UniqueViolation)
        {
            throw new InvalidOperationException("Room already exists.", ex);
        }
    }

    public bool TryUpdate(string roomId, string joinKey, long expectedVersion, Func<RoomSnapshot, (RoomState newState, List<RoomLogEntry> newLogs)> apply, out RoomSnapshot? updated)
    {
        updated = null;

        using var connection = _database.OpenConnection();
        using var transaction = connection.BeginTransaction(IsolationLevel.ReadCommitted);

        var record = GetRoom(connection, transaction, roomId, forUpdate: true);
        if (record is null)
        {
            return false;
        }

        if (record.JoinKey != joinKey || record.State.Version != expectedVersion)
        {
            return false;
        }

        var currentSnapshot = ToSnapshot(record);
        record.History.Add(new RoomHistoryEntry { State = record.State, LogsCount = record.Logs.Count });

        var (newState, newLogs) = apply(currentSnapshot);
        record.State = newState;
        record.Logs = newLogs.ToList();
        record.Seq = record.Logs.Count == 0 ? record.Seq : record.Logs.Max(x => x.Seq);

        SaveRoom(connection, transaction, record);
        transaction.Commit();

        updated = ToSnapshot(record);
        return true;
    }

    public bool TryUndo(string roomId, string joinKey, long expectedVersion, out RoomSnapshot? updated)
    {
        updated = null;

        using var connection = _database.OpenConnection();
        using var transaction = connection.BeginTransaction(IsolationLevel.ReadCommitted);

        var record = GetRoom(connection, transaction, roomId, forUpdate: true);
        if (record is null)
        {
            return false;
        }

        if (record.JoinKey != joinKey || record.State.Version != expectedVersion)
        {
            return false;
        }

        if (record.History.Count == 0)
        {
            record.State = record.State with { Version = record.State.Version + 1 };
        }
        else
        {
            var index = record.History.Count - 1;
            var previous = record.History[index];
            record.History.RemoveAt(index);

            record.State = previous.State with { Version = record.State.Version + 1 };
            if (record.Logs.Count > previous.LogsCount)
            {
                record.Logs.RemoveRange(previous.LogsCount, record.Logs.Count - previous.LogsCount);
            }
        }

        record.Seq += 1;
        record.Logs.Add(new RoomLogEntry
        {
            Seq = record.Seq,
            At = DateTimeOffset.UtcNow,
            Type = RoomLogType.Undo,
            Message = "Undo completed.",
        });

        SaveRoom(connection, transaction, record);
        transaction.Commit();

        updated = ToSnapshot(record);
        return true;
    }

    public bool TryDelete(string roomId, string joinKey)
    {
        using var connection = _database.OpenConnection();
        using var command = connection.CreateCommand();
        command.CommandText = """
                              DELETE FROM rooms
                              WHERE room_id = @roomId
                                AND join_key = @joinKey;
                              """;
        command.Parameters.AddWithValue("roomId", roomId);
        command.Parameters.AddWithValue("joinKey", joinKey);

        return command.ExecuteNonQuery() == 1;
    }

    private static RoomRecord? GetRoom(NpgsqlConnection connection, NpgsqlTransaction? transaction, string roomId, bool forUpdate)
    {
        using var command = connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = forUpdate
            ? """
              SELECT room_id, join_key, state_json::text, logs_json::text, history_json::text, created_at, seq
              FROM rooms
              WHERE room_id = @roomId
              FOR UPDATE;
              """
            : """
              SELECT room_id, join_key, state_json::text, logs_json::text, history_json::text, created_at, seq
              FROM rooms
              WHERE room_id = @roomId;
              """;
        command.Parameters.AddWithValue("roomId", roomId);

        using var reader = command.ExecuteReader();
        if (!reader.Read())
        {
            return null;
        }

        return new RoomRecord
        {
            RoomId = reader.GetString(0),
            JoinKey = reader.GetString(1),
            State = Deserialize<RoomState>(reader.GetString(2), "room state"),
            Logs = Deserialize<List<RoomLogEntry>>(reader.GetString(3), "room logs"),
            History = Deserialize<List<RoomHistoryEntry>>(reader.GetString(4), "room history"),
            CreatedAt = reader.GetFieldValue<DateTimeOffset>(5),
            Seq = reader.GetInt64(6),
        };
    }

    private static void SaveRoom(NpgsqlConnection connection, NpgsqlTransaction transaction, RoomRecord record)
    {
        using var command = connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = """
                              UPDATE rooms
                              SET state_json = @stateJson,
                                  logs_json = @logsJson,
                                  history_json = @historyJson,
                                  seq = @seq
                              WHERE room_id = @roomId;
                              """;
        command.Parameters.Add(new NpgsqlParameter("stateJson", NpgsqlDbType.Jsonb) { Value = Serialize(record.State) });
        command.Parameters.Add(new NpgsqlParameter("logsJson", NpgsqlDbType.Jsonb) { Value = Serialize(record.Logs) });
        command.Parameters.Add(new NpgsqlParameter("historyJson", NpgsqlDbType.Jsonb) { Value = Serialize(record.History) });
        command.Parameters.AddWithValue("seq", record.Seq);
        command.Parameters.AddWithValue("roomId", record.RoomId);

        var affected = command.ExecuteNonQuery();
        if (affected != 1)
        {
            throw new InvalidOperationException("Room update failed.");
        }
    }

    private static RoomSnapshot ToSnapshot(RoomRecord record)
    {
        return new RoomSnapshot
        {
            RoomId = record.RoomId,
            JoinKey = record.JoinKey,
            State = record.State,
            Logs = record.Logs.ToList(),
            CreatedAt = record.CreatedAt,
        };
    }

    private static string Serialize<T>(T value)
    {
        return JsonSerializer.Serialize(value, JsonOptions);
    }

    private static T Deserialize<T>(string json, string targetName)
    {
        var value = JsonSerializer.Deserialize<T>(json, JsonOptions);
        return value ?? throw new InvalidOperationException($"Failed to deserialize {targetName}.");
    }
}

public sealed class PostgresMatchRepository : IMatchRepository
{
    private static readonly JsonSerializerOptions JsonOptions = new();

    private readonly PostgresDatabase _database;

    public PostgresMatchRepository(PostgresDatabase database)
    {
        _database = database;
    }

    public void Create(MatchSnapshot snapshot)
    {
        using var connection = _database.OpenConnection();
        using var command = connection.CreateCommand();
        command.CommandText = """
                              INSERT INTO match_records (
                                  match_id,
                                  room_id,
                                  started_at,
                                  ended_at,
                                  participants_json,
                                  final_state_json,
                                  logs_json,
                                  source_type,
                                  deleted_at
                              )
                              VALUES (
                                  @matchId,
                                  @roomId,
                                  @startedAt,
                                  @endedAt,
                                  @participantsJson,
                                  @finalStateJson,
                                  @logsJson,
                                  @sourceType,
                                  @deletedAt
                              );
                              """;
        command.Parameters.AddWithValue("matchId", snapshot.MatchId);
        command.Parameters.AddWithValue("roomId", snapshot.RoomId);
        command.Parameters.AddWithValue("startedAt", snapshot.StartedAt);
        command.Parameters.AddWithValue("endedAt", snapshot.EndedAt);
        command.Parameters.Add(new NpgsqlParameter("participantsJson", NpgsqlDbType.Jsonb) { Value = Serialize(snapshot.Participants) });
        command.Parameters.Add(new NpgsqlParameter("finalStateJson", NpgsqlDbType.Jsonb) { Value = Serialize(snapshot.FinalState) });
        command.Parameters.Add(new NpgsqlParameter("logsJson", NpgsqlDbType.Jsonb) { Value = Serialize(snapshot.Logs) });
        command.Parameters.AddWithValue("sourceType", (int)snapshot.Source);
        command.Parameters.Add(new NpgsqlParameter("deletedAt", NpgsqlDbType.TimestampTz) { Value = (object?)snapshot.DeletedAt ?? DBNull.Value });

        try
        {
            command.ExecuteNonQuery();
        }
        catch (PostgresException ex) when (ex.SqlState == PostgresErrorCodes.UniqueViolation)
        {
            throw new InvalidOperationException("Match already exists.", ex);
        }
    }

    public MatchSnapshot? Get(Guid matchId)
    {
        using var connection = _database.OpenConnection();
        using var command = connection.CreateCommand();
        command.CommandText = """
                              SELECT match_id, room_id, started_at, ended_at,
                                     participants_json::text, final_state_json::text, logs_json::text, source_type, deleted_at
                              FROM match_records
                              WHERE match_id = @matchId
                                AND deleted_at IS NULL;
                              """;
        command.Parameters.AddWithValue("matchId", matchId);

        using var reader = command.ExecuteReader();
        return reader.Read() ? ReadMatch(reader) : null;
    }

    public IReadOnlyList<MatchSnapshot> GetAll()
    {
        using var connection = _database.OpenConnection();
        using var command = connection.CreateCommand();
        command.CommandText = """
                              SELECT match_id, room_id, started_at, ended_at,
                                     participants_json::text, final_state_json::text, logs_json::text, source_type, deleted_at
                              FROM match_records
                              WHERE deleted_at IS NULL
                              ORDER BY ended_at DESC, match_id DESC;
                              """;

        using var reader = command.ExecuteReader();
        var records = new List<MatchSnapshot>();
        while (reader.Read())
        {
            records.Add(ReadMatch(reader));
        }

        return records;
    }

    public bool TryUpdate(Guid matchId, Func<MatchSnapshot, MatchSnapshot> update, out MatchSnapshot? updated)
    {
        updated = null;

        using var connection = _database.OpenConnection();
        using var transaction = connection.BeginTransaction(IsolationLevel.ReadCommitted);

        MatchSnapshot current;
        using (var getCommand = connection.CreateCommand())
        {
            getCommand.Transaction = transaction;
            getCommand.CommandText = """
                                     SELECT match_id, room_id, started_at, ended_at,
                                            participants_json::text, final_state_json::text, logs_json::text, source_type, deleted_at
                                     FROM match_records
                                     WHERE match_id = @matchId
                                       AND deleted_at IS NULL
                                     FOR UPDATE;
                                     """;
            getCommand.Parameters.AddWithValue("matchId", matchId);

            using var reader = getCommand.ExecuteReader();
            if (!reader.Read())
            {
                return false;
            }

            current = ReadMatch(reader);
        }

        var next = update(current) with
        {
            MatchId = current.MatchId,
            RoomId = current.RoomId,
            Source = current.Source,
            DeletedAt = current.DeletedAt,
        };

        using var updateCommand = connection.CreateCommand();
        updateCommand.Transaction = transaction;
        updateCommand.CommandText = """
                                    UPDATE match_records
                                    SET started_at = @startedAt,
                                        ended_at = @endedAt,
                                        participants_json = @participantsJson,
                                        final_state_json = @finalStateJson,
                                        logs_json = @logsJson
                                    WHERE match_id = @matchId
                                      AND deleted_at IS NULL;
                                    """;
        updateCommand.Parameters.AddWithValue("startedAt", next.StartedAt);
        updateCommand.Parameters.AddWithValue("endedAt", next.EndedAt);
        updateCommand.Parameters.Add(new NpgsqlParameter("participantsJson", NpgsqlDbType.Jsonb) { Value = Serialize(next.Participants) });
        updateCommand.Parameters.Add(new NpgsqlParameter("finalStateJson", NpgsqlDbType.Jsonb) { Value = Serialize(next.FinalState) });
        updateCommand.Parameters.Add(new NpgsqlParameter("logsJson", NpgsqlDbType.Jsonb) { Value = Serialize(next.Logs) });
        updateCommand.Parameters.AddWithValue("matchId", matchId);

        if (updateCommand.ExecuteNonQuery() != 1)
        {
            return false;
        }

        transaction.Commit();
        updated = next;
        return true;
    }

    public bool TrySoftDelete(Guid matchId, DateTimeOffset deletedAt)
    {
        using var connection = _database.OpenConnection();
        using var command = connection.CreateCommand();
        command.CommandText = """
                              UPDATE match_records
                              SET deleted_at = @deletedAt
                              WHERE match_id = @matchId
                                AND deleted_at IS NULL;
                              """;
        command.Parameters.AddWithValue("matchId", matchId);
        command.Parameters.AddWithValue("deletedAt", deletedAt);
        return command.ExecuteNonQuery() == 1;
    }

    private static MatchSnapshot ReadMatch(NpgsqlDataReader reader)
    {
        return new MatchSnapshot
        {
            MatchId = reader.GetGuid(0),
            RoomId = reader.GetString(1),
            StartedAt = reader.GetFieldValue<DateTimeOffset>(2),
            EndedAt = reader.GetFieldValue<DateTimeOffset>(3),
            Participants = Deserialize<List<MatchParticipantSnapshot>>(reader.GetString(4), "match participants"),
            FinalState = Deserialize<RoomState>(reader.GetString(5), "match final state"),
            Logs = Deserialize<List<RoomLogEntry>>(reader.GetString(6), "match logs"),
            Source = (MatchRecordSource)reader.GetInt32(7),
            DeletedAt = reader.IsDBNull(8) ? null : reader.GetFieldValue<DateTimeOffset>(8),
        };
    }

    private static string Serialize<T>(T value)
    {
        return JsonSerializer.Serialize(value, JsonOptions);
    }

    private static T Deserialize<T>(string json, string targetName)
    {
        var value = JsonSerializer.Deserialize<T>(json, JsonOptions);
        return value ?? throw new InvalidOperationException($"Failed to deserialize {targetName}.");
    }
}
