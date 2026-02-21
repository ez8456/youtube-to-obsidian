---
name: youtube-note
description: >
  Convert a YouTube video into a structured Obsidian note. Automatically fetches
  video metadata and subtitles, generates a summarized outline, and saves it to
  the Obsidian vault.
  Trigger this skill whenever the user's message contains any YouTube or youtu.be
  link — even if the user just pastes a link without further context, proactively
  ask whether they'd like to create a note.
  Also applies to: "record this video", "video note", "YouTube note",
  "help me watch this video", "what's this video about", "summarize this video",
  "take notes on this video", or any intent to extract or organize information
  from a YouTube video. Even without the explicit word "note", if the intent is
  to extract or summarize video content, use this skill.
---

# YouTube Note Skill

Transform YouTube subtitles / transcripts into structured Obsidian Markdown notes.

## Prerequisites

This skill works alongside the `obsidian-markdown` skill (from kepano/obsidian-skills).
When writing notes, follow the syntax conventions defined in the obsidian-markdown
skill (Properties, Wikilinks, Callouts, Tags, etc.). This ensures generated notes
are consistent with other notes in the user's vault and that Obsidian's graph view
and search work correctly.

## Workflow Overview

1. Receive a YouTube URL
2. Fetch video metadata with `yt-dlp`
3. Fetch subtitles (three-tier fallback: native subtitles → Whisper speech recognition → video description)
4. Analyze subtitle content and produce a structured outline
5. Format as Obsidian Markdown using the template
6. Save to `10 - Sources/Videos/` using the video title as filename

## Step 1: Fetch Video Data

```bash
yt-dlp --dump-json --no-download "URL" > /tmp/yt_meta.json
```

If `yt-dlp` is not installed, run `pip install yt-dlp --break-system-packages` first.
If the command fails (network issues, video not found, region restrictions, etc.), inform the user of the specific error and stop the workflow.

Extract from JSON:

| Field | Purpose |
|-------|---------|
| `title` | Video title (note title & filename) |
| `channel` | Channel name (frontmatter & tag) |
| `upload_date` | Publish date, format YYYYMMDD → convert to YYYY-MM-DD |
| `duration_string` | Video duration |
| `description` | Video description (aids categorization, also tier 3 fallback material) |
| `webpage_url` | Original link |

## Step 2: Fetch Subtitles

Try the following three tiers in order; stop as soon as one succeeds.

### Tier 1: YouTube Native Subtitles (fastest, most accurate)

Try manual subtitles first, then auto-generated:

```bash
# Preferred: manual subtitles
yt-dlp --write-sub --sub-lang en --skip-download -o "/tmp/yt_sub" "URL"

# Fallback: auto-generated subtitles
yt-dlp --write-auto-sub --sub-lang en --skip-download -o "/tmp/yt_sub" "URL"
```

After obtaining the .vtt file, clean it to plain text:

```bash
sed '/^WEBVTT/d; /^$/d; /^[0-9][0-9]:[0-9][0-9]/d; /-->/d; s/<[^>]*>//g' /tmp/yt_sub.*.vtt | awk '!seen[$0]++' > /tmp/yt_transcript.txt
```

If the cleaned text is fewer than 50 characters, treat it as a failure and proceed to the next tier.

### Tier 2: Whisper Speech Recognition

When YouTube has no subtitles at all, use Whisper to transcribe from audio.
Whisper is optional — if not installed, skip directly to tier 3.

```bash
# Install (if not already installed)
pip install openai-whisper --break-system-packages

# Download audio
yt-dlp -x --audio-format mp3 --audio-quality 5 -o "/tmp/yt_audio.%(ext)s" "URL"

# Transcribe (base model balances speed and quality)
whisper /tmp/yt_audio.mp3 --model base --output_format txt --output_dir /tmp/

# Clean up temp files
rm -f /tmp/yt_audio.mp3
```

