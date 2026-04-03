# Mahjong Scoreboard プロジェクト - フル技術ハンドオーバー（更新版）

更新日: 2026-02-17
対象: `client/` + `server/` + `deploy/`（UI/接続復旧/デプロイ導線の最新状態）
補足: 本更新にはルーム別ルール、接続再同期、戦績導線、VPS Docker 構成を含む

------------------------------------------------------------------------

# 1. サマリー

フロントエンドは、ルーム単位ルール設定・画像編集（切り抜き）に加え、
再接続時の自動復旧・状態再同期、終局後の戦績保存導線まで含めて運用可能な状態です。
従来の対局進行（リーチ・和了・流局・Undo・席割当・点数修正）は維持しつつ、
盤面表示と終局操作が現場運用向けに拡張されています。

今回の主要追加:
- ルーム作成時のルール設定（切り上げ満貫 / 数え役満）
- `RoomState.rules` のクライアント/サーバー連携
- 和了プレビュー・符候補がルームルールを参照
- アイコン画像の切り抜きUI（ドラッグ + ピンチ/ホイール拡縮）
- アイコン画像サイズ上限の引き上げ（保存 2MB）
- SignalR 再接続時の自動再 Join と定期再同期（5秒間隔）
- `VersionMismatch` 発生時の自動リロード（`joinRoom` 再取得）
- 盤面の `DIFF/SCORE` 切替、席回転、スコア差分表示強化
- 終局パネルでのウマオカ表示・戦績保存・再戦・東風→半荘移行
- VPS Docker + Host Nginx の構成整理（`VPS_DOCKER_DEPLOY.md`）

検証結果（2026-02-17 時点）:
- `flutter analyze`: error/warning 0（info は既存 13 件）
- `dotnet build /t:Compile`（server）: PASS
- `dotnet build`（server）: 実行中プロセスが DLL/EXE をロックしている場合は失敗しうる

------------------------------------------------------------------------

# 2. 現在のフロントエンド構成

## 技術スタック
- Flutter
- Material 3
- SignalR（`signalr_core`）
- HTTP API（`http`）
- ファイル選択（`file_picker`）
- 音声再生（`audioplayers`）
- 画像切り抜き（`crop_your_image`）
- ルーム状態 + 楽観ロック（`expectedVersion`）

## 主要画面
- `HomePage`: ルーム作成/参加、作成時ルール設定
- `RoomPage`: 盤面表示、各種操作、履歴、席割当、点数修正、戦績保存
- `UserManagePage`: ユーザー作成/編集、アイコン設定、リーチボイス設定
- `RecordsPage`: 戦績一覧・統計表示

## 主要ウィジェット
- `Board`
- `SeatCard`
- `AnimatedScore`
- `AgariDialog`
- `SeatAssignSheet`
- `ScoreEditDialog`
- `RyukyokuDialog`
- `LogSheet`
- `IconCropDialog`（新規）

------------------------------------------------------------------------

# 3. 今回の修正内容（反映済み）

## 3.1 ルーム別ルール設定の導入（切り上げ満貫/数え役満）

### client 側
対象:
- `lib/model/models.dart`
- `lib/ui/home_page.dart`
- `lib/util/score_calc.dart`
- `lib/ui/widgets/agari_dialog.dart`
- `lib/ui/room_page.dart`

対応内容:
- `RuleConfig` をモデル追加し、`RoomState.rules` を保持
- ルーム作成 API 送信時に `rules` を含める
- 作成 UI にトグル追加
  - 切り上げ満貫: ON/OFF
  - 数え役満: ON/OFF
- `ScoreCalc` は固定定数を廃止し、`state.rules` を参照
- `AgariDialog` の符候補も `state.rules` 参照に変更
- `RoomPage` 上に現在ルール（切上/数役満）の表示を追加

### server 側（連携変更）
対象:
- `src/MahjongScore.Server/Domain/MahjongDomain.cs`
- `src/MahjongScore.Server/Server/UseCase/UseCases.cs`
- `src/MahjongScore.Server/Program.cs`

対応内容:
- `RoomState.Rules` を追加
- `CreateRoomRequest` に `Rules`（任意）を追加
- ルーム作成時に `Rules` を state に保存
- `MahjongScoreService` はグローバル `RuleConfig` 依存を廃止
- 和了計算時に `state.Rules` を参照して点数テーブルを利用
- DI から固定 `RuleConfig` / `ScoreTable` の登録を削除

## 3.2 アイコン画像登録導線の強化（切り抜き対応）

対象:
- `lib/ui/user_manage_page.dart`
- `lib/ui/widgets/icon_crop_dialog.dart`（新規）
- `pubspec.yaml`
- `src/MahjongScore.Server/Server/UseCase/UseCases.cs`

対応内容:
- 画像選択後に切り抜きダイアログを表示
- 切り抜きダイアログで:
  - 位置調整（ドラッグ）
  - 拡大/縮小（ピンチ・ホイール）
  - 円形UIでのアイコン作成
