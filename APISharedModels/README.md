# APISharedModels

ReuseBackup Server API共有モデル

## 概要

ReuseBackupServerとReuseBackupClientの間で使用されるAPIモデルを定義したSwiftパッケージです。OpenAPI 3.0.3仕様に基づいて自動生成されたモデルを提供します。

## 特徴

- **OpenAPI駆動**: OpenAPI 3.0.3仕様から自動生成
- **型安全**: Swiftの型システムによる安全なAPI通信
- **共有モデル**: サーバーとクライアント間でのモデル一貫性保証

## 構成

- `openapi.yaml`: API仕様定義
- `openapi-generator-config.yaml`: コード生成設定
- 自動生成されたSwiftモデル（Types.swift、Client.swift、Server.swift）

## 使用方法

### 1. 依存関係の追加

Package.swiftに以下を追加：

```swift
dependencies: [
    .package(path: "../APISharedModels")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["APISharedModels"]
    )
]
```

### 2. モデルの使用

```swift
import APISharedModels

// メッセージリクエストの作成
let messageRequest = Components.Schemas.MessageRequest(
    message: "Hello Server",
    timestamp: Date()
)

// サーバーステータスの処理
let serverStatus = Components.Schemas.ServerStatus(
    status: .running,
    uptime: 3600,
    version: "1.0.0",
    serverTime: Date()
)
```

## 開発

### モデルの再生成

OpenAPI仕様を変更した後、以下の手順でモデルを再生成：

1. `openapi.yaml`を更新
2. Xcodeでプロジェクトをビルド（自動的に再生成される）

### API仕様

詳細なAPI仕様は`openapi.yaml`を参照してください。

## APIモデル

### MessageRequest
クライアントからサーバーへのメッセージ送信に使用

### MessageResponse  
サーバーからクライアントへのメッセージ応答に使用

### ServerStatus
サーバーのステータス情報に使用

### ErrorResponse
エラー情報の返却に使用

## テスト

### APIテスト

APIをテストするためのドキュメントとスクリプトが用意されています：

- `TESTING.md`: 詳細なテスト手順とcurlコマンド例
- `test_api.sh`: 基本的なAPIテストスクリプト
- `test_api_detailed.sh`: 包括的なAPIテストスクリプト（エラーケース含む）

### テストの実行

1. シミュレータでReuseBackupServerアプリを起動
2. アプリ内でサーバーを開始
3. 以下のコマンドでテストを実行：

```bash
# 基本テスト
./test_api.sh

# 詳細テスト（エラーケース含む）
./test_api_detailed.sh
```

### 手動テスト

個別のAPIエンドポイントをテストする場合は、`TESTING.md`を参照してcurlコマンドを実行してください。