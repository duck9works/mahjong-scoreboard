#nullable enable
using Microsoft.Extensions.Configuration;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace MahjongScore.Server.Persistence;

public sealed class MahjongDbContextFactory : IDesignTimeDbContextFactory<MahjongDbContext>
{
    public MahjongDbContext CreateDbContext(string[] args)
    {
        var basePath = ResolveProjectPath();
        var environment = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") ?? "Development";

        var configuration = new ConfigurationBuilder()
            .SetBasePath(basePath)
            .AddJsonFile("appsettings.json", optional: true, reloadOnChange: false)
            .AddJsonFile($"appsettings.{environment}.json", optional: true, reloadOnChange: false)
            .AddEnvironmentVariables()
            .Build();

        var connectionString = configuration.GetConnectionString("MahjongScore")
            ?? Environment.GetEnvironmentVariable("MAHJONGSCORE_CONNECTION_STRING");
        if (string.IsNullOrWhiteSpace(connectionString))
        {
            throw new InvalidOperationException(
                "Connection string 'MahjongScore' is not configured. Set appsettings.json or ConnectionStrings__MahjongScore.");
        }

        var optionsBuilder = new DbContextOptionsBuilder<MahjongDbContext>();
        optionsBuilder.UseNpgsql(connectionString);

        return new MahjongDbContext(optionsBuilder.Options);
    }

    private static string ResolveProjectPath()
    {
        var current = Directory.GetCurrentDirectory();

        if (File.Exists(Path.Combine(current, "MahjongScore.Server.csproj")))
        {
            return current;
        }

        var fromCurrent = FindProjectPathUpward(current);
        if (fromCurrent is not null)
        {
            return fromCurrent;
        }

        var nested = Path.Combine(current, "server", "src", "MahjongScore.Server");
        if (File.Exists(Path.Combine(nested, "MahjongScore.Server.csproj")))
        {
            return nested;
        }

        var assemblyDir = Path.GetDirectoryName(typeof(MahjongDbContextFactory).Assembly.Location);
        if (!string.IsNullOrWhiteSpace(assemblyDir))
        {
            var fromAssembly = FindProjectPathUpward(assemblyDir);
            if (fromAssembly is not null)
            {
                return fromAssembly;
            }
        }

        return current;
    }

    private static string? FindProjectPathUpward(string path)
    {
        var cursor = new DirectoryInfo(path);
        while (cursor is not null)
        {
            if (File.Exists(Path.Combine(cursor.FullName, "MahjongScore.Server.csproj")))
            {
                return cursor.FullName;
            }

            cursor = cursor.Parent;
        }

        return null;
    }
}
