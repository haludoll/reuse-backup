# CLAUDE.md

このファイルは、このリポジトリでコードを扱う際にClaude Code (claude.ai/code) にガイダンスを提供します。

## プロジェクト概要

ReuseBackupは、古いiPhoneを写真・動画のローカルバックアップサーバーとして再利用する革新的なiOSアプリケーションエコシステムです。このプロジェクトは2つの独立したiOSアプリケーションで構成されています：

1. **ReuseBackupServer** - 古いiPhone（iOS 15+）で動作、HTTPサーバーとして機能
2. **ReuseBackupClient** - 新しいiPhone（iOS 17+）で動作、サーバーにコンテンツをアップロード

**現在のステータス**: 積極的な開発段階 - 基本機能実装済み、写真・動画アップロード機能のサーバーサイド実装中（Issue #47）

## 技術スタック

- **言語**: Swift（サーバー: 5.9+、クライアント: 6.0+）
- **フレームワーク**: 
  - サーバー: HummingBird HTTPサーバー、Bonjourサービス発見
  - クライアント: SwiftUI、HTTPリクエスト用URLSession
- **アーキテクチャ**: 単方向HTTP通信（クライアント → サーバー）
- **プラットフォーム**: ローカル専用・プライバシー重視のiOS
- **API仕様**: OpenAPI 3.0.3 仕様（swift-openapi-generator使用）
- **HTTP抽象化**: HTTPAdapters Swift Package（HummingBird統合）

## 実際のディレクトリ構造

```
ReuseBackupServer/          # 古いiPhone用サーバーアプリ（Xcodeプロジェクト）
├── ReuseBackupServer/
│   ├── Services/          # HTTPサーバー、Bonjour、ストレージサービス
│   ├── Handlers/          # APIエンドポイントハンドラー
│   ├── ViewModels/        # SwiftUI ViewModels
│   ├── Views/            # SwiftUIビュー
│   └── ReuseBackupServerApp.swift
└── ReuseBackupServerTests/

ReuseBackupClient/          # 新しいiPhone用クライアントアプリ（Xcodeプロジェクト）
├── ReuseBackupClient/
│   ├── Services/          # HTTPクライアント、サーバー発見
│   ├── ViewModels/        # SwiftUI ViewModels
│   ├── Views/            # SwiftUIビュー
│   └── ReuseBackupClientApp.swift
└── ReuseBackupClientTests/

APISharedModels/          # 共有APIモデルSwiftパッケージ
├── Sources/APISharedModels/
│   ├── openapi.yaml      # OpenAPI 3.0.3 仕様
│   └── Generated/        # 自動生成されたSwiftモデル
└── Tests/

HTTPAdapters/            # HTTPサーバー抽象化Swiftパッケージ
├── Sources/HTTPAdapters/
│   ├── HTTPServerAdapter.swift
│   ├── HummingBirdAdapter.swift
│   └── TLSCertificateManager.swift
└── Tests/
```

## 開発コマンド

実際に使用されているコマンド：

```bash
# サーバーアプリのビルド
xcodebuild -project ReuseBackupServer/ReuseBackupServer.xcodeproj -scheme ReuseBackupServer build

# クライアントアプリのビルド
xcodebuild -project ReuseBackupClient/ReuseBackupClient.xcodeproj -scheme ReuseBackupClient build

# テスト実行（XCTestPlan使用）
xcodebuild test -project ReuseBackupServer/ReuseBackupServer.xcodeproj -testPlan ReuseBackupServerTests
xcodebuild test -project ReuseBackupClient/ReuseBackupClient.xcodeproj -testPlan ReuseBackupClientTests

# 共有APIモデル用Swiftパッケージ
swift build -c debug --package-path APISharedModels/
swift test --package-path APISharedModels/

# HTTPAdapters用Swiftパッケージ
swift build -c debug --package-path HTTPAdapters/
swift test --package-path HTTPAdapters/

# OpenAPI仕様からコード自動生成
swift run --package-path APISharedModels/ swift-openapi-generator generate

# コードフォーマット
swiftformat ReuseBackupServer/ReuseBackupServer ReuseBackupServer/ReuseBackupServerTests
```

