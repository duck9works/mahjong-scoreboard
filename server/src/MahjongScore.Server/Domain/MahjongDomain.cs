#nullable enable
using System;
using System.Collections.Generic;
using System.Linq;

namespace MahjongScore.Domain;
// FIXED12

/// <summary>
/// 和了方法
/// </summary>
public enum AgariMethod
{
    /// <summary>
    /// ロン
    /// </summary>
    Ron = 0,

    /// <summary>
    /// ツモ
    /// </summary>
    Tsumo = 1,
}

/// <summary>
/// 席
/// </summary>
public enum Seat
{
    /// <summary>
    /// 東
    /// </summary>
    East = 0,

    /// <summary>
    /// 南
    /// </summary>
    South = 1,

    /// <summary>
    /// 西
    /// </summary>
    West = 2,

    /// <summary>
    /// 北
    /// </summary>
    North = 3,
}

/// <summary>
/// 場風
/// </summary>
public enum RoundWind
{
    /// <summary>
    /// 東場
    /// </summary>
    East = 0,

    /// <summary>
    /// 南場
    /// </summary>
    South = 1,
}

/// <summary>
/// 点数区分
/// </summary>
public enum GameType
{
    Tonpu = 0,
    Hanchan = 1,
}

public enum LimitType
{
    /// <summary>
    /// 通常
    /// </summary>
    None = 0,

    /// <summary>
    /// 満貫
    /// </summary>
    Mangan = 1,

    /// <summary>
    /// 跳満
    /// </summary>
    Haneman = 2,

    /// <summary>
    /// 倍満
    /// </summary>
    Baiman = 3,

    /// <summary>
    /// 三倍満
    /// </summary>
    Sanbaiman = 4,

    /// <summary>
    /// 役満
    /// </summary>
    Yakuman = 5,
}

/// <summary>
/// ルーム内イベント種別
/// </summary>
public enum RoomLogType
{
    /// <summary>
    /// 席割当
    /// </summary>
    SeatAssignment = 0,

    /// <summary>
    /// リーチ
    /// </summary>
    Riichi = 1,

    /// <summary>
    /// 和了
    /// </summary>
    Agari = 2,

    /// <summary>
    /// Undo
    /// </summary>
    Undo = 3,

    /// <summary>
    /// 点数修正
    /// </summary>
    ScoreEdit = 4,
    Ryukyoku = 5,
    GameTypeChange = 6,
    Rematch = 7,
    Furo = 8,
}

public readonly record struct UserId(Guid Value);
public readonly record struct ScoreKey(int Han, int Fu);

public sealed record RuleConfig
{
    /// <summary>
    /// 25符を候補に含める
    /// </summary>
    public bool KeepFu25 { get; init; } = true;

    /// <summary>
    /// 切り上げ満貫を有効にする
    /// </summary>
    public bool EnableKiriageMangan { get; init; } = true;

    /// <summary>
    /// 数え役満を役満扱いにする
    /// </summary>
    public bool KazoeAsYakuman { get; init; } = true;
}

public sealed record UserProfile
{
    public required UserId UserId { get; init; }
    public required string DisplayName { get; init; }
    public string? IconDataUrl { get; init; }
    public int RiichiVoiceId { get; init; } = 0;
    public bool IsHidden { get; init; } = false;
}

public sealed record SeatState
{
    public required Seat Seat { get; init; }
    public required int Points { get; init; }
    public required UserId? AssignedUserId { get; init; }
    public required bool IsRiichi { get; init; }
    public bool IsFuro { get; init; } = false;
}

public sealed record RoomState
{
    public string RoomName { get; init; } = string.Empty;
    public int InitialPoints { get; init; } = 25000;
    public required IReadOnlyList<SeatState> Seats { get; init; }
    public required Seat DealerSeat { get; init; }
    public required RoundWind RoundWind { get; init; }
    public required int Kyoku { get; init; }
    public required int Honba { get; init; }
    public int Renchan { get; init; } = 0;
    public required int Kyotaku { get; init; }
    public GameType GameType { get; init; } = GameType.Tonpu;
    public int PlayerCount { get; init; } = 4;
    public RuleConfig Rules { get; init; } = new();
    public bool IsFinished { get; init; } = false;
    public required long Version { get; init; }
}

