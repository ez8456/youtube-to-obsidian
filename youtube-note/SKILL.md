---
name: youtube-note
description: >
  將 YouTube 影片轉換為結構化的 Obsidian 筆記。自動抓取影片 metadata 與字幕，
  產出大綱摘要並存入 Obsidian vault。
  當使用者的訊息中出現任何 YouTube 或 youtu.be 連結時，一律觸發本 skill——即使使用者
  只是貼了連結沒有多說什麼，也應該主動詢問是否要做筆記。
  也適用於以下情境：提到「記錄影片」「影片筆記」「YouTube 筆記」「幫我看這個影片」
  「這影片在講什麼」「整理一下這部影片」「筆記這支影片」或任何暗示想從 YouTube 影片
  擷取資訊的對話。即使使用者沒有明確說「筆記」，只要意圖是從影片中提取或整理內容，
  就應該使用本 skill。
---

# YouTube Note Skill

將 YouTube 影片的字幕 / transcript 轉化為結構化 Obsidian Markdown 筆記。

## 前置依賴

本 skill 搭配 `obsidian-markdown` skill 使用（來自 kepano/obsidian-skills）。
撰寫筆記時，遵循 obsidian-markdown skill 中定義的語法規範（Properties、Wikilinks、
Callouts、Tags 等）。這能確保產出的筆記與使用者 vault 中其他筆記風格一致，
也讓 Obsidian 的 graph view 和搜尋功能正常運作。

## 工作流程總覽

1. 接收 YouTube URL
2. 使用 `yt-dlp` 抓取影片 metadata
3. 抓取字幕（三層備案：原生字幕 → Whisper 語音辨識 → 影片描述）
4. 分析字幕內容，產出結構化大綱
5. 依照模板格式化為 Obsidian Markdown
6. 以影片標題為檔名，存入 `10 - Sources/Videos/`

## Step 1：抓取影片資料

```bash
yt-dlp --dump-json --no-download "URL" > /tmp/yt_meta.json
```

如果 `yt-dlp` 未安裝，先執行 `pip install yt-dlp --break-system-packages`。
如果指令失敗（網路問題、影片不存在、地區限制等），告知使用者具體錯誤原因並停止流程。

從 JSON 中擷取：

| 欄位 | 用途 |
|------|------|
| `title` | 影片標題（筆記標題 & 檔名） |
| `channel` | 頻道名稱（frontmatter & tag） |
| `upload_date` | 發布日期，格式 YYYYMMDD → 轉為 YYYY-MM-DD |
| `duration_string` | 影片長度 |
| `description` | 影片描述（輔助分類，也是層級 3 備案素材） |
| `webpage_url` | 原始連結 |

## Step 2：抓取字幕

依照以下三層備案機制，依序嘗試，成功即停。

### 層級 1：YouTube 原生字幕（最快、最準確）

先嘗試手動字幕，再嘗試自動生成字幕：

```bash
# 優先：手動字幕
yt-dlp --write-sub --sub-lang zh-Hant,zh-Hans,zh,en --skip-download -o "/tmp/yt_sub" "URL"

# 備用：自動生成字幕
yt-dlp --write-auto-sub --sub-lang zh-Hant,zh-Hans,zh,en --skip-download -o "/tmp/yt_sub" "URL"
```

取得 .vtt 檔後，清理為純文字：

```bash
sed '/^WEBVTT/d; /^$/d; /^[0-9][0-9]:[0-9][0-9]/d; /-->/d; s/<[^>]*>//g' /tmp/yt_sub.*.vtt | awk '!seen[$0]++' > /tmp/yt_transcript.txt
```

如果清理後的文字不到 50 字，視為失敗，進入下一層級。

### 層級 2：Whisper 語音辨識

當 YouTube 完全沒有字幕時，使用 Whisper 從音訊辨識文字。
Whisper 是選裝工具——未安裝時直接跳到層級 3。

```bash
# 安裝（如果尚未安裝）
pip install openai-whisper --break-system-packages

# 下載音訊
yt-dlp -x --audio-format mp3 --audio-quality 5 -o "/tmp/yt_audio.%(ext)s" "URL"

# 轉文字（base 模型速度與品質的平衡點）
whisper /tmp/yt_audio.mp3 --model base --language zh --output_format txt --output_dir /tmp/

# 清理暫存
rm -f /tmp/yt_audio.mp3
```

