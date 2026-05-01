#!/usr/bin/env bash

LT_UPDATE_OK=0
LT_UPDATE_FAILED=1
LT_UPDATE_REFUSED=2
LT_UPDATE_REMOTE_FAILED=3
LT_UPDATE_RESTART_REQUIRED=10

lt_update_step() {
    printf '%s[INFO]%s %s\n' "$LT_COLOR_CYAN" "$LT_COLOR_RESET" "$*"
}

lt_update_done() {
    printf '%s[OK]%s %s\n' "$LT_COLOR_GREEN" "$LT_COLOR_RESET" "$*"
}

lt_update_remote_version_url() {
    printf '%s/VERSION\n' "$LT_CLOUD_RAW_BASE"
}

lt_update_fetch_remote_version() {
    local output
    local url

    lt_has_command curl || return 1
    url="$(lt_update_remote_version_url)"
    output="$(curl -fsSL --connect-timeout 3 --max-time 8 "$url" 2>/dev/null | head -n 1 | tr -d '\r\n')" || return 1
    [ -n "$output" ] || return 1
    printf '%s\n' "$output"
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
    printf '%sLinux Tool Update%s\n' "$LT_COLOR_BOLD" "$LT_COLOR_RESET"
    printf '当前版本：%s\n' "$(lt_version)"
    printf '应用目录：%s\n' "$(lt_pretty_path "$LT_APP_DIR")"
    printf '工具目录：%s\n' "$(lt_pretty_path "$LT_TOOL_DIR")"
    printf '远程版本：%s\n' "$(lt_update_remote_version_url)"
    printf '\n'
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

lt_update_sync_bundled_tools() {
    local bundled_dir="${LT_APP_DIR}/tool"
    local source_file
    local target_file

    [ -d "$bundled_dir" ] || return 0
    lt_ensure_dir "$LT_TOOL_DIR"

    while IFS= read -r source_file; do
        [ -n "$source_file" ] || continue
        target_file="${LT_TOOL_DIR}/$(basename "$source_file")"
        if [ ! -e "$target_file" ]; then
            cp "$source_file" "$target_file"
            chmod +x "$target_file" 2>/dev/null || true
            lt_log_info "install bundled tool: $(basename "$source_file")"
        fi
    done < <(find "$bundled_dir" -maxdepth 1 -type f -name '*.sh' 2>/dev/null | sort)
}

lt_update_finalize_app() {
    chmod +x "${LT_APP_DIR}/bin/linux-tool" 2>/dev/null || true
    lt_ensure_dir "$LT_TOOL_DIR"
    lt_ensure_dir "$LT_INSTALL_DB"
    lt_ensure_dir "$LT_CLOUD_TOOL_CACHE"

    if [ "$LT_APP_DIR" = "$LT_DEFAULT_APP_DIR" ]; then
        lt_update_sync_bundled_tools
        rm -rf "${LT_APP_DIR}/tool"
    fi

    if [ -d "$LT_TOOL_DIR" ]; then
        find "$LT_TOOL_DIR" -maxdepth 1 -type f -name '*.sh' -exec chmod +x {} \; 2>/dev/null || true
    fi
}

lt_update_from_git() {
    lt_update_step "使用 git 更新：$(lt_pretty_path "$LT_APP_DIR")"
    lt_update_spinner "git pull --ff-only" git -C "$LT_APP_DIR" pull --ff-only
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
    if ! cp -a "${temp_dir}/extract" "$LT_APP_DIR"; then
        rm -rf "$temp_dir"
        lt_update_restore_backup "$backup_path"
        return 1
    fi

    rm -rf "${LT_APP_DIR}/.git"
    rm -rf "$temp_dir"
}

lt_update_perform() {
    local backup_path

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
        if ! lt_update_from_git; then
            lt_log_error "update failed: git pull failed"
            return 1
        fi
    else
        if ! lt_update_from_archive "$backup_path"; then
            lt_log_error "update failed: archive update failed"
            lt_print_error "更新失败，已回滚到备份。"
            return 1
        fi
    fi

    lt_update_finalize_app
    return 0
}

lt_update_confirm() {
    local local_version="$1"
    local remote_version="$2"
    local answer

    if [ ! -t 0 ]; then
        return 1
    fi

    printf '发现新版本。\n'
    printf '当前版本：%s\n' "$local_version"
    printf '最新版本：%s\n' "$remote_version"
    printf '是否现在更新？[y/N] '
    read -r answer || return 1

    case "${answer,,}" in
        y|yes) return 0 ;;
        *) return 1 ;;
    esac
}

