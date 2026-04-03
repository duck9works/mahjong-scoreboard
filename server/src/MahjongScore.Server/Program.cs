#nullable enable
using MahjongScore.Domain;
using MahjongScore.Server.Persistence;
using MahjongScore.Server.Repository;
using MahjongScore.Server.Transport;
using MahjongScore.Server.UseCase;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddSignalR();
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    options.KnownIPNetworks.Clear();
    options.KnownProxies.Clear();
});

builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.SetIsOriginAllowed(_ => true)
            .AllowAnyHeader()
            .AllowAnyMethod()
            .AllowCredentials();
    });
});

var connectionString = builder.Configuration.GetConnectionString("MahjongScore");
if (string.IsNullOrWhiteSpace(connectionString))
{
    throw new InvalidOperationException(
        "Connection string 'MahjongScore' is not configured. Set ConnectionStrings__MahjongScore.");
}

builder.Services.AddDbContext<MahjongDbContext>(options => options.UseNpgsql(connectionString));
builder.Services.AddSingleton(new PostgresDatabase(connectionString));
builder.Services.AddSingleton<IUserRepository, PostgresUserRepository>();
builder.Services.AddSingleton<IRoomRepository, PostgresRoomRepository>();
builder.Services.AddSingleton<IMatchRepository, PostgresMatchRepository>();

builder.Services.AddSingleton<MahjongScoreService>();

builder.Services.AddSingleton<UserUseCases>();
builder.Services.AddSingleton<RoomUseCases>();

var app = builder.Build();

using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<MahjongDbContext>();
    db.Database.Migrate();
}

app.UseForwardedHeaders();
app.UseCors();

app.MapHub<RoomHub>("/hubs/room");

app.MapPost("/api/users", (UserUseCases uc, RegisterUserRequest req) =>
{
    var r = uc.Register(req);
    return r.IsSuccess ? Results.Ok(r.Value) : Results.BadRequest(r);
});

app.MapGet("/api/users", (UserUseCases uc) =>
{
    var r = uc.GetAll();
    return Results.Ok(r.Value);
});

app.MapPut("/api/users/{userId}", (UserUseCases uc, string userId, UpdateUserRequest req) =>
{
    var r = uc.Update(userId, req);
    return r.IsSuccess ? Results.Ok(r.Value) : Results.BadRequest(r);
});

app.MapPost("/api/rooms", (RoomUseCases uc, CreateRoomRequest req) =>
{
    var r = uc.Create(req);
    return r.IsSuccess ? Results.Ok(r.Value) : Results.BadRequest(r);
});

app.MapGet("/api/rooms", (RoomUseCases uc) =>
{
    var r = uc.GetRooms();
    return Results.Ok(r.Value);
});

app.MapGet("/api/rooms/{roomId}", (RoomUseCases uc, string roomId, string key) =>
{
    var r = uc.Get(roomId, key);
    if (!r.IsSuccess)
    {
        return r.Error!.Type == UseCaseErrorType.RoomNotFound ? Results.NotFound(r) : Results.Unauthorized();
    }
    return Results.Ok(r.Value);
});

app.MapDelete("/api/rooms/{roomId}", (RoomUseCases uc, string roomId, string key) =>
{
    var r = uc.CloseRoom(roomId, key);
    if (!r.IsSuccess)
    {
        return r.Error!.Type switch
        {
            UseCaseErrorType.RoomNotFound => Results.NotFound(r),
            UseCaseErrorType.JoinKeyMismatch => Results.Json(r, statusCode: StatusCodes.Status401Unauthorized),
            _ => Results.BadRequest(r),
        };
    }

    return Results.Ok(r.Value);
});

app.MapPost("/api/rooms/{roomId}/records", (RoomUseCases uc, string roomId, string key) =>
{
    var r = uc.FinalizeRecord(roomId, key);
    if (!r.IsSuccess)
    {
        return r.Error!.Type switch
        {
            UseCaseErrorType.RoomNotFound => Results.NotFound(r),
            UseCaseErrorType.JoinKeyMismatch => Results.Unauthorized(),
            _ => Results.BadRequest(r),
        };
    }

    return Results.Ok(r.Value);
});

app.MapGet("/api/records", (RoomUseCases uc) =>
{
    var r = uc.GetRecords();
    return Results.Ok(r.Value);
});

app.MapPost("/api/records", (RoomUseCases uc, CreateManualRecordRequest req) =>
{
    var r = uc.CreateManualRecord(req);
    if (!r.IsSuccess)
    {
        return Results.BadRequest(r);
    }

    return Results.Ok(r.Value);
});

app.MapPut("/api/records/{recordId}", (RoomUseCases uc, string recordId, CreateManualRecordRequest req) =>
{
    var r = uc.UpdateRecord(recordId, req);
    if (!r.IsSuccess)
    {
        return r.Error!.Type switch
        {
            UseCaseErrorType.RecordNotFound => Results.NotFound(r),
            UseCaseErrorType.ValidationFailed => Results.BadRequest(r),
            _ => Results.BadRequest(r),
        };
    }

    return Results.Ok(r.Value);
});

app.MapGet("/api/records/{recordId}", (RoomUseCases uc, string recordId) =>
{
    var r = uc.GetRecord(recordId);
    if (!r.IsSuccess)
    {
        return r.Error!.Type switch
        {
            UseCaseErrorType.RecordNotFound => Results.NotFound(r),
            UseCaseErrorType.ValidationFailed => Results.BadRequest(r),
            _ => Results.BadRequest(r),
        };
    }

    return Results.Ok(r.Value);
});

app.MapDelete("/api/records/{recordId}", (RoomUseCases uc, string recordId) =>
{
    var r = uc.DeleteRecord(recordId);
    if (!r.IsSuccess)
    {
        return r.Error!.Type switch
        {
            UseCaseErrorType.RecordNotFound => Results.NotFound(r),
            UseCaseErrorType.ValidationFailed => Results.BadRequest(r),
            _ => Results.BadRequest(r),
        };
    }

    return Results.Ok(r.Value);
});

app.Run();