## コアアーキテクチャ

### 通信フロー
1. クライアントがBonjour経由でサーバーを発見（`_reuse-backup._tcp`）
2. クライアントがHTTP POSTで`/api/media/upload`にファイルをアップロード
3. サーバーがファイルを保存してステータスを返答
4. クライアントが転送進捗を追跡してエラーを処理
5. クライアントが`/api/status`でサーバーの状態を確認
6. メッセージ送受信は`/api/message`エンドポイントで実行

### 主要データモデル（OpenAPI仕様ベース）
- **MediaUploadRequest**: メディアアップロード要求（ファイル、メタデータ）
- **MediaUploadResponse**: アップロード結果（成功/失敗、保存パス）
- **StatusResponse**: サーバー状態（ストレージ使用量、デバイス情報）
- **MessageRequest/MessageResponse**: メッセージ送受信
- **ErrorResponse**: エラー情報（コード、メッセージ、詳細）

### APIエンドポイント（OpenAPI仕様定義済み）
- `GET /api/status` - サーバーの健全性とストレージ情報（**実装済み**）
- `POST /api/message` - メッセージ送受信（**実装済み**）
- `POST /api/media/upload` - メディアファイルアップロード（**サーバーサイド実装中**）
- `GET /api/files` - 保存されたファイル一覧（**未実装**）
- `DELETE /api/files/{id}` - 特定ファイルの削除（**未実装**）

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

## 現在の実装状況

### 実装済み機能
- ✅ 両アプリのXcodeプロジェクトセットアップ完了
- ✅ APISharedModels SwiftパッケージとOpenAPI仕様
- ✅ HTTPAdapters Swiftパッケージ
- ✅ サーバーのBonjour発見機能
- ✅ 基本的なHTTPサーバー機能
- ✅ メッセージ送受信機能
- ✅ サーバーステータス取得機能
- ✅ クライアントのサーバー発見機能
- ✅ 写真・動画選択UI
- ✅ アップロード管理UI
- ✅ 両アプリの基本UI構築

### 実装中の機能
- 🔄 写真・動画アップロードのサーバーサイド処理（Issue #47）
  - MediaUploadHandler実装
  - マルチパートフォーム解析
  - ストリーミングアップロード対応

### 未実装の機能
- ⏳ ファイル一覧取得機能
- ⏳ ファイル削除機能
- ⏳ 重複検出機能
- ⏳ 進捗追跡の詳細実装
- ⏳ バッテリー配慮の最適化
- ⏳ 包括的なエラーハンドリング
- ⏳ App Store準備

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

## Git Worktree運用

本プロジェクトでは、**Issue作業時に必ずGit Worktreeを使用**します。これにより、複数のIssueを同時に作業可能にし、作業環境を分離して効率的な開発を実現します。

### Git Worktree使用原則

- **必須使用**: Claude Codeを含む全ての開発者は、Issue作業時に必ずgit worktreeを作成して作業する
- **作業分離**: 各Issueは独立したworktreeで作業し、mainブランチに影響を与えない
- **環境独立**: 各worktreeは独立したファイルシステム上に配置され、同時並行作業が可能
- **整理整頓**: 作業完了後は不要なworktreeを削除し、環境を整理する

### Git Worktree作業フロー

1. **Worktree作成**: Issue作業開始時に`./scripts/claude-parallel.sh new <issue番号> [<説明>]`を実行
2. **作業実行**: 作成されたworktreeディレクトリで開発作業を実行
3. **コミット・プッシュ**: 通常のgit操作でコミット・プッシュを実行
4. **PR作成**: 作業完了後、Pull Requestを作成
5. **Worktree削除**: PR完了後、`./scripts/worktree-manager.sh delete <branch名>`で削除

### 使用可能なWorktreeスクリプト

#### worktree-manager.sh
```bash
# 新規worktreeの作成（子ディレクトリ方式）
./scripts/worktree-manager.sh create <branch名> [<path>]

# 既存worktreeの一覧表示
./scripts/worktree-manager.sh list

# worktreeの状態確認
./scripts/worktree-manager.sh status

# worktreeの削除
./scripts/worktree-manager.sh delete <branch名>
```

