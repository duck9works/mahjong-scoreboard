#nullable enable
using MahjongScore.Domain;
using MahjongScore.Server.Repository;

namespace MahjongScore.Server.UseCase;

public enum UseCaseErrorType
{
    /// <summary>
    /// Unknown error.
    /// </summary>
    Unknown = 0,

    /// <summary>
    /// Room not found.
    /// </summary>
    RoomNotFound = 1,

    /// <summary>
    /// Join key mismatch.
    /// </summary>
    JoinKeyMismatch = 2,

    /// <summary>
    /// Version mismatch.
    /// </summary>
    VersionMismatch = 3,

    /// <summary>
    /// Validation failed.
    /// </summary>
    ValidationFailed = 4,
    RecordNotFound = 5,
}

public sealed record UseCaseError
{
    public required UseCaseErrorType Type { get; init; }
    public required string Message { get; init; }
}

public sealed record UseCaseResult<T>
{
    public required bool IsSuccess { get; init; }
    public T? Value { get; init; }
    public UseCaseError? Error { get; init; }
    public RoomState? CurrentState { get; init; }

    public static UseCaseResult<T> Success(T value) => new() { IsSuccess = true, Value = value, Error = null, CurrentState = null };
    public static UseCaseResult<T> Failure(UseCaseError error, RoomState? current) => new() { IsSuccess = false, Value = default, Error = error, CurrentState = current };
}

public sealed record RegisterUserRequest { public required string DisplayName { get; init; } }
public sealed record RegisterUserResponse { public required UserProfile User { get; init; } }
public sealed record GetUsersResponse { public required IReadOnlyList<UserProfile> Users { get; init; } }
public sealed record UpdateUserRequest { public required string DisplayName { get; init; } public string? IconDataUrl { get; init; } public required int RiichiVoiceId { get; init; } public bool? IsHidden { get; init; } }
public sealed record UpdateUserResponse { public required UserProfile User { get; init; } }

public sealed record CreateRoomRequest
{
    public required string RoomName { get; init; }
    public required int InitialPoints { get; init; }
    public int PlayerCount { get; init; } = 4;
    public GameType GameType { get; init; } = GameType.Tonpu;
    public RuleConfig? Rules { get; init; }
}
public sealed record CreateRoomResponse { public required string RoomId { get; init; } public required string JoinKey { get; init; } public required RoomState State { get; init; } public required IReadOnlyList<RoomLogEntry> Logs { get; init; } }
public sealed record GetRoomResponse { public required string RoomId { get; init; } public required RoomState State { get; init; } public required IReadOnlyList<RoomLogEntry> Logs { get; init; } }
public sealed record RoomSummaryResponse { public required string RoomId { get; init; } public required string RoomName { get; init; } public required string JoinKey { get; init; } public required bool IsFinished { get; init; } public DateTimeOffset? CreatedAt { get; init; } }
public sealed record GetRoomsResponse { public required IReadOnlyList<RoomSummaryResponse> Rooms { get; init; } }
public sealed record CloseRoomResponse { public required string RoomId { get; init; } }

public sealed record SetSeatResponse { public required RoomState State { get; init; } public required IReadOnlyList<RoomLogEntry> Logs { get; init; } }
public sealed record SetSeatsResponse { public required RoomState State { get; init; } public required IReadOnlyList<RoomLogEntry> Logs { get; init; } }
public sealed record GameTypeResponse { public required RoomState State { get; init; } public required IReadOnlyList<RoomLogEntry> Logs { get; init; } }
public sealed record EditScoresResponse { public required RoomState State { get; init; } public required IReadOnlyList<RoomLogEntry> Logs { get; init; } }
public sealed record RiichiResponse { public required RoomState State { get; init; } public required IReadOnlyList<RoomLogEntry> Logs { get; init; } }
public sealed record FuroResponse { public required RoomState State { get; init; } public required IReadOnlyList<RoomLogEntry> Logs { get; init; } }
public sealed record AgariResponse { public required RoomState State { get; init; } public required PaymentBreakdown Breakdown { get; init; } public required IReadOnlyList<RoomLogEntry> Logs { get; init; } }
public sealed record RyukyokuResponse { public required RoomState State { get; init; } public required IReadOnlyList<RoomLogEntry> Logs { get; init; } }
public sealed record UndoResponse { public required RoomState State { get; init; } public required IReadOnlyList<RoomLogEntry> Logs { get; init; } }
public sealed record RematchResponse { public required RoomState State { get; init; } public required IReadOnlyList<RoomLogEntry> Logs { get; init; } }
public sealed record MatchParticipantResponse { public required Seat Seat { get; init; } public required UserId? UserId { get; init; } public required int FinalPoints { get; init; } }
public sealed record MatchRecordResponse { public required Guid MatchId { get; init; } public required string RoomId { get; init; } public required DateTimeOffset StartedAt { get; init; } public required DateTimeOffset EndedAt { get; init; } public required IReadOnlyList<MatchParticipantResponse> Participants { get; init; } public required RoomState FinalState { get; init; } public required IReadOnlyList<RoomLogEntry> Logs { get; init; } }
public sealed record ManualRecordParticipantInput { public required Seat Seat { get; init; } public required UserId? UserId { get; init; } public required int FinalPoints { get; init; } }
public sealed record CreateManualRecordRequest { public required GameType GameType { get; init; } public required IReadOnlyList<ManualRecordParticipantInput> Participants { get; init; } public DateTimeOffset? StartedAt { get; init; } public DateTimeOffset? EndedAt { get; init; } }
public sealed record FinalizeRecordResponse { public required MatchRecordResponse Record { get; init; } }
public sealed record CreateManualRecordResponse { public required MatchRecordResponse Record { get; init; } }
public sealed record UpdateRecordResponse { public required MatchRecordResponse Record { get; init; } }
public sealed record GetRecordsResponse { public required IReadOnlyList<MatchRecordResponse> Records { get; init; } }
public sealed record GetRecordResponse { public required MatchRecordResponse Record { get; init; } }
public sealed record DeleteRecordResponse { public required Guid MatchId { get; init; } }

public sealed class UserUseCases
{
    private const int MaxIconBytes = 2 * 1024 * 1024;

    private readonly IUserRepository _users;

    public UserUseCases(IUserRepository users)
    {
        _users = users;
    }

    public UseCaseResult<RegisterUserResponse> Register(RegisterUserRequest request)
    {
        try
        {
            var snap = _users.Create(request.DisplayName);
            return UseCaseResult<RegisterUserResponse>.Success(new RegisterUserResponse { User = snap.User });
        }
        catch (Exception ex)
        {
            return UseCaseResult<RegisterUserResponse>.Failure(new UseCaseError { Type = UseCaseErrorType.ValidationFailed, Message = ex.Message }, null);
        }
    }

