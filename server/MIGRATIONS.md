# EF Core Migrations

## 1) Connection string (PowerShell)

```powershell
$env:ConnectionStrings__MahjongScore="Host=YOUR_HOST;Port=5432;Database=mahjong_scoreboard;Username=YOUR_USER;Password=YOUR_PASS"
```

## 2) Apply existing migrations

From repository root (`mahjong-scoreboard/`):

```powershell
dotnet ef database update `
  --project server/src/MahjongScore.Server/MahjongScore.Server.csproj `
  --startup-project server/src/MahjongScore.Server/MahjongScore.Server.csproj
```

From `server/` directory:

```powershell
dotnet ef database update `
  --project src/MahjongScore.Server/MahjongScore.Server.csproj `
  --startup-project src/MahjongScore.Server/MahjongScore.Server.csproj
```

## 3) Create a new migration

From repository root (`mahjong-scoreboard/`):

```powershell
dotnet ef migrations add <MigrationName> `
  --project server/src/MahjongScore.Server/MahjongScore.Server.csproj `
  --startup-project server/src/MahjongScore.Server/MahjongScore.Server.csproj
```

From `server/` directory:

```powershell
dotnet ef migrations add <MigrationName> `
  --project src/MahjongScore.Server/MahjongScore.Server.csproj `
  --startup-project src/MahjongScore.Server/MahjongScore.Server.csproj
```

## 4) Apply after creating migration

From repository root (`mahjong-scoreboard/`):

```powershell
dotnet ef database update `
  --project server/src/MahjongScore.Server/MahjongScore.Server.csproj `
  --startup-project server/src/MahjongScore.Server/MahjongScore.Server.csproj
```

From `server/` directory:

```powershell
dotnet ef database update `
  --project src/MahjongScore.Server/MahjongScore.Server.csproj `
  --startup-project src/MahjongScore.Server/MahjongScore.Server.csproj
```

## Optional: update dotnet-ef tool

If EF tools version warning appears:

```powershell
dotnet tool update --global dotnet-ef --version 10.0.3
```
