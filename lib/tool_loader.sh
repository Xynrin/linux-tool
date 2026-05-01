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

lt_tool_files() {
    local file
    local item
    local seen="|"

    if [ -d "$LT_TOOL_DIR" ]; then
        while IFS= read -r file; do
            [ -n "$file" ] || continue
            printf '%s\n' "$file"
            seen="${seen}${file}|"
        done < <(find "$LT_TOOL_DIR" -maxdepth 1 -type f -name '*.sh' 2>/dev/null | sort)
    fi

    if [ -f "${LT_APP_DIR}/tools.txt" ]; then
        while IFS= read -r item; do
            item="$(lt_trim "$item")"
            case "$item" in
                ''|'#'*) continue ;;
            esac
            file="${LT_TOOL_DIR}/${item}"
            case "$seen" in
                *"|${file}|"*) continue ;;
            esac
            [ -f "$file" ] && printf '%s\n' "$file"
        done <"${LT_APP_DIR}/tools.txt"
    fi
}

lt_tool_find_by_id() {
    local wanted="$1"
    local file
    local id

    while IFS= read -r file; do
        id="$(lt_tool_id "$file")"
        if [ "$id" = "$wanted" ]; then
            printf '%s\n' "$file"
            return 0
        fi
    done < <(lt_tool_files)

    return 1
}

lt_tool_list_for_fzf() {
    local file
    local id
    local category
    local desc

    while IFS= read -r file; do
        id="$(lt_tool_id "$file")"
        category="$(lt_tool_category "$file")"
        desc="$(lt_tool_desc "$file")"
        printf '%s\t[%s] %-14s %s\t%s\n' "$id" "$category" "$id" "$desc" "$file"
    done < <(lt_tool_files)
}

lt_tool_list() {
    local file

    if [ ! -d "$LT_TOOL_DIR" ]; then
        lt_print_warn "tool directory does not exist: $(lt_pretty_path "$LT_TOOL_DIR")"
        return 0
    fi

    printf '%-18s %-18s %-14s %-10s %s\n' "TOOL ID" "NAME" "CATEGORY" "VERSION" "PATH"
    while IFS= read -r file; do
        printf '%-18s %-18s %-14s %-10s %s\n' \
            "$(lt_tool_id "$file")" \
            "$(lt_tool_name "$file")" \
            "$(lt_tool_category "$file")" \
            "$(lt_tool_version "$file")" \
            "$(lt_pretty_path "$file")"
    done < <(lt_tool_files)
}
