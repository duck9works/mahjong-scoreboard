using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MahjongScore.Server.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddMatchRecordSourceAndSoftDelete : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "deleted_at",
                table: "match_records",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "source_type",
                table: "match_records",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.CreateIndex(
                name: "ix_match_records_deleted_at",
                table: "match_records",
                column: "deleted_at");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "ix_match_records_deleted_at",
                table: "match_records");

            migrationBuilder.DropColumn(
                name: "deleted_at",
                table: "match_records");

            migrationBuilder.DropColumn(
                name: "source_type",
                table: "match_records");
        }
    }
}
