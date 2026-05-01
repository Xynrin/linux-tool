#!/usr/bin/env bash

lt_ui_fzf_header() {
    lt_logo_print
    cat <<EOF

Linux Tool Center  version $(lt_version)
本地工具：$(lt_pretty_path "$LT_TOOL_DIR")
云端来源：${LT_GITHUB_REPO}@${LT_GITHUB_BRANCH}
日志文件：$(lt_pretty_path "$LT_LOG_FILE")

Enter：安装/运行工具  Ctrl+X：删除本地工具  Ctrl+R：刷新云端列表
Ctrl+I：查看信息      Ctrl+U：检查更新      Ctrl+L：查看日志      Esc：退出
EOF
}

lt_ui_header() {
    clear 2>/dev/null || true
    lt_ui_fzf_header
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
    local header

    if ! lt_has_command fzf; then
        lt_ui_header
        lt_ui_require_fzf || return 1
    fi

    self="$(lt_shell_quote "$LT_ENTRYPOINT")"
    list_cmd="${self} list --fzf"
    header="$(lt_ui_fzf_header)"

    while true; do
        if [ -z "$(lt_tool_list_for_fzf)" ]; then
            lt_print_warn "no local tools or cloud tools found"
            return 0
        fi

        set +e
        selected="$(
            lt_tool_list_for_fzf | fzf \
                --ansi \
                --height=90% \
                --border=rounded \
                --layout=reverse \
                --prompt="linux-tool > " \
                --header="$header" \
                --header-first \
                --delimiter=$'\t' \
                --with-nth=2 \
                --preview="${self} preview {1}" \
                --preview-window=right:55%:wrap \
                --bind="ctrl-r:reload(${list_cmd})" \
                --bind="ctrl-i:execute(${self} preview {1} < /dev/tty > /dev/tty 2>&1)" \
                --bind="ctrl-u:execute(${self} update < /dev/tty > /dev/tty 2>&1)" \
                --bind="ctrl-l:execute(${self} logs < /dev/tty > /dev/tty 2>&1)" \
                --bind="ctrl-x:execute(${self} remove {1} < /dev/tty > /dev/tty 2>&1)+reload(${list_cmd})"
        )"
        status=$?
        set -e

        if [ "$status" -ne 0 ] || [ -z "$selected" ]; then
            lt_log_info "exit linux-tool"
            return 0
        fi

        "$LT_ENTRYPOINT" run "${selected%%$'\t'*}" || true
        lt_pause
    done
}
