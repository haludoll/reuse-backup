# HTTPAdapters

HTTPサーバーの抽象化レイヤーを提供するSwiftパッケージ群です。

## 概要

ReuseBackupServerアプリで直接HummingBirdを使用せず、統一されたインターフェースでHTTPサーバー機能を利用するためのアダプターパターン実装です。

## パッケージ構成

### HTTPServerAdapters
- **目的**: HTTPサーバーの統一インターフェース提供
- **対応**: HummingBird v1.x（iOS 15+対応）
- **場所**: `HTTPServerAdapters/`

## 開発経緯

1. **初期計画**: HummingBird v1/v2の複数サーバー対応
2. **アーキテクチャ変更**: iOS17+でv2、iOS15-17でv1の分離パッケージ構成を試行
3. **依存関係問題**: Swift Package Managerの推移的依存でiOS15+とiOS17+の同時サポートが不可能と判明
4. **最終決定**: HummingBird v1.xのみでiOS15+対応の単一パッケージに統一

## 使用方法

```swift
import HTTPServerAdapters

// サーバー作成
let server = HTTPServerAdapterFactory.createServer(port: 8080)

// ルート追加
await server.appendRoute(
    HTTPRouteInfo(method: .get, path: "/api/status"),
    to: statusHandler
)

// サーバー開始
try await server.run()
```

## 今後の計画

iOS15サポート終了時にHummingBird v2への移行を検討予定です。