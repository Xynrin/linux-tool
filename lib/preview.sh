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
    local cloud_name
    local name
    local category
    local desc
    local version
    local author
    local deps
    local dangerous
    local display_path

    if [ -z "$ref" ]; then
        lt_print_error "missing tool id"
        return 1
    fi

    tool_id="$(lt_tool_key_id "$ref")"
    source="$(lt_tool_source_for_key "$ref")"

    if [ "$source" = "local" ]; then
        file="$(lt_local_find_by_id "$tool_id")" || {
            lt_print_error "tool not found: $tool_id"
            return 1
        }
    else
        cloud_name="${tool_id}.sh"
        if [ -f "$LT_CLOUD_INDEX_CACHE" ]; then
            while IFS= read -r name; do
                [ -n "$name" ] || continue
                if [ "${name%.sh}" = "$tool_id" ]; then
                    cloud_name="$name"
                    break
                fi
            done <"$LT_CLOUD_INDEX_CACHE"
        fi

        file="$(lt_cloud_cached_file_by_name "$cloud_name" || true)"
        cloud_url="$(lt_cloud_raw_url_for_name "$cloud_name")"
    fi

    if [ -n "${file:-}" ] && [ -f "$file" ]; then
        name="$(lt_tool_name "$file")"
        category="$(lt_tool_category "$file")"
        desc="$(lt_tool_desc "$file")"
        version="$(lt_tool_version "$file")"
        author="$(lt_tool_author "$file")"
        deps="$(lt_tool_deps "$file")"
        dangerous="$(lt_tool_dangerous "$file")"
        display_path="$(lt_pretty_path "$file")"
    else
        name="$(lt_cloud_default_name "$tool_id")"
        category="$(lt_cloud_default_category)"
        desc="$(lt_cloud_default_desc)"
        version="online"
        author="unknown"
        deps="unknown"
        dangerous="false"
        display_path="$cloud_url"
    fi

    cat <<EOF
工具名称：$name
工具 ID：$tool_id
来源：$(lt_source_cn "$source")
安装状态：$(lt_install_status_cn "$tool_id")
分类：$category
版本：$version
作者：$author
依赖：$deps
危险操作：$(lt_yes_no_cn "$dangerous")
文件路径：$display_path
EOF

    if [ -n "$cloud_url" ]; then
        printf '云端 raw：%s\n' "$cloud_url"
    fi

    cat <<EOF

说明：
$(lt_tool_desc "$file")
EOF
}
