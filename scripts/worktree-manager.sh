#!/bin/bash

# Git Worktree管理スクリプト
# 使用方法:
#   ./worktree-manager.sh create <branch-name> [<path>]
#   ./worktree-manager.sh list
#   ./worktree-manager.sh status
#   ./worktree-manager.sh delete <branch-name>

set -e

# 使用方法を表示
show_usage() {
    echo "使用方法:"
    echo "  $0 create <branch-name> [<path>]  - 新しいWorktreeを作成"
    echo "  $0 list                          - 既存のWorktreeを一覧表示"
    echo "  $0 status                        - Worktreeの状態を確認"
    echo "  $0 delete <branch-name>          - Worktreeを削除"
    echo ""
    echo "例:"
    echo "  $0 create issue-41-test"
    echo "  $0 create issue-41-test worktrees/issue-41-work"
    echo "  $0 list"
    echo "  $0 status"
    echo "  $0 delete issue-41-test"
}

# Worktreeを作成
create_worktree() {
    local branch_name="$1"
    local path="$2"
    
    if [ -z "$branch_name" ]; then
        echo "エラー: ブランチ名が指定されていません"
        show_usage
        exit 1
    fi
    
    # パスが指定されていない場合は、worktrees/{branch_name}を使用（子ディレクトリ方式）
    if [ -z "$path" ]; then
        path="worktrees/${branch_name}"
    fi
    
    echo "Worktreeを作成しています: $branch_name -> $path"
    
    # worktreesディレクトリを作成（存在しない場合）
    mkdir -p "$(dirname "$path")"
    
    # ブランチが存在するかチェック
    if git rev-parse --verify "$branch_name" >/dev/null 2>&1; then
        echo "既存のブランチ $branch_name のWorktreeを作成します"
        git worktree add "$path" "$branch_name"
    else
        echo "新しいブランチ $branch_name を作成してWorktreeを作成します"
        git worktree add -b "$branch_name" "$path"
    fi
    
    echo "Worktreeが正常に作成されました: $path"
}

# Worktreeの一覧を表示
list_worktrees() {
    echo "現在のWorktree一覧:"
    git worktree list
}

# Worktreeの状態を確認
status_worktrees() {
    echo "Worktreeの状態を確認しています..."
    echo ""
    
    # 各Worktreeの状態をチェック
    git worktree list --porcelain | while IFS= read -r line; do
        if [[ $line == worktree* ]]; then
            worktree_path=$(echo "$line" | cut -d' ' -f2)
            echo "=== Worktree: $worktree_path ==="
            
            if [ -d "$worktree_path" ]; then
                cd "$worktree_path"
                echo "ブランチ: $(git branch --show-current)"
                echo "状態:"
                git status --short
                echo ""
                cd - > /dev/null
            else
                echo "警告: Worktreeディレクトリが見つかりません: $worktree_path"
                echo ""
            fi
        fi
    done
}

# Worktreeを削除
delete_worktree() {
    local branch_name="$1"
    
    if [ -z "$branch_name" ]; then
        echo "エラー: ブランチ名が指定されていません"
        show_usage
        exit 1
    fi
    
    echo "ブランチ $branch_name のWorktreeを削除しています..."
    
    # Worktreeのパスを取得
    worktree_path=$(git worktree list --porcelain | grep -A1 "branch refs/heads/$branch_name" | head -1 | cut -d' ' -f2)
    
    if [ -z "$worktree_path" ]; then
        echo "エラー: ブランチ $branch_name のWorktreeが見つかりません"
        echo "現在のWorktree一覧:"
        git worktree list
        exit 1
    fi
    
    # Worktreeを削除
    git worktree remove "$worktree_path"
    echo "Worktreeが正常に削除されました: $worktree_path"
}

# メイン処理
main() {
    if [ $# -eq 0 ]; then
        show_usage
        exit 1
    fi
    
    case "$1" in
        create)
            create_worktree "$2" "$3"
            ;;
        list)
            list_worktrees
            ;;
        status)
            status_worktrees
            ;;
        delete)
            delete_worktree "$2"
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