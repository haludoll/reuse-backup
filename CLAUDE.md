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

## ブランチ戦略

本プロジェクトでは**トランクベース開発戦略**を採用します：

### ブランチフロー
1. **Issue作成**: 機能・バグ修正ごとにGitHub Issueを作成
2. **ブランチ作成**: `issue-{issue番号}-{簡潔な説明}` 形式でブランチを作成
   - 例: `issue-42-add-upload-feature`
3. **初回コミット**: 最初のコミット後、直ちにdraft Pull Requestを作成
4. **継続開発**: ブランチで継続的に開発・コミット
5. **レビュー準備**: 実装完了時にPull Requestを「Ready for review」に変更
6. **自動レビュー**: PR がopenになったタイミングでClaude Codeによる自動レビューを実行
7. **マージ**: レビュー完了後、mainブランチにマージ

### ブランチ命名規則
- `issue-{番号}-{機能名}`: 新機能開発
- `issue-{番号}-fix-{バグ内容}`: バグ修正
- `issue-{番号}-refactor-{対象}`: リファクタリング
- `issue-{番号}-docs-{ドキュメント種類}`: ドキュメント更新

### Pull Request運用
- **Draft作成**: 初回コミット時に自動でdraft PRを作成
- **継続的更新**: 開発中も定期的にコミット・プッシュ
- **Claude Codeレビュー**: PRがReady for reviewになった際にClaude Code自身が実行
- **マージ条件**: レビュー承認 + CI/CDパス

### コードレビュー機能
- **自動レビュー**: Claude CodeがPull Requestのコード変更を自動的にレビュー
- **レビュー観点**: 
  - コード品質とベストプラクティス準拠
  - 設計パターンとアーキテクチャの一貫性
  - セキュリティ上の問題や脆弱性
  - パフォーマンスと効率性
  - テストカバレッジと品質
- **フィードバック方法**: 必要に応じてレビューコメントを追加
- **承認プロセス**: レビュー完了後、適切と判断されればマージを実行

### Issue管理ルール
- **Issue-PR連携**: Pull Requestタイトルに`Issue #{番号}:`を含めてIssueと紐づけ
- **自動クローズ**: Pull Requestがマージされた際、紐づいているIssueを自動的にClose
- **マージコミット**: マージ時のコミットメッセージにIssue番号を含める
- **ステータス更新**: Issue作業開始時にAssigneeを設定し、進捗を可視化

## テスト駆動開発(TDD)

本プロジェクトでは**テスト駆動開発(Test-Driven Development)**を採用し、高品質で保守性の高いコードを実現します。

### TDDサイクル
1. **Red**: まず失敗するテストを書く
2. **Green**: テストをパスする最小限のコードを実装
3. **Refactor**: テストを維持しながらコードを改善

### テスト戦略
- **Unit Tests**: 個別のクラス・メソッドの動作確認
- **Integration Tests**: コンポーネント間の連携確認
- **End-to-End Tests**: アプリ全体の動作確認（UI含む）

### テスト実装ルール
- **テストファースト**: 実装前に必ずテストを作成
- **テストカバレッジ**: 最低80%以上を目標
- **命名規則**: `test_when条件_then期待結果` 形式
- **Arrange-Act-Assert**: テスト構造の統一

## コメント記述ガイドライン

### DocCコメント（推奨）
- **対象**: public/internal API、クラス、構造体、プロトコル、重要なメソッド
- **形式**: SwiftDoc形式の三重スラッシュ（`///`）を使用
- **内容**: 目的、パラメータ、戻り値、使用例を記述

### インラインコメント（最小限）
- **原則**: コードを見れば分かることは書かない
- **対象**: 複雑なアルゴリズム、非自明なビジネスロジック、なぜその実装にしたかの理由
- **避けるべき**: 変数代入、関数呼び出し、自明な処理の説明

### 具体例
```swift
// ❌ 悪い例（自明なコメント）
// ユーザー名を取得
let username = user.name

// サーバーを開始
try await server.start()

// ❌ 悪い例（コードの説明）
// ルートエンドポイント
await server.appendRoute(.init(method: .GET, path: "/"), to: handler)

// ✅ 良い例（非自明な理由）
// server.run()は永続的にawaitするため、先にインスタンスを保存
self.server = server

// ✅ 良い例（複雑なロジックの説明）
// 指数バックオフで再試行：初回100ms、最大10秒まで倍々で増加
let delay = min(100 * pow(2, retryCount), 10000)
```

## Swift コード構造ガイドライン

### プロパティの配置順序

**基本原則**: プロパティは機能的に関連するもの同士を近くに配置し、アクセスレベルと性質により整理する

**推奨配置順序**:
1. **Stored Properties** (保存プロパティ)
2. **Computed Properties** (計算プロパティ)  
3. **Initialization** (イニシャライザ)
4. **Instance Methods** (インスタンスメソッド)
5. **Static/Class Members** (静的メンバー)

### MARK活用による構造化

```swift
class ExampleViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var data: [Item] = []
    
    // MARK: - Private Properties  
    private let service: ServiceProtocol
    private let logger = Logger(...)
    
    // MARK: - Computed Properties
    var isDataEmpty: Bool {
        return data.isEmpty
    }
    
    var displayText: String {
        return isLoading ? "読み込み中..." : "完了"
    }
    
    // MARK: - Initialization
    init(service: ServiceProtocol = DefaultService()) {
        self.service = service
    }
    
    // MARK: - Public Methods
    func loadData() async { ... }
    
    // MARK: - Private Methods
    private func processData() { ... }
}
```

### アクセス修飾子の配置
- **public** → **internal** → **private** の順序
- 同じアクセスレベル内では機能グループで整理

## タスク完了時の運用

### Git運用ルール
- **コミット**: タスク完了時に必ずgit commitとpushを実行
- **コミットメッセージ**: 求められたプロンプトと実施した変更内容を日本語で簡潔に記述
- **Author情報**: コミットメッセージにAuthor情報は含めない

### コードフォーマット自動実行
- **自動フォーマット**: タスク実行後に必ずコードフォーマットを実行
- **フォーマット対象**: Swiftファイル（.swift）のみ
- **フォーマットコマンド**: `swiftformat`
- **実行タイミング**: コード変更を伴うタスク完了時
- **対象ディレクトリ**: ReuseBackupServer/ReuseBackupServer および ReuseBackupServerTests

#### フォーマット実行手順
1. コード変更を伴うタスクの完了
2. swift-formatによる自動フォーマット実行
3. フォーマット後のコードをgit commitに含める
