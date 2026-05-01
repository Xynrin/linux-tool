#!/usr/bin/env bash

lt_tool_is_dangerous() {
    local file="$1"
    [ "$(lt_tool_dangerous "$file")" = "true" ]
}

lt_confirm_tool_execution() {
    local file="$1"
    local tool_id
    local answer

    tool_id="$(lt_tool_id "$file")"

    printf '%s\n' "即将运行工具：$(lt_tool_name "$file")"
    printf '%s\n' "工具 ID：$tool_id"
    printf '%s\n' "文件路径：$(lt_pretty_path "$file")"
    printf '\n'

    if lt_tool_is_dangerous "$file"; then
        printf '%s\n' "该工具可能修改系统配置或执行危险操作。"
        printf '请输入工具 ID 以确认执行：%s\n> ' "$tool_id"
        read -r answer || return 1
        [ "$answer" = "$tool_id" ]
        return $?
    fi

    printf '按 Enter 运行，输入 n 取消：'
    read -r answer || return 1
    case "${answer,,}" in
        n|no|q|quit|cancel) return 1 ;;
        *) return 0 ;;
    esac
}
