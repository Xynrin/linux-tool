#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/Xynrin/linux-tool}"
BRANCH="${BRANCH:-main}"

COLOR_RESET=$'\033[0m'
COLOR_RED=$'\033[0;31m'
COLOR_GREEN=$'\033[0;32m'
COLOR_YELLOW=$'\033[1;33m'
COLOR_CYAN=$'\033[0;36m'

TEMP_DIRS=()

cleanup() {
    local dir
    for dir in "${TEMP_DIRS[@]:-}"; do
        [ -n "$dir" ] && [ -d "$dir" ] && rm -rf "$dir"
    done
    return 0
}
trap cleanup EXIT

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

run_with_spinner() {
    local message="$1"
    shift
    local frames='|/-\'
    local i=0
    local pid
    local status

    if [ ! -t 2 ]; then
        print_info "$message" >&2
        "$@"
        return $?
    fi

    "$@" &
    pid=$!
    while kill -0 "$pid" 2>/dev/null; do
        printf '\r%s[INFO]%s %s %s' "$COLOR_CYAN" "$COLOR_RESET" "$message" "${frames:i++%4:1}" >&2
        sleep 0.12
    done

    wait "$pid"
    status=$?
    printf '\r\033[K' >&2
    if [ "$status" -eq 0 ]; then
        print_ok "$message" >&2
    else
        print_error "$message failed"
    fi
    return "$status"
}

die() {
    print_error "$*"
    exit 1
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

    [ -n "$home" ] && [ -d "$home" ] || die "cannot detect home directory for user: $user"
    printf '%s\n' "$home"
}

package_hint() {
    local package="$1"

    if has_command apt; then
        printf 'sudo apt install %s\n' "$package"
    elif has_command dnf; then
        printf 'sudo dnf install %s\n' "$package"
    elif has_command pacman; then
        printf 'sudo pacman -S %s\n' "$package"
    elif has_command zypper; then
        printf 'sudo zypper install %s\n' "$package"
    else
        printf 'Install %s with your distribution package manager.\n' "$package"
    fi
}

script_dir() {
    local source="${BASH_SOURCE[0]:-$0}"
    local dir

    if [ -n "$source" ] && [ -f "$source" ]; then
        dir="$(cd "$(dirname "$source")" >/dev/null 2>&1 && pwd)"
    else
        dir="$(pwd)"
    fi

    printf '%s\n' "$dir"
}

download_source() {
    local temp_dir
    local archive
    local url

    has_command curl || die "curl is required when installing from a remote script"
    has_command tar || die "tar is required when installing from a remote script"

    temp_dir="$(mktemp -d)"
    TEMP_DIRS+=("$temp_dir")
    archive="${temp_dir}/linux-tool.tar.gz"
    url="${REPO_URL}/archive/refs/heads/${BRANCH}.tar.gz"

    print_info "downloading linux-tool from $url" >&2
    run_with_spinner "download linux-tool" curl -fsSL "$url" -o "$archive" || die "failed to download linux-tool archive"

    mkdir -p "${temp_dir}/source"
    run_with_spinner "extract linux-tool" tar -xzf "$archive" --strip-components=1 -C "${temp_dir}/source" || die "failed to extract linux-tool archive"
    [ -f "${temp_dir}/source/bin/linux-tool" ] && [ -d "${temp_dir}/source/lib" ] || {
        die "downloaded archive does not look like a linux-tool release"
    }

    printf '%s\n' "${temp_dir}/source"
}

detect_source_dir() {
    local dir
    dir="$(script_dir)"

    if [ -f "${dir}/bin/linux-tool" ] && [ -d "${dir}/lib" ] && [ -d "${dir}/tool" ]; then
        printf '%s\n' "$dir"
        return 0
    fi

    download_source
}

safe_remove_app_dir() {
    local app_dir="$1"
    local target_home="$2"

    case "$app_dir" in
        "$target_home"/.local/share/linux-tool/app) rm -rf "$app_dir" ;;
        *) die "refusing to remove unexpected application path: $app_dir" ;;
    esac
}

