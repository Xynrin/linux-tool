#!/usr/bin/env bash

lt_yes_no_cn() {
    case "$1" in
        true) printf '是\n' ;;
        *) printf '否\n' ;;
    esac
}

lt_preview_tool() {
    local tool_id="${1:-}"
    local file

    if [ -z "$tool_id" ]; then
        lt_print_error "missing tool id"
        return 1
    fi

    file="$(lt_tool_find_by_id "$tool_id")" || {
        lt_print_error "tool not found: $tool_id"
        return 1
    }

    cat <<EOF
工具名称：$(lt_tool_name "$file")
工具 ID：$(lt_tool_id "$file")
分类：$(lt_tool_category "$file")
版本：$(lt_tool_version "$file")
作者：$(lt_tool_author "$file")
依赖：$(lt_tool_deps "$file")
危险操作：$(lt_yes_no_cn "$(lt_tool_dangerous "$file")")
文件路径：$(lt_pretty_path "$file")

说明：
$(lt_tool_desc "$file")

可执行操作：
Enter：运行工具
Ctrl+R：刷新工具列表
Ctrl+I：查看工具信息
Ctrl+U：检查更新
Ctrl+L：查看日志
Esc：返回/退出
EOF
}
