#!/usr/bin/env bash

lt_paths_init() {
    LT_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
    LT_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
    LT_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
    LT_BIN_HOME="${HOME}/.local/bin"
    LT_DEFAULT_APP_DIR="${LT_DATA_HOME}/linux-tool/app"
    LT_APP_DIR="${LT_APP_DIR:-$LT_DEFAULT_APP_DIR}"

    if [ -n "${LINUX_TOOL_TOOL_DIR:-}" ]; then
        LT_TOOL_DIR="$LINUX_TOOL_TOOL_DIR"
    else
        LT_TOOL_DIR="${LT_DATA_HOME}/linux-tool/tool"
    fi

    LT_ASSETS_DIR="${LT_APP_DIR}/assets"
    LT_LOG_DIR="${LT_STATE_HOME}/linux-tool"
    LT_LOG_FILE="${LT_LOG_DIR}/linux-tool.log"
    LT_BACKUP_DIR="${LT_DATA_HOME}/linux-tool/backups"
    LT_INSTALL_DB="${LT_DATA_HOME}/linux-tool/installed"
    LT_CACHE_DIR="${LT_CACHE_HOME}/linux-tool"
    LT_CLOUD_TOOL_CACHE="${LT_CACHE_DIR}/cloud/tool"
    LT_CLOUD_INDEX_CACHE="${LT_CACHE_DIR}/cloud/tool-index"
    LT_CLOUD_CACHE_TTL="${LT_CLOUD_CACHE_TTL:-300}"
    LT_LOGO_CACHE="${LT_CACHE_DIR}/logo.ansi"
    LT_GITHUB_REPO="${LT_GITHUB_REPO:-Xynrin/linux-tool}"
    LT_GITHUB_BRANCH="${LT_GITHUB_BRANCH:-main}"
    LT_GITHUB_URL="${LT_GITHUB_URL:-https://github.com/${LT_GITHUB_REPO}}"
    LT_CLOUD_TREE_URL="${LT_CLOUD_TREE_URL:-${LT_GITHUB_URL}/tree/${LT_GITHUB_BRANCH}/tool}"
    LT_CLOUD_RAW_BASE="${LT_CLOUD_RAW_BASE:-https://raw.githubusercontent.com/${LT_GITHUB_REPO}/${LT_GITHUB_BRANCH}}"

    export LT_DATA_HOME LT_STATE_HOME LT_CACHE_HOME LT_BIN_HOME LT_DEFAULT_APP_DIR
    export LT_TOOL_DIR LT_ASSETS_DIR LT_LOG_DIR LT_LOG_FILE LT_BACKUP_DIR LT_INSTALL_DB
    export LT_CACHE_DIR LT_CLOUD_TOOL_CACHE LT_GITHUB_REPO LT_GITHUB_BRANCH
    export LT_CLOUD_INDEX_CACHE LT_CLOUD_CACHE_TTL LT_LOGO_CACHE
    export LT_GITHUB_URL LT_CLOUD_TREE_URL LT_CLOUD_RAW_BASE
}

lt_paths_init

LT_COLOR_RESET=$'\033[0m'
LT_COLOR_RED=$'\033[0;31m'
LT_COLOR_GREEN=$'\033[0;32m'
LT_COLOR_YELLOW=$'\033[1;33m'
LT_COLOR_BLUE=$'\033[0;34m'
LT_COLOR_CYAN=$'\033[0;36m'
LT_COLOR_BOLD=$'\033[1m'
LT_COLOR_DIM=$'\033[2m'
LT_COLOR_MAGENTA=$'\033[0;35m'

lt_term_cols() {
    local cols
    cols="$(tput cols 2>/dev/null || printf '100')"
    printf '%s\n' "${cols:-100}"
}

lt_term_lines() {
    local lines
    lines="$(tput lines 2>/dev/null || printf '30')"
    printf '%s\n' "${lines:-30}"
}

lt_print_info() {
    printf '%s[INFO]%s %s\n' "$LT_COLOR_CYAN" "$LT_COLOR_RESET" "$*"
}

lt_print_ok() {
    printf '%s[OK]%s %s\n' "$LT_COLOR_GREEN" "$LT_COLOR_RESET" "$*"
}

lt_print_warn() {
    printf '%s[WARN]%s %s\n' "$LT_COLOR_YELLOW" "$LT_COLOR_RESET" "$*"
}

lt_print_error() {
    printf '%s[ERROR]%s %s\n' "$LT_COLOR_RED" "$LT_COLOR_RESET" "$*" >&2
}

lt_die() {
    lt_print_error "$*"
    exit 1
}

lt_has_command() {
    command -v "$1" >/dev/null 2>&1
}

lt_ensure_dir() {
    mkdir -p "$1"
}

lt_trim() {
    local value="$*"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

lt_pretty_path() {
    local path="$1"
    case "$path" in
        "$HOME"/*) printf '~/%s' "${path#"$HOME/"}" ;;
        "$HOME") printf '~' ;;
        *) printf '%s' "$path" ;;
    esac
}

lt_shell_quote() {
    local value="$1"
    printf "'%s'" "$(printf '%s' "$value" | sed "s/'/'\\\\''/g")"
}

lt_hyperlink() {
    local url="$1"
    local label="${2:-$1}"

    if [ -t 1 ]; then
        printf '\033]8;;%s\033\\%s\033]8;;\033\\' "$url" "$label"
    else
        printf '%s' "$label"
    fi
}

lt_pause() {
    if [ -t 0 ]; then
        printf '\nPress Enter to continue...'
        read -r _ || true
    fi
}

lt_package_hint() {
    local package="$1"

    if lt_has_command apt; then
        printf 'sudo apt install %s\n' "$package"
    elif lt_has_command dnf; then
        printf 'sudo dnf install %s\n' "$package"
    elif lt_has_command pacman; then
        printf 'sudo pacman -S %s\n' "$package"
    elif lt_has_command zypper; then
        printf 'sudo zypper install %s\n' "$package"
    else
        printf 'Install %s with your distribution package manager.\n' "$package"
    fi
}

lt_file_age_seconds() {
    local file="$1"
    local now
    local mtime

    [ -f "$file" ] || return 1
    now="$(date +%s)"
    if mtime="$(stat -c %Y "$file" 2>/dev/null)"; then
        printf '%s\n' "$((now - mtime))"
        return 0
    fi

    if mtime="$(stat -f %m "$file" 2>/dev/null)"; then
        printf '%s\n' "$((now - mtime))"
        return 0
    fi

    return 1
}

lt_cache_is_fresh() {
    local file="$1"
    local ttl="$2"
    local age

    age="$(lt_file_age_seconds "$file" 2>/dev/null)" || return 1
    [ "$age" -le "$ttl" ]
}
