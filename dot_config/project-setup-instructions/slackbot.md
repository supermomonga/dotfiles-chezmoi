# Slack Bot プロジェクト構成ガイド

Bun + TypeScript + Slack Bolt (Socket Mode) による Slack Bot の構成テンプレート。
VPS 上で systemd により常駐運用する想定。

---

## 技術スタック

| レイヤー | 技術 | 備考 |
|---------|------|------|
| ランタイム | **Bun** (latest) | Node.js は使わない |
| 言語 | **TypeScript** (ES2020, strict) | |
| Slack SDK | **@slack/bolt** | Socket Mode で接続 |
| DB | **bun:sqlite** (Bun 組み込み) | 外部 DB 不要 |
| スケジューラ | **croner** | タイムゾーン指定対応の cron |
| 設定ファイル | **smol-toml** | TOML 形式で管理 |
| デプロイ | **systemd** | Docker は使わない |
| ツール管理 | **mise** | Bun のバージョン固定 |

### 使わないもの

- **Express / Koa / HTTP サーバー** — Socket Mode なので不要
- **Docker** — VPS + systemd でシンプルに運用
- **dotenv** — Bun が `.env` を自動読み込みする
- **better-sqlite3 / pg / ioredis** — Bun 組み込み API を使う
- **ws** — Bun 組み込み WebSocket を使う
- **node:fs の readFile/writeFile** — `Bun.file` を優先
- **Trigger (Slack のトリガー機能)** — 使わない。cron ベースでスケジュール管理する
- **Slack の Workflow Builder / ワークフロー** — Bot コード内で完結させる

---

## プロジェクト構成

```
project-name/
├── src/
│   ├── main.ts          # エントリポイント: 初期化・起動
│   ├── config.ts        # TOML 設定の読み込み・バリデーション
│   ├── slack.ts         # Slack API ラッパー関数
│   ├── cron.ts          # cron ジョブの定義
│   ├── actions.ts       # Slack インタラクション (ボタン等) のハンドラ
│   ├── db.ts            # SQLite CRUD 操作
│   └── ...              # 必要に応じてモジュール追加
├── deploy/
│   └── project-name.service  # systemd ユニットファイル
├── package.json
├── tsconfig.json
├── mise.toml
├── CLAUDE.md
├── .gitignore
└── bun.lock
```

---

## Slack 接続方式: Socket Mode

HTTP エンドポイントを公開せず、WebSocket で Slack と接続する。

- ファイアウォールのインバウンド設定不要
- ポート公開不要
- 3 つのトークンが必要:
  - `SLACK_BOT_TOKEN` (xoxb-) — Bot User OAuth Token
  - `SLACK_SIGNING_SECRET` — リクエスト署名検証用
  - `SLACK_APP_TOKEN` (xapp-) — App-Level Token (`connections:write` スコープ)

```ts
import { App } from "@slack/bolt";

const app = new App({
  token: process.env.SLACK_BOT_TOKEN,
  signingSecret: process.env.SLACK_SIGNING_SECRET,
  socketMode: true,
  appToken: process.env.SLACK_APP_TOKEN,
});

await app.start();
```

### Bot Token のスコープ例

- `chat:write` — メンバーになっているチャンネルへの投稿
- `chat:write.public` — パブリックチャンネルへの投稿 (未参加でも可)
- `users.profile:read` — ユーザー表示名の取得

---

## 設定管理

**秘密情報 (トークン等)** と **アプリ設定** を分離する。

### 環境変数 (`.env`)

```
SLACK_BOT_TOKEN=xoxb-...
SLACK_SIGNING_SECRET=...
SLACK_APP_TOKEN=xapp-...
```

- 配置先: `~/.config/<project-name>/.env`
- Bun が自動読み込みするため dotenv は不要
- `.gitignore` に追加して Git 管理外にする

### アプリ設定 (`config.toml`)

```toml
[slack]
channel_id = "C0123456789"
admin_id = "U0123456789"

[[schedules]]
name = "定時タスク"
post_cron = "0 9 * * 1-5"
check_cron = "30 9 * * 1-5"
```

