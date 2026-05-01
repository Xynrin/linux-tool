#!/usr/bin/env bash

normalize_version() {
    local version="${1:-}"
    local major
    local minor
    local patch

    version="$(lt_trim "$version")"
    version="${version#v}"
    version="${version#V}"

    if [[ ! "$version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
        return 1
    fi

    major="${BASH_REMATCH[1]}"
    minor="${BASH_REMATCH[2]}"
    patch="${BASH_REMATCH[3]}"

    printf '%d.%d.%d\n' "$((10#$major))" "$((10#$minor))" "$((10#$patch))"
}

compare_versions() {
    local left
    local right
    local left_major
    local left_minor
    local left_patch
    local right_major
    local right_minor
    local right_patch

    left="$(normalize_version "${1:-}")" || return 2
    right="$(normalize_version "${2:-}")" || return 2

    IFS=. read -r left_major left_minor left_patch <<<"$left"
    IFS=. read -r right_major right_minor right_patch <<<"$right"

    if [ "$left_major" -gt "$right_major" ]; then
        printf '1\n'
    elif [ "$left_major" -lt "$right_major" ]; then
        printf -- '-1\n'
    elif [ "$left_minor" -gt "$right_minor" ]; then
        printf '1\n'
    elif [ "$left_minor" -lt "$right_minor" ]; then
        printf -- '-1\n'
    elif [ "$left_patch" -gt "$right_patch" ]; then
        printf '1\n'
    elif [ "$left_patch" -lt "$right_patch" ]; then
        printf -- '-1\n'
    else
        printf '0\n'
    fi
}

lt_version() {
    local version_file="${LT_APP_DIR}/VERSION"
    local version="dev"

    if [ -f "$version_file" ]; then
        version="$(head -n 1 "$version_file" | tr -d '\r\n')"
        version="${version:-dev}"
    fi

    printf '%s\n' "$version"
}

lt_print_version() {
    printf 'linux-tool %s\n' "$(lt_version)"
}