    public UseCaseResult<GetUsersResponse> GetAll()
    {
        return UseCaseResult<GetUsersResponse>.Success(new GetUsersResponse { Users = _users.GetAll().Select(x => x.User).ToList() });
    }

    public UseCaseResult<UpdateUserResponse> Update(string userId, UpdateUserRequest request)
    {
        if (!Guid.TryParse(userId, out var guid))
        {
            return UseCaseResult<UpdateUserResponse>.Failure(
                new UseCaseError { Type = UseCaseErrorType.ValidationFailed, Message = "User ID is invalid." },
                null
            );
        }

        var name = request.DisplayName.Trim();
        if (string.IsNullOrWhiteSpace(name))
        {
            return UseCaseResult<UpdateUserResponse>.Failure(
                new UseCaseError { Type = UseCaseErrorType.ValidationFailed, Message = "Display name is required." },
                null
            );
        }

        if (request.RiichiVoiceId is < 0 or > 7)
        {
            return UseCaseResult<UpdateUserResponse>.Failure(
                new UseCaseError { Type = UseCaseErrorType.ValidationFailed, Message = "Riichi voice ID is invalid." },
                null
            );
        }

        if (!TryNormalizeIconDataUrl(request.IconDataUrl, out var iconDataUrl, out var iconError))
        {
            return UseCaseResult<UpdateUserResponse>.Failure(
                new UseCaseError
                {
                    Type = UseCaseErrorType.ValidationFailed,
                    Message = iconError ?? "iconDataUrl is invalid.",
                },
                null
            );
        }

        var id = new UserId(guid);

        if (!_users.TryUpdate(id, snap => snap with
            {
                User = snap.User with
                {
                    DisplayName = name,
                    IconDataUrl = iconDataUrl,
                    RiichiVoiceId = request.RiichiVoiceId,
                    IsHidden = request.IsHidden ?? snap.User.IsHidden,
                },
            },
            out var updated) || updated is null)
        {
            return UseCaseResult<UpdateUserResponse>.Failure(
                new UseCaseError { Type = UseCaseErrorType.ValidationFailed, Message = "User not found." },
                null
            );
        }

        return UseCaseResult<UpdateUserResponse>.Success(new UpdateUserResponse { User = updated.User });
    }

    private static bool TryNormalizeIconDataUrl(string? source, out string? normalized, out string? error)
    {
        normalized = null;
        error = null;

        if (string.IsNullOrWhiteSpace(source))
        {
            return true;
        }

        var value = source.Trim();
        if (!value.StartsWith("data:image/", StringComparison.OrdinalIgnoreCase))
        {
            error = "iconDataUrl must be data:image/* URL.";
            return false;
        }

        var commaIndex = value.IndexOf(',');
        if (commaIndex <= 0 || commaIndex == value.Length - 1)
        {
            error = "iconDataUrl format is invalid.";
            return false;
        }

        var header = value[..commaIndex];
        var payload = value[(commaIndex + 1)..];
        if (!header.Contains(";base64", StringComparison.OrdinalIgnoreCase))
        {
            error = "iconDataUrl must be base64 encoded.";
            return false;
        }

        try
        {
            var bytes = Convert.FromBase64String(payload);
            if (bytes.Length > MaxIconBytes)
            {
                error = $"iconDataUrl must be <= {MaxIconBytes} bytes.";
                return false;
            }
        }
        catch (FormatException)
        {
            error = "iconDataUrl base64 payload is invalid.";
            return false;
        }

        normalized = value;
        return true;
    }
}

public sealed class RoomUseCases
{
    private readonly IRoomRepository _rooms;
    private readonly IUserRepository _users;
    private readonly IMatchRepository _matches;
    private readonly MahjongScoreService _score;

    public RoomUseCases(IRoomRepository rooms, IUserRepository users, IMatchRepository matches, MahjongScoreService score)
    {
        _rooms = rooms;
        _users = users;
        _matches = matches;
        _score = score;
    }

    public UseCaseResult<CreateRoomResponse> Create(CreateRoomRequest request)
    {
        var roomName = request.RoomName?.Trim() ?? string.Empty;
        if (string.IsNullOrWhiteSpace(roomName))
        {
            return UseCaseResult<CreateRoomResponse>.Failure(
                new UseCaseError { Type = UseCaseErrorType.ValidationFailed, Message = "RoomName is required." },
                null
            );
        }

        if (_rooms.GetAll().Any(x =>
                string.Equals(
                    x.State.RoomName?.Trim(),
                    roomName,
                    StringComparison.OrdinalIgnoreCase)))
        {
            return UseCaseResult<CreateRoomResponse>.Failure(
                new UseCaseError { Type = UseCaseErrorType.ValidationFailed, Message = "Room name already exists." },
                null
            );
        }

        if (request.InitialPoints <= 0)
        {
            return UseCaseResult<CreateRoomResponse>.Failure(new UseCaseError { Type = UseCaseErrorType.ValidationFailed, Message = "Initial points must be greater than 0." }, null);
        }

        if (!Enum.IsDefined(request.GameType))
        {
            return UseCaseResult<CreateRoomResponse>.Failure(
                new UseCaseError { Type = UseCaseErrorType.ValidationFailed, Message = "GameType is invalid." },
                null
            );
        }

        if (request.PlayerCount is not (3 or 4))
        {
            return UseCaseResult<CreateRoomResponse>.Failure(
                new UseCaseError { Type = UseCaseErrorType.ValidationFailed, Message = "PlayerCount must be 3 or 4." },
                null
            );
        }

        var rules = request.Rules ?? new RuleConfig();

        var roomId = Guid.NewGuid().ToString("N")[..6].ToUpperInvariant();
        var joinKey = Convert.ToBase64String(Guid.NewGuid().ToByteArray()).Replace("+", "-").Replace("/", "_").TrimEnd('=');

        var seats = CreateInitialSeats(request.InitialPoints, request.PlayerCount);

        var state = new RoomState
        {
            RoomName = roomName,
            InitialPoints = request.InitialPoints,
            Seats = seats,
            DealerSeat = Seat.East,
            RoundWind = RoundWind.East,
            Kyoku = 1,
            Honba = 0,
            Renchan = 0,
            Kyotaku = 0,
            GameType = request.GameType,
            PlayerCount = request.PlayerCount,
            Rules = rules,
            IsFinished = false,
            Version = 1,
        };

        var logs = new List<RoomLogEntry>
        {
            new RoomLogEntry { Seq = 1, At = DateTimeOffset.UtcNow, Type = RoomLogType.SeatAssignment, Message = $"ルームを作成しました: {roomName}" },
        };

        _rooms.Create(new RoomSnapshot { RoomId = roomId, JoinKey = joinKey, State = state, Logs = logs });

        return UseCaseResult<CreateRoomResponse>.Success(new CreateRoomResponse { RoomId = roomId, JoinKey = joinKey, State = state, Logs = logs });
    }