public sealed record RoomLogEntry
{
    public required long Seq { get; init; }
    public required DateTimeOffset At { get; init; }
    public required RoomLogType Type { get; init; }
    public required string Message { get; init; }
    public Seat? ActorSeat { get; init; }
    public Seat? WinnerSeat { get; init; }
    public Seat? LoserSeat { get; init; }
    public AgariMethod? Method { get; init; }
    public int? Han { get; init; }
    public int? Fu { get; init; }
    public int? PointValue { get; init; }
    public int? DealInPointValue { get; init; }
}

public sealed record SeatAssignmentInput
{
    public required Seat Seat { get; init; }
    public required UserId? UserId { get; init; }
    public required long ExpectedVersion { get; init; }
}

public sealed record SeatAssignment
{
    public required Seat Seat { get; init; }
    public required UserId? UserId { get; init; }
}

public sealed record SeatAssignmentsInput
{
    public required IReadOnlyList<SeatAssignment> Assignments { get; init; }
    public required long ExpectedVersion { get; init; }
}

public sealed record GameTypeInput
{
    public required GameType GameType { get; init; }
    public required long ExpectedVersion { get; init; }
}

public sealed record SeatPoints
{
    public required Seat Seat { get; init; }
    public required int Points { get; init; }
}

public sealed record ScoreEditInput
{
    public required IReadOnlyList<SeatPoints> Seats { get; init; }
    public required long ExpectedVersion { get; init; }
}

public sealed record RiichiInput
{
    public required Seat Seat { get; init; }
    public required long ExpectedVersion { get; init; }
}

public sealed record FuroInput
{
    public required Seat Seat { get; init; }
    public required long ExpectedVersion { get; init; }
}

public sealed record UndoInput
{
    public required long ExpectedVersion { get; init; }
}

public sealed record RematchInput
{
    public required long ExpectedVersion { get; init; }
}

public sealed record AgariInput
{
    public required Seat WinnerSeat { get; init; }
    public required AgariMethod Method { get; init; }
    public Seat? RonLoserSeat { get; init; }
    public required int Han { get; init; }
    public required int Fu { get; init; }

    /// <summary>
    /// 役満倍数
    /// </summary>
    /// <remarks>
    /// <list type="bullet">
    /// <item>通常手: 0</item>
    /// <item>役満: 1</item>
    /// <item>ダブル役満: 2</item>
    /// </list>
    /// </remarks>
    public int YakumanMultiplier { get; init; } = 0;

    public required long ExpectedVersion { get; init; }
}

public sealed record RyukyokuInput
{
    public required IReadOnlyList<Seat> TenpaiSeats { get; init; }
    public required long ExpectedVersion { get; init; }
}

public sealed record PaymentBreakdown
{
    public required LimitType LimitType { get; init; }
    public required AgariMethod Method { get; init; }
    public required bool WinnerIsDealer { get; init; }
    public required int Honba { get; init; }
    public required int KyotakuPaidToWinner { get; init; }
    public required IReadOnlyDictionary<Seat, int> PaymentsByPayerSeat { get; init; }
}

public sealed record ScoreTableRow
{
    public required int Han { get; init; }
    public required int Fu { get; init; }
    public required LimitType LimitType { get; init; }
    public required int BasePoints { get; init; }
    public required int ChildRon { get; init; }
    public required int ChildTsumoFromDealer { get; init; }
    public required int ChildTsumoFromChild { get; init; }
    public required int DealerRon { get; init; }
    public required int DealerTsumoFromAny { get; init; }
}

public sealed class ScoreTable
{
    private readonly IReadOnlyDictionary<ScoreKey, ScoreTableRow> _rows;

    public ScoreTable(RuleConfig rules)
    {
        _rows = ScoreTableFactory.Build(rules);
    }

    public ScoreTableRow Get(int han, int fu)
    {
        var key = new ScoreKey(han, fu);
        if (!_rows.TryGetValue(key, out var row))
        {
            throw new KeyNotFoundException($"Score table row not found: han={han}, fu={fu}");
        }
        return row;
    }
}

