#nullable enable
using System.Collections.Concurrent;
using MahjongScore.Domain;

namespace MahjongScore.Server.Repository;

public enum MatchRecordSource
{
    Progress = 0,
    Manual = 1,
}

public sealed record UserSnapshot
{
    public required UserProfile User { get; init; }
}

public sealed record RoomSnapshot
{
    public required string RoomId { get; init; }
    public required string JoinKey { get; init; }
    public required RoomState State { get; init; }
    public required IReadOnlyList<RoomLogEntry> Logs { get; init; }
    public DateTimeOffset? CreatedAt { get; init; }
}

public sealed record MatchParticipantSnapshot
{
    public required Seat Seat { get; init; }
    public required UserId? UserId { get; init; }
    public required int FinalPoints { get; init; }
}

public sealed record MatchSnapshot
{
    public required Guid MatchId { get; init; }
    public required string RoomId { get; init; }
    public required DateTimeOffset StartedAt { get; init; }
    public required DateTimeOffset EndedAt { get; init; }
    public required IReadOnlyList<MatchParticipantSnapshot> Participants { get; init; }
    public required RoomState FinalState { get; init; }
    public required IReadOnlyList<RoomLogEntry> Logs { get; init; }
    public required MatchRecordSource Source { get; init; }
    public required DateTimeOffset? DeletedAt { get; init; }
}

public interface IUserRepository
{
    UserSnapshot Create(string displayName);
    UserSnapshot? Get(UserId id);
    IReadOnlyList<UserSnapshot> GetAll();
    bool TryUpdate(UserId id, Func<UserSnapshot, UserSnapshot> update, out UserSnapshot? updated);
}

public interface IRoomRepository
{
    RoomSnapshot? Get(string roomId);
    IReadOnlyList<RoomSnapshot> GetAll();
    void Create(RoomSnapshot snapshot);

    bool TryUpdate(string roomId, string joinKey, long expectedVersion, Func<RoomSnapshot, (RoomState newState, List<RoomLogEntry> newLogs)> apply, out RoomSnapshot? updated);
    bool TryUndo(string roomId, string joinKey, long expectedVersion, out RoomSnapshot? updated);
    bool TryDelete(string roomId, string joinKey);
}

public interface IMatchRepository
{
    void Create(MatchSnapshot snapshot);
    MatchSnapshot? Get(Guid matchId);
    IReadOnlyList<MatchSnapshot> GetAll();
    bool TryUpdate(Guid matchId, Func<MatchSnapshot, MatchSnapshot> update, out MatchSnapshot? updated);
    bool TrySoftDelete(Guid matchId, DateTimeOffset deletedAt);
}

public sealed class InMemoryUserRepository : IUserRepository
{
    private readonly ConcurrentDictionary<Guid, UserSnapshot> _users = new();

    public UserSnapshot Create(string displayName)
    {
        if (string.IsNullOrWhiteSpace(displayName))
        {
            throw new ArgumentException("表示名は必須です");
        }

        var id = new UserId(Guid.NewGuid());
        var riichiVoiceId = Random.Shared.Next(0, 8);
        var snap = new UserSnapshot
        {
            User = new UserProfile
            {
                UserId = id,
                DisplayName = displayName.Trim(),
                IconDataUrl = null,
                RiichiVoiceId = riichiVoiceId,
                IsHidden = false,
            },
        };
        _users.TryAdd(id.Value, snap);
        return snap;
    }

    public UserSnapshot? Get(UserId id)
    {
        if (_users.TryGetValue(id.Value, out var s))
        {
            return s;
        }
        return null;
    }

    public IReadOnlyList<UserSnapshot> GetAll() => _users.Values.ToList();

    public bool TryUpdate(UserId id, Func<UserSnapshot, UserSnapshot> update, out UserSnapshot? updated)
    {
        updated = null;

        while (true)
        {
            if (!_users.TryGetValue(id.Value, out var current))
            {
                return false;
            }

            var next = update(current);
            if (_users.TryUpdate(id.Value, next, current))
            {
                updated = next;
                return true;
            }
        }
    }
}

public sealed class InMemoryMatchRepository : IMatchRepository
{
    private readonly ConcurrentDictionary<Guid, MatchSnapshot> _matches = new();

    public void Create(MatchSnapshot snapshot)
    {
        if (!_matches.TryAdd(snapshot.MatchId, snapshot))
        {
            throw new InvalidOperationException("Match already exists");
        }
    }

    public MatchSnapshot? Get(Guid matchId)
    {
        if (!_matches.TryGetValue(matchId, out var snapshot))
        {
            return null;
        }

        return snapshot.DeletedAt is null ? snapshot : null;
    }

    public IReadOnlyList<MatchSnapshot> GetAll()
    {
        return _matches.Values
            .Where(x => x.DeletedAt is null)
            .OrderByDescending(x => x.EndedAt)
            .ThenByDescending(x => x.MatchId)
            .ToList();
    }

    public bool TryUpdate(Guid matchId, Func<MatchSnapshot, MatchSnapshot> update, out MatchSnapshot? updated)
    {
        updated = null;

        while (true)
        {
            if (!_matches.TryGetValue(matchId, out var current))
            {
                return false;
            }

            if (current.DeletedAt is not null)
            {
                return false;
            }

            var next = update(current);
            if (_matches.TryUpdate(matchId, next, current))
            {
                updated = next;
                return true;
            }
        }
    }

