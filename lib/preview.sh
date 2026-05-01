#!/usr/bin/env bash

lt_yes_no_cn() {
    case "$1" in
        true) printf '是\n' ;;
        *) printf '否\n' ;;
    esac
}

lt_source_cn() {
    case "$1" in
        local) printf '本地已安装\n' ;;
        cloud) printf '云端可安装\n' ;;
        *) printf '自动\n' ;;
    esac
}

lt_install_status_cn() {
    local tool_id="$1"

    if lt_local_find_by_id "$tool_id" >/dev/null 2>&1; then
        printf '已安装\n'
    else
        printf '未安装\n'
    fi
}

lt_preview_tool() {
    local ref="${1:-}"
    local file
    local source
    local tool_id
    local cloud_url=""

    if [ -z "$ref" ]; then
        lt_print_error "missing tool id"
        return 1
    fi

    tool_id="$(lt_tool_key_id "$ref")"
    source="$(lt_tool_source_for_key "$ref")"
    file="$(lt_tool_find_by_key "$ref")" || {
        lt_print_error "tool not found: $tool_id"
        return 1
    }

    if [ "$source" = "cloud" ]; then
        cloud_url="$(lt_cloud_raw_url_for_name "$(basename "$file")")"
    fi

    cat <<EOF
工具名称：$(lt_tool_name "$file")
工具 ID：$(lt_tool_id "$file")
来源：$(lt_source_cn "$source")
安装状态：$(lt_install_status_cn "$(lt_tool_id "$file")")
分类：$(lt_tool_category "$file")
版本：$(lt_tool_version "$file")
作者：$(lt_tool_author "$file")
依赖：$(lt_tool_deps "$file")
危险操作：$(lt_yes_no_cn "$(lt_tool_dangerous "$file")")
文件路径：$(lt_pretty_path "$file")
EOF

    if [ -n "$cloud_url" ]; then
        printf '云端地址：%s\n' "$cloud_url"
    fi

    cat <<EOF

说明：
$(lt_tool_desc "$file")
EOF
}
