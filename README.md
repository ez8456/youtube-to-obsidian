# YouTube to Obsidian

Copy a YouTube link, press a hotkey, get a structured note in your Obsidian vault.

Uses [Claude Code](https://code.claude.com) to extract video metadata and subtitles via `yt-dlp`, then generates a summarized outline and saves it as an Obsidian-compatible Markdown note.

## How It Works

```
Copy YouTube URL → Press hotkey → Claude Code runs yt-note.sh
  → yt-dlp fetches metadata + subtitles
  → Claude reads transcript, generates outline
  → Note saved to Obsidian vault
```

Three-tier transcript strategy:
1. YouTube native subtitles (fastest, most accurate)
2. Whisper speech recognition (optional, for videos without subtitles)
3. Video description fallback (last resort)

## Requirements

- macOS
- [Homebrew](https://brew.sh)
- [Node.js](https://nodejs.org) (`brew install node`)
- [Claude Code](https://code.claude.com) (`npm install -g @anthropic-ai/claude-code`)
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) (`brew install yt-dlp`)
- [Whisper](https://github.com/openai/whisper) (optional: `pip install openai-whisper`)
- [Raycast](https://raycast.com) (for hotkey trigger, or use any alternative)

### Claude Code Authentication

Claude Code supports two authentication methods:

- **Subscription (Pro/Max)**: Log in with your claude.ai account via `claude login`. Usage counts against your plan's included quota. No API key needed.
- **API key**: Set `ANTHROPIC_API_KEY` environment variable. Billed per token at [API rates](https://claude.com/pricing#api).

If you're on a Pro or Max plan, subscription auth is simpler and has no per-use cost beyond your monthly fee. Run `/status` inside Claude Code to verify which method is active.

## Setup

### 1. Install dependencies

```bash
brew install yt-dlp
# Whisper is optional — only needed for videos without subtitles
# pip install openai-whisper
```

### 2. Deploy the skill

Copy `SKILL.md` into your Obsidian vault's `.claude/skills/` directory:

```bash
mkdir -p "/path/to/your/vault/.claude/skills/youtube-note"
cp SKILL.md "/path/to/your/vault/.claude/skills/youtube-note/SKILL.md"
```

### 3. Deploy the script

```bash
mkdir -p ~/bin
cp yt-note.sh ~/bin/yt-note.sh
chmod +x ~/bin/yt-note.sh
```

### 4. Configure the script

Edit `~/bin/yt-note.sh` and update the Config section:

```bash
OBSIDIAN_DIR="/path/to/your/vault/10 - Sources/Videos"  # where notes are saved
SKILL_DIR="/path/to/your/vault/.claude/skills/youtube-note"  # where SKILL.md lives
MODEL="sonnet"  # claude model (see Model Selection below)
```

Also update the PATH line to include your `claude` binary location:

```bash
export PATH="/path/to/claude:$HOME/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
```

Find your claude path with `which claude`.

### 5. Set up hotkey (Raycast)

Create a Raycast Script Command:

```bash
mkdir -p ~/.raycast-scripts

cat > ~/.raycast-scripts/youtube-note.sh << 'EOF'
#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title YouTube to Obsidian
# @raycast.mode compact

# Optional parameters:
# @raycast.packageName YouTube to Obsidian

export PATH="/path/to/claude:/opt/homebrew/bin:/usr/local/bin:$HOME/bin:$PATH"
$HOME/bin/yt-note.sh "$(pbpaste)"
EOF

chmod +x ~/.raycast-scripts/youtube-note.sh
```

Then in Raycast:
1. Settings (`Cmd+,`) → Extensions → Script Commands → Add Script Directory → select `~/.raycast-scripts`
2. Find "YouTube to Obsidian" in the list → assign a hotkey (e.g. `Cmd+Option+Y`)

**Raycast display modes** — change `@raycast.mode` in the script:

| Mode | Behavior |
|------|----------|
| `silent` | Runs in background, no UI. Rely on macOS notification. |
| `compact` | Shows a small bar at top with output. Recommended for debugging. |
| `fullOutput` | Opens a full panel with complete Claude Code output. |

## Usage

**Via hotkey**: Copy a YouTube URL → press your hotkey.

**Via terminal**:

```bash
# from clipboard
yt-note.sh

# pass URL directly
yt-note.sh "https://www.youtube.com/watch?v=..."

# batch process
yt-note.sh --batch urls.txt
```

## Model Selection

Set `MODEL` in `yt-note.sh`:

| Value | Model | Notes |
|-------|-------|-------|
| `sonnet` | Sonnet 4.5 | Recommended. Good balance of speed and quality. |
| `opus` | Opus 4.6 | Best outline quality, but consumes more quota. |
| `haiku` | Haiku 4.5 | Fastest and most economical. Lower quality. |

For this task, `sonnet` is the sweet spot.

## Customization

### SKILL.md

`SKILL.md` is not code — it's a set of instructions that Claude follows. Edit it to change:

- **Outline length**: adjust "3-8 sections" in Step 3
- **Language**: change the language rules
- **Tags**: modify the category list to match your vault structure
- **Template**: edit the Markdown template in Step 4
- **Frontmatter fields**: add or remove properties

Changes take effect immediately, no reinstall needed.

### CLAUDE.md (optional)

Place a `CLAUDE.md` at your vault root to give Claude Code context when you use it interactively (not required for the hotkey workflow). See `CLAUDE.md` in this repo for an example.

## File Structure

```
your-vault/
  ├── .claude/
  │   └── skills/
  │       └── youtube-note/
  │           └── SKILL.md        ← skill instructions
  ├── CLAUDE.md                   ← optional, for interactive Claude Code use
  ├── 10 - Sources/
  │   └── Videos/                 ← generated notes go here
  └── 20 - Cards/                 ← concept notes (wikilinked from outlines)

~/bin/
  └── yt-note.sh                  ← runner script

~/.raycast-scripts/
  └── youtube-note.sh             ← Raycast trigger
```

## Permissions

`yt-note.sh` passes `--allowedTools` to Claude Code so it can run without interactive permission prompts. The allowed tools are scoped to what the workflow needs:

- `Write`, `Edit`, `Read` — file operations
- `Bash(yt-dlp*)` — fetch video data
- `Bash(whisper*)` — speech recognition
- `Bash(mkdir*)`, `Bash(sed *)`, `Bash(awk *)`, `Bash(cat *)` — text processing

No `rm` or destructive commands are pre-approved. Temp files are cleaned up via `trap`.

## Credits

- [yt-dlp](https://github.com/yt-dlp/yt-dlp) for video metadata and subtitle extraction
- [Claude Code](https://code.claude.com) by Anthropic for AI-powered summarization
- [Whisper](https://github.com/openai/whisper) by OpenAI for speech recognition
- [kepano/obsidian-skills](https://github.com/kepano/obsidian-skills) for Obsidian Markdown conventions
- [Raycast](https://raycast.com) for hotkey automation

## License

MIT
