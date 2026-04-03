#nullable enable
using MahjongScore.Domain;
using MahjongScore.Server.UseCase;
using Microsoft.AspNetCore.SignalR;

namespace MahjongScore.Server.Transport;

public sealed class RoomHub : Hub
{
    private readonly RoomUseCases _rooms;

    public RoomHub(RoomUseCases rooms)
    {
        _rooms = rooms;
    }

    public async Task<UseCaseResult<GetRoomResponse>> JoinRoom(string roomId, string joinKey)
    {
        var result = _rooms.Get(roomId, joinKey);
        if (!result.IsSuccess)
        {
            return result;
        }

        await Groups.AddToGroupAsync(Context.ConnectionId, roomId);
        await Clients.Caller.SendAsync("LogsUpdated", result.Value!.Logs);
        return result;
    }

    public async Task<UseCaseResult<SetSeatResponse>> SetSeat(string roomId, string joinKey, SeatAssignmentInput input)
    {
        var result = _rooms.SetSeat(roomId, joinKey, input);
        if (!result.IsSuccess)
        {
            return result;
        }

        await Clients.Group(roomId).SendAsync("StateUpdated", result.Value!.State);
        await Clients.Group(roomId).SendAsync("LogsUpdated", result.Value!.Logs);
        return result;
    }

    public async Task<UseCaseResult<SetSeatsResponse>> SetSeats(string roomId, string joinKey, SeatAssignmentsInput input)
    {
        var result = _rooms.SetSeats(roomId, joinKey, input);
        if (!result.IsSuccess)
        {
            return result;
        }

        await Clients.Group(roomId).SendAsync("StateUpdated", result.Value!.State);
        await Clients.Group(roomId).SendAsync("LogsUpdated", result.Value!.Logs);
        return result;
    }

    public async Task<UseCaseResult<GameTypeResponse>> SetGameType(string roomId, string joinKey, GameTypeInput input)
    {
        var result = _rooms.SetGameType(roomId, joinKey, input);
        if (!result.IsSuccess)
        {
            return result;
        }

        await Clients.Group(roomId).SendAsync("StateUpdated", result.Value!.State);
        await Clients.Group(roomId).SendAsync("LogsUpdated", result.Value!.Logs);
        return result;
    }

    public async Task<UseCaseResult<EditScoresResponse>> EditScores(string roomId, string joinKey, ScoreEditInput input)
    {
        var result = _rooms.EditScores(roomId, joinKey, input);
        if (!result.IsSuccess)
        {
            return result;
        }

        await Clients.Group(roomId).SendAsync("StateUpdated", result.Value!.State);
        await Clients.Group(roomId).SendAsync("LogsUpdated", result.Value!.Logs);
        return result;
    }

    public async Task<UseCaseResult<RiichiResponse>> DeclareRiichi(string roomId, string joinKey, RiichiInput input)
    {
        var result = _rooms.Riichi(roomId, joinKey, input);
        if (!result.IsSuccess)
        {
            return result;
        }

        await Clients.Group(roomId).SendAsync("StateUpdated", result.Value!.State);
        await Clients.Group(roomId).SendAsync("LogsUpdated", result.Value!.Logs);
        return result;
    }

    public async Task<UseCaseResult<FuroResponse>> DeclareFuro(string roomId, string joinKey, FuroInput input)
    {
        var result = _rooms.Furo(roomId, joinKey, input);
        if (!result.IsSuccess)
        {
            return result;
        }

        await Clients.Group(roomId).SendAsync("StateUpdated", result.Value!.State);
        await Clients.Group(roomId).SendAsync("LogsUpdated", result.Value!.Logs);
        return result;
    }

    public async Task<UseCaseResult<AgariResponse>> EnterAgari(string roomId, string joinKey, AgariInput input)
    {
        var result = _rooms.Agari(roomId, joinKey, input);
        if (!result.IsSuccess)
        {
            return result;
        }

        await Clients.Group(roomId).SendAsync("StateUpdated", result.Value!.State);
        await Clients.Group(roomId).SendAsync("LogsUpdated", result.Value!.Logs);
        return result;
    }

    public async Task<UseCaseResult<RyukyokuResponse>> EnterRyukyoku(string roomId, string joinKey, RyukyokuInput input)
    {
        var result = _rooms.Ryukyoku(roomId, joinKey, input);
        if (!result.IsSuccess)
        {
            return result;
        }

        await Clients.Group(roomId).SendAsync("StateUpdated", result.Value!.State);
        await Clients.Group(roomId).SendAsync("LogsUpdated", result.Value!.Logs);
        return result;
    }

    public async Task<UseCaseResult<UndoResponse>> Undo(string roomId, string joinKey, UndoInput input)
    {
        var result = _rooms.Undo(roomId, joinKey, input);
        if (!result.IsSuccess)
        {
            return result;
        }

        await Clients.Group(roomId).SendAsync("StateUpdated", result.Value!.State);
        await Clients.Group(roomId).SendAsync("LogsUpdated", result.Value!.Logs);
        return result;
    }

    public async Task<UseCaseResult<RematchResponse>> Rematch(string roomId, string joinKey, RematchInput input)
    {
        var result = _rooms.Rematch(roomId, joinKey, input);
        if (!result.IsSuccess)
        {
            return result;
        }

        await Clients.Group(roomId).SendAsync("StateUpdated", result.Value!.State);
        await Clients.Group(roomId).SendAsync("LogsUpdated", result.Value!.Logs);
        return result;
    }
}