- `PlatformFile.bytes` が null の場合、`readStream` から読み取りフォールバック
- MIME 判定を拡張子依存だけでなくバイナリシグネチャ優先へ改善
- 依存に `crop_your_image` を追加
- サイズ上限変更:
  - 元画像上限（client）: 8MB
  - 保存画像上限（client）: 2MB
  - API 受け入れ上限（server）: 2MB

## 3.3 接続復旧と状態再同期の強化

対象:
- `lib/gateway/room_gateway.dart`
- `lib/ui/room_page.dart`

対応内容:
- `RoomGateway` に `_activeRoomId/_activeJoinKey` を保持し、再接続後に自動再 Join
- `_connecting` / `_rejoining` により多重接続・多重再 Join を抑止
- Hub 呼び出し失敗時に `reconnect()` を挟んで 1 回再試行
- `RoomPage` で 5 秒周期の状態同期タイマーを追加
- アプリ復帰時（`AppLifecycleState.resumed`）に同期/再接続を試行
- 接続状態（connected/connecting/reconnecting/disconnected）を UI 表示
- `VersionMismatch` 相当エラー時は `joinRoom` 再取得で整合回復

## 3.4 盤面表示とスコア演出の改善

対象:
- `lib/ui/widgets/board.dart`
- `lib/ui/widgets/seat_card.dart`
- `lib/ui/widgets/animated_score.dart`
- `lib/ui/room_page.dart`

対応内容:
- 盤面中央に `DIFF/SCORE` 切替を追加（絶対点/自席基準差分の切替）
- 席回転操作を追加（表示向きのローテーション）
- スコア差分を `deltaParts` で分割表示（供託回収分と通常収支）
- 差分表示時間を操作種別で変更（リーチは短時間、和了系は長時間 + タップ消去）
- リーチ中アバターにリングアニメーションを追加
- 相対点表示では符号表示・符号色分けを有効化

## 3.5 終局導線と戦績連携の強化

対象:
- `lib/ui/room_page.dart`
- `lib/gateway/record_gateway.dart`
- `lib/ui/records_page.dart`
- `lib/util/uma_oka.dart`

対応内容:
- 終局時に順位/最終点/ウマオカ（30返し・50/10/-10/-30）を即時表示
- `/api/rooms/{roomId}/records` で終局戦績を確定保存
- 戦績未保存時の再戦前確認ダイアログを追加
- 東風戦終局時は `GameType.hanchan` への移行操作を提供
- `RecordsPage` で東風/半荘フィルタと集計表示を提供

## 3.6 Docker/VPS デプロイ構成の整理

対象:
- `docker-compose.yml`
- `.env.example`
- `deploy/nginx/example.com.bootstrap.conf`
- `deploy/nginx/example.com.conf`
- `VPS_DOCKER_DEPLOY.md`
- `server/src/MahjongScore.Server/Program.cs`

対応内容:
- `db` / `api` / `client` の 3 コンテナ構成を定義
- `api` / `client` は `127.0.0.1` バインドで公開範囲を制限
- Host Nginx で `/`, `/api/`, `/hubs/room` を適切にプロキシ
- Certbot 発行前後で Nginx 設定を段階化（bootstrap/prod）
- ASP.NET で `ForwardedHeaders` と起動時 Migration（`db.Database.Migrate()`）を適用

------------------------------------------------------------------------

# 4. 現在のランタイム挙動

## 4.1 ルール設定
- ルーム作成時に以下を指定可能:
  - 切り上げ満貫
  - 数え役満
- `keepFu25` は現在 UI には出しておらず `true` 固定送信
- 設定はルーム state に保持され、和了プレビューと実計算の双方に反映

## 4.2 進行操作ガード
`RoomPage` の更新系操作は、接続中かつ非 busy 時に有効:
- リーチ
- 和了入力
- 流局入力
- Undo
- 席割当
- 点数修正

## 4.3 アイコン登録
- 画像選択後に切り抜き画面へ遷移
- 切り抜き結果が 2MB 以下なら `data:image/*;base64,...` として更新 API 送信
- サーバー側で data URL 形式/サイズを再検証

## 4.4 接続復旧と同期
- 切断中は `RoomGateway.connectionStatus` が `disconnected` を通知
- 再接続時は Hub 自動再接続 + ルーム自動再 Join を実施
- 画面表示中は 5 秒ごとに `joinRoom` で整合確認
- 画面復帰時は同期を優先し、未接続時は再接続を先行

## 4.5 スコア表示挙動
- 通常表示: 各席の絶対点を表示
- `DIFF` 表示: 盤面手前席を 0 とした差分表示
- 増減バッジは操作種別で表示時間を変更
- 供託払い出しがある場合は増減を分割表示（例: `+3000` と `+2600`）