Language parameter: omit `--language` to let Whisper auto-detect, or specify `--language en` / `--language zh` if known.

Mark the subtitle source as `whisper` in the note.

### Tier 3: Video Description (last resort)

Use the video description as substitute material. Mark the subtitle source as `description` in the note.
Outline quality will be lower; add a callout to the note:

> [!warning] Subtitles unavailable
> This note was generated from the video description. Content may be incomplete — consider watching the video and adding notes manually.

## Step 3: Generate Outline

### Summary

2-3 sentences summarizing the video's core message. Focus on "what this video is about" and "key conclusions or action items."

### Outline

- Split into 3-8 major sections, adjusted based on the video's complexity
- Each section: one descriptive heading + 2-3 key points
- Preserve key terms, data, and names from the video
- If the video has clear time segments, annotate approximate timestamps

### Language Rules

- **Default output language: English.** To change the output language, edit this section (e.g., replace "English" with your preferred language).
- Preserve proper nouns in their original form (technical terms, names, product names)

### Tag Categorization

Generate 1-4 tags based on video content. Tags help users quickly filter and discover related notes in Obsidian, so choose categories that reflect the video's core topics.

**Format**: always lowercase English kebab-case (e.g., `side-project`, `mental-model`)

**Prefer from these categories** (corresponding to `20 - Cards/` subfolders):
- `career` — career, job hunting, workplace skills
- `connection` — relationships, communication, social skills
- `finance` — investing, personal finance, economics
- `frameworks` — mental models, methodologies, systems
- `health` — health, fitness, psychology
- `life` — lifestyle, habits, personal growth
- `product` — product design, user experience, PM
- `tech` — programming, AI, tools, software development

**Additional tags**: you may add more specific sub-categories (e.g., `ai`, `llm`, `investing`), and use the channel name in kebab-case as a tag (e.g., `fireship`, `ali-abdaal`). `youtube` is included as a base tag in the template by default.

## Step 4: Note Template

Every frontmatter field in this template serves a purpose — `title` and `aliases` improve searchability, `tags` power Obsidian's filtering, and `type` enables Dataview queries to target YouTube notes. Fill in all fields completely.

Syntax follows the obsidian-markdown skill conventions: standard YAML frontmatter, `> [!type]` callouts, `[[wikilink]]` links, no HTML tags.

```markdown
---
title: "{{title}}"
source: "{{url}}"
channel: "{{channel}}"
date_watched: {{today_date}}
date_published: {{publish_date}}
duration: "{{duration}}"
transcript_source: "{{subtitle | whisper | description}}"
tags:
  - youtube
  - {{tag1}}
  - {{tag2}}
  - {{tag3}}
type: youtube
aliases:
  - "{{short_title}}"
---
# {{title}}

## Summary

{{summary}}

## Outline

### {{section_1_title}}
- {{point_1}}
- {{point_2}}

### {{section_2_title}}
- {{point_1}}
- {{point_2}}

(and so on)

```

## Step 5: Filename & Storage

- **Filename** = video title, with special characters removed: `/ \ : * ? " < > |`
- Spaces are preserved (Obsidian natively supports filenames with spaces)
- Extension: `.md`
- **Save path**: `10 - Sources/Videos/`

On completion, output a confirmation message: `Saved: "Video Title" → file path`

## Vault Structure Reference

```
your-vault/
  ├── 10 - Sources/
  │   └── Videos/         ← YouTube notes go here
  ├── 20 - Cards/         ← Concepts in outlines can be wikilinked here
  └── ...
```

## Edge Cases

- **Very long subtitles** (over 50,000 characters): process only the first 80% and add a callout noting the truncation
- **Livestreams / Premieres**: process as normal, but subtitles are less likely to be available — be prepared to fall back to tier 2 or 3
- **Playlist links**: process only the single video; if the URL contains a `list=` parameter, extract the `v=` portion and process it alone
- **Shorts**: process as normal, but they're typically very short — the outline may only need 1-2 sections
