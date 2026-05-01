#!/usr/bin/env bash

lt_ui_project_link() {
    printf '\033]8;;%s\033\\%s\033]8;;\033\\' "$LT_GITHUB_URL" "$LT_GITHUB_URL"
}

lt_ui_rule() {
    local cols
    local width

    cols="$(lt_term_cols)"
    if [ "$cols" -lt 40 ]; then
        width="$cols"
    elif [ "$cols" -gt 110 ]; then
        width=110
    else
        width="$cols"
    fi

    printf '%*s\n' "$width" '' | tr ' ' '-'
}

lt_ui_fzf_header() {
    local lines
    lines="$(lt_term_lines)"

    lt_logo_print

    if [ "$lines" -lt 22 ]; then
        printf 'Linux Tool %s | %s | %s\n' "$(lt_version)" "${LT_GITHUB_REPO}@${LT_GITHUB_BRANCH}" "$(lt_ui_project_link)"
        printf 'Enter 运行/安装 | Ctrl+X 删除 | Ctrl+R 刷新 | Ctrl+P 预览 | Esc 退出\n'
        lt_ui_rule
        printf '选项 | 说明\n'
        return 0
    fi

    cat <<EOF

Linux Tool Center  version $(lt_version)
本地工具：$(lt_pretty_path "$LT_TOOL_DIR")
云端来源：${LT_GITHUB_REPO}@${LT_GITHUB_BRANCH}
项目主页：$(lt_ui_project_link)
日志文件：$(lt_pretty_path "$LT_LOG_FILE")

Enter：安装/运行工具  Ctrl+X：删除本地工具  Ctrl+R：刷新云端列表
Ctrl+I：查看信息      Ctrl+U：检查更新      Ctrl+L：查看日志      Ctrl+P：切换预览      Esc：退出
EOF
    lt_ui_rule
    printf '选项 | 说明\n'
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

lt_ui_preview_window() {
    local cols
    local lines

    cols="$(lt_term_cols)"
    lines="$(lt_term_lines)"

    if [ "$lines" -lt 18 ] || [ "$cols" -lt 64 ]; then
        printf 'hidden'
    elif [ "$cols" -lt 100 ]; then
        printf 'down:45%%:wrap'
    else
        printf 'right:52%%:wrap'
    fi
}

lt_ui_start() {
    local selected
    local status
    local self
    local list_cmd
    local refresh_cmd
    local header
    local preview_window

    if ! lt_has_command fzf; then
        lt_ui_header
        lt_ui_require_fzf || return 1
    fi

    self="$(lt_shell_quote "$LT_ENTRYPOINT")"
    list_cmd="${self} list --fzf"
    refresh_cmd="LT_CLOUD_FORCE_REFRESH=1 ${self} list --fzf"
    header="$(lt_ui_fzf_header)"
    preview_window="$(lt_ui_preview_window)"

    while true; do
        set +e
        selected="$(
            lt_tool_list_for_fzf | fzf \
                --ansi \
                --height=100% \
                --border=rounded \
                --layout=reverse \
                --info=inline \
                --prompt="linux-tool > " \
                --header="$header" \
                --header-first \
                --delimiter=$'\t' \
                --with-nth=2 \
                --preview="${self} preview {1}" \
                --preview-window="$preview_window" \
                --bind="ctrl-r:reload(${refresh_cmd})" \
                --bind="ctrl-i:execute(${self} preview {1} < /dev/tty > /dev/tty 2>&1)" \
                --bind="ctrl-u:execute(${self} update < /dev/tty > /dev/tty 2>&1)" \
                --bind="ctrl-l:execute(${self} logs < /dev/tty > /dev/tty 2>&1)" \
                --bind="ctrl-p:toggle-preview" \
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