## 4.6 終局時導線
- 終局時に順位とウマオカ結果を同パネルに表示
- 「戦績保存」後は保存済み状態を保持
- 「再戦」は保存前警告付きで実行可能
- 東風戦の終局時は半荘移行ボタンを表示（保存導線と併用）

------------------------------------------------------------------------

# 5. 検証ログ（2026-02-17）

実行コマンド:

```bash
flutter analyze
```

結果:
- error/warning は 0
- info は 13 件（既存ルール由来）

実行コマンド:

```bash
dotnet build /t:Compile
```

結果:
- 成功（0 error）

補足:

```bash
dotnet build
```

は、`MahjongScore.Server` 実行中プロセスによる DLL/EXE ロックで失敗する場合がある。
（コード不整合ではなくファイルロック要因）

------------------------------------------------------------------------

# 6. 残課題 / リスク

1. `client/test` が存在せず、自動テスト未整備（接続復旧/同期の回帰を検知しにくい）。
2. `VersionMismatch` 判定が例外文字列依存で、文言変更時に誤検知/見逃しの可能性がある。
3. 5秒周期の同期ポーリングは、同時接続増加時に API 負荷要因になりうる。
4. 画像切り抜き後に 2MB を超えるケースでは再圧縮処理が未実装。
5. ルール変更は「ルーム作成時のみ」で、対局中の変更 UI/API は未提供。
6. サーバープロセス起動中に `dotnet build` が失敗しうる（ロック問題）。

------------------------------------------------------------------------

# 7. 次の推奨作業（優先順）

1. `VersionMismatch` をサーバーのエラーコードで判定し、例外文字列依存を撤廃。
2. 接続復旧まわりの Widget/Integration テストを追加（切断 -> 復帰 -> 再同期）。
3. 画像再圧縮（品質調整）を追加し、2MB 超過時の救済導線を用意。
4. ルールプリセット（例: Mリーグ）を導入し、作成操作を簡略化。
5. 同期ポーリングの間隔/条件を運用値で調整可能にする（設定化）。

------------------------------------------------------------------------

# 8. 主要ファイルマップ

- `lib/model/models.dart`
  `RuleConfig` / `RoomState.rules` を含むドメインモデル

- `lib/ui/home_page.dart`
  ルーム作成 UI（ゲーム種別、初期点、ルール設定）

- `lib/util/score_calc.dart`
  ルームルール参照での和了プレビュー計算

- `lib/gateway/room_gateway.dart`
  SignalR 接続、再接続、ルーム再 Join、Hub 呼び出し再試行

- `lib/ui/room_page.dart`
  対局操作、状態同期、終局パネル、戦績保存/再戦導線

- `lib/ui/widgets/board.dart`
  盤面配置、席回転、`DIFF/SCORE` 表示切替

- `lib/ui/widgets/seat_card.dart`
  各席カード、リーチ演出、点数表示トリガ

- `lib/ui/widgets/animated_score.dart`
  点数アニメーション、増減バッジ、分割差分表示

- `lib/ui/widgets/agari_dialog.dart`
  和了入力と符候補表示（ルール反映）

- `lib/ui/user_manage_page.dart`
  ユーザー編集、アイコン選択/更新フロー

- `lib/ui/widgets/icon_crop_dialog.dart`
  アイコン切り抜き/拡大調整 UI（新規）

- `lib/gateway/record_gateway.dart`
  戦績 API（一覧取得/終局保存）

- `lib/util/uma_oka.dart`
  終局順位計算の表示用ウマオカ定義

- `server/src/MahjongScore.Server/Domain/MahjongDomain.cs`
  `RoomState.Rules` とルール参照計算

- `server/src/MahjongScore.Server/Server/UseCase/UseCases.cs`
  ルーム作成時の Rules 受け取り、アイコンサイズ上限

- `server/src/MahjongScore.Server/Program.cs`
  Minimal API / SignalR / ForwardedHeaders / 起動時 Migration

- `docker-compose.yml`
  `db` / `api` / `client` のコンテナ定義

- `deploy/nginx/example.com.conf`
  HTTPS 本番ルーティング（`/` `/api/` `/hubs/room`）

- `VPS_DOCKER_DEPLOY.md`
  VPS 配備の手順書（DNS から証明書発行、更新手順まで）

------------------------------------------------------------------------

# 9. 今後の編集ガイドライン

- ルール計算の真値は `state.rules` に集約し、UI 固定値を増やさない。
- 接続復旧系は `RoomGateway` に寄せ、画面側に再接続手順を分散させない。
- アイコン更新導線は「取得 -> 切り抜き -> サイズ検証 -> 送信」の順を維持する。
- 競合系エラーは可能な限りコードベース判定へ寄せ、文言依存を増やさない。
- 点数表示ロジック（絶対点/差分/演出）は `Board` と `AnimatedScore` の責務分離を維持する。
- デプロイ手順更新時は `docker-compose.yml`・Nginx 設定・`VPS_DOCKER_DEPLOY.md` を同時更新する。

------------------------------------------------------------------------

END OF DOCUMENT
