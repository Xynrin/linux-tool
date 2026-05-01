#!/usr/bin/env bash

lt_ui_header() {
    clear 2>/dev/null || true
    lt_logo_print
    printf '\n'
    printf '%sLinux Tool Center%s  version %s\n' "$LT_COLOR_BOLD" "$LT_COLOR_RESET" "$(lt_version)"
    printf '工具目录：%s\n' "$(lt_pretty_path "$LT_TOOL_DIR")"
    printf '日志文件：%s\n' "$(lt_pretty_path "$LT_LOG_FILE")"
    printf '\n'
}

lt_ui_require_fzf() {
    if lt_has_command fzf; then
        return 0
    fi

    lt_print_error "fzf is required for the TUI."
    lt_print_info "install hint: $(lt_package_hint fzf)"
    return 1
}

lt_ui_start() {
    local selected
    local status
    local self
    local list_cmd

    lt_ui_header
    lt_ui_require_fzf || return 1

    if [ -z "$(lt_tool_list_for_fzf)" ]; then
        lt_print_warn "no tools found in $(lt_pretty_path "$LT_TOOL_DIR")"
        return 0
    fi

    self="$(lt_shell_quote "$LT_ENTRYPOINT")"
    list_cmd="${self} list --fzf"

    set +e
    selected="$(
        lt_tool_list_for_fzf | fzf \
            --ansi \
            --height=90% \
            --border=rounded \
            --layout=reverse \
            --prompt="linux-tool > " \
            --delimiter=$'\t' \
            --with-nth=2 \
            --preview="${self} preview {1}" \
            --preview-window=right:55%:wrap \
            --bind="ctrl-r:reload(${list_cmd})" \
            --bind="ctrl-i:execute(${self} preview {1} < /dev/tty > /dev/tty 2>&1)" \
            --bind="ctrl-u:execute(${self} update < /dev/tty > /dev/tty 2>&1)" \
            --bind="ctrl-l:execute(${self} logs < /dev/tty > /dev/tty 2>&1)"
    )"
    status=$?
    set -e

    if [ "$status" -ne 0 ] || [ -z "$selected" ]; then
        lt_log_info "exit linux-tool"
        return 0
    fi

    "$LT_ENTRYPOINT" run "${selected%%$'\t'*}"
}
