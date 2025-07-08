#!/bin/bash

# Claude Code並列起動スクリプト
# 複数のworktreeでClaude Codeインスタンスを管理

set -e

WORKTREE_MANAGER="/Users/shota-nishizawa/dev/reuse-backup/scripts/worktree-manager.sh"
WORKTREE_BASE_DIR="/Users/shota-nishizawa/dev/reuse-backup-worktrees"

# 色付きメッセージ用
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# ヘルプ表示
show_help() {
    echo "Claude Code並列起動スクリプト"
    echo ""
    echo "使用方法:"
    echo "  $0 <コマンド> [オプション]"
    echo ""
    echo "コマンド:"
    echo "  start <branch-name>         指定worktreeでClaude Codeを起動"
    echo "  new <branch-name> [base]    新しいworktree作成してClaude Code起動"
    echo "  list-running                実行中のClaude Codeプロセスを表示"
    echo "  kill <branch-name>          指定worktreeのClaude Codeを終了"
    echo "  kill-all                    全てのClaude Codeプロセスを終了"
    echo ""
    echo "例:"
    echo "  $0 new issue-25-new-feature"
    echo "  $0 start issue-26-bugfix"
    echo "  $0 list-running"
    echo "  $0 kill issue-25-new-feature"
    echo "  $0 kill-all"
}

# Claude Code起動
start_claude() {
    local branch_name="$1"
    local worktree_path="$WORKTREE_BASE_DIR/$branch_name"
    
    if [ -z "$branch_name" ]; then
        log_error "ブランチ名を指定してください"
        return 1
    fi
    
    if [ ! -d "$worktree_path" ]; then
        log_error "worktreeが存在しません: $worktree_path"
        log_info "先にworktreeを作成してください: $WORKTREE_MANAGER create $branch_name"
        return 1
    fi
    
    # 既に起動しているかチェック
    if pgrep -f "claude.*$worktree_path" > /dev/null; then
        log_warning "Claude Codeは既に起動しています: $branch_name"
        return 1
    fi
    
    log_info "Claude Code起動: $branch_name ($worktree_path)"
    
    # 新しいターミナルウィンドウでClaude Codeを起動
    osascript <<EOF
tell application "Terminal"
    do script "cd '$worktree_path' && echo '=== Claude Code - $branch_name ===' && claude ."
    set custom title of front window to "Claude Code - $branch_name"
end tell
EOF
    
    log_success "Claude Code起動完了: $branch_name"
}

# 新規worktree作成してClaude Code起動
new_worktree_and_start() {
    local branch_name="$1"
    local base_branch="$2"
    
    if [ -z "$branch_name" ]; then
        log_error "ブランチ名を指定してください"
        return 1
    fi
    
    log_info "新規worktree作成: $branch_name"
    if "$WORKTREE_MANAGER" create "$branch_name" "$base_branch"; then
        log_info "Claude Code起動中..."
        sleep 1  # worktree作成完了を待機
        start_claude "$branch_name"
    else
        log_error "worktree作成に失敗しました"
        return 1
    fi
}

# 実行中のClaude Codeプロセス一覧
list_running_claude() {
    echo "=== 実行中のClaude Codeプロセス ==="
    
    local found=false
    
    # Claude Codeプロセスを検索
    pgrep -f "claude" | while read -r pid; do
        # プロセス詳細を取得
        local cmdline=$(ps -p "$pid" -o command= 2>/dev/null || true)
        
        if [[ $cmdline == *"$WORKTREE_BASE_DIR"* ]]; then
            found=true
            local worktree=$(echo "$cmdline" | grep -o "$WORKTREE_BASE_DIR/[^/]*" | head -1)
            local branch_name=$(basename "$worktree")
            
            echo "PID: $pid | Branch: $branch_name | Path: $worktree"
        fi
    done
    
    if [ "$found" = false ]; then
        echo "実行中のClaude Codeプロセスはありません"
    fi
}

# 指定worktreeのClaude Code終了
kill_claude() {
    local branch_name="$1"
    local worktree_path="$WORKTREE_BASE_DIR/$branch_name"
    
    if [ -z "$branch_name" ]; then
        log_error "ブランチ名を指定してください"
        return 1
    fi
    
    log_info "Claude Code終了: $branch_name"
    
    # 該当プロセスを検索して終了
    local killed=false
    pgrep -f "claude.*$worktree_path" | while read -r pid; do
        log_info "プロセス終了: PID $pid"
        kill "$pid"
        killed=true
    done
    
    if [ "$killed" = true ]; then
        log_success "Claude Code終了完了: $branch_name"
    else
        log_warning "実行中のClaude Codeプロセスが見つかりません: $branch_name"
    fi
}

# 全Claude Codeプロセス終了
kill_all_claude() {
    echo -n "全てのClaude Codeプロセスを終了しますか？ (y/N): "
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        log_info "全Claude Codeプロセスを終了中..."
        
        pgrep -f "claude" | while read -r pid; do
            local cmdline=$(ps -p "$pid" -o command= 2>/dev/null || true)
            if [[ $cmdline == *"$WORKTREE_BASE_DIR"* ]]; then
                log_info "プロセス終了: PID $pid"
                kill "$pid"
            fi
        done
        
        log_success "全プロセス終了完了"
    else
        log_info "キャンセルしました"
    fi
}

# メイン処理
main() {
    case "${1:-}" in
        "start")
            start_claude "$2"
            ;;
        "new")
            new_worktree_and_start "$2" "$3"
            ;;
        "list-running")
            list_running_claude
            ;;
        "kill")
            kill_claude "$2"
            ;;
        "kill-all")
            kill_all_claude
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