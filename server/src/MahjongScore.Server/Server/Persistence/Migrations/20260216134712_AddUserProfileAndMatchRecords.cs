using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MahjongScore.Server.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddUserProfileAndMatchRecords : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "icon_data_url",
                table: "users",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "riichi_voice_id",
                table: "users",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.CreateTable(
                name: "match_records",
                columns: table => new
                {
                    match_id = table.Column<Guid>(type: "uuid", nullable: false),
                    room_id = table.Column<string>(type: "text", nullable: false),
                    started_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    ended_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    participants_json = table.Column<string>(type: "jsonb", nullable: false),
                    final_state_json = table.Column<string>(type: "jsonb", nullable: false),
                    logs_json = table.Column<string>(type: "jsonb", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_match_records", x => x.match_id);
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "match_records");

            migrationBuilder.DropColumn(
                name: "icon_data_url",
                table: "users");

            migrationBuilder.DropColumn(
                name: "riichi_voice_id",
                table: "users");
        }
    }
}