copy_application() {
    local source_dir="$1"
    local app_dir="$2"
    local target_home="$3"
    local backup_dir="$4"
    local source_real
    local app_real

    mkdir -p "$(dirname "$app_dir")" "$backup_dir"
    source_real="$(cd "$source_dir" >/dev/null 2>&1 && pwd -P)"

    if [ -d "$app_dir" ]; then
        app_real="$(cd "$app_dir" >/dev/null 2>&1 && pwd -P)"
    else
        app_real=""
    fi

    if [ "$source_real" = "$app_real" ]; then
        print_info "source is already the installed app directory"
        return 0
    fi

    if [ -d "$app_dir" ]; then
        local backup_path="${backup_dir}/install-$(date '+%Y%m%d_%H%M%S')"
        print_info "backup existing app to $backup_path"
        cp -a "$app_dir" "$backup_path"
        safe_remove_app_dir "$app_dir" "$target_home"
    fi

    mkdir -p "$app_dir"
    cp -a "${source_dir}/." "$app_dir/"
    rm -rf "${app_dir}/.git" "${app_dir}/tool"
}

prepare_tool_storage() {
    local source_dir="$1"
    local tool_dir="$2"
    local tool_file
    local target_file

    mkdir -p "$tool_dir"

    if [ -d "${source_dir}/tool" ]; then
        while IFS= read -r tool_file; do
            [ -n "$tool_file" ] || continue
            target_file="${tool_dir}/$(basename "$tool_file")"
            if [ ! -e "$target_file" ]; then
                cp "$tool_file" "$target_file"
                chmod +x "$target_file" 2>/dev/null || true
            fi
        done < <(find "${source_dir}/tool" -maxdepth 1 -type f -name '*.sh' 2>/dev/null | sort)
    fi
}

create_commands() {
    local bin_dir="$1"
    local app_dir="$2"

    mkdir -p "$bin_dir"
    chmod +x "${app_dir}/bin/linux-tool"

    ln -sfn "${app_dir}/bin/linux-tool" "${bin_dir}/linux-tool"
    ln -sfn "${bin_dir}/linux-tool" "${bin_dir}/linuxtool"
}

fix_ownership() {
    local target_user="$1"
    local target_group="$2"
    shift 2

    if [ "$(id -u)" -eq 0 ]; then
        chown -R "${target_user}:${target_group}" "$@" 2>/dev/null || true
    fi
}

main() {
    local target_user
    local target_group
    local target_home
    local source_dir
    local bin_dir
    local data_root
    local app_dir
    local tool_dir
    local state_root
    local log_dir
    local backup_dir

    target_user="$(detect_target_user)"
    target_group="$(id -gn "$target_user" 2>/dev/null || printf '%s' "$target_user")"
    target_home="$(detect_user_home "$target_user")"
    source_dir="$(detect_source_dir)"
    [ -d "$source_dir" ] || die "source directory not found: $source_dir"

    bin_dir="${target_home}/.local/bin"
    data_root="${target_home}/.local/share/linux-tool"
    app_dir="${data_root}/app"
    tool_dir="${data_root}/tool"
    state_root="${target_home}/.local/state/linux-tool"
    log_dir="${state_root}"
    backup_dir="${data_root}/backups"

    print_info "target user: $target_user"
    print_info "source dir: $source_dir"
    print_info "app dir: $app_dir"

    mkdir -p "$bin_dir" "$data_root" "$tool_dir" "$log_dir" "$backup_dir"
    copy_application "$source_dir" "$app_dir" "$target_home" "$backup_dir"
    prepare_tool_storage "$source_dir" "$tool_dir"
    create_commands "$bin_dir" "$app_dir"

    chmod +x "${tool_dir}"/*.sh 2>/dev/null || true
    fix_ownership "$target_user" "$target_group" "$bin_dir" "$data_root" "$state_root"

    print_ok "installed linux-tool"
    print_info "main command: ${bin_dir}/linux-tool"
    print_info "compat command: ${bin_dir}/linuxtool"
    print_info "tool dir: ${tool_dir}"
    print_info "log file: ${log_dir}/linux-tool.log"

    case ":${PATH}:" in
        *":${bin_dir}:"*) ;;
        *)
            print_warn "${bin_dir} is not in PATH"
            print_info "add this line to your shell profile:"
            printf 'export PATH="$HOME/.local/bin:$PATH"\n'
            ;;
    esac

    if ! has_command fzf; then
        print_warn "fzf is not installed; the TUI needs it"
        print_info "install hint: $(package_hint fzf)"
    fi

    if ! has_command npx; then
        print_warn "npx is not installed; static logo fallback will be used"
    fi

    print_ok "try: linux-tool --version"
}

main "$@"
