#!/bin/bash

# Git Worktree管理スクリプト
# ReuseBackupプロジェクト用の並列開発支援ツール

set -e

# 設定
MAIN_REPO_DIR="/Users/shota-nishizawa/dev/reuse-backup"
WORKTREE_BASE_DIR="/Users/shota-nishizawa/dev/reuse-backup-worktrees"
DEFAULT_BASE_BRANCH="main"

# 色付きメッセージ用
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ヘルプ表示
show_help() {
    echo "Git Worktree管理スクリプト - ReuseBackupプロジェクト用"
    echo ""
    echo "使用方法:"
    echo "  $0 <コマンド> [オプション]"
    echo ""
    echo "コマンド:"
    echo "  create <branch-name> [base-branch]  新しいworktreeを作成"
    echo "  delete <branch-name>                既存のworktreeを削除"
    echo "  list                                全worktreeを一覧表示"
    echo "  cleanup                             マージ済みブランチのworktreeを削除"
    echo "  status                              各worktreeの状態を表示"
    echo "  cd <branch-name>                    指定worktreeのパスを出力（eval用）"
    echo ""
    echo "例:"
    echo "  $0 create issue-25-new-feature"
    echo "  $0 create issue-26-bugfix main"
    echo "  $0 delete issue-25-new-feature"
    echo "  $0 list"
    echo "  $0 cleanup"
    echo "  $0 status"
    echo ""
    echo "Claude Code用のworktree切り替え:"
    echo "  eval \"\$($0 cd issue-25-new-feature)\""
}

# ログ出力
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# worktreeディレクトリの初期化
init_worktree_dir() {
    if [ ! -d "$WORKTREE_BASE_DIR" ]; then
        log_info "worktreeベースディレクトリを作成: $WORKTREE_BASE_DIR"
        mkdir -p "$WORKTREE_BASE_DIR"
    fi
}

# ブランチ存在確認
branch_exists() {
    local branch_name="$1"
    cd "$MAIN_REPO_DIR"
    git show-ref --verify --quiet "refs/heads/$branch_name"
}

# リモートブランチ存在確認
remote_branch_exists() {
    local branch_name="$1"
    cd "$MAIN_REPO_DIR"
    git show-ref --verify --quiet "refs/remotes/origin/$branch_name"
}

# worktree作成
create_worktree() {
    local branch_name="$1"
    local base_branch="${2:-$DEFAULT_BASE_BRANCH}"
    local worktree_path="$WORKTREE_BASE_DIR/$branch_name"
    
    if [ -z "$branch_name" ]; then
        log_error "ブランチ名を指定してください"
        return 1
    fi
    
    init_worktree_dir
    
    # worktreeが既に存在するかチェック
    if [ -d "$worktree_path" ]; then
        log_error "worktree既に存在: $worktree_path"
        return 1
    fi
    
    cd "$MAIN_REPO_DIR"
    
    # ベースブランチの最新化
    log_info "ベースブランチ '$base_branch' を最新化"
    git fetch origin
    git checkout "$base_branch"
    git pull origin "$base_branch"
    
    # ブランチ作成（既に存在する場合はスキップ）
    if ! branch_exists "$branch_name"; then
        if remote_branch_exists "$branch_name"; then
            log_info "リモートブランチから作成: $branch_name"
            git checkout -b "$branch_name" "origin/$branch_name"
        else
            log_info "新規ブランチ作成: $branch_name (base: $base_branch)"
            git checkout -b "$branch_name" "$base_branch"
        fi
    fi
    
    # worktree作成
    log_info "worktree作成: $worktree_path"
    git worktree add "$worktree_path" "$branch_name"
    
    log_success "worktree作成完了: $worktree_path"
    log_info "Claude Codeで開くには: cd $worktree_path && claude ."
}

# worktree削除
delete_worktree() {
    local branch_name="$1"
    local worktree_path="$WORKTREE_BASE_DIR/$branch_name"
    
    if [ -z "$branch_name" ]; then
        log_error "ブランチ名を指定してください"
        return 1
    fi
    
    if [ ! -d "$worktree_path" ]; then
        log_error "worktreeが存在しません: $worktree_path"
        return 1
    fi
    
    cd "$MAIN_REPO_DIR"
    
    # worktree削除
    log_info "worktree削除: $worktree_path"
    git worktree remove "$worktree_path" --force
    
    # ブランチ削除の確認
    echo -n "ブランチ '$branch_name' も削除しますか？ (y/N): "
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        git branch -D "$branch_name" 2>/dev/null || log_warning "ローカルブランチ削除失敗"
        
        echo -n "リモートブランチも削除しますか？ (y/N): "
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            git push origin --delete "$branch_name" 2>/dev/null || log_warning "リモートブランチ削除失敗"
        fi
    fi
    
    log_success "worktree削除完了"
}