    public bool TrySoftDelete(Guid matchId, DateTimeOffset deletedAt)
    {
        while (true)
        {
            if (!_matches.TryGetValue(matchId, out var current))
            {
                return false;
            }

            if (current.DeletedAt is not null)
            {
                return false;
            }

            var next = current with { DeletedAt = deletedAt };
            if (_matches.TryUpdate(matchId, next, current))
            {
                return true;
            }
        }
    }
}

public sealed class InMemoryRoomRepository : IRoomRepository
{
    private sealed class RoomRecord
    {
        public required object Gate { get; init; }
        public required string RoomId { get; init; }
        public required string JoinKey { get; init; }
        public required DateTimeOffset CreatedAt { get; init; }
        public required Stack<(RoomState state, int logsCount)> History { get; init; }
        public required List<RoomLogEntry> Logs { get; init; }
        public required RoomState State { get; set; }
        public long Seq { get; set; }
    }

    private readonly ConcurrentDictionary<string, RoomRecord> _rooms = new();

    public RoomSnapshot? Get(string roomId)
    {
        if (!_rooms.TryGetValue(roomId, out var rec))
        {
            return null;
        }

        lock (rec.Gate)
        {
            return new RoomSnapshot
            {
                RoomId = rec.RoomId,
                JoinKey = rec.JoinKey,
                State = rec.State,
                Logs = rec.Logs.ToList(),
                CreatedAt = rec.CreatedAt,
            };
        }
    }

    public IReadOnlyList<RoomSnapshot> GetAll()
    {
        return _rooms.Values
            .Select(rec =>
            {
                lock (rec.Gate)
                {
                    return new RoomSnapshot
                    {
                        RoomId = rec.RoomId,
                        JoinKey = rec.JoinKey,
                        State = rec.State,
                        Logs = rec.Logs.ToList(),
                        CreatedAt = rec.CreatedAt,
                    };
                }
            })
            .OrderBy(x => x.RoomId)
            .ToList();
    }

    public void Create(RoomSnapshot snapshot)
    {
        var rec = new RoomRecord
        {
            Gate = new object(),
            RoomId = snapshot.RoomId,
            JoinKey = snapshot.JoinKey,
            CreatedAt = snapshot.CreatedAt ?? DateTimeOffset.UtcNow,
            History = new Stack<(RoomState, int)>(),
            Logs = snapshot.Logs.ToList(),
            State = snapshot.State,
            Seq = snapshot.Logs.Count == 0 ? 0 : snapshot.Logs.Max(x => x.Seq),
        };

        if (!_rooms.TryAdd(snapshot.RoomId, rec))
        {
            throw new InvalidOperationException("Room already exists");
        }
    }

    public bool TryUpdate(string roomId, string joinKey, long expectedVersion, Func<RoomSnapshot, (RoomState newState, List<RoomLogEntry> newLogs)> apply, out RoomSnapshot? updated)
    {
        updated = null;

        if (!_rooms.TryGetValue(roomId, out var rec))
        {
            return false;
        }

        lock (rec.Gate)
        {
            if (rec.JoinKey != joinKey)
            {
                return false;
            }

            if (rec.State.Version != expectedVersion)
            {
                return false;
            }

            var snap = new RoomSnapshot
            {
                RoomId = rec.RoomId,
                JoinKey = rec.JoinKey,
                State = rec.State,
                Logs = rec.Logs.ToList(),
                CreatedAt = rec.CreatedAt,
            };

            rec.History.Push((rec.State, rec.Logs.Count));

            var (newState, newLogs) = apply(snap);

            rec.State = newState;
            rec.Logs.Clear();
            rec.Logs.AddRange(newLogs);
            rec.Seq = rec.Logs.Count == 0 ? rec.Seq : rec.Logs.Max(x => x.Seq);

            updated = new RoomSnapshot
            {
                RoomId = rec.RoomId,
                JoinKey = rec.JoinKey,
                State = rec.State,
                Logs = rec.Logs.ToList(),
                CreatedAt = rec.CreatedAt,
            };

            return true;
        }
    }

    public bool TryUndo(string roomId, string joinKey, long expectedVersion, out RoomSnapshot? updated)
    {
        updated = null;

        if (!_rooms.TryGetValue(roomId, out var rec))
        {
            return false;
        }

        lock (rec.Gate)
        {
            if (rec.JoinKey != joinKey)
            {
                return false;
            }

            if (rec.State.Version != expectedVersion)
            {
                return false;
            }

            if (rec.History.Count == 0)
            {
                rec.State = rec.State with { Version = rec.State.Version + 1 };
            }
            else
            {
                var (prevState, logsCount) = rec.History.Pop();
                rec.State = prevState with { Version = rec.State.Version + 1 };

                if (rec.Logs.Count > logsCount)
                {
                    rec.Logs.RemoveRange(logsCount, rec.Logs.Count - logsCount);
                }
            }

            rec.Seq += 1;
            rec.Logs.Add(new RoomLogEntry
            {
                Seq = rec.Seq,
                At = DateTimeOffset.UtcNow,
                Type = RoomLogType.Undo,
                Message = "直前操作を取り消しました",
            });

            updated = new RoomSnapshot
            {
                RoomId = rec.RoomId,
                JoinKey = rec.JoinKey,
                State = rec.State,
                Logs = rec.Logs.ToList(),
                CreatedAt = rec.CreatedAt,
            };

            return true;
        }
    }

    public bool TryDelete(string roomId, string joinKey)
    {
        if (!_rooms.TryGetValue(roomId, out var rec))
        {
            return false;
        }

        lock (rec.Gate)
        {
            if (rec.JoinKey != joinKey)
            {
                return false;
            }
        }

        return _rooms.TryRemove(roomId, out _);
    }
}
