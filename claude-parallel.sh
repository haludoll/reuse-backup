#!/bin/bash

# Claude Codeとの並行作業を効率化するスクリプト
# 使用方法:
#   ./claude-parallel.sh new <issue-number> [<description>]

set -e

# 使用方法を表示
show_usage() {
    echo "使用方法:"
    echo "  $0 new <issue-number> [<description>]  - 新しい作業環境を作成"
    echo ""
    echo "例:"
    echo "  $0 new 41"
    echo "  $0 new 41 \"worktree-test\""
    echo "  $0 new 42 \"add-new-feature\""
    echo ""
    echo "このスクリプトは以下を自動実行します:"
    echo "  - Issue番号に基づいたブランチを作成"
    echo "  - 適切なWorktreeを設定"
    echo "  - 開発環境を初期化"
}

# 新しい作業環境を作成
create_work_environment() {
    local issue_number="$1"
    local description="$2"
    
    if [ -z "$issue_number" ]; then
        echo "エラー: Issue番号が指定されていません"
        show_usage
        exit 1
    fi
    
    # 数字かどうかチェック
    if ! [[ "$issue_number" =~ ^[0-9]+$ ]]; then
        echo "エラー: Issue番号は数字で指定してください"
        exit 1
    fi
    
    # 説明が指定されていない場合は、デフォルト値を使用
    if [ -z "$description" ]; then
        description="task"
    fi
    
    # ブランチ名を生成
    local branch_name="issue-${issue_number}-${description}"
    local worktree_path="worktrees/${branch_name}"
    
    echo "=== Claude Code並行作業環境のセットアップ ==="
    echo "Issue番号: #${issue_number}"
    echo "説明: ${description}"
    echo "ブランチ名: ${branch_name}"
    echo "Worktreeパス: ${worktree_path}"
    echo ""
    
    # 既存のブランチをチェック
    if git rev-parse --verify "$branch_name" >/dev/null 2>&1; then
        echo "警告: ブランチ $branch_name は既に存在します"
        read -p "続行しますか？ (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "キャンセルされました"
            exit 1
        fi
    fi
    
    # 既存のWorktreeをチェック
    if [ -d "$worktree_path" ]; then
        echo "警告: Worktreeディレクトリ $worktree_path は既に存在します"
        read -p "削除して続行しますか？ (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$worktree_path"
            echo "既存のWorktreeディレクトリを削除しました"
        else
            echo "キャンセルされました"
            exit 1
        fi
    fi
    
    echo "1. Worktreeを作成しています..."
    
    # worktreesディレクトリを作成（存在しない場合）
    mkdir -p "$(dirname "$worktree_path")"
    
    if git rev-parse --verify "$branch_name" >/dev/null 2>&1; then
        # 既存のブランチの場合
        git worktree add "$worktree_path" "$branch_name"
    else
        # 新しいブランチの場合
        git worktree add -b "$branch_name" "$worktree_path"
    fi
    
    echo "2. 作業ディレクトリに移動しています..."
    cd "$worktree_path"
    
    echo "3. 開発環境を初期化しています..."
    
    # git configの設定
    git config user.name "$(git config --global user.name || echo 'Claude Code')"
    git config user.email "$(git config --global user.email || echo 'claude@anthropic.com')"
    
    # 初期コミット（新しいブランチの場合）
    if ! git rev-parse --verify "$branch_name" >/dev/null 2>&1; then
        echo "4. 初期コミットを作成しています..."
        git commit --allow-empty -m "feat: Issue #${issue_number} 作業開始 - ${description}

Issue #${issue_number} の作業を開始します。

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"
    fi
    
    echo ""
    echo "=== セットアップ完了 ==="
    echo "作業環境が正常に作成されました！"
    echo ""
    echo "次の手順："
    echo "  1. 作業ディレクトリに移動: cd $worktree_path"
    echo "  2. 開発を開始"
    echo "  3. 作業完了後、Worktreeを削除: ./worktree-manager.sh delete $branch_name"
    echo ""
    echo "Claude Code使用時の重要な注意:"
    echo "  - 子ディレクトリ方式を採用しているため、Claude Codeの制限内で正常に動作します"
    echo "  - 作業ディレクトリは $worktree_path です"
    echo ""
    echo "現在のディレクトリ: $(pwd)"
    echo "現在のブランチ: $(git branch --show-current)"
    
    # 元のディレクトリに戻る
    cd - > /dev/null
}

# メイン処理
main() {
    if [ $# -eq 0 ]; then
        show_usage
        exit 1
    fi
    
    case "$1" in
        new)
            create_work_environment "$2" "$3"
            ;;
        *)
            echo "エラー: 不明なコマンド: $1"
            show_usage
            exit 1
            ;;
    esac
}

# スクリプトを実行
main "$@"