public static class ScoreTableFactory
{
    public static IReadOnlyDictionary<ScoreKey, ScoreTableRow> Build(RuleConfig rules)
    {
        var table = new Dictionary<ScoreKey, ScoreTableRow>();

        for (var han = 1; han <= 13; han++)
        {
            foreach (var fu in EnumerateFu(rules))
            {
                var (limitType, basePoints) = CalculateBasePoints(han, fu, rules);

                table[new ScoreKey(han, fu)] = new ScoreTableRow
                {
                    Han = han,
                    Fu = fu,
                    LimitType = limitType,
                    BasePoints = basePoints,
                    ChildRon = RoundUpTo100(basePoints * 4),
                    ChildTsumoFromDealer = RoundUpTo100(basePoints * 2),
                    ChildTsumoFromChild = RoundUpTo100(basePoints * 1),
                    DealerRon = RoundUpTo100(basePoints * 6),
                    DealerTsumoFromAny = RoundUpTo100(basePoints * 2),
                };
            }
        }

        return table;
    }

    public static IReadOnlyList<int> FuCandidates(RuleConfig rules)
    {
        var list = new List<int> { 20 };
        if (rules.KeepFu25)
        {
            list.Add(25);
        }
        for (var fu = 30; fu <= 110; fu += 10)
        {
            list.Add(fu);
        }
        return list;
    }

    private static IEnumerable<int> EnumerateFu(RuleConfig rules)
    {
        yield return 20;
        if (rules.KeepFu25)
        {
            yield return 25;
        }
        for (var fu = 30; fu <= 110; fu += 10)
        {
            yield return fu;
        }
    }

    private static (LimitType limitType, int basePoints) CalculateBasePoints(int han, int fu, RuleConfig rules)
    {
        if (han >= 13)
        {
            if (rules.KazoeAsYakuman)
            {
                return (LimitType.Yakuman, 8000);
            }
            return (LimitType.Sanbaiman, 6000);
        }
        if (han >= 11)
        {
            return (LimitType.Sanbaiman, 6000);
        }
        if (han >= 8)
        {
            return (LimitType.Baiman, 4000);
        }
        if (han >= 6)
        {
            return (LimitType.Haneman, 3000);
        }
        if (han >= 5)
        {
            return (LimitType.Mangan, 2000);
        }
        if (han == 4 && fu >= 40)
        {
            return (LimitType.Mangan, 2000);
        }
        if (han == 3 && fu >= 70)
        {
            return (LimitType.Mangan, 2000);
        }

        var basePoints = fu * (1 << (han + 2));
        if (basePoints >= 2000)
        {
            return (LimitType.Mangan, 2000);
        }
        if (rules.EnableKiriageMangan && basePoints == 1920)
        {
            return (LimitType.Mangan, 2000);
        }
        return (LimitType.None, basePoints);
    }

    private static int RoundUpTo100(int value)
    {
        return ((value + 99) / 100) * 100;
    }
}

public sealed class MahjongScoreService
{
    public MahjongScoreService() { }

    public RoomState ApplyRiichi(RoomState state, RiichiInput input)
    {
        if (state.Version != input.ExpectedVersion)
        {
            throw new InvalidOperationException("Version mismatch");
        }
        if (state.IsFinished)
        {
            throw new InvalidOperationException("Match already finished");
        }

        var target = state.Seats.FirstOrDefault(x => x.Seat == input.Seat) ?? throw new ArgumentException("Seat invalid");

        if (target.IsRiichi)
        {
            return state;
        }

        if (target.IsFuro)
        {
            throw new InvalidOperationException("Cannot declare riichi after furo");
        }

        if (target.Points < 1000)
        {
            throw new InvalidOperationException("Not enough points for riichi");
        }

        var newSeats = state.Seats.Select(s =>
        {
            if (s.Seat != input.Seat)
            {
                return s;
            }
            return s with { Points = s.Points - 1000, IsRiichi = true };
        }).ToList();

        return state with { Seats = newSeats, Kyotaku = state.Kyotaku + 1, Version = state.Version + 1 };
    }

    public RoomState ApplyFuro(RoomState state, FuroInput input)
    {
        if (state.Version != input.ExpectedVersion)
        {
            throw new InvalidOperationException("Version mismatch");
        }
        if (state.IsFinished)
        {
            throw new InvalidOperationException("Match already finished");
        }

        var target = state.Seats.FirstOrDefault(x => x.Seat == input.Seat) ?? throw new ArgumentException("Seat invalid");

        if (target.IsFuro)
        {
            return state;
        }

        if (target.IsRiichi)
        {
            throw new InvalidOperationException("Cannot declare furo after riichi");
        }

        var newSeats = state.Seats.Select(s =>
        {
            if (s.Seat != input.Seat)
            {
                return s;
            }
            return s with { IsFuro = true };
        }).ToList();

        return state with { Seats = newSeats, Version = state.Version + 1 };
    }

