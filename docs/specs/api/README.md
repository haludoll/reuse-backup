# ReuseBackup API仕様書

## 概要

ReuseBackupServerが提供するHTTP APIの外部仕様書です。クライアントアプリケーションからサーバーアプリケーションとの通信に使用されます。

## 基本情報

- **プロトコル**: HTTP/1.1
- **ポート**: 8080（デフォルト）
- **データ形式**: JSON
- **文字エンコーディング**: UTF-8
- **タイムゾーン**: UTC

## エンドポイント一覧

### 1. メッセージ送信

#### `POST /api/message`

クライアントからサーバーへメッセージを送信します。

**リクエスト**
```http
POST /api/message HTTP/1.1
Content-Type: application/json

{
  "message": "Hello from client",
  "timestamp": "2025-07-08T12:00:00Z"
}
```

**リクエストパラメータ**
- `message` (string, 必須): メッセージ内容（1-1000文字）
- `timestamp` (string, 必須): 送信時刻（ISO 8601形式）

**成功レスポンス（200 OK）**
```json
{
  "status": "success",
  "received": true,
  "serverTimestamp": "2025-07-08T12:00:01Z"
}
```

**エラーレスポンス（400 Bad Request）**
```json
{
  "status": "error",
  "error": "Invalid JSON format",
  "received": false
}
```

**エラーレスポンス（500 Internal Server Error）**
```json
{
  "status": "error",
  "error": "Internal server error",
  "received": false
}
```

### 2. サーバーステータス取得

#### `GET /api/status`

サーバーの現在のステータスと基本情報を取得します。

**リクエスト**
```http
GET /api/status HTTP/1.1
```

**成功レスポンス（200 OK）**
```json
{
  "status": "running",
  "uptime": 3600,
  "version": "1.0.0",
  "serverTime": "2025-07-08T12:00:00Z"
}
```

**レスポンスパラメータ**
- `status` (string): サーバーステータス
  - `"running"`: 稼働中
  - `"starting"`: 開始中
  - `"stopping"`: 停止中
- `uptime` (integer): 稼働時間（秒）
- `version` (string): サーバーアプリバージョン
- `serverTime` (string): サーバー現在時刻（ISO 8601形式）

## データ形式詳細

### メッセージリクエスト
```json
{
  "message": "string (1-1000文字)",
  "timestamp": "string (ISO 8601形式)"
}
```

### メッセージレスポンス（成功）
```json
{
  "status": "success",
  "received": true,
  "serverTimestamp": "string (ISO 8601形式)"
}
```

### エラーレスポンス
```json
{
  "status": "error",
  "error": "string (エラーメッセージ)",
  "received": false
}
```

### サーバーステータスレスポンス
```json
{
  "status": "string (running|starting|stopping)",
  "uptime": "integer (秒)",
  "version": "string (バージョン)",
  "serverTime": "string (ISO 8601形式)"
}
```

## エラーハンドリング

### HTTPステータスコード
- `200 OK`: 正常処理
- `400 Bad Request`: 無効なリクエスト
- `500 Internal Server Error`: サーバー内部エラー

### 一般的なエラーケース
- **無効なJSON**: リクエストボディが正しいJSON形式でない
- **必須パラメータ不足**: 必須フィールドが不足している
- **文字数制限超過**: メッセージが1000文字を超えている
- **不正な日時形式**: timestampが正しいISO 8601形式でない
- **サーバー内部エラー**: サーバー側での処理エラー

## 使用例

### メッセージ送信の例
```bash
curl -X POST http://192.168.1.100:8080/api/message \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Hello from client",
    "timestamp": "2025-07-08T12:00:00Z"
  }'
```

### サーバーステータス確認の例
```bash
curl -X GET http://192.168.1.100:8080/api/status
```

## 制限事項

- **メッセージ長**: 最大1000文字
- **同時接続**: 制限なし（サーバー能力に依存）
- **リクエスト頻度**: 制限なし
- **認証**: 現在未実装
- **HTTPS**: 現在未対応（HTTP通信のみ）

## 関連仕様

- **[サーバーアプリ仕様](../server/README.md)** - サーバー側の実装詳細
- **[クライアントアプリ仕様](../client/README.md)** - クライアント側の実装詳細
- **[ネットワーク仕様](../network/README.md)** - ネットワーク通信詳細