# worktree一覧表示
list_worktrees() {
    cd "$MAIN_REPO_DIR"
    echo "=== Git Worktree一覧 ==="
    git worktree list
    
    if [ -d "$WORKTREE_BASE_DIR" ]; then
        echo ""
        echo "=== ReuseBackup Worktreeディレクトリ ==="
        ls -la "$WORKTREE_BASE_DIR/"
    fi
}

# マージ済みworktreeクリーンアップ
cleanup_worktrees() {
    cd "$MAIN_REPO_DIR"
    
    log_info "マージ済みブランチを確認中..."
    
    # マージ済みブランチ一覧（main以外）
    merged_branches=$(git branch --merged "$DEFAULT_BASE_BRANCH" | grep -v "$DEFAULT_BASE_BRANCH" | grep -v "^\*" | sed 's/^[[:space:]]*//' || true)
    
    if [ -z "$merged_branches" ]; then
        log_info "クリーンアップ対象のworktreeはありません"
        return 0
    fi
    
    echo "=== マージ済みブランチ ==="
    echo "$merged_branches"
    echo ""
    
    echo -n "これらのブランチのworktreeを削除しますか？ (y/N): "
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "$merged_branches" | while read -r branch; do
            if [ -n "$branch" ] && [ -d "$WORKTREE_BASE_DIR/$branch" ]; then
                log_info "クリーンアップ: $branch"
                git worktree remove "$WORKTREE_BASE_DIR/$branch" --force
                git branch -d "$branch" 2>/dev/null || true
            fi
        done
        log_success "クリーンアップ完了"
    else
        log_info "クリーンアップをキャンセルしました"
    fi
}

# worktree状態表示
show_status() {
    cd "$MAIN_REPO_DIR"
    
    echo "=== Git Worktree状態 ==="
    git worktree list
    
    echo ""
    echo "=== 各Worktreeの詳細状態 ==="
    
    git worktree list --porcelain | while read -r line; do
        if [[ $line == worktree* ]]; then
            worktree_path=${line#worktree }
            echo ""
            echo "--- $worktree_path ---"
            
            if [ -d "$worktree_path" ]; then
                cd "$worktree_path"
                
                # ブランチ名取得
                current_branch=$(git branch --show-current)
                echo "ブランチ: $current_branch"
                
                # 変更状況
                if [ -n "$(git status --porcelain)" ]; then
                    echo "状態: 変更あり"
                    git status --short
                else
                    echo "状態: クリーン"
                fi
                
                # リモートとの差分
                upstream=$(git for-each-ref --format='%(upstream:short)' "refs/heads/$current_branch")
                if [ -n "$upstream" ]; then
                    ahead=$(git rev-list --count "$upstream".."$current_branch" 2>/dev/null || echo "0")
                    behind=$(git rev-list --count "$current_branch".."$upstream" 2>/dev/null || echo "0")
                    echo "リモート: $ahead ahead, $behind behind"
                else
                    echo "リモート: 未設定"
                fi
            fi
        fi
    done
}

# worktreeディレクトリパス出力（cd用）
get_worktree_cd() {
    local branch_name="$1"
    local worktree_path="$WORKTREE_BASE_DIR/$branch_name"
    
    if [ -z "$branch_name" ]; then
        log_error "ブランチ名を指定してください"
        return 1
    fi
    
    if [ ! -d "$worktree_path" ]; then
        log_error "worktreeが存在しません: $worktree_path"
        return 1
    fi
    
    echo "cd '$worktree_path'"
}

# メイン処理
main() {
    case "${1:-}" in
        "create")
            create_worktree "$2" "$3"
            ;;
        "delete")
            delete_worktree "$2"
            ;;
        "list")
            list_worktrees
            ;;
        "cleanup")
            cleanup_worktrees
            ;;
        "status")
            show_status
            ;;
        "cd")
            get_worktree_cd "$2"
            ;;
        "help"|"-h"|"--help"|"")
            show_help
            ;;
        *)
            log_error "無効なコマンド: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# スクリプト実行
main "$@"