    public (RoomState newState, PaymentBreakdown breakdown) ApplyAgari(RoomState state, AgariInput input)
    {
        if (state.Version != input.ExpectedVersion)
        {
            throw new InvalidOperationException("Version mismatch");
        }
        if (state.IsFinished)
        {
            throw new InvalidOperationException("Match already finished");
        }

        var activeSeats = ResolveActiveSeats(state);
        var winnerIsDealer = input.WinnerSeat == state.DealerSeat;
        var playerCount = activeSeats.Count;

        var core = ComputeCore(state, input, winnerIsDealer, playerCount);

        var deltas = activeSeats.ToDictionary(x => x, _ => 0);
        var payments = new Dictionary<Seat, int>();

        if (input.Method == AgariMethod.Ron)
        {
            if (input.RonLoserSeat is null)
            {
                throw new ArgumentException("Ron requires RonLoserSeat");
            }

            var payer = input.RonLoserSeat.Value;
            if (!deltas.ContainsKey(payer))
            {
                throw new InvalidOperationException("Ron loser seat is invalid for this match mode.");
            }
            if (payer == input.WinnerSeat)
            {
                throw new InvalidOperationException("Ron loser seat must be different from winner seat.");
            }
            var pay = core.SinglePay;
            deltas[payer] -= pay;
            deltas[input.WinnerSeat] += pay;
            payments[payer] = pay;
        }
        else
        {
            foreach (var payer in activeSeats)
            {
                if (payer == input.WinnerSeat)
                {
                    continue;
                }

                var pay = ResolveTsumoPay(core, payer, state.DealerSeat, winnerIsDealer);
                deltas[payer] -= pay;
                deltas[input.WinnerSeat] += pay;
                payments[payer] = pay;
            }
        }

        var kyotakuPaid = state.Kyotaku * 1000;
        if (kyotakuPaid != 0)
        {
            deltas[input.WinnerSeat] += kyotakuPaid;
        }

        var newSeats = state.Seats.Select(s => s with
        {
            Points = s.Points + deltas[s.Seat],
            IsRiichi = false,
            IsFuro = false,
        }).ToList();

        var nextDealer = state.DealerSeat;
        var nextHonba = state.Honba + 1;
        var nextRenchan = state.Renchan + 1;
        var nextRoundWind = state.RoundWind;
        var nextKyoku = state.Kyoku;
        var isFinished = state.IsFinished;

        if (!winnerIsDealer)
        {
            nextDealer = NextSeat(state.DealerSeat, activeSeats);
            nextHonba = 0;
            nextRenchan = 0;
            var progression = AdvanceKyoku(state.RoundWind, state.Kyoku, state.GameType, activeSeats.Count);
            nextRoundWind = progression.roundWind;
            nextKyoku = progression.kyoku;
            isFinished = progression.isFinished;
        }

        var newState = state with
        {
            Seats = newSeats,
            DealerSeat = nextDealer,
            RoundWind = nextRoundWind,
            Kyoku = nextKyoku,
            Honba = nextHonba,
            Renchan = nextRenchan,
            Kyotaku = 0,
            IsFinished = isFinished,
            Version = state.Version + 1,
        };

        return (newState, new PaymentBreakdown
        {
            LimitType = core.LimitType,
            Method = input.Method,
            WinnerIsDealer = winnerIsDealer,
            Honba = state.Honba,
            KyotakuPaidToWinner = kyotakuPaid,
            PaymentsByPayerSeat = payments,
        });
    }