- 配置先: `~/.config/<project-name>/config.toml`
- `smol-toml` でパース
- バリデーションを `loadConfig()` 内で行い、不足フィールドは明確なエラーメッセージを出す

---

## データベース (SQLite)

Bun 組み込みの `bun:sqlite` を使う。

```ts
import { Database } from "bun:sqlite";
import { mkdirSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";

const dataDir = join(homedir(), ".local/share/<project-name>");
mkdirSync(dataDir, { recursive: true });

const db = new Database(join(dataDir, "app.db"));
db.run("PRAGMA journal_mode = WAL");
```

### 設計方針

- **WAL モード有効化** — クラッシュ耐性の向上
- **UPSERT パターン** (`INSERT OR REPLACE`) — 冪等性の確保
- データファイルは `~/.local/share/<project-name>/` に配置 (XDG 準拠)

---

## cron ジョブ

`croner` を使い、タイムゾーンを明示的に指定する。

```ts
import { Cron } from "croner";

new Cron(
  "0 9 * * 1-5",
  { timezone: "Asia/Tokyo" },
  async () => {
    // ジョブ処理
  }
);
```

### 設計方針

- タイムゾーンは必ず `Asia/Tokyo` を明示する (サーバーの TZ 設定に依存しない)
- 祝日判定には `@holiday-jp/holiday_jp` を使う
- スケジュール定義は `config.toml` に外出しする

---

## Slack インタラクション

Block Kit のボタン等のインタラクションは `app.action()` で処理する。

### 設計方針

- ボタン押下後は `chat.update` でメッセージを更新し、ボタンを無効化する
- メッセージの `ts` (タイムスタンプ) を DB に保存し、操作対象の特定に使う
- 重複操作の防止: DB の状態を確認してから処理する (冪等性)

---

## エラーハンドリング

- 各 async 関数を try-catch で囲む
- `console.log` / `console.error` でログ出力 (`[モジュール名]` プレフィックス付き)
- journalctl でログを確認する想定
- 外部のエラー通知サービスは使わない (シンプルさ優先)

---

## デプロイ (systemd)

### ユニットファイル例

```ini
[Unit]
Description=<Project Name>
After=network.target

[Service]
Type=simple
User=code
WorkingDirectory=/home/code/ghq/github.com/<org>/<project-name>
EnvironmentFile=/home/code/.config/<project-name>/.env
ExecStart=/usr/local/bin/bun run src/main.ts
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

### デプロイ手順

```bash
# ユニットファイルの配置
sudo cp deploy/<project-name>.service /etc/systemd/system/

# 有効化 & 起動
sudo systemctl enable --now <project-name>

# ログ確認
journalctl -u <project-name> -f

# 再起動
sudo systemctl restart <project-name>
```

---

## TypeScript 設定

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ES2020",
    "moduleResolution": "bundler",
    "strict": true,
    "skipLibCheck": true,
    "types": ["bun-types"]
  }
}
```

---

## パッケージ管理

```bash
# 依存追加
bun add @slack/bolt croner smol-toml @holiday-jp/holiday_jp

# 型定義
bun add -d bun-types @types/bun

# インストール
bun install
```

---

## 開発時コマンド

```bash
# 起動 (HMR 付き)
bun --hot src/main.ts

# テスト
bun test

# 型チェック
bunx tsc --noEmit
```

---

## 設計原則まとめ

1. **Socket Mode** — HTTP サーバー不要、ポート公開不要
2. **Bun ファースト** — ランタイム組み込み API を最大限活用
3. **設定とシークレットの分離** — TOML (設定) + .env (秘密情報)
4. **XDG 準拠のパス** — `~/.config/` (設定), `~/.local/share/` (データ)
5. **タイムゾーン明示** — サーバー設定に依存しない
6. **冪等な操作** — UPSERT、重複チェック
7. **シンプルな運用** — systemd + journalctl、Docker 不使用
8. **Slack トリガー/ワークフロー不使用** — cron + Bot コードで完結
9. **最小限の外部依存** — Bun 組み込みで賄えるものは組み込みを使う
10. **エラーは console + journalctl** — 外部通知サービスは使わない