    public UseCaseResult<GetRoomResponse> Get(string roomId, string joinKey)
    {
        var snap = _rooms.Get(roomId);
        if (snap is null)
        {
            return UseCaseResult<GetRoomResponse>.Failure(new UseCaseError { Type = UseCaseErrorType.RoomNotFound, Message = "Room not found." }, null);
        }
        if (snap.JoinKey != joinKey)
        {
            return UseCaseResult<GetRoomResponse>.Failure(new UseCaseError { Type = UseCaseErrorType.JoinKeyMismatch, Message = "Join key mismatch." }, null);
        }

        return UseCaseResult<GetRoomResponse>.Success(new GetRoomResponse { RoomId = snap.RoomId, State = snap.State, Logs = snap.Logs });
    }

    public UseCaseResult<GetRoomsResponse> GetRooms()
    {
        var rooms = _rooms.GetAll()
            .Select(x => new RoomSummaryResponse
            {
                RoomId = x.RoomId,
                RoomName = string.IsNullOrWhiteSpace(x.State.RoomName)
                    ? "未設定ルーム"
                    : x.State.RoomName.Trim(),
                JoinKey = x.JoinKey,
                IsFinished = x.State.IsFinished,
                CreatedAt = x.CreatedAt,
            })
            .OrderBy(x => x.RoomName, StringComparer.OrdinalIgnoreCase)
            .ThenBy(x => x.RoomId, StringComparer.OrdinalIgnoreCase)
            .ToList();

        return UseCaseResult<GetRoomsResponse>.Success(new GetRoomsResponse
        {
            Rooms = rooms,
        });
    }

    public UseCaseResult<CloseRoomResponse> CloseRoom(string roomId, string joinKey)
    {
        var snap = _rooms.Get(roomId);
        if (snap is null)
        {
            return UseCaseResult<CloseRoomResponse>.Failure(
                new UseCaseError { Type = UseCaseErrorType.RoomNotFound, Message = "Room not found." },
                null
            );
        }

        if (snap.JoinKey != joinKey)
        {
            return UseCaseResult<CloseRoomResponse>.Failure(
                new UseCaseError { Type = UseCaseErrorType.JoinKeyMismatch, Message = "Join key mismatch." },
                null
            );
        }

        if (!_rooms.TryDelete(roomId, joinKey))
        {
            var current = _rooms.Get(roomId);
            if (current is null)
            {
                return UseCaseResult<CloseRoomResponse>.Failure(
                    new UseCaseError { Type = UseCaseErrorType.RoomNotFound, Message = "Room not found." },
                    null
                );
            }

            return UseCaseResult<CloseRoomResponse>.Failure(
                new UseCaseError { Type = UseCaseErrorType.JoinKeyMismatch, Message = "Join key mismatch." },
                current.State
            );
        }

        return UseCaseResult<CloseRoomResponse>.Success(new CloseRoomResponse { RoomId = roomId });
    }

    public UseCaseResult<FinalizeRecordResponse> FinalizeRecord(string roomId, string joinKey)
    {
        var snap = _rooms.Get(roomId);
        if (snap is null)
        {
            return UseCaseResult<FinalizeRecordResponse>.Failure(
                new UseCaseError { Type = UseCaseErrorType.RoomNotFound, Message = "Room not found." },
                null
            );
        }

        if (snap.JoinKey != joinKey)
        {
            return UseCaseResult<FinalizeRecordResponse>.Failure(
                new UseCaseError { Type = UseCaseErrorType.JoinKeyMismatch, Message = "Join key mismatch." },
                null
            );
        }
        if (!snap.State.IsFinished)
        {
            return UseCaseResult<FinalizeRecordResponse>.Failure(
                new UseCaseError { Type = UseCaseErrorType.ValidationFailed, Message = "Match is not finished yet." },
                snap.State
            );
        }

        var endedAt = DateTimeOffset.UtcNow;
        var startedAt = snap.Logs.Count == 0 ? endedAt : snap.Logs.Min(x => x.At);
        var participants = snap.State.Seats
            .Select(x => new MatchParticipantSnapshot
            {
                Seat = x.Seat,
                UserId = x.AssignedUserId,
                FinalPoints = x.Points,
            })
            .ToList();

        var record = new MatchSnapshot
        {
            MatchId = Guid.NewGuid(),
            RoomId = roomId,
            StartedAt = startedAt,
            EndedAt = endedAt,
            Participants = participants,
            FinalState = snap.State,
            Logs = snap.Logs.ToList(),
            Source = MatchRecordSource.Progress,
            DeletedAt = null,
        };

        _matches.Create(record);
        return UseCaseResult<FinalizeRecordResponse>.Success(
            new FinalizeRecordResponse { Record = ToRecordResponse(record) }
        );
    }

    public UseCaseResult<CreateManualRecordResponse> CreateManualRecord(CreateManualRecordRequest request)
    {
        if (!TryValidateRecordInput(
                request,
                out var participantsBySeat,
                out var playerCount,
                out var startedAt,
                out var endedAt,
                out var validationError))
        {
            return UseCaseResult<CreateManualRecordResponse>.Failure(
                validationError!,
                null
            );
        }

        var participants = BuildMatchParticipants(participantsBySeat);

        var finalState = BuildManualFinalState(request.GameType, playerCount, participantsBySeat);
        var record = new MatchSnapshot
        {
            MatchId = Guid.NewGuid(),
            RoomId = "MANUAL",
            StartedAt = startedAt,
            EndedAt = endedAt,
            Participants = participants,
            FinalState = finalState,
            Logs = Array.Empty<RoomLogEntry>(),
            Source = MatchRecordSource.Manual,
            DeletedAt = null,
        };

        _matches.Create(record);
        return UseCaseResult<CreateManualRecordResponse>.Success(new CreateManualRecordResponse
        {
            Record = ToRecordResponse(record),
        });
    }

    public UseCaseResult<UpdateRecordResponse> UpdateRecord(string recordId, CreateManualRecordRequest request)
    {
        if (!Guid.TryParse(recordId, out var guid))
        {
            return UseCaseResult<UpdateRecordResponse>.Failure(
                new UseCaseError { Type = UseCaseErrorType.ValidationFailed, Message = "recordId is invalid." },
                null
            );
        }

        var currentRecord = _matches.Get(guid);
        if (currentRecord is null)
        {
            return UseCaseResult<UpdateRecordResponse>.Failure(
                new UseCaseError { Type = UseCaseErrorType.RecordNotFound, Message = "Record not found." },
                null
            );
        }

        if (!TryValidateRecordInput(
                request,
                out var participantsBySeat,
                out var playerCount,
                out var startedAt,
                out var endedAt,
                out var validationError,
                defaultStartedAt: currentRecord.StartedAt))
        {
            return UseCaseResult<UpdateRecordResponse>.Failure(
                validationError!,
                null
            );
        }

        var participants = BuildMatchParticipants(participantsBySeat);
        if (!_matches.TryUpdate(guid, current =>
        {
            var finalState = BuildUpdatedFinalState(current.FinalState, request.GameType, playerCount, participantsBySeat);
            return current with
            {
                StartedAt = startedAt,
                EndedAt = endedAt,
                Participants = participants,
                FinalState = finalState,
            };
        }, out var updated) || updated is null)
        {
            return UseCaseResult<UpdateRecordResponse>.Failure(
                new UseCaseError { Type = UseCaseErrorType.RecordNotFound, Message = "Record not found." },
                null
            );
        }

        return UseCaseResult<UpdateRecordResponse>.Success(new UpdateRecordResponse
        {
            Record = ToRecordResponse(updated),
        });
    }

