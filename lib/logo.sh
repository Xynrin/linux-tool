#!/usr/bin/env bash

lt_logo_static() {
    local logo_file="${LT_ASSETS_DIR}/logo.txt"

    if [ -f "$logo_file" ]; then
        printf '%b\n' "$(cat "$logo_file")"
        return 0
    fi

    printf '%b\n' "\033[1;36m _ _                      _              _ \033[0m"
    printf '%b\n' "\033[1;36m| (_)_ __  _   ___  __   | |_ ___   ___ | |\033[0m"
    printf '%b\n' "\033[1;36m| | | '_ \| | | \ \/ /   | __/ _ \ / _ \| |\033[0m"
    printf '%b\n' "\033[1;32m| | | | | | |_| |>  <    | || (_) | (_) | |\033[0m"
    printf '%b\n' "\033[1;32m|_|_|_| |_|\__,_/_/\_\    \__\___/ \___/|_|\033[0m"
}

lt_logo_dynamic() {
    local output

    [ "${LT_NO_DYNAMIC_LOGO:-0}" = "1" ] && return 1
    lt_has_command npx || return 1

    if lt_has_command timeout; then
        output="$(timeout 6s npx --yes oh-my-logo@latest "linux-tool" fire --filled 2>/dev/null)" || return 1
    else
        output="$(npx --yes oh-my-logo@latest "linux-tool" fire --filled 2>/dev/null)" || return 1
    fi

    [ -n "$output" ] || return 1
    printf '%s\n' "$output"
}

lt_logo_print() {
    if ! lt_logo_dynamic; then
        lt_logo_static
    fi
}