    public RoomState ApplyRyukyoku(RoomState state, RyukyokuInput input)
    {
        if (state.Version != input.ExpectedVersion)
        {
            throw new InvalidOperationException("Version mismatch");
        }
        if (state.IsFinished)
        {
            throw new InvalidOperationException("Match already finished");
        }

        var activeSeats = ResolveActiveSeats(state);
        var tenpaiSeats = NormalizeTenpaiSeats(input.TenpaiSeats, activeSeats);
        var deltas = activeSeats.ToDictionary(x => x, _ => 0);
        var playerCount = activeSeats.Count;

        var tenpaiCount = tenpaiSeats.Count;
        if (tenpaiCount is > 0 && tenpaiCount < playerCount)
        {
            var notenCount = playerCount - tenpaiCount;
            var penaltyTotal = NotenPenaltyTotal(playerCount);
            var tenpaiGain = penaltyTotal / tenpaiCount;
            var notenLoss = penaltyTotal / notenCount;

            foreach (var seat in activeSeats)
            {
                if (tenpaiSeats.Contains(seat))
                {
                    deltas[seat] += tenpaiGain;
                }
                else
                {
                    deltas[seat] -= notenLoss;
                }
            }
        }

        var newSeats = state.Seats
            .Select(s => s with
            {
                Points = s.Points + deltas[s.Seat],
                IsRiichi = false,
                IsFuro = false,
            })
            .ToList();

        var dealerTenpai = tenpaiSeats.Contains(state.DealerSeat);
        var nextDealer = state.DealerSeat;
        var nextHonba = state.Honba + 1;
        var nextRenchan = state.Renchan + 1;
        var nextRoundWind = state.RoundWind;
        var nextKyoku = state.Kyoku;
        var isFinished = state.IsFinished;

        if (!dealerTenpai)
        {
            nextDealer = NextSeat(state.DealerSeat, activeSeats);
            nextRenchan = 0;
            var progression = AdvanceKyoku(state.RoundWind, state.Kyoku, state.GameType, playerCount);
            nextRoundWind = progression.roundWind;
            nextKyoku = progression.kyoku;
            isFinished = progression.isFinished;
        }

        return state with
        {
            Seats = newSeats,
            DealerSeat = nextDealer,
            RoundWind = nextRoundWind,
            Kyoku = nextKyoku,
            Honba = nextHonba,
            Renchan = nextRenchan,
            IsFinished = isFinished,
            Version = state.Version + 1,
        };
    }

    private static HashSet<Seat> NormalizeTenpaiSeats(
        IReadOnlyList<Seat> source,
        IReadOnlyCollection<Seat> activeSeats)
    {
        source ??= Array.Empty<Seat>();
        if (source.Count > activeSeats.Count)
        {
            throw new ArgumentOutOfRangeException(nameof(source), $"Tenpai seat count must be <= {activeSeats.Count}.");
        }

        var activeSeatSet = activeSeats.ToHashSet();
        var seats = new HashSet<Seat>();
        foreach (var seat in source)
        {
            if (!activeSeatSet.Contains(seat))
            {
                throw new ArgumentOutOfRangeException(nameof(source), "Tenpai seat contains invalid seat.");
            }
            if (!seats.Add(seat))
            {
                throw new InvalidOperationException("Tenpai seat contains duplicates.");
            }
        }

        return seats;
    }

    private static List<Seat> ResolveActiveSeats(RoomState state)
    {
        var orderedSeats = state.Seats
            .Select(x => x.Seat)
            .Distinct()
            .OrderBy(x => x)
            .ToList();

        if (orderedSeats.Count is not (3 or 4))
        {
            throw new InvalidOperationException("Active seat count must be 3 or 4.");
        }

        if (!orderedSeats.Contains(Seat.East) ||
            !orderedSeats.Contains(Seat.South) ||
            !orderedSeats.Contains(Seat.West))
        {
            throw new InvalidOperationException("East, South, and West must always be active.");
        }

        if (orderedSeats.Count == 4 && !orderedSeats.Contains(Seat.North))
        {
            throw new InvalidOperationException("North seat is required in 4-player mode.");
        }

        if (orderedSeats.Count == 3 && orderedSeats.Contains(Seat.North))
        {
            throw new InvalidOperationException("North seat is not allowed in 3-player mode.");
        }

        return orderedSeats;
    }

