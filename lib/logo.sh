#!/usr/bin/env bash

lt_logo_compact() {
    printf '%b\n' "\033[1;36m██╗     ██╗███╗   ██╗██╗   ██╗██╗  ██╗\033[0m\033[1;35m    ████████╗ ██████╗  ██████╗ ██╗\033[0m"
    printf '%b\n' "\033[1;36m██║     ██║████╗  ██║██║   ██║╚██╗██╔╝\033[0m\033[1;35m    ╚══██╔══╝██╔═══██╗██╔═══██╗██║\033[0m"
    printf '%b\n' "\033[1;34m██║     ██║██╔██╗ ██║██║   ██║ ╚███╔╝ \033[0m\033[1;32m       ██║   ██║   ██║██║   ██║██║\033[0m"
    printf '%b\n' "\033[1;32m███████╗██║██║ ╚████║╚██████╔╝ ██╔██╗ \033[0m\033[1;32m       ██║   ╚██████╔╝╚██████╔╝███████╗\033[0m"
    printf '%b\n' "\033[1;32m╚══════╝╚═╝╚═╝  ╚═══╝ ╚═════╝  ╚═╝╚═╝ \033[0m\033[1;36m       ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝\033[0m"
}

lt_logo_small() {
    printf '%b\n' "\033[1;36mlinux\033[0m\033[1;35m-tool\033[0m  \033[1;32mLinux Tool Center\033[0m"
}

lt_logo_static() {
    local logo_file="${LT_ASSETS_DIR}/logo.txt"
    local cols

    cols="$(lt_term_cols)"
    if [ "$cols" -lt 82 ]; then
        lt_logo_small
        return 0
    fi

    if [ -f "$logo_file" ]; then
        printf '%b\n' "$(cat "$logo_file")"
        return 0
    fi

    lt_logo_compact
}

lt_logo_dynamic_cache() {
    local output
    local tmp_file

    [ "${LT_LOGO_DYNAMIC:-0}" = "1" ] || return 1
    [ "${LT_NO_DYNAMIC_LOGO:-0}" = "1" ] && return 1
    lt_has_command npx || return 1

    if [ -f "$LT_LOGO_CACHE" ]; then
        cat "$LT_LOGO_CACHE"
        return 0
    fi

    lt_ensure_dir "$(dirname "$LT_LOGO_CACHE")"
    tmp_file="${LT_LOGO_CACHE}.tmp.$$"

    if lt_has_command timeout; then
        output="$(timeout 8s npx --yes oh-my-logo@latest "linux-tool" fire --filled 2>/dev/null)" || return 1
    else
        output="$(npx --yes oh-my-logo@latest "linux-tool" fire --filled 2>/dev/null)" || return 1
    fi

    [ -n "$output" ] || return 1
    printf '%s\n' "$output" >"$tmp_file"
    mv "$tmp_file" "$LT_LOGO_CACHE"
    printf '%s\n' "$output"
}

lt_logo_print() {
    if ! lt_logo_dynamic_cache; then
        lt_logo_static
    fi
}
