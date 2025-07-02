# API Testing Guide

このドキュメントでは、ReuseBackup Server APIをcurlコマンドでテストする方法を説明します。

## 前提条件

1. シミュレータでReuseBackupServerアプリを起動
2. アプリ内でサーバーを開始（通常は`localhost:8080`で動作）
3. ターミナルでcurlコマンドを実行

## API エンドポイント

### GET /api/status
サーバーのステータス情報を取得します。

**リクエスト例:**
```bash
curl -X GET "http://localhost:8080/api/status" \
  -H "Accept: application/json" \
  -v
```

**レスポンス例:**
```json
{
  "status": "running",
  "uptime": 1800,
  "version": "1.0.0",
  "serverTime": "2025-07-02T14:30:00Z"
}
```

### POST /api/message
クライアントからサーバーにメッセージを送信します。

**リクエスト例:**
```bash
curl -X POST "http://localhost:8080/api/message" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{
    "message": "Hello from client",
    "timestamp": "2025-07-02T14:30:00Z"
  }' \
  -v
```

**レスポンス例:**
```json
{
  "status": "success",
  "received": true,
  "serverTimestamp": "2025-07-02T14:30:01Z"
}
```

## テストケース

### 1. 基本的な動作確認

#### サーバーステータス確認
```bash
curl -X GET "http://localhost:8080/api/status" \
  -H "Accept: application/json"
```

#### メッセージ送信（英語）
```bash
curl -X POST "http://localhost:8080/api/message" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{
    "message": "Hello from client",
    "timestamp": "2025-07-02T14:30:00Z"
  }'
```

#### メッセージ送信（日本語）
```bash
curl -X POST "http://localhost:8080/api/message" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{
    "message": "こんにちは、サーバーからのテストメッセージです",
    "timestamp": "2025-07-02T14:35:00Z"
  }'
```

#### 接続テスト用メッセージ
```bash
curl -X POST "http://localhost:8080/api/message" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{
    "message": "Connection test",
    "timestamp": "2025-07-02T14:40:00Z"
  }'
```

### 2. エラーケーステスト

#### 無効なJSON形式
```bash
curl -X POST "http://localhost:8080/api/message" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{
    "message": "Invalid JSON"
    "timestamp": "2025-07-02T14:45:00Z"
  }'
```

**期待される結果:** 400 Bad Request

#### 必須フィールド不足
```bash
curl -X POST "http://localhost:8080/api/message" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{
    "timestamp": "2025-07-02T14:50:00Z"
  }'
```

**期待される結果:** 400 Bad Request

#### 無効なタイムスタンプ形式
```bash
curl -X POST "http://localhost:8080/api/message" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{
    "message": "Invalid timestamp test",
    "timestamp": "2025/07/02 14:55:00"
  }'
```

**期待される結果:** 400 Bad Request

### 3. 許可されていないメソッドのテスト

#### GET /api/message（許可されていない）
```bash
curl -X GET "http://localhost:8080/api/message" \
  -H "Accept: application/json"
```

**期待される結果:** 405 Method Not Allowed

#### DELETE /api/message（許可されていない）
```bash
curl -X DELETE "http://localhost:8080/api/message" \
  -H "Accept: application/json"
```

**期待される結果:** 405 Method Not Allowed

## エラーレスポンス

API呼び出しでエラーが発生した場合、以下の形式でエラー情報が返されます：

```json
{
  "status": "error",
  "error": "Invalid message format",
  "received": false
}
```

## 自動テストスクリプト

より効率的なテストのために、自動テストスクリプトが用意されています：

```bash
# 基本テストスクリプトの実行
./test_api.sh

# 詳細テストスクリプトの実行
./test_api_detailed.sh
```

## トラブルシューティング

### Connection refused エラー
- シミュレータでReuseBackupServerアプリが起動していることを確認
- アプリ内でサーバーが開始されていることを確認
- ポート番号が8080であることを確認

### JSON形式エラー
- リクエストボディが有効なJSON形式であることを確認
- `Content-Type: application/json`ヘッダーが設定されていることを確認

### タイムスタンプエラー
- ISO 8601形式（`YYYY-MM-DDTHH:mm:ssZ`）でタイムスタンプを指定
- UTC時刻を使用することを推奨

## 注意事項

- すべての日時はISO 8601形式（UTC）で指定してください
- メッセージの最大長は1000文字です
- サーバーは開発・テスト目的のため、本番環境での使用は想定されていません