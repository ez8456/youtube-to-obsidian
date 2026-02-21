# Obsidian Cabinet

## Vault

`/path/to/your/vault`

```
10 - Sources/
    Videos/       ← YouTube notes (via youtube-note skill)
    Articles/ Books/ Courses/ Podcasts/ Conversations/
20 - Cards/       ← Concept notes by topic
    Career/ Connection/ Finance/ Frameworks/
    Health/ Life/ Product/ Tech/
30 - Projects/    ← Blog drafts, side projects
40 - Maps/        ← MOCs
```

## Skills

`.claude/skills/youtube-note/SKILL.md` — YouTube video → structured note.
Triggered by any YouTube URL or intent to extract info from a video.
Follows kepano/obsidian-markdown syntax conventions.

## Writing Rules

- Content language: Traditional Chinese
- Preserve original terms for proper nouns, tech terms, names
- Tags: English only, lowercase kebab-case, match Cards subfolders
- Links: `[[wikilinks]]` to Cards when relevant
- Filenames: strip `/ \ : * ? " < > |`, keep spaces
- Frontmatter: YAML properties on every note
- Callouts: `> [!type] Title`

## Tools

- `yt-dlp` — YouTube metadata + subtitles
- `whisper` (optional) — speech-to-text fallback
