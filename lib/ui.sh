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
        printf 'Linux Tool %s | Enter 运行/安装 | Ctrl+U 更新 | Esc 退出\n' "$(lt_version)"
        lt_ui_rule
        printf '选项 | 说明\n'
        return 0
    fi

    cat <<EOF

Linux Tool Center $(lt_version) | ${LT_GITHUB_REPO}@${LT_GITHUB_BRANCH} | $(lt_ui_project_link)
Enter 运行/安装  Ctrl+U 更新  Ctrl+R 刷新  Ctrl+I 信息  Ctrl+L 日志  Ctrl+X 删除  Ctrl+P 预览  Esc 退出
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
    local fzf_output
    local action
    local status
    local self
    local header
    local preview_window
    local refresh_next=0
    local ref

    if ! lt_has_command fzf; then
        lt_ui_header
        lt_ui_require_fzf || return 1
    fi

    self="$(lt_shell_quote "$LT_ENTRYPOINT")"
    header="$(lt_ui_fzf_header)"
    preview_window="$(lt_ui_preview_window)"

    while true; do
        set +e
        if [ "$refresh_next" -eq 1 ]; then
            fzf_output="$(
                LT_CLOUD_FORCE_REFRESH=1 lt_tool_list_for_fzf | fzf \
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
                    --expect=enter,ctrl-r,ctrl-i,ctrl-u,ctrl-l,ctrl-x \
                    --bind="ctrl-p:toggle-preview"
            )"
        else
            fzf_output="$(
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
                --expect=enter,ctrl-r,ctrl-i,ctrl-u,ctrl-l,ctrl-x \
                --bind="ctrl-p:toggle-preview"
        )"
        fi
        status=$?
        set -e
        refresh_next=0

        if [ "$status" -ne 0 ] || [ -z "$fzf_output" ]; then
            lt_log_info "exit linux-tool"
            return 0
        fi

        action="$(printf '%s\n' "$fzf_output" | sed -n '1p')"
        selected="$(printf '%s\n' "$fzf_output" | sed -n '2p')"
        if [ "$action" != "enter" ] && [ "$action" != "ctrl-r" ] && [ "$action" != "ctrl-i" ] \
            && [ "$action" != "ctrl-u" ] && [ "$action" != "ctrl-l" ] && [ "$action" != "ctrl-x" ]; then
            selected="$action"
            action="enter"
        fi

        ref="${selected%%$'\t'*}"

        case "$action" in
            ctrl-r)
                refresh_next=1
                continue
                ;;
            ctrl-u)
                set +e
                lt_update_run "tui"
                status=$?
                set -e
                if [ "$status" -eq 10 ]; then
                    return 0
                fi
                lt_pause
                continue
                ;;
            ctrl-l)
                lt_view_logs
                lt_pause
                continue
                ;;
            ctrl-i)
                if [ -n "$ref" ]; then
                    lt_preview_tool "$ref" || true
                    lt_pause
                fi
                continue
                ;;
            ctrl-x)
                if [ -n "$ref" ]; then
                    lt_tool_remove_local "$(lt_tool_key_id "$ref")" || true
                    lt_pause
                    refresh_next=1
                fi
                continue
                ;;
            enter)
                [ -n "$ref" ] || continue
                "$LT_ENTRYPOINT" run "$ref" || true
                lt_pause
                ;;
        esac
    done
}