    public UseCaseResult<GetRecordsResponse> GetRecords()
    {
        var records = _matches.GetAll().Select(ToRecordResponse).ToList();
        return UseCaseResult<GetRecordsResponse>.Success(new GetRecordsResponse { Records = records });
    }

    public UseCaseResult<GetRecordResponse> GetRecord(string recordId)
    {
        if (!Guid.TryParse(recordId, out var guid))
        {
            return UseCaseResult<GetRecordResponse>.Failure(
                new UseCaseError { Type = UseCaseErrorType.ValidationFailed, Message = "recordId is invalid." },
                null
            );
        }

        var record = _matches.Get(guid);
        if (record is null)
        {
            return UseCaseResult<GetRecordResponse>.Failure(
                new UseCaseError { Type = UseCaseErrorType.RecordNotFound, Message = "Record not found." },
                null
            );
        }

        return UseCaseResult<GetRecordResponse>.Success(new GetRecordResponse { Record = ToRecordResponse(record) });
    }

    public UseCaseResult<DeleteRecordResponse> DeleteRecord(string recordId)
    {
        if (!Guid.TryParse(recordId, out var guid))
        {
            return UseCaseResult<DeleteRecordResponse>.Failure(
                new UseCaseError { Type = UseCaseErrorType.ValidationFailed, Message = "recordId is invalid." },
                null
            );
        }

        if (!_matches.TrySoftDelete(guid, DateTimeOffset.UtcNow))
        {
            return UseCaseResult<DeleteRecordResponse>.Failure(
                new UseCaseError { Type = UseCaseErrorType.RecordNotFound, Message = "Record not found." },
                null
            );
        }

        return UseCaseResult<DeleteRecordResponse>.Success(new DeleteRecordResponse
        {
            MatchId = guid,
        });
    }

    public UseCaseResult<SetSeatResponse> SetSeat(string roomId, string joinKey, SeatAssignmentInput input)
    {
        try
        {
            if (input.UserId is not null)
            {
                var user = _users.Get(input.UserId.Value);
                if (user is null)
                {
                    return UseCaseResult<SetSeatResponse>.Failure(new UseCaseError { Type = UseCaseErrorType.ValidationFailed, Message = "User not found." }, null);
                }
                if (user.User.IsHidden)
                {
                    return UseCaseResult<SetSeatResponse>.Failure(new UseCaseError { Type = UseCaseErrorType.ValidationFailed, Message = "Hidden user cannot be assigned." }, null);
                }
            }

            if (!_rooms.TryUpdate(roomId, joinKey, input.ExpectedVersion, snap =>
            {
                var activeSeats = ActiveSeatsFromState(snap.State);
                if (!activeSeats.Contains(input.Seat))
                {
                    throw new ArgumentException("Seat is invalid.");
                }

                var logs = snap.Logs.ToList();
                var seq = logs.Count == 0 ? 1 : logs.Max(x => x.Seq) + 1;

                var newSeats = snap.State.Seats
                    .Select(s => s.Seat == input.Seat ? s with { AssignedUserId = input.UserId } : s)
                    .ToList();
                var newState = snap.State with { Seats = newSeats, Version = snap.State.Version + 1 };

                var msg = input.UserId is null
                    ? $"{ToJp(input.Seat)}: cleared"
                    : $"{ToJp(input.Seat)}: assigned";
                logs.Add(new RoomLogEntry { Seq = seq, At = DateTimeOffset.UtcNow, Type = RoomLogType.SeatAssignment, Message = msg });

                return (newState, logs);
            }, out var updated) || updated is null)
            {
                var current = _rooms.Get(roomId);
                return UseCaseResult<SetSeatResponse>.Failure(
                    new UseCaseError { Type = UseCaseErrorType.VersionMismatch, Message = "Version mismatch." },
                    current?.State
                );
            }

            return UseCaseResult<SetSeatResponse>.Success(new SetSeatResponse { State = updated.State, Logs = updated.Logs });
        }
        catch (Exception ex) when (ex is InvalidOperationException or ArgumentException)
        {
            var current = _rooms.Get(roomId);
            return UseCaseResult<SetSeatResponse>.Failure(
                new UseCaseError { Type = UseCaseErrorType.ValidationFailed, Message = ex.Message },
                current?.State
            );
        }
    }

