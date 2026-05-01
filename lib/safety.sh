#!/usr/bin/env bash

lt_tool_is_dangerous() {
    local file="$1"
    [ "$(lt_tool_dangerous "$file")" = "true" ]
}

lt_confirm_disclaimer() {
    local title="$1"
    local answer

    printf '%s\n' "$title"
    printf '%s\n' "免责声明："
    printf '%s\n' "  1. 工具脚本可能修改系统配置、安装软件、删除文件或执行网络操作。"
    printf '%s\n' "  2. 请在运行前确认你理解工具用途、来源和潜在风险。"
    printf '%s\n' "  3. 继续操作表示你同意自行承担由此产生的风险。"
    printf '\n'

    if [ ! -t 0 ]; then
        lt_print_error "非交互环境无法确认免责声明，已取消。"
        return 1
    fi

    printf '是否已阅读并同意免责声明？[y/N] '
    read -r answer || return 1
    case "${answer,,}" in
        y|yes|同意|agree|i-agree) return 0 ;;
        *) return 1 ;;
    esac
}

lt_confirm_cloud_tool_download() {
    local tool_id="$1"
    local source_url="$2"

    printf '%s\n' "即将下载云端工具：$tool_id"
    printf '%s\n' "来源：$source_url"
    printf '\n'
    lt_confirm_disclaimer "下载云端工具前请确认免责声明。"
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
        lt_confirm_disclaimer "该工具可能修改系统配置或执行危险操作。"
        return $?
    fi

    printf '按 Enter 运行，输入 n 取消：'
    read -r answer || return 1
    case "${answer,,}" in
        n|no|q|quit|cancel) return 1 ;;
        *) return 0 ;;
    esac
}
