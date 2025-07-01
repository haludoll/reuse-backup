# CLAUDE.md

このファイルは、このリポジトリでコードを扱う際にClaude Code (claude.ai/code) にガイダンスを提供します。

## プロジェクト概要

ReuseBackupは、古いiPhoneを写真・動画のローカルバックアップサーバーとして再利用する革新的なiOSアプリケーションエコシステムです。このプロジェクトは2つの独立したiOSアプリケーションで構成されています：

1. **ReuseBackupServer** - 古いiPhone（iOS 15+）で動作、HTTPサーバーとして機能
2. **ReuseBackupClient** - 新しいiPhone（iOS 17+）で動作、サーバーにコンテンツをアップロード

**現在のステータス**: 計画・ドキュメント作成段階 - ソースコードは未実装

## 技術スタック

- **言語**: Swift（サーバー: 5.9+、クライアント: 6.0+）
- **フレームワーク**: 
  - サーバー: FlyingFox HTTPサーバー、Bonjourサービス発見
  - クライアント: SwiftUI、HTTPリクエスト用URLSession
- **アーキテクチャ**: 単方向HTTP通信（クライアント → サーバー）
- **プラットフォーム**: ローカル専用・プライバシー重視のiOS

## 計画されたディレクトリ構造

```
ReuseBackupServer/          # 古いiPhone用サーバーアプリ
├── Sources/
│   ├── Models/            # コアデータモデル
│   ├── Network/           # HTTPサーバー、Bonjour
│   ├── Storage/           # ファイル管理
│   └── UI/               # UIKitベースのUI
└── Tests/

ReuseBackupClient/          # 新しいiPhone用クライアントアプリ
├── Sources/
│   ├── Models/            # コアデータモデル
│   ├── Network/           # HTTPクライアント、発見機能
│   ├── UI/               # SwiftUIビュー
│   └── PhotoLibrary/     # Photosフレームワーク統合
└── Tests/

SharedModels/              # 共有Swiftパッケージ
├── Sources/SharedModels/
│   ├── FileMetadata.swift
│   ├── TransferStatus.swift
│   └── NetworkModels.swift
└── Tests/
```

## 想定される開発コマンド

実装後の典型的なコマンド：

```bash
# サーバーアプリのビルド
xcodebuild -project ReuseBackupServer/ReuseBackupServer.xcodeproj -scheme ReuseBackupServer build

# クライアントアプリのビルド
xcodebuild -project ReuseBackupClient/ReuseBackupClient.xcodeproj -scheme ReuseBackupClient build

# テスト実行
xcodebuild test -project ReuseBackupServer/ReuseBackupServer.xcodeproj -scheme ReuseBackupServer
xcodebuild test -project ReuseBackupClient/ReuseBackupClient.xcodeproj -scheme ReuseBackupClient

# 共有モデル用Swiftパッケージ
swift build -c debug --package-path SharedModels/
swift test --package-path SharedModels/
```

## コアアーキテクチャ

### 通信フロー
1. クライアントがBonjour経由でサーバーを発見（`_reuse-backup._tcp`）
2. クライアントがHTTP POSTで`/api/upload`にファイルをアップロード
3. サーバーがファイルを保存してステータスを返答
4. クライアントが転送進捗を追跡してエラーを処理

### 主要データモデル
- **FileMetadata**: ファイル情報（名前、サイズ、ハッシュ、作成日）
- **TransferStatus**: アップロード進捗と状態管理
- **ServerInfo**: デバイス機能とストレージ状況

### APIエンドポイント（計画中）
- `GET /api/status` - サーバーの健全性とストレージ情報
- `POST /api/upload` - メタデータ付きファイルアップロード
- `GET /api/files` - 保存されたファイル一覧
- `DELETE /api/files/{id}` - 特定ファイルの削除

## 設計原則

- **プライバシー重視**: 全データがローカル保存、クラウドサービス不使用
- **シンプルさ**: コア機能に特化したミニマルUI
- **信頼性**: 堅牢なエラーハンドリングと復旧機能
- **パフォーマンス**: 進捗追跡付きの効率的な転送
- **バッテリー配慮**: 古いデバイスの制限に最適化

## 開発優先度

1. **MVPフェーズ**（2週間）: 基本的なファイル転送機能
2. **拡張フェーズ**: 重複検出などの高度な機能
3. **仕上げフェーズ**: UI改良とApp Store準備

## 実装への次のステップ

1. 両アプリのXcodeプロジェクトセットアップ
2. SharedModels Swiftパッケージの作成
3. コアネットワーキング層の実装
4. 両アプリの基本UI構築
5. 包括的なエラーハンドリングとテストの追加

## ビジネスコンテキスト

- **ターゲット**: ローカルバックアップソリューションを求めるiOSユーザー
- **配布**: 2つの独立したApp Storeアプリ
- **価格**: 買い切り（¥600-¥1,200の範囲）
- **市場**: プライバシー意識の高い複数iPhone所有者

# タスク完了時に行うこと
タスクを完了した際に、gitのコミットをしてください。
求められたプロンプトと行なった変更を日本語で簡潔にコミットメッセージに含めてください。