    public UseCaseResult<SetSeatsResponse> SetSeats(string roomId, string joinKey, SeatAssignmentsInput input)
    {
        try
        {
            if (input.Assignments is null || input.Assignments.Count == 0)
            {
                return UseCaseResult<SetSeatsResponse>.Failure(
                    new UseCaseError { Type = UseCaseErrorType.ValidationFailed, Message = "Assignments are required." },
                    null
                );
            }
            if (input.Assignments.Count > 4)
            {
                return UseCaseResult<SetSeatsResponse>.Failure(
                    new UseCaseError { Type = UseCaseErrorType.ValidationFailed, Message = "Assignments must be <= 4." },
                    null
                );
            }

            var assignmentsBySeat = new Dictionary<Seat, UserId?>();
            foreach (var assignment in input.Assignments)
            {
                if (!Enum.IsDefined(assignment.Seat))
                {
                    return UseCaseResult<SetSeatsResponse>.Failure(
                        new UseCaseError { Type = UseCaseErrorType.ValidationFailed, Message = "Seat is invalid." },
                        null
                    );
                }
                if (!assignmentsBySeat.TryAdd(assignment.Seat, assignment.UserId))
                {
                    return UseCaseResult<SetSeatsResponse>.Failure(
                        new UseCaseError { Type = UseCaseErrorType.ValidationFailed, Message = "Seat is duplicated." },
                        null
                    );
                }
                if (assignment.UserId is not null)
                {
                    var user = _users.Get(assignment.UserId.Value);
                    if (user is null)
                    {
                        return UseCaseResult<SetSeatsResponse>.Failure(
                            new UseCaseError { Type = UseCaseErrorType.ValidationFailed, Message = "User not found." },
                            null
                        );
                    }
                    if (user.User.IsHidden)
                    {
                        return UseCaseResult<SetSeatsResponse>.Failure(
                            new UseCaseError { Type = UseCaseErrorType.ValidationFailed, Message = "Hidden user cannot be assigned." },
                            null
                        );
                    }
                }
            }

            if (!_rooms.TryUpdate(roomId, joinKey, input.ExpectedVersion, snap =>
            {
                var activeSeats = ActiveSeatsFromState(snap.State);
                foreach (var seat in assignmentsBySeat.Keys)
                {
                    if (!activeSeats.Contains(seat))
                    {
                        throw new ArgumentException("Seat is invalid.");
                    }
                }

                var logs = snap.Logs.ToList();
                var seq = logs.Count == 0 ? 1 : logs.Max(x => x.Seq) + 1;

                var newSeats = snap.State.Seats.Select(s =>
                {
                    if (assignmentsBySeat.TryGetValue(s.Seat, out var userId))
                    {
                        return s with { AssignedUserId = userId };
                    }
                    return s;
                }).ToList();

                var newState = snap.State with
                {
                    Seats = newSeats,
                    Version = snap.State.Version + 1,
                };

                foreach (var pair in assignmentsBySeat.OrderBy(x => x.Key))
                {
                    var msg = pair.Value is null
                        ? $"{ToJp(pair.Key)}: cleared"
                        : $"{ToJp(pair.Key)}: assigned";
                    logs.Add(new RoomLogEntry
                    {
                        Seq = seq++,
                        At = DateTimeOffset.UtcNow,
                        Type = RoomLogType.SeatAssignment,
                        Message = msg,
                    });
                }

                return (newState, logs);
            }, out var updated) || updated is null)
            {
                var current = _rooms.Get(roomId);
                return UseCaseResult<SetSeatsResponse>.Failure(
                    new UseCaseError { Type = UseCaseErrorType.VersionMismatch, Message = "Version mismatch." },
                    current?.State
                );
            }

            return UseCaseResult<SetSeatsResponse>.Success(new SetSeatsResponse
            {
                State = updated.State,
                Logs = updated.Logs,
            });
        }
        catch (Exception ex) when (ex is InvalidOperationException or ArgumentException)
        {
            var current = _rooms.Get(roomId);
            return UseCaseResult<SetSeatsResponse>.Failure(
                new UseCaseError { Type = UseCaseErrorType.ValidationFailed, Message = ex.Message },
                current?.State
            );
        }
    }

    public UseCaseResult<GameTypeResponse> SetGameType(string roomId, string joinKey, GameTypeInput input)
    {
        if (!Enum.IsDefined(input.GameType))
        {
            return UseCaseResult<GameTypeResponse>.Failure(
                new UseCaseError { Type = UseCaseErrorType.ValidationFailed, Message = "GameType is invalid." },
                null
            );
        }

        try
        {
            if (!_rooms.TryUpdate(roomId, joinKey, input.ExpectedVersion, snap =>
            {
                var maxKyoku = MaxKyokuForPlayerCount(ActiveSeatsFromState(snap.State).Count);
                var canResumeIntoSouthRound = snap.State.IsFinished &&
                    snap.State.GameType == GameType.Tonpu &&
                    input.GameType == GameType.Hanchan &&
                    snap.State.RoundWind == RoundWind.East &&
                    snap.State.Kyoku == maxKyoku;

                if (snap.State.IsFinished && !canResumeIntoSouthRound)
                {
                    throw new InvalidOperationException("Match already finished.");
                }
                if (snap.State.RoundWind == RoundWind.South && input.GameType == GameType.Tonpu)
                {
                    throw new InvalidOperationException("Cannot switch to Tonpu after South round started.");
                }

                var logs = snap.Logs.ToList();
                var seq = logs.Count == 0 ? 1 : logs.Max(x => x.Seq) + 1;

                var newState = snap.State with
                {
                    GameType = input.GameType,
                    RoundWind = canResumeIntoSouthRound ? RoundWind.South : snap.State.RoundWind,
                    Kyoku = canResumeIntoSouthRound ? 1 : snap.State.Kyoku,
                    IsFinished = canResumeIntoSouthRound ? false : snap.State.IsFinished,
                    Version = snap.State.Version + 1,
                };

                logs.Add(new RoomLogEntry
                {
                    Seq = seq,
                    At = DateTimeOffset.UtcNow,
                    Type = RoomLogType.GameTypeChange,
                    Message = $"GameType: {ToJp(input.GameType)}",
                });

                return (newState, logs);
            }, out var updated) || updated is null)
            {
                var current = _rooms.Get(roomId);
                return UseCaseResult<GameTypeResponse>.Failure(
                    new UseCaseError { Type = UseCaseErrorType.VersionMismatch, Message = "Version mismatch." },
                    current?.State
                );
            }

            return UseCaseResult<GameTypeResponse>.Success(new GameTypeResponse
            {
                State = updated.State,
                Logs = updated.Logs,
            });
        }
        catch (Exception ex) when (ex is InvalidOperationException or ArgumentException)
        {
            var current = _rooms.Get(roomId);
            return UseCaseResult<GameTypeResponse>.Failure(
                new UseCaseError { Type = UseCaseErrorType.ValidationFailed, Message = ex.Message },
                current?.State
            );
        }
    }

    public UseCaseResult<RyukyokuResponse> Ryukyoku(string roomId, string joinKey, RyukyokuInput input)
    {
        try
        {
            if (!_rooms.TryUpdate(roomId, joinKey, input.ExpectedVersion, snap =>
            {
                var next = _score.ApplyRyukyoku(snap.State, input);
                var logs = snap.Logs.ToList();
                var seq = logs.Count == 0 ? 1 : logs.Max(x => x.Seq) + 1;

                var tenpaiSeats = input.TenpaiSeats
                    .Distinct()
                    .OrderBy(x => x)
                    .Select(ToJp)
                    .ToList();
                var tenpaiText = tenpaiSeats.Count == 0
                    ? "none"
                    : string.Join(",", tenpaiSeats);

                logs.Add(new RoomLogEntry
                {
                    Seq = seq,
                    At = DateTimeOffset.UtcNow,
                    Type = RoomLogType.Ryukyoku,
                    Message = $"Ryukyoku (tenpai: {tenpaiText})",
                });

                return (next, logs);
            }, out var updated) || updated is null)
            {
                var current = _rooms.Get(roomId);
                return UseCaseResult<RyukyokuResponse>.Failure(
                    new UseCaseError { Type = UseCaseErrorType.VersionMismatch, Message = "Version mismatch." },
                    current?.State
                );
            }

            return UseCaseResult<RyukyokuResponse>.Success(new RyukyokuResponse
            {
                State = updated.State,
                Logs = updated.Logs,
            });
        }
        catch (Exception ex) when (ex is InvalidOperationException or ArgumentException)
        {
            var current = _rooms.Get(roomId);
            return UseCaseResult<RyukyokuResponse>.Failure(
                new UseCaseError { Type = UseCaseErrorType.ValidationFailed, Message = ex.Message },
                current?.State
            );
        }
    }

