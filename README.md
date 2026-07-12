# tools-windows-export-directory-content
# 📂 Directory Content Exporter

A pair of PowerShell scripts to **scan any directory recursively** and export all text-based file contents — either as plain text file or a fully styled, interactive HTML report.

---

## Scripts

| Script | Output |
|---|
| `export-directory-content.ps1` | Plain `.txt` file with all file contents |
| `export-html-report.ps1` | Styled `.html` report with syntax highlighting & file tree |

---

## Features

### `export-directory-content.ps1`
- Recursively scans a target directory
- Collects all text-based files (30+ supported extensions)
- Concatenates all content into a single `.txt` file with clear separators
- Useful for code review, documentation, or feeding code to AI tools

### `export-html-report.ps1`
- Everything above, plus:
- **Syntax highlighting** via [highlight.js](https://highlightjs.org/) (GitHub Dark theme)
- **Interactive file tree** sidebar with folder toggle
- **Search** filter files by name
- **Copy button** per file
- File metadata: size, last modified date, language badge
- Smooth scroll navigation between files

---

## Requirements

- Windows PowerShell 5.1+ or PowerShell 7+
- Internet connection (HTML report loads highlight.js from CDN)

---

## Usage

### Plain Text Export
```powershell
.\export-directory-content.ps1

powershell
# With custom options
.\export-directory-content.ps1 -TargetDir "C:\MyProject" -OutputFile ".\output.txt"

### HTML Report

powershell
.\export-html-report.ps1

powershell
# With custom options
.\export-html-report.ps1 -TargetDir "C:\MyProject" -OutputFile ".\report.html"

---

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `-TargetDir` | `.` (current dir) | Directory to scan |
| `-OutputFile` | `.\directory_content.txt` / `.\directory_report.html` | Output file path |
| `-Extensions` | 30+ common types | File extensions to include |

### Default Extensions


.ps1 .psm1 .psd1 .py .js .ts .jsx .tsx .cs .java .cpp .c .h
.html .css .scss .json .xml .yaml .yml .md .txt .csv
.sh .bash .sql .config .env .ini .toml

---

## Custom Extension Example

powershell
.\export-html-report.ps1 `
  -TargetDir "C:\MyApp" `
  -OutputFile ".\report.html" `
  -Extensions @("*.py", "*.json", "*.md")

---

## Output Preview

**Text export** — clean, separator-delimited:

================================================
FILE: src/main.py
================================================
<file content here>

**HTML report** — opens in any browser with:
- Left sidebar file tree (collapsible folders)
- Search bar to filter files
- Syntax-highlighted code blocks
- Per-file copy button

---

## Notes

- Both scripts **skip unreadable files** gracefully and log an inline error message instead of crashing
- Duplicate files from overlapping extension patterns are automatically removed
- Output is always **UTF-8 encoded**
`
