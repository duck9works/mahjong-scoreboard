#nullable enable
using Microsoft.EntityFrameworkCore;

namespace MahjongScore.Server.Persistence;

public sealed class MahjongDbContext : DbContext
{
    public MahjongDbContext(DbContextOptions<MahjongDbContext> options)
        : base(options)
    {
    }

    public DbSet<UserEntity> Users => Set<UserEntity>();
    public DbSet<RoomEntity> Rooms => Set<RoomEntity>();
    public DbSet<MatchRecordEntity> MatchRecords => Set<MatchRecordEntity>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        var users = modelBuilder.Entity<UserEntity>();
        users.ToTable("users");
        users.HasKey(x => x.UserId);
        users.Property(x => x.UserId).HasColumnName("user_id");
        users.Property(x => x.DisplayName).HasColumnName("display_name").IsRequired();
        users.Property(x => x.IconDataUrl).HasColumnName("icon_data_url");
        users.Property(x => x.RiichiVoiceId).HasColumnName("riichi_voice_id").HasDefaultValue(0);
        users.Property(x => x.IsHidden).HasColumnName("is_hidden").HasDefaultValue(false);
        users.Property(x => x.CreatedAt).HasColumnName("created_at").HasDefaultValueSql("now()");

        var rooms = modelBuilder.Entity<RoomEntity>();
        rooms.ToTable("rooms");
        rooms.HasKey(x => x.RoomId);
        rooms.Property(x => x.RoomId).HasColumnName("room_id");
        rooms.Property(x => x.JoinKey).HasColumnName("join_key").IsRequired();
        rooms.Property(x => x.StateJson).HasColumnName("state_json").HasColumnType("jsonb").IsRequired();
        rooms.Property(x => x.LogsJson).HasColumnName("logs_json").HasColumnType("jsonb").IsRequired();
        rooms.Property(x => x.HistoryJson).HasColumnName("history_json").HasColumnType("jsonb").IsRequired();
        rooms.Property(x => x.Seq).HasColumnName("seq");
        rooms.Property(x => x.CreatedAt).HasColumnName("created_at").HasDefaultValueSql("now()");

        var records = modelBuilder.Entity<MatchRecordEntity>();
        records.ToTable("match_records");
        records.HasKey(x => x.MatchId);
        records.Property(x => x.MatchId).HasColumnName("match_id");
        records.Property(x => x.RoomId).HasColumnName("room_id").IsRequired();
        records.Property(x => x.StartedAt).HasColumnName("started_at");
        records.Property(x => x.EndedAt).HasColumnName("ended_at");
        records.Property(x => x.ParticipantsJson).HasColumnName("participants_json").HasColumnType("jsonb").IsRequired();
        records.Property(x => x.FinalStateJson).HasColumnName("final_state_json").HasColumnType("jsonb").IsRequired();
        records.Property(x => x.LogsJson).HasColumnName("logs_json").HasColumnType("jsonb").IsRequired();
        records.Property(x => x.SourceType).HasColumnName("source_type").HasDefaultValue(0);
        records.Property(x => x.DeletedAt).HasColumnName("deleted_at");
        records.HasIndex(x => x.DeletedAt).HasDatabaseName("ix_match_records_deleted_at");
    }
}

public sealed class UserEntity
{
    public Guid UserId { get; set; }
    public string DisplayName { get; set; } = string.Empty;
    public string? IconDataUrl { get; set; }
    public int RiichiVoiceId { get; set; }
    public bool IsHidden { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
}

public sealed class RoomEntity
{
    public string RoomId { get; set; } = string.Empty;
    public string JoinKey { get; set; } = string.Empty;
    public string StateJson { get; set; } = "{}";
    public string LogsJson { get; set; } = "[]";
    public string HistoryJson { get; set; } = "[]";
    public long Seq { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
}

public sealed class MatchRecordEntity
{
    public Guid MatchId { get; set; }
    public string RoomId { get; set; } = string.Empty;
    public DateTimeOffset StartedAt { get; set; }
    public DateTimeOffset EndedAt { get; set; }
    public string ParticipantsJson { get; set; } = "[]";
    public string FinalStateJson { get; set; } = "{}";
    public string LogsJson { get; set; } = "[]";
    public int SourceType { get; set; }
    public DateTimeOffset? DeletedAt { get; set; }
}