    public UseCaseResult<EditScoresResponse> EditScores(string roomId, string joinKey, ScoreEditInput input)
    {
        try
        {
            var pointsBySeat = new Dictionary<Seat, int>();
            foreach (var e in input.Seats)
            {
                if (!pointsBySeat.TryAdd(e.Seat, e.Points))
                {
                    return UseCaseResult<EditScoresResponse>.Failure(
                        new UseCaseError { Type = UseCaseErrorType.ValidationFailed, Message = "Seat is duplicated." },
                        null
                    );
                }
            }

            if (!_rooms.TryUpdate(roomId, joinKey, input.ExpectedVersion, snap =>
            {
                var activeSeats = ActiveSeatsFromState(snap.State);
                if (pointsBySeat.Count != activeSeats.Count)
                {
                    throw new ArgumentException($"Exactly {activeSeats.Count} seat scores are required.");
                }

                foreach (var seat in activeSeats)
                {
                    if (!pointsBySeat.ContainsKey(seat))
                    {
                        throw new ArgumentException($"Scores for {string.Join(", ", activeSeats.Select(ToJp))} are required.");
                    }
                }

                foreach (var seat in pointsBySeat.Keys)
                {
                    if (!activeSeats.Contains(seat))
                    {
                        throw new ArgumentException("Seat is invalid.");
                    }
                }

                var logs = snap.Logs.ToList();
                var seq = logs.Count == 0 ? 1 : logs.Max(x => x.Seq) + 1;

                var newSeats = snap.State.Seats.Select(s =>
                {
                    if (!pointsBySeat.TryGetValue(s.Seat, out var p))
                    {
                        return s;
                    }
                    return s with { Points = p };
                }).ToList();

                var newState = snap.State with { Seats = newSeats, Version = snap.State.Version + 1 };

                var scoreText = string.Join(" / ", activeSeats.Select(seat => $"{ToJp(seat)} {pointsBySeat[seat]}"));
                logs.Add(new RoomLogEntry
                {
                    Seq = seq,
                    At = DateTimeOffset.UtcNow,
                    Type = RoomLogType.ScoreEdit,
                    Message = $"点数修正: {scoreText}",
                });

                return (newState, logs);
            }, out var updated) || updated is null)
            {
                var current = _rooms.Get(roomId);
                return UseCaseResult<EditScoresResponse>.Failure(
                    new UseCaseError { Type = UseCaseErrorType.VersionMismatch, Message = "Version mismatch." },
                    current?.State
                );
            }

            return UseCaseResult<EditScoresResponse>.Success(new EditScoresResponse { State = updated.State, Logs = updated.Logs });
        }
        catch (Exception ex) when (ex is InvalidOperationException or ArgumentException)
        {
            var current = _rooms.Get(roomId);
            return UseCaseResult<EditScoresResponse>.Failure(
                new UseCaseError { Type = UseCaseErrorType.ValidationFailed, Message = ex.Message },
                current?.State
            );
        }
    }

    public UseCaseResult<RiichiResponse> Riichi(string roomId, string joinKey, RiichiInput input)
    {
        try
        {
            if (!_rooms.TryUpdate(roomId, joinKey, input.ExpectedVersion, snap =>
            {
                var next = _score.ApplyRiichi(snap.State, input);

                var logs = snap.Logs.ToList();
                var seq = logs.Count == 0 ? 1 : logs.Max(x => x.Seq) + 1;
                logs.Add(new RoomLogEntry
                {
                    Seq = seq,
                    At = DateTimeOffset.UtcNow,
                    Type = RoomLogType.Riichi,
                    Message = $"{ToJp(input.Seat)}がリーチ",
                    ActorSeat = input.Seat,
                });

                return (next, logs);
            }, out var updated) || updated is null)
            {
                var current = _rooms.Get(roomId);
                return UseCaseResult<RiichiResponse>.Failure(
                    new UseCaseError { Type = UseCaseErrorType.VersionMismatch, Message = "更新競合が発生しました" },
                    current?.State
                );
            }

            return UseCaseResult<RiichiResponse>.Success(new RiichiResponse { State = updated.State, Logs = updated.Logs });
        }
        catch (Exception ex) when (ex is InvalidOperationException or ArgumentException)
        {
            var current = _rooms.Get(roomId);
            return UseCaseResult<RiichiResponse>.Failure(
                new UseCaseError { Type = UseCaseErrorType.ValidationFailed, Message = ex.Message },
                current?.State
            );
        }
    }

