#!/bin/bash
# yt-note.sh — YouTube to Obsidian note automation
# Usage:
#   yt-note.sh                   # read URL from clipboard
#   yt-note.sh "https://..."     # pass URL directly
#   yt-note.sh --batch urls.txt  # batch process (one URL per line)

# ============================================================
# Config
# ============================================================

OBSIDIAN_DIR="/path/to/your/vault/10 - Sources/Videos"
SKILL_DIR="/path/to/your/vault/.claude/skills/youtube-note"
ALLOWED_TOOLS="Write,Edit,Read,Bash(yt-dlp*),Bash(whisper*),Bash(mkdir*),Bash(sed *),Bash(awk *),Bash(cat *)"
MODEL="sonnet"

# ============================================================
# Environment
# ============================================================

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$HOME/bin:$HOME/.npm-global/bin:$PATH"
set -euo pipefail

# ============================================================
# Helpers
# ============================================================

log()    { echo "[INFO] $1"; }
warn()   { echo "[WARN] $1"; }
err()    { echo "[ERROR] $1" >&2; }

notify() {
    osascript -e "display notification \"$1\" with title \"yt-note\"" 2>/dev/null || true
}

validate_url() {
    [[ "$1" =~ ^https?://(www\.)?(youtube\.com/watch\?v=|youtu\.be/|youtube\.com/shorts/|youtube\.com/live/) ]]
}

# ============================================================
# Core
# ============================================================

process_single() {
    local url="$1"

    if ! validate_url "$url"; then
        err "Invalid YouTube URL: $url"
        notify "FAIL - invalid URL"
        return 1
    fi

    log "Processing: $url"
    notify "Processing..."

    mkdir -p "$OBSIDIAN_DIR"

    local prompt_file
    prompt_file=$(mktemp)
    trap 'rm -f "$prompt_file"' RETURN

    cat > "$prompt_file" <<PROMPT
Process this YouTube video according to the skill instructions below.

URL: $url
Output directory: $OBSIDIAN_DIR
Date: $(date +%Y-%m-%d)

--- SKILL ---
$(<"$SKILL_DIR/SKILL.md")
--- END ---

Execute the full workflow: fetch metadata, fetch transcript, generate outline, save to file.
Report the saved file path when done.
PROMPT

    if claude -p --model "$MODEL" --allowedTools "$ALLOWED_TOOLS" < "$prompt_file"; then
        log "Done"
        notify "Done - note saved to Obsidian"
    else
        err "Failed: $url"
        notify "FAIL - check terminal"
        return 1
    fi
}

process_batch() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        err "File not found: $file"
        return 1
    fi

    local count=0 failed=0

    while IFS= read -r url; do
        [[ -z "$url" || "$url" == \#* ]] && continue
        count=$((count + 1))
        log "[$count] Processing..."
        if ! process_single "$url"; then
            failed=$((failed + 1))
            warn "Skipped: $url"
        fi
        sleep 2
    done < "$file"

    log "Batch done: $count processed, $failed failed"
    notify "Batch done: $count processed, $failed failed"
}

# ============================================================
# Main
# ============================================================

for cmd in claude yt-dlp; do
    if ! command -v "$cmd" &>/dev/null; then
        err "Missing: $cmd"
        exit 1
    fi
done

case "${1:-}" in
    --batch)
        process_batch "${2:?Please provide a file path}"
        ;;
    --help|-h)
        echo "Usage:"
        echo "  yt-note.sh                   # read URL from clipboard"
        echo "  yt-note.sh \"URL\"             # pass URL directly"
        echo "  yt-note.sh --batch urls.txt  # batch process"
        ;;
    *)
        url="${1:-$(pbpaste 2>/dev/null || echo "")}"
        if [[ -z "$url" ]]; then
            err "Clipboard is empty"
            exit 1
        fi
        process_single "$url"
        ;;
esac