    private Core ComputeCore(RoomState state, AgariInput input, bool winnerIsDealer, int playerCount)
    {
        var rules = state.Rules;
        var useTsumoLossless = playerCount == 3;

        if (input.YakumanMultiplier >= 1)
        {
            var basePoints = 8000 * input.YakumanMultiplier;

            if (input.Method == AgariMethod.Ron)
            {
                var pay = RoundUpTo100(basePoints * (winnerIsDealer ? 6 : 4)) + (state.Honba * 300);
                return new Core { LimitType = LimitType.Yakuman, SinglePay = pay, DealerEach = 0, ChildFromDealer = 0, ChildFromChild = 0 };
            }

            if (winnerIsDealer)
            {
                var eachBase = useTsumoLossless ? 3 : 2;
                var each = RoundUpTo100(basePoints * eachBase) + (state.Honba * 100);
                return new Core { LimitType = LimitType.Yakuman, SinglePay = 0, DealerEach = each, ChildFromDealer = 0, ChildFromChild = 0 };
            }

            var fromDealer = RoundUpTo100(basePoints * 2) + (state.Honba * 100);
            var fromChild = RoundUpTo100(basePoints * (useTsumoLossless ? 2 : 1)) + (state.Honba * 100);
            return new Core { LimitType = LimitType.Yakuman, SinglePay = 0, DealerEach = 0, ChildFromDealer = fromDealer, ChildFromChild = fromChild };
        }

        var fuKey = NormalizeFuKey(input.Fu, rules);
        var row = new ScoreTable(rules).Get(input.Han, fuKey);

        if (input.Method == AgariMethod.Ron)
        {
            var basePay = winnerIsDealer ? row.DealerRon : row.ChildRon;
            return new Core { LimitType = row.LimitType, SinglePay = basePay + (state.Honba * 300), DealerEach = 0, ChildFromDealer = 0, ChildFromChild = 0 };
        }

        if (winnerIsDealer)
        {
            var dealerEach = useTsumoLossless
                ? RoundUpTo100(row.BasePoints * 3)
                : row.DealerTsumoFromAny;
            return new Core
            {
                LimitType = row.LimitType,
                SinglePay = 0,
                DealerEach = dealerEach + (state.Honba * 100),
                ChildFromDealer = 0,
                ChildFromChild = 0,
            };
        }

        var childFromChild = useTsumoLossless
            ? RoundUpTo100(row.BasePoints * 2)
            : row.ChildTsumoFromChild;
        return new Core
        {
            LimitType = row.LimitType,
            SinglePay = 0,
            DealerEach = 0,
            ChildFromDealer = row.ChildTsumoFromDealer + (state.Honba * 100),
            ChildFromChild = childFromChild + (state.Honba * 100),
        };
    }

    private static int NormalizeFuKey(int fu, RuleConfig rules)
    {
        if (rules.KeepFu25 && fu == 25)
        {
            return 25;
        }

        var rounded = ((fu + 9) / 10) * 10;
        if (rounded < 20 || rounded > 110)
        {
            throw new ArgumentOutOfRangeException(nameof(fu));
        }
        return rounded;
    }

    private static int ResolveTsumoPay(Core core, Seat payerSeat, Seat dealerSeat, bool winnerIsDealer)
    {
        if (winnerIsDealer)
        {
            return core.DealerEach;
        }

        if (payerSeat == dealerSeat)
        {
            return core.ChildFromDealer;
        }

        return core.ChildFromChild;
    }

    private static Seat NextSeat(Seat seat, IReadOnlyList<Seat> activeSeats)
    {
        if (activeSeats.Count == 0)
        {
            throw new InvalidOperationException("Active seats are required.");
        }

        var index = -1;
        for (var i = 0; i < activeSeats.Count; i++)
        {
            if (activeSeats[i] == seat)
            {
                index = i;
                break;
            }
        }
        if (index < 0)
        {
            throw new ArgumentOutOfRangeException(nameof(seat));
        }

        return activeSeats[(index + 1) % activeSeats.Count];
    }

    private static (RoundWind roundWind, int kyoku, bool isFinished) AdvanceKyoku(
        RoundWind currentWind,
        int currentKyoku,
        GameType gameType,
        int playerCount)
    {
        var maxKyoku = playerCount == 3 ? 3 : 4;

        if (currentKyoku < maxKyoku)
        {
            return (currentWind, currentKyoku + 1, false);
        }

        if (currentWind == RoundWind.East)
        {
            if (gameType == GameType.Tonpu)
            {
                return (RoundWind.East, maxKyoku, true);
            }

            return (RoundWind.South, 1, false);
        }

        return (RoundWind.South, maxKyoku, true);
    }

    private static int RoundUpTo100(int value)
    {
        return ((value + 99) / 100) * 100;
    }

    private static int NotenPenaltyTotal(int playerCount)
    {
        return playerCount == 3 ? 1000 : 3000;
    }

    private sealed record Core
    {
        public required LimitType LimitType { get; init; }
        public required int SinglePay { get; init; }
        public required int DealerEach { get; init; }
        public required int ChildFromDealer { get; init; }
        public required int ChildFromChild { get; init; }
    }
}