lt_update_restart() {
    local self="${LINUX_TOOL_SELF:-${LT_ENTRYPOINT:-}}"
    local resolved

    if [ -n "$self" ] && [ -x "$self" ]; then
        exec "$self"
    fi

    resolved="$(command -v linux-tool 2>/dev/null || true)"
    if [ -n "$resolved" ]; then
        exec "$resolved"
    fi

    lt_print_error "更新已完成，但自动重启失败。"
    printf '请手动重新运行：linux-tool\n'
    return "$LT_UPDATE_RESTART_REQUIRED"
}

lt_update_same_message() {
    local local_version="$1"
    local remote_version="$2"

    printf '当前已经是最新版本。\n'
    printf '当前版本：%s\n' "$local_version"
    printf '最新版本：%s\n' "$remote_version"
}

lt_update_run() {
    local mode="${1:-manual}"
    local local_version
    local local_compare_version
    local remote_version
    local remote_compare_version
    local compare_result

    local_version="$(lt_version)"

    remote_version="$(lt_update_fetch_remote_version || true)"
    if [ -z "$remote_version" ]; then
        lt_log_warn "update check failed: remote version unavailable"
        if [ "$mode" != "startup" ]; then
            lt_print_warn "无法读取远程版本，已取消更新。"
        fi
        return "$LT_UPDATE_REMOTE_FAILED"
    fi

    if ! remote_compare_version="$(normalize_version "$remote_version")"; then
        lt_log_warn "remote version format invalid: $remote_version"
        if [ "$mode" != "startup" ]; then
            printf '远程版本格式异常，已取消更新。\n'
        fi
        return "$LT_UPDATE_REMOTE_FAILED"
    fi

    if ! local_compare_version="$(normalize_version "$local_version")"; then
        local_compare_version="0.0.0"
    fi

    compare_result="$(compare_versions "$remote_compare_version" "$local_compare_version")" || {
        lt_log_warn "version compare failed: local=$local_version remote=$remote_version"
        if [ "$mode" != "startup" ]; then
            printf '远程版本格式异常，已取消更新。\n'
        fi
        return "$LT_UPDATE_REMOTE_FAILED"
    }

    if [ "$compare_result" -eq 0 ]; then
        lt_log_info "already latest version: $local_compare_version"
        if [ "$mode" != "startup" ]; then
            lt_update_same_message "$local_compare_version" "$remote_compare_version"
        fi
        return "$LT_UPDATE_OK"
    fi

    if [ "$compare_result" -lt 0 ]; then
        lt_log_info "local version is newer than remote: local=$local_compare_version remote=$remote_compare_version"
        if [ "$mode" != "startup" ]; then
            printf '当前版本不低于远程版本。\n'
            printf '当前版本：%s\n' "$local_compare_version"
            printf '最新版本：%s\n' "$remote_compare_version"
        fi
        return "$LT_UPDATE_OK"
    fi

    lt_log_info "new version available: local=$local_compare_version remote=$remote_compare_version"
    if ! lt_update_confirm "$local_compare_version" "$remote_compare_version"; then
        lt_log_info "update cancelled by user: local=$local_compare_version remote=$remote_compare_version"
        if [ "$mode" != "startup" ]; then
            lt_print_warn "已取消更新。"
        fi
        return "$LT_UPDATE_REFUSED"
    fi

    lt_update_header
    if lt_update_perform; then
        lt_log_info "update success: $(lt_version)"
        lt_update_done "更新完成：linux-tool $(lt_version)"
        case "$mode" in
            tui|startup)
                printf '更新完成，正在重新启动 linux-tool...\n'
                lt_update_restart
                return "$LT_UPDATE_RESTART_REQUIRED"
                ;;
            *)
                printf '更新完成。请重新运行 linux-tool。\n'
                return "$LT_UPDATE_RESTART_REQUIRED"
                ;;
        esac
    fi

    lt_log_error "update failed"
    lt_print_error "更新失败。"
    return "$LT_UPDATE_FAILED"
}

lt_update_startup_check() {
    local status

    [ "${LT_SKIP_UPDATE_CHECK:-0}" = "1" ] && return 0
    set +e
    lt_update_run "startup"
    status=$?
    set -e
    case "$status" in
        "$LT_UPDATE_RESTART_REQUIRED")
            exit 0
            ;;
        "$LT_UPDATE_FAILED")
            lt_print_warn "启动更新失败，已继续进入当前版本。"
            return 0
            ;;
        *)
            return 0
            ;;
    esac
}

lt_update() {
    local status

    set +e
    lt_update_run "manual"
    status=$?
    set -e
    case "$status" in
        "$LT_UPDATE_RESTART_REQUIRED") return 0 ;;
        "$LT_UPDATE_REFUSED") return 0 ;;
        *) return "$status" ;;
    esac
}
