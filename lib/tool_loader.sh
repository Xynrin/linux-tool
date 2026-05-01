#!/usr/bin/env bash

lt_tool_meta() {
    local file="$1"
    local key="$2"
    local line

    line="$(grep -m 1 -E "^#[[:space:]]*${key}=" "$file" 2>/dev/null || true)"
    if [ -n "$line" ]; then
        line="${line#*=}"
        lt_trim "$line"
    fi
}

lt_tool_id() {
    local file="$1"
    local value
    value="$(lt_tool_meta "$file" "LT_ID")"
    if [ -n "$value" ]; then
        printf '%s\n' "$value"
    else
        basename "$file" .sh
    fi
}

lt_tool_name() {
    local file="$1"
    local value
    value="$(lt_tool_meta "$file" "LT_NAME")"
    printf '%s\n' "${value:-$(lt_tool_id "$file")}"
}

lt_tool_category() {
    local file="$1"
    local value
    value="$(lt_tool_meta "$file" "LT_CATEGORY")"
    printf '%s\n' "${value:-未分类}"
}

lt_tool_desc() {
    local file="$1"
    local value
    value="$(lt_tool_meta "$file" "LT_DESC")"
    printf '%s\n' "${value:-暂无说明}"
}

lt_tool_version() {
    local file="$1"
    local value
    value="$(lt_tool_meta "$file" "LT_VERSION")"
    printf '%s\n' "${value:-unknown}"
}

lt_tool_author() {
    local file="$1"
    local value
    value="$(lt_tool_meta "$file" "LT_AUTHOR")"
    printf '%s\n' "${value:-unknown}"
}

lt_tool_deps() {
    local file="$1"
    local value
    value="$(lt_tool_meta "$file" "LT_DEPS")"
    printf '%s\n' "${value:-unknown}"
}

lt_tool_dangerous() {
    local file="$1"
    local value
    value="$(lt_tool_meta "$file" "LT_DANGEROUS")"
    case "${value,,}" in
        true|yes|1|y) printf 'true\n' ;;
        *) printf 'false\n' ;;
    esac
}

lt_tool_valid_id() {
    [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]]
}

lt_tool_key_source() {
    case "$1" in
        local:*) printf 'local\n' ;;
        cloud:*) printf 'cloud\n' ;;
        *) printf 'auto\n' ;;
    esac
}

lt_tool_key_id() {
    case "$1" in
        local:*|cloud:*) printf '%s\n' "${1#*:}" ;;
        *) printf '%s\n' "$1" ;;
    esac
}

lt_local_tool_files() {
    if [ -d "$LT_TOOL_DIR" ]; then
        find "$LT_TOOL_DIR" -maxdepth 1 -type f -name '*.sh' 2>/dev/null | sort
    fi
}

lt_tool_files() {
    lt_local_tool_files
}

lt_local_find_by_id() {
    local wanted="$1"
    local file

    while IFS= read -r file; do
        [ -n "$file" ] || continue
        if [ "$(lt_tool_id "$file")" = "$wanted" ]; then
            printf '%s\n' "$file"
            return 0
        fi
    done < <(lt_local_tool_files)

    return 1
}

lt_cloud_raw_url_for_name() {
    local name="$1"
    printf '%s/tool/%s\n' "$LT_CLOUD_RAW_BASE" "$name"
}

lt_cloud_index_refresh() {
    local tmp_html
    local tmp_names

    lt_has_command curl || return 1
    lt_ensure_dir "$(dirname "$LT_CLOUD_INDEX_CACHE")"

    tmp_html="${LT_CLOUD_INDEX_CACHE}.html.$$"
    tmp_names="${LT_CLOUD_INDEX_CACHE}.tmp.$$"

    if ! curl -fsSL --connect-timeout 3 --max-time 8 "$LT_CLOUD_TREE_URL" -o "$tmp_html" 2>/dev/null; then
        rm -f "$tmp_html" "$tmp_names"
        return 1
    fi

    grep -Eo 'tool/[A-Za-z0-9._-]+\.sh' "$tmp_html" 2>/dev/null \
        | sed 's#^tool/##' \
        | sort -u >"$tmp_names" || true

    rm -f "$tmp_html"
    if [ -s "$tmp_names" ]; then
        mv "$tmp_names" "$LT_CLOUD_INDEX_CACHE"
        return 0
    fi

    rm -f "$tmp_names"
    return 1
}

lt_cloud_index_file() {
    if [ "${LT_CLOUD_FORCE_REFRESH:-0}" != "1" ] && lt_cache_is_fresh "$LT_CLOUD_INDEX_CACHE" "$LT_CLOUD_CACHE_TTL"; then
        printf '%s\n' "$LT_CLOUD_INDEX_CACHE"
        return 0
    fi

    if lt_cloud_index_refresh; then
        printf '%s\n' "$LT_CLOUD_INDEX_CACHE"
        return 0
    fi

    [ -f "$LT_CLOUD_INDEX_CACHE" ] && printf '%s\n' "$LT_CLOUD_INDEX_CACHE"
}

