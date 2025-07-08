# Git Worktree 管理スクリプト

このドキュメントは、Git Worktree管理スクリプトの使用方法を説明します。

## スクリプト一覧

### worktree-manager.sh

Git Worktreeの管理を行うメインスクリプトです。

#### 使用方法

```bash
# 新しいWorktreeを作成
./worktree-manager.sh create <branch-name> [<path>]

# 既存のWorktreeを一覧表示
./worktree-manager.sh list

# Worktreeの状態を確認
./worktree-manager.sh status

# Worktreeを削除
./worktree-manager.sh delete <branch-name>
```

#### コマンド説明

- `create`: 指定されたブランチ名で新しいWorktreeを作成します
- `list`: 現在のWorktreeの一覧を表示します
- `status`: 各Worktreeの状態（変更、未コミット等）を確認します
- `delete`: 指定されたブランチのWorktreeを削除します

### claude-parallel.sh

Claude Codeとの並行作業を効率化するスクリプトです。

#### 使用方法

```bash
# 新しい作業環境を作成
./claude-parallel.sh new <issue-number> [<description>]
```

#### コマンド説明

- `new`: 指定されたIssue番号で新しい作業環境を作成します
  - 自動的にブランチを作成
  - 適切なWorktreeを設定
  - 開発環境を初期化

## 使用例

```bash
# Issue #41用の作業環境を作成
./claude-parallel.sh new 41 "worktree-test"

# Worktreeの状態を確認
./worktree-manager.sh status

# 作業完了後、Worktreeを削除
./worktree-manager.sh delete issue-41-worktree-test
```

## 注意事項

- これらのスクリプトはテスト用に作成されたドキュメントです
- 実際のスクリプトファイルは別途実装が必要です
- 本番環境で使用する前に十分なテストを行ってください