語言參數：中文影片用 `--language zh`，英文影片用 `--language en`，不確定就省略讓 Whisper 自動偵測。

成功後在筆記中標註字幕來源為 `whisper`。

### 層級 3：影片描述（最後備案）

以影片描述作為替代素材，在筆記中標註字幕來源為 `description`。
大綱品質會較低，在筆記中加入提示：

> [!warning] 字幕不可用
> 本筆記基於影片描述生成，內容可能不完整，建議觀看影片後手動補充。

## Step 3：產出大綱

### 摘要（Summary）

2-3 句話總結影片核心觀點。重點放在「這支影片在講什麼」和「主要結論或行動建議」。

### 大綱（Outline）

- 分為 3-8 個主要段落，依影片內容的複雜度調整
- 每個段落：一句描述性標題 + 2-3 個重點
- 保留影片中的關鍵術語、數據、人名
- 如果影片有明確的時間段落，標註大約時間戳

### 語言規則

- 大綱一律使用中文撰寫，即使原始字幕是英文
- 保留專有名詞的原文（如技術術語、人名、產品名）

### Tags 自動分類

根據影片內容產生 1-4 個 tags。Tags 的用途是讓使用者在 Obsidian 中快速篩選和發現相關筆記，所以選擇能反映影片核心主題的分類。

**格式**：一律小寫英文 kebab-case（如 `side-project`、`mental-model`）

**優先從以下分類中選擇**（對應 `20 - Cards/` 的子資料夾）：
- `career` — 職涯、求職、職場技能
- `connection` — 人際關係、溝通、社交
- `finance` — 投資、理財、經濟
- `frameworks` — 思維模型、方法論、系統
- `health` — 健康、運動、心理
- `life` — 生活、習慣、個人成長
- `product` — 產品設計、用戶體驗、PM
- `tech` — 程式、AI、工具、軟體開發

**額外 tags**：可加入更細的子分類（如 `ai`、`llm`、`investing`），並以頻道名稱的 kebab-case 作為 tag（如 `fireship`、`ali-abdaal`）。`youtube` 作為基礎 tag 已在模板中預設。

## Step 4：筆記模板

以下模板中的每個 frontmatter 欄位都有其作用——`title` 和 `aliases` 讓搜尋更方便，`tags` 驅動 Obsidian 的篩選功能，`type` 讓 Dataview 查詢能精準抓取 YouTube 筆記。請完整填入所有欄位。

語法遵循 obsidian-markdown skill 規範：標準 YAML frontmatter、`> [!type]` callouts、`[[wikilink]]` 連結，不使用任何 HTML 標籤。

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

## 摘要

{{summary}}

## 大綱

### {{section_1_title}}
- {{point_1}}
- {{point_2}}

### {{section_2_title}}
- {{point_1}}
- {{point_2}}

（依此類推）

```

## Step 5：檔名與儲存

- **檔名** = 影片標題，移除特殊字元：`/ \ : * ? " < > |`
- 空格保留（Obsidian 原生支援含空格的檔名）
- 副檔名 `.md`
- **儲存路徑**：`10 - Sources/Videos/`

完成後輸出確認訊息：`已儲存：《影片標題》→ 檔案路徑`

## Vault 結構參考

```
Cabinet/
  ├── 10 - Sources/
  │   └── Videos/         ← YouTube 筆記存放於此
  ├── 20 - Cards/          ← 大綱中的概念可用 wikilink 連結到此
  └── ...
```

## 邊界情況處理

- **超長字幕**（超過 50,000 字）：只取前 80% 內容處理，並在筆記中以 callout 標註
- **直播 / Premiere**：照常處理，但若無字幕可用機率較高，做好進入層級 2 或 3 的準備
- **播放清單連結**：只處理單一影片，如果 URL 含有 `list=` 參數，擷取 `v=` 的部分單獨處理
- **Shorts**：照常處理，但通常很短，大綱可能只需 1-2 個段落