lt_cloud_tool_names() {
    local index_file

    index_file="$(lt_cloud_index_file || true)"
    [ -n "$index_file" ] && [ -f "$index_file" ] || return 0
    sed 's/\r$//' "$index_file" | sed '/^[[:space:]]*$/d' | sort -u
}

lt_cloud_name_for_id() {
    local tool_id="$1"
    local name

    lt_tool_valid_id "$tool_id" || return 1
    while IFS= read -r name; do
        [ -n "$name" ] || continue
        if [ "${name%.sh}" = "$tool_id" ]; then
            printf '%s\n' "$name"
            return 0
        fi
    done < <(lt_cloud_tool_names)

    return 1
}

lt_cloud_cached_file_by_name() {
    local name="$1"
    local cache_file="${LT_CLOUD_TOOL_CACHE}/${name}"

    [ -f "$cache_file" ] && printf '%s\n' "$cache_file"
}

lt_cloud_cache_tool_by_name() {
    local name="$1"
    local cache_file
    local tmp_file
    local url

    case "$name" in
        */*|*'..'*|'' ) return 1 ;;
    esac

    lt_has_command curl || return 1
    lt_ensure_dir "$LT_CLOUD_TOOL_CACHE"

    cache_file="${LT_CLOUD_TOOL_CACHE}/${name}"
    tmp_file="${cache_file}.tmp.$$"
    url="$(lt_cloud_raw_url_for_name "$name")"

    if [ "${LT_CLOUD_FORCE_REFRESH:-0}" != "1" ] && lt_cache_is_fresh "$cache_file" "$LT_CLOUD_CACHE_TTL"; then
        printf '%s\n' "$cache_file"
        return 0
    fi

    if curl -fsSL --connect-timeout 3 --max-time 10 "$url" -o "$tmp_file" 2>/dev/null; then
        mv "$tmp_file" "$cache_file"
        chmod +x "$cache_file" 2>/dev/null || true
        printf '%s\n' "$cache_file"
        return 0
    fi

    rm -f "$tmp_file"
    [ -f "$cache_file" ] && printf '%s\n' "$cache_file"
}

lt_cloud_find_by_id() {
    local wanted="$1"
    local name

    name="$(lt_cloud_name_for_id "$wanted")" || return 1
    lt_cloud_cache_tool_by_name "$name"
}

lt_tool_find_by_id() {
    local wanted="$1"
    local file

    file="$(lt_local_find_by_id "$wanted" || true)"
    if [ -n "$file" ]; then
        printf '%s\n' "$file"
        return 0
    fi

    lt_cloud_find_by_id "$wanted"
}

lt_tool_find_by_key() {
    local key="$1"
    local source
    local tool_id

    source="$(lt_tool_key_source "$key")"
    tool_id="$(lt_tool_key_id "$key")"

    case "$source" in
        local) lt_local_find_by_id "$tool_id" ;;
        cloud) lt_cloud_find_by_id "$tool_id" ;;
        *) lt_tool_find_by_id "$tool_id" ;;
    esac
}

lt_tool_source_for_key() {
    local key="$1"
    local source
    local tool_id

    source="$(lt_tool_key_source "$key")"
    tool_id="$(lt_tool_key_id "$key")"
    if [ "$source" != "auto" ]; then
        printf '%s\n' "$source"
        return 0
    fi

    if lt_local_find_by_id "$tool_id" >/dev/null 2>&1; then
        printf 'local\n'
    else
        printf 'cloud\n'
    fi
}

lt_cloud_default_name() {
    local tool_id="$1"
    printf '%s\n' "$tool_id"
}

lt_cloud_default_category() {
    printf '云端\n'
}

lt_cloud_default_desc() {
    printf '在线脚本，Enter 按需安装/运行\n'
}

lt_source_label() {
    case "$1" in
        local) printf '%b' "\033[1;32m[本地]\033[0m" ;;
        cloud) printf '%b' "\033[1;36m[云端]\033[0m" ;;
        *) printf '%b' "\033[1;33m[未知]\033[0m" ;;
    esac
}

lt_category_label() {
    printf '%b' "\033[1;35m[$1]\033[0m"
}

lt_tool_install_from_cloud() {
    local tool_id="$1"
    local cloud_name
    local cloud_file
    local local_file
    local meta_file
    local source_url

    LT_TOOL_INSTALL_STATUS=""

    lt_tool_valid_id "$tool_id" || {
        lt_print_error "invalid tool id: $tool_id"
        return 1
    }

    if lt_local_find_by_id "$tool_id" >/dev/null 2>&1; then
        lt_print_warn "tool already installed: $tool_id"
        return 0
    fi

    cloud_name="$(lt_cloud_name_for_id "$tool_id")" || {
        lt_print_error "cloud tool not found: $tool_id"
        return 1
    }
    source_url="$(lt_cloud_raw_url_for_name "$cloud_name")"

    if ! lt_confirm_cloud_tool_download "$tool_id" "$source_url"; then
        lt_log_info "cloud tool download cancelled: $tool_id"
        LT_TOOL_INSTALL_STATUS="cancelled"
        lt_print_warn "已取消下载。"
        return 0
    fi

    cloud_file="$(lt_cloud_find_by_id "$tool_id")" || {
        lt_print_error "cloud tool not found: $tool_id"
        return 1
    }

    lt_ensure_dir "$LT_TOOL_DIR"
    lt_ensure_dir "$LT_INSTALL_DB"

    local_file="${LT_TOOL_DIR}/${tool_id}.sh"
    meta_file="${LT_INSTALL_DB}/${tool_id}.meta"

    cp "$cloud_file" "$local_file"
    chmod +x "$local_file"
    {
        printf 'LT_ID=%s\n' "$tool_id"
        printf 'SOURCE_URL=%s\n' "$source_url"
        printf 'INSTALLED_AT=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
        printf 'FILE=%s\n' "$local_file"
    } >"$meta_file"

    lt_log_info "install cloud tool: $tool_id"
    LT_TOOL_INSTALL_STATUS="installed"
    lt_print_ok "installed tool: $tool_id"
}

lt_tool_remove_local() {
    local tool_id="$1"
    local file

    lt_tool_valid_id "$tool_id" || {
        lt_print_error "invalid tool id: $tool_id"
        return 1
    }

    file="$(lt_local_find_by_id "$tool_id")" || {
        lt_print_warn "tool is not installed: $tool_id"
        return 0
    }

    case "$file" in
        "$LT_TOOL_DIR"/*.sh) ;;
        *)
            lt_print_error "refusing to remove unexpected path: $file"
            return 1
            ;;
    esac

    rm -f "$file" "${LT_INSTALL_DB}/${tool_id}.meta"
    lt_log_info "remove local tool: $tool_id"
    lt_print_ok "removed tool: $tool_id"
}

lt_tool_list_for_fzf() {
    local file
    local id
    local category
    local desc
    local name
    local cache_file
    local seen="|"

    while IFS= read -r file; do
        [ -n "$file" ] || continue
        id="$(lt_tool_id "$file")"
        category="$(lt_tool_category "$file")"
        desc="$(lt_tool_desc "$file")"
        seen="${seen}${id}|"
        printf 'local:%s\t%b %-14s | %s\t%s\n' "$id" "$(lt_source_label local) $(lt_category_label "$category")" "$id" "$desc" "$file"
    done < <(lt_local_tool_files)

    while IFS= read -r name; do
        [ -n "$name" ] || continue
        id="${name%.sh}"
        case "$seen" in
            *"|${id}|"*) continue ;;
        esac

        cache_file="$(lt_cloud_cached_file_by_name "$name" || true)"
        if [ -n "$cache_file" ]; then
            category="$(lt_tool_category "$cache_file")"
            desc="$(lt_tool_desc "$cache_file")"
        else
            category="$(lt_cloud_default_category)"
            desc="$(lt_cloud_default_desc)"
        fi

        printf 'cloud:%s\t%b %-14s | %s\t%s\n' "$id" "$(lt_source_label cloud) $(lt_category_label "$category")" "$id" "$desc" "$(lt_cloud_raw_url_for_name "$name")"
    done < <(lt_cloud_tool_names)
}

lt_tool_list() {
    local mode="${1:-merged}"
    local file
    local id
    local name
    local cache_file
    local category
    local desc
    local display_name
    local version
    local path
    local seen="|"

    printf '%-10s %-18s %-18s %-14s %-10s %s\n' "SOURCE" "TOOL ID" "NAME" "CATEGORY" "VERSION" "PATH"

    if [ "$mode" != "cloud" ] && [ "$mode" != "available" ]; then
        while IFS= read -r file; do
            [ -n "$file" ] || continue
            id="$(lt_tool_id "$file")"
            seen="${seen}${id}|"
            printf '%-10s %-18s %-18s %-14s %-10s %s\n' \
                "local" \
                "$id" \
                "$(lt_tool_name "$file")" \
                "$(lt_tool_category "$file")" \
                "$(lt_tool_version "$file")" \
                "$(lt_pretty_path "$file")"
        done < <(lt_local_tool_files)
    fi

    if [ "$mode" != "local" ]; then
        while IFS= read -r name; do
            [ -n "$name" ] || continue
            id="${name%.sh}"
            if [ "$mode" != "cloud" ]; then
                case "$seen" in
                    *"|${id}|"*) continue ;;
                esac
            fi

            cache_file="$(lt_cloud_cached_file_by_name "$name" || true)"
            if [ -n "$cache_file" ]; then
                display_name="$(lt_tool_name "$cache_file")"
                category="$(lt_tool_category "$cache_file")"
                desc="$(lt_tool_desc "$cache_file")"
                version="$(lt_tool_version "$cache_file")"
                path="$(lt_pretty_path "$cache_file")"
            else
                display_name="$(lt_cloud_default_name "$id")"
                category="$(lt_cloud_default_category)"
                desc="$(lt_cloud_default_desc)"
                version="online"
                path="$(lt_cloud_raw_url_for_name "$name")"
            fi

            : "$desc"
            printf '%-10s %-18s %-18s %-14s %-10s %s\n' \
                "cloud" \
                "$id" \
                "$display_name" \
                "$category" \
                "$version" \
                "$path"
        done < <(lt_cloud_tool_names)
    fi
}