    public UseCaseResult<FuroResponse> Furo(string roomId, string joinKey, FuroInput input)
    {
        try
        {
            if (!_rooms.TryUpdate(roomId, joinKey, input.ExpectedVersion, snap =>
            {
                var next = _score.ApplyFuro(snap.State, input);

                var logs = snap.Logs.ToList();
                var seq = logs.Count == 0 ? 1 : logs.Max(x => x.Seq) + 1;
                logs.Add(new RoomLogEntry
                {
                    Seq = seq,
                    At = DateTimeOffset.UtcNow,
                    Type = RoomLogType.Furo,
                    Message = $"{ToJp(input.Seat)}が鳴き",
                    ActorSeat = input.Seat,
                });

                return (next, logs);
            }, out var updated) || updated is null)
            {
                var current = _rooms.Get(roomId);
                return UseCaseResult<FuroResponse>.Failure(
                    new UseCaseError { Type = UseCaseErrorType.VersionMismatch, Message = "更新競合が発生しました" },
                    current?.State
                );
            }

            return UseCaseResult<FuroResponse>.Success(new FuroResponse { State = updated.State, Logs = updated.Logs });
        }
        catch (Exception ex) when (ex is InvalidOperationException or ArgumentException)
        {
            var current = _rooms.Get(roomId);
            return UseCaseResult<FuroResponse>.Failure(
                new UseCaseError { Type = UseCaseErrorType.ValidationFailed, Message = ex.Message },
                current?.State
            );
        }
    }
    public UseCaseResult<AgariResponse> Agari(string roomId, string joinKey, AgariInput input)
    {
        try
        {
            PaymentBreakdown? breakdown = null;
            if (!_rooms.TryUpdate(roomId, joinKey, input.ExpectedVersion, snap =>
            {
                var (next, computedBreakdown) = _score.ApplyAgari(snap.State, input);
                breakdown = computedBreakdown;

                var logs = snap.Logs.ToList();
                var seq = logs.Count == 0 ? 1 : logs.Max(x => x.Seq) + 1;

                var method = input.Method == AgariMethod.Ron ? "ロン" : "ツモ";
                var winnerGain = computedBreakdown.PaymentsByPayerSeat.Values.Sum() + computedBreakdown.KyotakuPaidToWinner;

                int? dealInPointValue = null;
                if (input.Method == AgariMethod.Ron &&
                    input.RonLoserSeat is { } loserSeat &&
                    computedBreakdown.PaymentsByPayerSeat.TryGetValue(loserSeat, out var dealInPoint))
                {
                    dealInPointValue = dealInPoint;
                }

                logs.Add(new RoomLogEntry
                {
                    Seq = seq,
                    At = DateTimeOffset.UtcNow,
                    Type = RoomLogType.Agari,
                    Message = $"{ToJp(input.WinnerSeat)} {method} {input.Han}翻{input.Fu}符",
                    ActorSeat = input.WinnerSeat,
                    WinnerSeat = input.WinnerSeat,
                    LoserSeat = input.RonLoserSeat,
                    Method = input.Method,
                    Han = input.Han,
                    Fu = input.Fu,
                    PointValue = winnerGain,
                    DealInPointValue = dealInPointValue,
                });

                return (next, logs);
            }, out var updated) || updated is null)
            {
                var current = _rooms.Get(roomId);
                return UseCaseResult<AgariResponse>.Failure(
                    new UseCaseError { Type = UseCaseErrorType.VersionMismatch, Message = "更新競合が発生しました" },
                    current?.State
                );
            }

            return UseCaseResult<AgariResponse>.Success(new AgariResponse
            {
                State = updated.State,
                Breakdown = breakdown ?? new PaymentBreakdown
                {
                    LimitType = LimitType.None,
                    Method = input.Method,
                    WinnerIsDealer = input.WinnerSeat == updated.State.DealerSeat,
                    Honba = updated.State.Honba,
                    KyotakuPaidToWinner = 0,
                    PaymentsByPayerSeat = new Dictionary<Seat, int>(),
                },
                Logs = updated.Logs,
            });
        }
        catch (Exception ex) when (ex is InvalidOperationException or ArgumentException)
        {
            var current = _rooms.Get(roomId);
            return UseCaseResult<AgariResponse>.Failure(
                new UseCaseError { Type = UseCaseErrorType.ValidationFailed, Message = ex.Message },
                current?.State
            );
        }
    }
    public UseCaseResult<UndoResponse> Undo(string roomId, string joinKey, UndoInput input)
    {
        if (!_rooms.TryUndo(roomId, joinKey, input.ExpectedVersion, out var updated) || updated is null)
        {
            var current = _rooms.Get(roomId);
            return UseCaseResult<UndoResponse>.Failure(new UseCaseError { Type = UseCaseErrorType.VersionMismatch, Message = "Version mismatch." }, current?.State);
        }

        return UseCaseResult<UndoResponse>.Success(new UndoResponse { State = updated.State, Logs = updated.Logs });
    }

    public UseCaseResult<RematchResponse> Rematch(string roomId, string joinKey, RematchInput input)
    {
        try
        {
            if (!_rooms.TryUpdate(roomId, joinKey, input.ExpectedVersion, snap =>
            {
                if (!snap.State.IsFinished)
                {
                    throw new InvalidOperationException("Match is not finished.");
                }

                var seats = snap.State.Seats
                    .Select(s => s with
                    {
                        Points = snap.State.InitialPoints,
                        IsRiichi = false,
                        IsFuro = false,
                    })
                    .ToList();

                var logs = snap.Logs.ToList();
                var seq = logs.Count == 0 ? 1 : logs.Max(x => x.Seq) + 1;

                var next = snap.State with
                {
                    Seats = seats,
                    DealerSeat = Seat.East,
                    RoundWind = RoundWind.East,
                    Kyoku = 1,
                    Honba = 0,
                    Renchan = 0,
                    Kyotaku = 0,
                    IsFinished = false,
                    Version = snap.State.Version + 1,
                };

                logs.Add(new RoomLogEntry
                {
                    Seq = seq,
                    At = DateTimeOffset.UtcNow,
                    Type = RoomLogType.Rematch,
                    Message = "再戦を開始しました",
                });

                return (next, logs);
            }, out var updated) || updated is null)
            {
                var current = _rooms.Get(roomId);
                return UseCaseResult<RematchResponse>.Failure(
                    new UseCaseError { Type = UseCaseErrorType.VersionMismatch, Message = "Version mismatch." },
                    current?.State
                );
            }

            return UseCaseResult<RematchResponse>.Success(new RematchResponse
            {
                State = updated.State,
                Logs = updated.Logs,
            });
        }
        catch (Exception ex) when (ex is InvalidOperationException or ArgumentException)
        {
            var current = _rooms.Get(roomId);
            return UseCaseResult<RematchResponse>.Failure(
                new UseCaseError { Type = UseCaseErrorType.ValidationFailed, Message = ex.Message },
                current?.State
            );
        }
    }

    private bool TryValidateRecordInput(
        CreateManualRecordRequest request,
        out IReadOnlyDictionary<Seat, ManualRecordParticipantInput> participantsBySeat,
        out int playerCount,
        out DateTimeOffset startedAt,
        out DateTimeOffset endedAt,
        out UseCaseError? error,
        DateTimeOffset? defaultStartedAt = null)
    {
        participantsBySeat = new Dictionary<Seat, ManualRecordParticipantInput>();
        playerCount = 0;
        startedAt = default;
        endedAt = default;
        error = null;

        if (!Enum.IsDefined(request.GameType))
        {
            error = new UseCaseError
            {
                Type = UseCaseErrorType.ValidationFailed,
                Message = "Game type is invalid.",
            };
            return false;
        }

        if (request.Participants is null || request.Participants.Count is not (3 or 4))
        {
            error = new UseCaseError
            {
                Type = UseCaseErrorType.ValidationFailed,
                Message = "Participants must contain 3 or 4 seats.",
            };
            return false;
        }

        playerCount = request.Participants.Count;
        var expectedSeats = ExpectedSeatsForPlayerCount(playerCount);

        var mapped = new Dictionary<Seat, ManualRecordParticipantInput>();
        foreach (var participant in request.Participants)
        {
            if (!Enum.IsDefined(participant.Seat))
            {
                error = new UseCaseError
                {
                    Type = UseCaseErrorType.ValidationFailed,
                    Message = "Seat is invalid.",
                };
                return false;
            }

            if (!mapped.TryAdd(participant.Seat, participant))
            {
                error = new UseCaseError
                {
                    Type = UseCaseErrorType.ValidationFailed,
                    Message = "Seat is duplicated.",
                };
                return false;
            }

            if (participant.UserId is not null && _users.Get(participant.UserId.Value) is null)
            {
                error = new UseCaseError
                {
                    Type = UseCaseErrorType.ValidationFailed,
                    Message = "User not found.",
                };
                return false;
            }
        }

        foreach (var seat in expectedSeats)
        {
            if (mapped.ContainsKey(seat))
            {
                continue;
            }

            error = new UseCaseError
            {
                Type = UseCaseErrorType.ValidationFailed,
                Message = $"All seats must be specified: {string.Join(", ", expectedSeats.Select(ToJp))}.",
            };
            return false;
        }

        foreach (var seat in mapped.Keys)
        {
            if (expectedSeats.Contains(seat))
            {
                continue;
            }

            error = new UseCaseError
            {
                Type = UseCaseErrorType.ValidationFailed,
                Message = "Participants contain invalid seats for the selected player count.",
            };
            return false;
        }

        endedAt = request.EndedAt ?? DateTimeOffset.UtcNow;
        startedAt = request.StartedAt ?? defaultStartedAt ?? endedAt;
        if (startedAt > endedAt)
        {
            error = new UseCaseError
            {
                Type = UseCaseErrorType.ValidationFailed,
                Message = "startedAt must be <= endedAt.",
            };
            return false;
        }

        participantsBySeat = mapped;
        return true;
    }

