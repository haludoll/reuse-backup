# アーキテクチャ設計書

ReuseBackupプロジェクトのアーキテクチャ設計に関する詳細仕様書です。

## 概要

ReuseBackupは、クライアント・サーバー間でHTTP通信を行うiOSアプリケーションエコシステムです。以下の設計原則に基づいて実装されています：

- **モジュラー設計**: 各機能が独立したモジュールとして実装
- **テスト可能性**: 依存性注入とモックオブジェクトによる単体テスト対応
- **拡張性**: 新機能追加時の影響を最小限に抑制
- **保守性**: 明確な責任分離と標準的なデザインパターンの採用

## システム全体構成

```
┌─────────────────────┐    HTTP/Bonjour    ┌─────────────────────┐
│   ReuseBackupClient │ ◄──────────────────► │ ReuseBackupServer   │
│   (新しいiPhone)     │                     │ (古いiPhone)        │
└─────────────────────┘                     └─────────────────────┘
         │                                            │
         ▼                                            ▼
┌─────────────────────┐                     ┌─────────────────────┐
│   APISharedModels   │                     │   APISharedModels   │
│   (共有データ型)     │                     │   (共有データ型)     │
└─────────────────────┘                     └─────────────────────┘
         │                                            │
         ▼                                            ▼
┌─────────────────────┐                     ┌─────────────────────┐
│   HTTPAdapters      │                     │   HTTPAdapters      │
│   (HTTP抽象化)       │                     │   (HTTP抽象化)       │
└─────────────────────┘                     └─────────────────────┘
```

## 主要コンポーネント

### 1. HTTPAdapters（HTTP抽象化層）
- **目的**: HTTPサーバー実装の抽象化
- **場所**: `HTTPAdapters/` Swift Package
- **主要クラス**: `HTTPServerAdapter`, `HummingBirdAdapter`

### 2. APISharedModels（共有APIモデル）
- **目的**: クライアント・サーバー間のデータ型統一
- **場所**: `APISharedModels/` Swift Package
- **主要ファイル**: `openapi.yaml`, 自動生成Swiftコード

### 3. Services層（ビジネスロジック）
- **目的**: 各機能のビジネスロジック実装
- **場所**: 各アプリの`Services/`ディレクトリ
- **主要サービス**: `HTTPServerService`, `BonjourService`, `PhotoLibraryManager`

### 4. ViewModels層（プレゼンテーション）
- **目的**: UIとビジネスロジックの分離
- **場所**: 各アプリの`ViewModels/`ディレクトリ
- **主要ViewModel**: `MessageSendViewModel`, `MediaUploadViewModel`

### 5. Views層（ユーザーインターフェース）
- **目的**: ユーザーインターフェースの実装
- **場所**: 各アプリの`Views/`ディレクトリ
- **主要View**: `MessageSendView`, `MediaUploadView`

## 設計仕様書詳細

### [dependency-injection.md](dependency-injection.md)
依存性注入の設計と実装方針

### [mvvm-pattern.md](mvvm-pattern.md)
MVVMパターンの実装詳細

### [http-adapters.md](http-adapters.md)
HTTPAdaptersの設計と実装

## データフロー

### メッセージ送信フロー
```
MessageSendView → MessageSendViewModel → HTTPClient → HTTPServerService → MessageHandler
```

### メディアアップロードフロー
```
MediaUploadView → MediaUploadViewModel → HTTPClient → HTTPServerService → MediaUploadHandler
```

### サーバー発見フロー
```
ServerDiscoveryView → ServerDiscoveryViewModel → ServerDiscoveryManager → BonjourService
```

## 技術的制約

### iOS最低バージョン
- **サーバー**: iOS 15.0+
- **クライアント**: iOS 17.0+

### 外部依存関係
- **HummingBird**: HTTPサーバー実装
- **swift-openapi-generator**: OpenAPI自動生成
- **Photos Framework**: 写真・動画アクセス

### パフォーマンス要件
- **メモリ使用量**: 大きなファイル処理時も100MB以下
- **ネットワーク効率**: 並行アップロード数は最大3つ
- **UI応答性**: メインスレッドブロック時間は100ms以下

## 将来の拡張計画

### Phase 1: 基本機能完成
- 写真・動画アップロードのサーバーサイド実装完了
- エラーハンドリングの統一

### Phase 2: 高度な機能追加
- 重複ファイル検出機能
- 進捗追跡の詳細化
- バックグラウンドアップロード対応

### Phase 3: パフォーマンス最適化
- メモリ効率の向上
- ネットワーク帯域使用量の最適化
- バッテリー消費の最小化

## 関連資料

- [OpenAPI仕様書](../../APISharedModels/Sources/APISharedModels/openapi.yaml)
- [CLAUDE.md開発ガイドライン](../../../CLAUDE.md)
- [外部仕様書](../../specs/)