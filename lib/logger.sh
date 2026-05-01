#!/usr/bin/env bash

lt_log() {
    local level="$1"
    shift || true
    local message="$*"
    local now

    lt_ensure_dir "$LT_LOG_DIR" || return 0
    now="$(date '+%Y-%m-%d %H:%M:%S')"
    printf '[%s] [%s] %s\n' "$now" "$level" "$message" >>"$LT_LOG_FILE" 2>/dev/null || true
}

lt_log_info() {
    lt_log "INFO" "$*"
}

lt_log_warn() {
    lt_log "WARN" "$*"
}

lt_log_error() {
    lt_log "ERROR" "$*"
}

lt_view_logs() {
    lt_ensure_dir "$LT_LOG_DIR"

    if [ ! -f "$LT_LOG_FILE" ]; then
        lt_print_warn "log file does not exist yet: $(lt_pretty_path "$LT_LOG_FILE")"
        return 0
    fi

    lt_print_info "log file: $(lt_pretty_path "$LT_LOG_FILE")"
    if [ -t 1 ] && lt_has_command less; then
        less "$LT_LOG_FILE"
    else
        cat "$LT_LOG_FILE"
    fi
}
