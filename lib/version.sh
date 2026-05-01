#!/usr/bin/env bash

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
