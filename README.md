# mahjong-scoreboard

リアルタイム麻雀スコア管理アプリです。  
同一ルームを複数端末で共有し、点棒操作・和了入力・流局・履歴・Undo・成績保存を行えます。

- Frontend: Flutter Web
- Backend: ASP.NET Core (.NET 10) + SignalR
- Database: PostgreSQL

## 主な機能

- ルーム作成 / 参加（JoinKey付き）
- リアルタイム同期（SignalR）
- リーチ、鳴き、和了（ロン/ツモ）、流局、Undo
- 対局終了後の成績保存
- 成績一覧、手動登録、編集、削除
- ユーザー管理（表示名、アイコン、リーチボイスID、表示非表示）
- ルールガイド（役一覧、翻符計算、点数表）

## 技術構成

- `client/`: Flutter Web フロントエンド
- `server/`: ASP.NET Core API + SignalR Hub
- `deploy/nginx/`: VPS向け Nginx 設定
- `docker-compose.yml`: `client` / `api` / `db` の起動定義

## Dockerで起動（推奨）

```bash
cp .env.example .env
docker compose build
docker compose up -d
docker compose ps
```

ローカル確認先:

- Web: `http://127.0.0.1:17001`
- API: `http://127.0.0.1:17000`

`.env` の主な項目:

```dotenv
POSTGRES_DB=mahjong_scoreboard_db
POSTGRES_USER=mahjong
POSTGRES_PASSWORD=change_me
API_BASE_URL=http://127.0.0.1:17000
```

`.env` や実運用の接続情報（接続先ホスト/パスワード）は Git にコミットしないでください。

## ローカル開発（Dockerを使わない実行）

### 1) PostgreSQLを用意

例: DBだけ Compose で起動

```bash
docker compose up -d db
```

### 2) Server

PowerShell:

```powershell
$env:ConnectionStrings__MahjongScore="Host=localhost;Port=5432;Database=mahjong_scoreboard_db;Username=mahjong;Password=change_me"
dotnet restore server/src/MahjongScore.Server/MahjongScore.Server.csproj
dotnet run --project server/src/MahjongScore.Server/MahjongScore.Server.csproj
```

既定: `http://localhost:5000`

### 3) Client (Flutter Web)

```bash
cd client
flutter pub get
flutter run -d chrome --web-port 5173 --dart-define=API_BASE_URL=http://localhost:5000
```

## リーチボイス音声の扱い

リポジトリにはリーチボイス音声（mp3）を含めていません。

- プレースホルダ: `client/assets/voices/`

音声を有効化する場合は、`client/assets/voices/README.md` に記載のファイル名（`voice_01.mp3` 〜 `voice_08.mp3`）で、自前で合法な音源を配置してください。

## 制約・注意

- 認証/認可は未実装です（JoinKeyベースの操作制御のみ）。
- 本番公開時は Nginx 等のリバースプロキシ配下での運用を前提としています。
- サーバ起動時に `db.Database.Migrate()` を実行します。

## 補足ドキュメント

- DBマイグレーション: `server/MIGRATIONS.md`
- VPSデプロイ: `VPS_DOCKER_DEPLOY.md`
