# ReuseBackup 外部仕様書

## 概要

ReuseBackupは、古いiPhoneを写真・動画のローカルバックアップサーバーとして再利用する革新的なiOSアプリケーションエコシステムです。このドキュメントでは、ユーザーから見える外部仕様について説明します。

## 仕様書構成

### アプリケーション仕様
- **[サーバーアプリ仕様](./server/README.md)** - ReuseBackupServer（古いiPhone用）
- **[クライアントアプリ仕様](./client/README.md)** - ReuseBackupClient（新しいiPhone用）

### 共通仕様
- **[API仕様](../../APISharedModels/Sources/APISharedModels/openapi.yaml)** - サーバー・クライアント間の通信仕様（OpenAPI形式）
- **[ネットワーク仕様](./network/README.md)** - サーバー発見とネットワーク通信

### 機能仕様
- **[メッセージング機能](./features/messaging.md)** - メッセージ送受信機能
- **[サーバー発見機能](./features/server-discovery.md)** - Bonjourベースのサーバー発見

## 対応バージョン

- **サーバーアプリ**: iOS 15.0+
- **クライアントアプリ**: iOS 17.0+  
- **API バージョン**: v1.0.0

## 更新履歴

- **2025-07-08**: 初版作成（基本メッセージング機能）

---

*このドキュメントは現在の実装に基づいて作成されています。*