#### claude-parallel.sh（推奨）
```bash
# Issue番号ベースでworktreeを作成（子ディレクトリ方式）
./scripts/claude-parallel.sh new <issue番号> [<説明>]
```

#### 使用例
```bash
# 新しいIssueの作業開始
./scripts/claude-parallel.sh new 75 "improve-performance"

# 作業ディレクトリに移動（Claude Code制限内で正常動作）
cd worktrees/issue-75-improve-performance

# 作業完了後の削除
./scripts/worktree-manager.sh delete issue-75-improve-performance
```

### Claude Code専用の運用ルール

- **子ディレクトリ方式**: Claude Codeのディレクトリ制限に対応するため、子ディレクトリ方式を採用
- **自動Worktree作成**: Claude CodeはIssue作業開始時に自動的にworktreeを作成
- **命名規則**: `issue-{番号}-{説明}`形式のブランチ名を使用
- **作業ディレクトリ**: `worktrees/issue-{番号}-{説明}/`ディレクトリで作業実行
- **制限回避**: 親ディレクトリや兄弟ディレクトリへの移動制限を回避
- **自動削除**: 作業完了時に不要なworktreeを自動的に削除

### メリット

- **並行作業**: 複数のIssueを同時に作業可能
- **環境分離**: 各作業が独立し、相互影響を防止
- **高速切り替え**: ブランチ切り替えが不要で、ディレクトリ移動のみ
- **安全性**: mainブランチを直接変更するリスクを排除
- **Claude Code対応**: 子ディレクトリ方式により、Claude Codeのディレクトリ制限内で完全に動作

### 重要な変更点（2025年7月）

以前は`../worktree-issue-XX-description/`形式で親ディレクトリにworktreeを作成していましたが、Claude Codeのセキュリティ制限により、以下の問題が発生していました：

- **制限**: Claude Codeは親ディレクトリや兄弟ディレクトリへの移動が制限される
- **問題**: worktreeが作成されても、実際にディレクトリ移動ができない
- **解決**: 子ディレクトリ方式（`worktrees/issue-XX-description/`）への変更

この変更により、Claude Codeでの作業効率が大幅に向上し、worktreeの利点を最大限に活用できるようになりました。

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

### 段階的実装の原則
- **Issue調査の必須**: Issue取り組み前にIssueに紐づくコメントを全て確認
- **一度で全てを実装しない**: 一度のタスクですべての実装を行わない
- **段階的指示待ち**: 必要な作業をリストアップ後、上から順に指示を受けて実行
- **レビュー負荷軽減**: 一度のタスクでのコード差分量を最小限に抑制
- **独立動作単位**: 各段階は独立して動作確認可能な単位で実装

### Git運用ルール
- **コミット**: タスク完了時に必ずgit commitとpushを実行
- **コミットメッセージ**: 求められたプロンプトと実施した変更内容を日本語で簡潔に記述
- **Author情報**: コミットメッセージにAuthor情報は含めない
- **小さなコミット単位**: 複雑な機能実装時は、タスクを小さく分割して1つずつコミット
  - レビュー負荷軽減のため、一度にすべてを実装せず段階的に進める
  - 各タスクは独立して動作確認可能な単位で区切る
  - **TODO単位コミット**: 各TODOタスク完了時に必ずコミットを実行
  - 例：「モデル定義」→「API実装」→「UI実装」→「エラーハンドリング」

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

# important-instruction-reminders
Do what has been asked; nothing more, nothing less.
NEVER create files unless they're absolutely necessary for achieving your goal.
ALWAYS prefer editing an existing file to creating a new one.
NEVER proactively create documentation files (*.md) or README files. Only create documentation files if explicitly requested by the User.

      
      IMPORTANT: this context may or may not be relevant to your tasks. You should not respond to this context or otherwise consider it in your response unless it is highly relevant to your task. Most of the time, it is not relevant.
