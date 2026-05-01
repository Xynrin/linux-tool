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

lt_cloud_fetch_names_from_api() {
    local json

    lt_has_command curl || return 1
    json="$(curl -fsSL "$LT_CLOUD_API_URL" 2>/dev/null)" || return 1
    printf '%s\n' "$json" | sed -n 's/.*"name":[[:space:]]*"\([^"]*\.sh\)".*/\1/p' | sort -u
}

lt_cloud_fetch_names_from_tools_txt() {
    local list

    lt_has_command curl || return 1
    list="$(curl -fsSL "$LT_CLOUD_TOOLS_TXT_URL" 2>/dev/null)" || return 1
    printf '%s\n' "$list" | sed 's/\r$//' | while IFS= read -r item; do
        item="$(lt_trim "$item")"
        case "$item" in
            ''|'#'*) continue ;;
            *.sh) printf '%s\n' "$item" ;;
        esac
    done | sort -u
}

lt_cloud_tool_names() {
    local names

    names="$(lt_cloud_fetch_names_from_api || true)"
    if [ -n "$names" ]; then
        printf '%s\n' "$names"
        return 0
    fi

    lt_cloud_fetch_names_from_tools_txt
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

    if curl -fsSL "$url" -o "$tmp_file" 2>/dev/null; then
        mv "$tmp_file" "$cache_file"
        chmod +x "$cache_file" 2>/dev/null || true
        printf '%s\n' "$cache_file"
        return 0
    fi

    rm -f "$tmp_file"
    [ -f "$cache_file" ] && printf '%s\n' "$cache_file"
}

lt_cloud_tool_files() {
    local name
    local file

    while IFS= read -r name; do
        [ -n "$name" ] || continue
        file="$(lt_cloud_cache_tool_by_name "$name" || true)"
        [ -n "$file" ] && [ -f "$file" ] && printf '%s\n' "$file"
    done < <(lt_cloud_tool_names || true)
}

lt_cloud_find_by_id() {
    local wanted="$1"
    local file

    while IFS= read -r file; do
        [ -n "$file" ] || continue
        if [ "$(lt_tool_id "$file")" = "$wanted" ]; then
            printf '%s\n' "$file"
            return 0
        fi
    done < <(lt_cloud_tool_files)

    return 1
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

lt_tool_install_from_cloud() {
    local tool_id="$1"
    local cloud_file
    local local_file
    local meta_file
    local source_url

    lt_tool_valid_id "$tool_id" || {
        lt_print_error "invalid tool id: $tool_id"
        return 1
    }

    if lt_local_find_by_id "$tool_id" >/dev/null 2>&1; then
        lt_print_warn "tool already installed: $tool_id"
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
    source_url="$(lt_cloud_raw_url_for_name "$(basename "$cloud_file")")"

    cp "$cloud_file" "$local_file"
    chmod +x "$local_file"
    {
        printf 'LT_ID=%s\n' "$tool_id"
        printf 'SOURCE_URL=%s\n' "$source_url"
        printf 'INSTALLED_AT=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
        printf 'FILE=%s\n' "$local_file"
    } >"$meta_file"

    lt_log_info "install cloud tool: $tool_id"
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
    local seen="|"

    while IFS= read -r file; do
        [ -n "$file" ] || continue
        id="$(lt_tool_id "$file")"
        category="$(lt_tool_category "$file")"
        desc="$(lt_tool_desc "$file")"
        seen="${seen}${id}|"
        printf 'local:%s\t[已安装] [%s] %-14s %s\t%s\n' "$id" "$category" "$id" "$desc" "$file"
    done < <(lt_local_tool_files)

    while IFS= read -r file; do
        [ -n "$file" ] || continue
        id="$(lt_tool_id "$file")"
        case "$seen" in
            *"|${id}|"*) continue ;;
        esac
        category="$(lt_tool_category "$file")"
        desc="$(lt_tool_desc "$file")"
        printf 'cloud:%s\t[云端]   [%s] %-14s %s\t%s\n' "$id" "$category" "$id" "$desc" "$file"
    done < <(lt_cloud_tool_files)
}

lt_tool_list() {
    local mode="${1:-merged}"
    local file
    local id
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
        while IFS= read -r file; do
            [ -n "$file" ] || continue
            id="$(lt_tool_id "$file")"
            if [ "$mode" != "cloud" ]; then
                case "$seen" in
                    *"|${id}|"*) continue ;;
                esac
            fi
            printf '%-10s %-18s %-18s %-14s %-10s %s\n' \
                "cloud" \
                "$id" \
                "$(lt_tool_name "$file")" \
                "$(lt_tool_category "$file")" \
                "$(lt_tool_version "$file")" \
                "$(lt_pretty_path "$file")"
        done < <(lt_cloud_tool_files)
    fi
}