    private static IReadOnlyList<MatchParticipantSnapshot> BuildMatchParticipants(
        IReadOnlyDictionary<Seat, ManualRecordParticipantInput> participantsBySeat)
    {
        return participantsBySeat
            .OrderBy(x => x.Key)
            .Select(x => new MatchParticipantSnapshot
            {
                Seat = x.Key,
                UserId = x.Value.UserId,
                FinalPoints = x.Value.FinalPoints,
            })
            .ToList();
    }

    private static MatchRecordResponse ToRecordResponse(MatchSnapshot snapshot)
    {
        return new MatchRecordResponse
        {
            MatchId = snapshot.MatchId,
            RoomId = snapshot.RoomId,
            StartedAt = snapshot.StartedAt,
            EndedAt = snapshot.EndedAt,
            Participants = snapshot.Participants
                .Select(x => new MatchParticipantResponse
                {
                    Seat = x.Seat,
                    UserId = x.UserId,
                    FinalPoints = x.FinalPoints,
                })
                .ToList(),
            FinalState = snapshot.FinalState,
            Logs = snapshot.Logs.ToList(),
        };
    }

    private static RoomState BuildManualFinalState(
        GameType gameType,
        int playerCount,
        IReadOnlyDictionary<Seat, ManualRecordParticipantInput> participantsBySeat)
    {
        var expectedSeats = ExpectedSeatsForPlayerCount(playerCount);
        var seats = expectedSeats.Select(ToSeatState).ToList();

        return new RoomState
        {
            RoomName = "手動入力",
            InitialPoints = DefaultInitialPointsForPlayerCount(playerCount),
            Seats = seats,
            DealerSeat = Seat.East,
            RoundWind = RoundWind.East,
            Kyoku = MaxKyokuForPlayerCount(playerCount),
            Honba = 0,
            Renchan = 0,
            Kyotaku = 0,
            GameType = gameType,
            PlayerCount = playerCount,
            Rules = new RuleConfig(),
            IsFinished = true,
            Version = 1,
        };

        SeatState ToSeatState(Seat seat)
        {
            var participant = participantsBySeat[seat];
            return new SeatState
            {
                Seat = seat,
                Points = participant.FinalPoints,
                AssignedUserId = participant.UserId,
                IsRiichi = false,
                IsFuro = false,
            };
        }
    }

    private static RoomState BuildUpdatedFinalState(
        RoomState currentFinalState,
        GameType gameType,
        int playerCount,
        IReadOnlyDictionary<Seat, ManualRecordParticipantInput> participantsBySeat)
    {
        var currentSeatBySeat = currentFinalState.Seats.ToDictionary(x => x.Seat);
        var expectedSeats = ExpectedSeatsForPlayerCount(playerCount);
        var seats = expectedSeats.Select(ToSeatState).ToList();

        return currentFinalState with
        {
            Seats = seats,
            InitialPoints = DefaultInitialPointsForPlayerCount(playerCount),
            GameType = gameType,
            PlayerCount = playerCount,
            Kyoku = MaxKyokuForPlayerCount(playerCount),
            IsFinished = true,
        };

        SeatState ToSeatState(Seat seat)
        {
            var participant = participantsBySeat[seat];
            if (currentSeatBySeat.TryGetValue(seat, out var currentSeat))
            {
                return currentSeat with
                {
                    Points = participant.FinalPoints,
                    AssignedUserId = participant.UserId,
                    IsRiichi = false,
                    IsFuro = false,
                };
            }

            return new SeatState
            {
                Seat = seat,
                Points = participant.FinalPoints,
                AssignedUserId = participant.UserId,
                IsRiichi = false,
                IsFuro = false,
            };
        }
    }

    private static List<SeatState> CreateInitialSeats(int initialPoints, int playerCount)
    {
        return ExpectedSeatsForPlayerCount(playerCount)
            .Select(seat => new SeatState
            {
                Seat = seat,
                Points = initialPoints,
                AssignedUserId = null,
                IsRiichi = false,
                IsFuro = false,
            })
            .ToList();
    }

    private static List<Seat> ActiveSeatsFromState(RoomState state)
    {
        var activeSeats = state.Seats
            .Select(x => x.Seat)
            .Distinct()
            .OrderBy(x => x)
            .ToList();

        if (activeSeats.Count is not (3 or 4))
        {
            throw new InvalidOperationException("Active seat count must be 3 or 4.");
        }

        if (!activeSeats.Contains(Seat.East) ||
            !activeSeats.Contains(Seat.South) ||
            !activeSeats.Contains(Seat.West))
        {
            throw new InvalidOperationException("East, South, and West must be active.");
        }

        if (activeSeats.Count == 4 && !activeSeats.Contains(Seat.North))
        {
            throw new InvalidOperationException("North seat is required in 4-player mode.");
        }

        if (activeSeats.Count == 3 && activeSeats.Contains(Seat.North))
        {
            throw new InvalidOperationException("North seat is not allowed in 3-player mode.");
        }

        return activeSeats;
    }

    private static List<Seat> ExpectedSeatsForPlayerCount(int playerCount)
    {
        if (playerCount == 3)
        {
            return new List<Seat> { Seat.East, Seat.South, Seat.West };
        }

        if (playerCount == 4)
        {
            return new List<Seat> { Seat.East, Seat.South, Seat.West, Seat.North };
        }

        throw new ArgumentOutOfRangeException(nameof(playerCount), "PlayerCount must be 3 or 4.");
    }

    private static int MaxKyokuForPlayerCount(int playerCount)
    {
        return playerCount == 3 ? 3 : 4;
    }

    private static int DefaultInitialPointsForPlayerCount(int playerCount)
    {
        return playerCount == 3 ? 35000 : 25000;
    }

    private static string ToJp(GameType gameType)
    {
        return gameType switch
        {
            GameType.Tonpu => "東風戦",
            GameType.Hanchan => "半荘戦",
            _ => "?",
        };
    }

    private static string ToJp(Seat seat)
    {
        return seat switch
        {
            Seat.East => "東",
            Seat.South => "南",
            Seat.West => "西",
            Seat.North => "北",
            _ => "?",
        };
    }
}
