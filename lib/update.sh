#!/usr/bin/env bash

lt_update_step() {
    printf '%s[INFO]%s %s\n' "$LT_COLOR_CYAN" "$LT_COLOR_RESET" "$*"
}

lt_update_done() {
    printf '%s[OK]%s %s\n' "$LT_COLOR_GREEN" "$LT_COLOR_RESET" "$*"
}

lt_update_spinner() {
    local message="$1"
    shift
    local frames='|/-\'
    local i=0
    local pid
    local status

    if [ ! -t 1 ]; then
        lt_update_step "$message"
        "$@"
        return $?
    fi

    "$@" &
    pid=$!
    while kill -0 "$pid" 2>/dev/null; do
        printf '\r%s[INFO]%s %s %s' "$LT_COLOR_CYAN" "$LT_COLOR_RESET" "$message" "${frames:i++%4:1}"
        sleep 0.12
    done

    wait "$pid"
    status=$?
    printf '\r\033[K'
    if [ "$status" -eq 0 ]; then
        lt_update_done "$message"
    else
        lt_print_error "$message failed"
    fi
    return "$status"
}

lt_update_header() {
    clear 2>/dev/null || true
    lt_logo_print
    printf '\n'
    printf '%sLinux Tool Update%s\n' "$LT_COLOR_BOLD" "$LT_COLOR_RESET"
    printf '当前版本：%s\n' "$(lt_version)"
    printf '应用目录：%s\n' "$(lt_pretty_path "$LT_APP_DIR")"
    printf '工具目录：%s\n' "$(lt_pretty_path "$LT_TOOL_DIR")"
    printf '项目主页：'
    lt_hyperlink "$LT_GITHUB_URL" "$LT_GITHUB_URL"
    printf '\n\n'
}

lt_update_backup_app() {
    local timestamp
    local backup_path

    timestamp="$(date '+%Y%m%d_%H%M%S')"
    backup_path="${LT_BACKUP_DIR}/app-${timestamp}"
    lt_ensure_dir "$LT_BACKUP_DIR"
    cp -a "$LT_APP_DIR" "$backup_path"
    printf '%s\n' "$backup_path"
}

lt_update_restore_backup() {
    local backup_path="$1"

    if [ -d "$backup_path" ]; then
        rm -rf "$LT_APP_DIR"
        cp -a "$backup_path" "$LT_APP_DIR"
    fi
}

lt_update_finalize_app() {
    rm -rf "${LT_APP_DIR}/tool"
    chmod +x "${LT_APP_DIR}/bin/linux-tool" 2>/dev/null || true
    lt_ensure_dir "$LT_TOOL_DIR"
    lt_ensure_dir "$LT_INSTALL_DB"
    lt_ensure_dir "$LT_CLOUD_TOOL_CACHE"

    if [ -d "$LT_TOOL_DIR" ]; then
        find "$LT_TOOL_DIR" -maxdepth 1 -type f -name '*.sh' -exec chmod +x {} \; 2>/dev/null || true
    fi
}

lt_update_from_git() {
    local backup_path="$1"

    lt_update_step "使用 git 更新：$(lt_pretty_path "$LT_APP_DIR")"
    if lt_update_spinner "git pull --ff-only" git -C "$LT_APP_DIR" pull --ff-only; then
        return 0
    fi

    lt_print_error "git update failed, rolling back"
    lt_update_restore_backup "$backup_path"
    return 1
}

lt_update_from_archive() {
    local backup_path="$1"
    local temp_dir
    local archive
    local url

    lt_has_command curl || {
        lt_print_error "curl is required for archive updates"
        return 1
    }
    lt_has_command tar || {
        lt_print_error "tar is required for archive updates"
        return 1
    }

    temp_dir="$(mktemp -d)"
    archive="${temp_dir}/linux-tool.tar.gz"
    url="https://github.com/${LT_GITHUB_REPO}/archive/refs/heads/${LT_GITHUB_BRANCH}.tar.gz"

    lt_update_step "更新源：$url"
    if ! lt_update_spinner "下载最新版本" curl -fsSL "$url" -o "$archive"; then
        rm -rf "$temp_dir"
        lt_update_restore_backup "$backup_path"
        return 1
    fi

    mkdir -p "${temp_dir}/extract"
    if ! lt_update_spinner "解压应用文件" tar -xzf "$archive" --strip-components=1 -C "${temp_dir}/extract"; then
        rm -rf "$temp_dir"
        lt_update_restore_backup "$backup_path"
        return 1
    fi

    rm -rf "$LT_APP_DIR"
    mkdir -p "$(dirname "$LT_APP_DIR")"
    cp -a "${temp_dir}/extract" "$LT_APP_DIR"
    rm -rf "${LT_APP_DIR}/.git" "${LT_APP_DIR}/tool"
    rm -rf "$temp_dir"
}

lt_update() {
    local backup_path

    lt_update_header
    if [ -z "$LT_APP_DIR" ] || [ "$LT_APP_DIR" = "/" ]; then
        lt_print_error "refusing to update unsafe application path: ${LT_APP_DIR:-empty}"
        return 1
    fi

    if [ ! -d "$LT_APP_DIR" ]; then
        lt_print_error "application directory not found: $(lt_pretty_path "$LT_APP_DIR")"
        return 1
    fi

    backup_path="$(lt_update_backup_app)"
    lt_update_done "备份完成：$(lt_pretty_path "$backup_path")"

    if [ -d "${LT_APP_DIR}/.git" ] && [ "$LT_APP_DIR" != "$LT_DEFAULT_APP_DIR" ] && lt_has_command git; then
        if ! lt_update_from_git "$backup_path"; then
            lt_log_error "update failed"
            return 1
        fi
    else
        if ! lt_update_from_archive "$backup_path"; then
            lt_log_error "update failed"
            lt_print_error "更新失败，已回滚到备份"
            return 1
        fi
    fi

    lt_update_finalize_app
    lt_log_info "update success: $(lt_version)"
    lt_update_done "更新完成：linux-tool $(lt_version)"
}
