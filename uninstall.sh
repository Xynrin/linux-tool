#!/usr/bin/env bash
set -euo pipefail

COLOR_RESET=$'\033[0m'
COLOR_RED=$'\033[0;31m'
COLOR_GREEN=$'\033[0;32m'
COLOR_YELLOW=$'\033[1;33m'
COLOR_CYAN=$'\033[0;36m'

print_info() {
    printf '%s[INFO]%s %s\n' "$COLOR_CYAN" "$COLOR_RESET" "$*"
}

print_ok() {
    printf '%s[OK]%s %s\n' "$COLOR_GREEN" "$COLOR_RESET" "$*"
}

print_warn() {
    printf '%s[WARN]%s %s\n' "$COLOR_YELLOW" "$COLOR_RESET" "$*"
}

print_error() {
    printf '%s[ERROR]%s %s\n' "$COLOR_RED" "$COLOR_RESET" "$*" >&2
}

has_command() {
    command -v "$1" >/dev/null 2>&1
}

detect_target_user() {
    if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
        printf '%s\n' "$SUDO_USER"
    else
        id -un
    fi
}

detect_user_home() {
    local user="$1"
    local home=""

    if has_command getent; then
        home="$(getent passwd "$user" | cut -d: -f6 || true)"
    fi

    if [ -z "$home" ]; then
        home="$(eval "printf '%s' ~${user}" 2>/dev/null || true)"
    fi

    [ -n "$home" ] && [ -d "$home" ] || {
        print_error "cannot detect home directory for user: $user"
        exit 1
    }

    printf '%s\n' "$home"
}

safe_rm_rf() {
    local path="$1"
    local target_home="$2"

    case "$path" in
        "$target_home"/.local/share/linux-tool|"$target_home"/.local/state/linux-tool|"$target_home"/.cache/linux-tool)
            rm -rf "$path"
            ;;
        *)
            print_error "refusing to remove unexpected path: $path"
            return 1
            ;;
    esac
}

ask_delete_logs() {
    local answer

    if [ ! -t 0 ]; then
        return 1
    fi

    printf 'Delete logs under ~/.local/state/linux-tool? [y/N] '
    read -r answer || return 1
    case "${answer,,}" in
        y|yes) return 0 ;;
        *) return 1 ;;
    esac
}

main() {
    local target_user
    local target_home
    local bin_dir
    local data_root
    local state_root
    local cache_root

    target_user="$(detect_target_user)"
    target_home="$(detect_user_home "$target_user")"
    bin_dir="${target_home}/.local/bin"
    data_root="${target_home}/.local/share/linux-tool"
    state_root="${target_home}/.local/state/linux-tool"
    cache_root="${target_home}/.cache/linux-tool"

    print_info "uninstalling linux-tool for user: $target_user"

    rm -f "${bin_dir}/linux-tool" "${bin_dir}/linuxtool"
    if [ -d "$data_root" ]; then
        safe_rm_rf "$data_root" "$target_home"
    fi

    if [ -d "$state_root" ]; then
        if ask_delete_logs; then
            safe_rm_rf "$state_root" "$target_home"
            print_ok "logs removed"
        else
            print_warn "logs kept: ${state_root}"
        fi
    fi

    if [ -d "$cache_root" ]; then
        safe_rm_rf "$cache_root" "$target_home"
        print_ok "cache removed"
    fi

    print_ok "linux-tool uninstalled"
}

main "$@"
