function Read-RequiredInput {
    param (
        [string]$Prompt
    )

    do {
        $value = Read-Host $Prompt
    } while ([string]::IsNullOrWhiteSpace($value))

    return $value.Trim()
}

function Read-YesNo {
    param (
        [string]$Prompt,
        [bool]$Default = $true
    )

    $suffix = if ($Default) { "[Y/n]" } else { "[y/N]" }

    while ($true) {
        $inputValue = Read-Host "$Prompt $suffix"

        if ([string]::IsNullOrWhiteSpace($inputValue)) {
            return $Default
        }

        switch ($inputValue.Trim().ToLowerInvariant()) {
            "y" { return $true }
            "yes" { return $true }
            "n" { return $false }
            "no" { return $false }
            default { Write-Host "Please enter Y or N." -ForegroundColor Yellow }
        }
    }
}

function Read-Choice {
    param (
        [string]$Prompt,
        [string[]]$AllowedValues,
        [string]$DefaultValue
    )

    $allowedText = $AllowedValues -join "/"

    while ($true) {
        $inputValue = Read-Host "$Prompt ($allowedText) [default: $DefaultValue]"

        if ([string]::IsNullOrWhiteSpace($inputValue)) {
            return $DefaultValue
        }

        $normalized = $inputValue.Trim().ToLowerInvariant()
        if ($AllowedValues -contains $normalized) {
            return $normalized
        }

        Write-Host "Invalid value. Allowed values: $allowedText" -ForegroundColor Yellow
    }
}

function Read-Integer {
    param (
        [string]$Prompt,
        [int64]$DefaultValue,
        [int64]$MinValue = 0
    )

    while ($true) {
        $inputValue = Read-Host "$Prompt [default: $DefaultValue]"

        if ([string]::IsNullOrWhiteSpace($inputValue)) {
            return $DefaultValue
        }

        $parsedValue = 0
        if ([int64]::TryParse($inputValue.Trim(), [ref]$parsedValue) -and $parsedValue -ge $MinValue) {
            return $parsedValue
        }

        Write-Host "Please enter a valid integer greater than or equal to $MinValue." -ForegroundColor Yellow
    }
}

function Escape-MarkdownInline {
    param (
        [string]$Text
    )

    if ($null -eq $Text) {
        return ""
    }

    return $Text.Replace([string][char]96, [string]([char]96) * 2)
}

function Escape-Html {
    param (
        [string]$Text
    )

    if ($null -eq $Text) {
        return ""
    }

    return [System.Net.WebUtility]::HtmlEncode($Text)
}

function New-MarkdownAnchor {
    param (
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return "item"
    }

    $anchor = $Text.ToLowerInvariant()
    $anchor = $anchor -replace '[^a-z0-9\-_\.\/: ]', ''
    $anchor = $anchor -replace '[\/: ]+', '-'
    $anchor = $anchor -replace '-+', '-'
    $anchor = $anchor.Trim('-')

    if ([string]::IsNullOrWhiteSpace($anchor)) {
        return "item"
    }

    return $anchor
}

function New-HtmlAnchor {
    param (
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return "item"
    }

    $anchor = $Text.ToLowerInvariant()
    $anchor = $anchor -replace '[^a-z0-9\-_]+', '-'
    $anchor = $anchor -replace '-+', '-'
    $anchor = $anchor.Trim('-')

    if ([string]::IsNullOrWhiteSpace($anchor)) {
        return "item"
    }

    return $anchor
}

function Test-IsBinaryFile {
    param (
        [string]$FilePath
    )

    try {
        $stream = [System.IO.File]::OpenRead($FilePath)
        try {
            $buffer = New-Object byte[] 8192
            $bytesRead = $stream.Read($buffer, 0, $buffer.Length)

            for ($i = 0; $i -lt $bytesRead; $i++) {
                if ($buffer[$i] -eq 0) {
                    return $true
                }
            }

            return $false
        }
        finally {
            $stream.Dispose()
        }
    }
    catch {
        return $true
    }
}

function Should-ExcludeItem {
    param (
        [System.IO.FileSystemInfo]$Item,
        [string[]]$ExcludePatterns
    )

    foreach ($pattern in $ExcludePatterns) {
        if ([string]::IsNullOrWhiteSpace($pattern)) {
            continue
        }

        if ($Item.Name -like $pattern -or $Item.FullName -like $pattern -or $Item.FullName -like "*$pattern*") {
            return $true
        }
    }

    return $false
}

function Normalize-Extensions {
    param (
        [string[]]$Extensions
    )

    $result = New-Object System.Collections.Generic.List[string]

    foreach ($ext in $Extensions) {
        if ([string]::IsNullOrWhiteSpace($ext)) {
            continue
        }

        $value = $ext.Trim().ToLowerInvariant()
        if (-not $value.StartsWith(".")) {
            $value = ".$value"
        }

        if (-not $result.Contains($value)) {
            [void]$result.Add($value)
        }
    }

    return $result.ToArray()
}

function Test-ExtensionMatch {
    param (
        [System.IO.FileInfo]$File,
        [bool]$UseExtensionFilter,
        [string]$ExtensionFilterMode,
        [string[]]$Extensions
    )

    if (-not $UseExtensionFilter) {
        return $true
    }

    $fileExt = $File.Extension.ToLowerInvariant()
    $contains = $Extensions -contains $fileExt

    switch ($ExtensionFilterMode) {
        "include" { return $contains }
        "exclude" { return -not $contains }
        default   { return $true }
    }
}

function Get-DirectoryTreeLines {
    param (
        [string]$RootPath,
        [bool]$IncludeHidden,
        [string[]]$ExcludePatterns
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $rootItem = Get-Item -LiteralPath $RootPath -Force
    $lines.Add($rootItem.FullName)

    function Add-TreeNodes {
        param (
            [string]$CurrentPath,
            [string]$Indent
        )

        $children = Get-ChildItem -LiteralPath $CurrentPath -Force -ErrorAction SilentlyContinue |
            Where-Object {
                ($IncludeHidden -or -not ($_.Attributes -band [System.IO.FileAttributes]::Hidden)) -and
                -not (Should-ExcludeItem -Item $_ -ExcludePaterns $ExcludePatterns)
            } |
            Sort-Object @{ Expression = { -not $_.PSIsContainer } }, Name

        $childArray = @($children)

        for ($index = 0; $index -lt $childArray.Count; $index++) {
            $child = $childArray[$index]
            $isLast = ($index -eq $childArray.Count - 1)

            if ($isLast) {
                $connector = "\---"
                $nextIndent = $Indent + "    "
            }
            else {
                $connector = "+---"
                $nextIndent = $Indent + "|   "
            }

            $displayName = $child.Name

            if ($child.Attributes -band [System.IO.FileAttributes]::Hidden) {
                $displayName += " [Hidden]"
            }

            if ($child.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                $displayName += " [Link]"
            }

            $lines.Add("$Indent$connector $displayName")

            if ($child.PSIsContainer -and -not ($child.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
                Add-TreeNodes -CurrentPath $child.FullName -Indent $nextIndent
            }
        }
    }

    Add-TreeNodes -CurrentPath $RootPath -Indent ""
    return $lines
}

function Get-FilteredFiles {
    param (
        [string]$RootPath,
        [bool]$IncludeHidden,
        [string[]]$ExcludePatterns,
        [bool]$UseExtensionFilter,
        [string]$ExtensionFilterMode,
        [string[]]$Extensions
    )

    $allItems = Get-ChildItem -LiteralPath $RootPath -Recurse -Force -File -ErrorAction SilentlyContinue

    return $allItems | Where-Object {
        ($IncludeHidden -or -not ($_.Attributes -band [System.IO.FileAttributes]::Hidden)) -and
        -not (Should-ExcludeItem -Item $_ -ExcludePatterns $ExcludePatterns) -and
        (Test-ExtensionMatch -File $_ -UseExtensionFilter $UseExtensionFilter -ExtensionFilterMode $ExtensionFilterMode -Extensions $Extensions)
    } | Sort-Object FullName
}

function Get-FileContentResult {
    param (
        [System.IO.FileInfo]$File,
        [int64]$MaxFileSizeBytes,
        [bool]$IncludeBinaryPlaceholder
    )

    $result = [ordered]@{
        Status  = "ok"
        Content = ""
    }

    if ($File.Length -gt $MaxFileSizeBytes) {
        $result.Status = "skipped-size"
        $result.Content = "[Skipped: file size $($File.Length) bytes exceds limit of $MaxFileSizeBytes bytes]"
        return [pscustomobject]$result
    }

    $isBinary = Test-IsBinaryFile -FilePath $File.FullName
    if ($isBinary) {
        if ($IncludeBinaryPlaceholder) {
            $result.Status = "binary"
            $result.Content = "[Binary file content not displayed]"
        }
        else {
            $result.Status = "skipped-binary"
            $result.Content = "[Skipped binary file]"
        }

        return [pscustomobject]$result
    }

    try {
        $result.Content = Get-Content -LiteralPath $File.FullName -Raw -Force -ErrorAction Stop
        return [pscustomobject]$result
    }
    catch {
        $result.Status = "read-error"
        $result.Content = "[Failed to read file: $($_.Exception.Message)]"
        return [pscustomobject]$result
    }
}

function Add-MarkdownReport {
    param (
        [System.Text.StringBuilder]$Builder,
        [string]$SourcePath,
        [string[]]$TreeLines,
        [object[]]$FileEntries,
        [hashtable]$Summary,
        [string[]]$ExcludePatterns,
        [bool]$UseExtensionFilter,
        [string]$ExtensionFilterMode,
        [string[]]$Extensions
    )

    # Use a variable for backtick to avoid PowerShell parse issues inside strings
    $bt = [string][char]96

    [void]$Builder.AppendLine("# Directory Export Report")
    [void]$Builder.AppendLine()
    [void]$Builder.AppendLine("## Source Directory")
    [void]$Builder.AppendLine()
    [void]$Builder.AppendLine("${bt}${SourcePath}${bt}")
    [void]$Builder.AppendLine()
    [void]$Builder.AppendLine("## Summary")
    [void]$Builder.AppendLine()
    [void]$Builder.AppendLine("- Generated at: ${bt}$($Summary.GeneratedAt)${bt}")
    [void]$Builder.AppendLine("- Total files considered: ${bt}$($Summary.TotalFiles)${bt}")
    [void]$Builder.AppendLine("- Text files exported: ${bt}$($Summary.TextFiles)${bt}")
    [void]$Builder.AppendLine("- Binary files: ${bt}$($Summary.BinaryFiles)${bt}")
    [void]$Builder.AppendLine("- Skipped by size: ${bt}$($Summary.SkippedBySize)${bt}")
    [void]$Builder.AppendLine("- Read errors: ${bt}$($Summary.ReadErrors)${bt}")
    [void]$Builder.AppendLine("- Hidden files included: ${bt}$($Summary.IncludeHidden)${bt}")
    [void]$Builder.AppendLine("- File contents included: ${bt}$($Summary.IncludeContents)${bt}")
    [void]$Builder.AppendLine("- Max file size in bytes: ${bt}$($Summary.MaxFileSizeBytes)${bt}")
    [void]$Builder.AppendLine()

    if ($ExcludePatterns.Count -gt 0) {
        [void]$Builder.AppendLine("## Exclude Patterns")
        [void]$Builder.AppendLine()
        foreach ($pattern in $ExcludePatterns) {
            [void]$Builder.AppendLine("- ${bt}${pattern}${bt}")
        }
        [void]$Builder.AppendLine()
    }

    if ($UseExtensionFilter) {
        [void]$Builder.AppendLine("## Extension Filter")
        [void]$Builder.AppendLine()
        [void]$Builder.AppendLine("- Mode: ${bt}${ExtensionFilterMode}${bt}")
        [void]$Builder.AppendLine("- Extensions: ${bt}$($Extensions -join ', ')${bt}")
        [void]$Builder.AppendLine()
    }

    # Fenced code block markers built from char to avoid parse issues
    $fence = [string][char]96 * 3

    [void]$Builder.AppendLine("## Directory Tree")
    [void]$Builder.AppendLine()
    [void]$Builder.AppendLine("${fence}text")
    foreach ($line in $TreeLines) {
        [void]$Builder.AppendLine($line)
    }
    [void]$Builder.AppendLine($fence)
    [void]$Builder.AppendLine()

    if ($Summary.IncludeContents) {
        [void]$Builder.AppendLine("## Table of Contents")
        [void]$Builder.AppendLine()
        foreach ($entry in $FileEntries) {
            $anchor = New-MarkdownAnchor -Text $entry.FullName
            $escapedName = Escape-MarkdownInline -Text $entry.FullName
            [void]$Builder.AppendLine("- [$escapedName](#$anchor)")
        }
        [void]$Builder.AppendLine()

        [void]$Builder.AppendLine("## File Contents")
        [void]$Builder.AppendLine()

        foreach ($entry in $FileEntries) {
            $anchor = New-MarkdownAnchor -Text $entry.FullName
            $escapedName = Escape-MarkdownInline -Text $entry.FullName

            [void]$Builder.AppendLine("### <a id=""$anchor""></a>File: ${bt}${escapedName}${bt}")
            [void]$Builder.AppendLine()
            [void]$Builder.AppendLine("Status: ${bt}$($entry.Status)${bt}")
            [void]$Builder.AppendLine()
            [void]$Builder.AppendLine($fence)
            if (-not [string]::IsNullOrEmpty($entry.Content)) {
                [void]$Builder.AppendLine($entry.Content)
            }
            [void]$Builder.AppendLine($fence)
            [void]$Builder.AppendLine()
        }
    }
}

function Add-TextReport {
    param (
        [System.Text.StringBuilder]$Builder,
        [string]$SourcePath,
        [string[]]$TreeLines,
        [object[]]$FileEntries,
        [hashtable]$Summary,
        [string[]]$ExcludePatterns,
        [bool]$UseExtensionFilter,
        [string]$ExtensionFilterMode,
        [string[]]$Extensions
    )

    [void]$Builder.AppendLine("DIRECTORY EXPORT REPORT")
    [void]$Builder.AppendLine("=====================")
    [void]$Builder.AppendLine()
    [void]$Builder.AppendLine("SOURCE DIRECTORY:")
    [void]$Builder.AppendLine($SourcePath)
    [void]$Builder.AppendLine()
    [void]$Builder.AppendLine("SUMMARY:")
    [void]$Builder.AppendLine("Generated at: $($Summary.GeneratedAt)")
    [void]$Builder.AppendLine("Total files considered: $($Summary.TotalFiles)")
    [void]$Builder.AppendLine("Text files exported: $($Summary.TextFiles)")
    [void]$Builder.AppendLine("Binary files: $($Summary.BinaryFiles)")
    [void]$Builder.AppendLine("Skipped by size: $($Summary.SkippedBySize)")
    [void]$Builder.AppendLine("Read errors: $($Summary.ReadErrors)")
    [void]$Builder.AppendLine("Hidden files included: $($Summary.IncludeHidden)")
    [void]$Builder.AppendLine("File contents included: $($Summary.IncludeContents)")
    [void]$Builder.AppendLine("Max file size in bytes: $($Summary.MaxFileSizeBytes)")
    [void]$Builder.AppendLine()

    if ($ExcludePatterns.Count -gt 0) {
        [void]$Builder.AppendLine("EXCLUDE PATTERNS:")
        foreach ($pattern in $ExcludePatterns) {
            [void]$Builder.AppendLine("- $pattern")
        }
        [void]$Builder.AppendLine()
    }

    if ($UseExtensionFilter) {
        [void]$Builder.AppendLine("EXTENSION FILTER:")
        [void]$Builder.AppendLine("Mode: $ExtensionFilterMode")
        [void]$Builder.AppendLine("Extensions: $($Extensions -join ', ')")
        [void]$Builder.AppendLine()
    }

    [void]$Builder.AppendLine("DIRECTORY TREE:")
    [void]$Builder.AppendLine()

    foreach ($line in $TreeLines) {
        [void]$Builder.AppendLine($line)
    }

    if ($Summary.IncludeContents) {
        [void]$Builder.AppendLine()
        [void]$Builder.AppendLine("FILE CONTENTS:")
        [void]$Builder.AppendLine()

        foreach ($entry in $FileEntries) {
            [void]$Builder.AppendLine("FILE: $($entry.FullName)")
            [void]$Builder.AppendLine("STATUS: $($entry.Status)")
            [void]$Builder.AppendLine("--------------------------------------------------------")
            [void]$Builder.AppendLine($entry.Content)
            [void]$Builder.AppendLine()
        }
    }
}

# --- Entry Point ---

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "export-html-report.ps1")

$sourceDirectory = Read-RequiredInput -Prompt "Enter source directory"
$outputDirectory = Read-RequiredInput -Prompt "Enter output directory"
$outputFormat = Read-Choice -Prompt "Enter output format" -AllowedValues @("md", "txt", "html") -DefaultValue "md"
$includeHidden = Read-YesNo -Prompt "Include hidden files and folders?" -Default $true
$includeContents = Read-YesNo -Prompt "Include file contents in the report?" -Default $true
$maxFileSizeBytes = Read-Integer -Prompt "Enter max file size in bytes for content export" -DefaultValue 1048576 -MinValue 1
$includeBinaryPlaceholder = Read-YesNo -Prompt "Include placeholder text for binary files?" -Default $true

$useRecommendedExcludes = Read-YesNo -Prompt "Use recommended exclude patterns (.git, node_modules, bin, obj, dist*.log, coverage, .vs)?" -Default $true
$excludePatterns = New-Object System.Collections.Generic.List[string]

if ($useRecommendedExcludes) {
    @(".git", "node_modules", "bin", "obj", "dist", "*.log", "coverage", ".vs") | ForEach-Object {
        [void]$excludePatterns.Add($_)
    }
}

$addCustomExcludes = Read-YesNo -Prompt "Do you want to add custom exclude patterns?" -Default $false
if ($addCustomExcludes) {
    $customInput = Read-Host "Enter custom exclude patterns separated by commas"
    if (-not [string]::IsNullOrWhiteSpace($customInput)) {
        $customInput.Split(",") | ForEach-Object {
            $pattern = $_.Trim()
            if (-not [string]::IsNullOrWhiteSpace($pattern)) {
                [void]$excludePatterns.Add($pattern)
            }
        }
    }
}

$useExtensionFilter = Read-YesNo -Prompt "Apply extension filtering?" -Default $false
$extensionFilterMode = "include"
$normalizedExtensions = @()

if ($useExtensionFilter) {
    $extensionFilterMode = Read-Choice -Prompt "Select extension filter mode" -AllowedValues @("include", "exclude") -DefaultValue "include"
    $extensionInput = Read-Host "Enter extensions separated by commas (example: .cs, .js, py)"
    if (-not [string]::IsNullOrWhiteSpace($extensionInput)) {
        $normalizedExtensions = Normalize-Extensions -Extensions ($extensionInput.Split(","))
    }
}

if (-not (Test-Path -LiteralPath $sourceDirectory)) {
    Write-Host "Source directory does not exist." -ForegroundColor Red
    exit 1
}

$sourceItem = Get-Item -LiteralPath $sourceDirectory -Force
if (-not $sourceItem.PSIsContainer) {
    Write-Host "Source path must be a directory." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outputFileName = "directory-export-$timestamp.$outputFormat"
$outputFilePath = Join-Path $outputDirectory $outputFileName

Write-Host "Building directory tree..." -ForegroundColor Cyan
$treeLines = Get-DirectoryTreeLines -RootPath $sourceItem.FullName -IncludeHidden $includeHidden -ExcludePatterns $excludePatterns.ToArray()

Write-Host "Collecting files..." -ForegroundColor Cyan
$allFiles = @(Get-FilteredFiles `
    -RootPath $sourceItem.FullName `
    -IncludeHidden $includeHidden `
    -ExcludePatterns $excludePatterns.ToArray() `
    -UseExtensionFilter $useExtensionFilter `
    -ExtensionFilterMode $extensionFilterMode `
    -Extensions $normalizedExtensions)

$fileEntries = New-Object System.Collections.Generic.List[object]
$textFiles = 0
$binaryFiles = 0
$skippedBySize = 0
$readErrors = 0

if ($includeContents) {
    foreach ($file in $allFiles) {
        Write-Host "Processing file: $($file.FullName)" -ForegroundColor DarkGray
        $contentResult = Get-FileContentResult -File $file -MaxFileSizeBytes $maxFileSizeBytes -IncludeBinaryPlaceholder $includeBinaryPlaceholder

        switch ($contentResult.Status) {
            "ok"             { $textFiles++ }
            "binary"         { $binaryFiles++ }
            "skipped-binary" { $binaryFiles++ }
            "skipped-size"   { $skippedBySize++ }
            "read-error"     { $readErrors++ }
        }

        $fileEntries.Add([pscustomobject]@{
            FullName = $file.FullName
            Status   = $contentResult.Status
            Content  = $contentResult.Content
        }) | Out-Null
    }
}
else {
    foreach ($file in $allFiles) {
        $fileEntries.Add([pscustomobject]@{
            FullName = $file.FullName
            Status   = "content-not-requested"
            Content  = "[File contents were not requested]"
        }) | Out-Null
    }
}

$summary = @{
    GeneratedAt      = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    TotalFiles       = $allFiles.Count
    TextFiles        = $textFiles
    BinaryFiles      = $binaryFiles
    SkippedBySize    = $skippedBySize
    ReadErrors       = $readErrors
    IncludeHidden    = $includeHidden
    IncludeContents  = $includeContents
    MaxFileSizeBytes = $maxFileSizeBytes
}

$outputBuilder = New-Object System.Text.StringBuilder

$reportParams = @{
    Builder              = $outputBuilder
    SourcePath           = $sourceItem.FullName
    TreeLines            = $treeLines
    FileEntries          = $fileEntries.ToArray()
    Summary              = $summary
    ExcludePatterns      = $ExcludePatterns.ToArray()
    UseExtensionFilter   = $useExtensionFilter
    ExtensionFilterMode  = $extensionFilterMode
    Extensions           = $normalizedExtensions
}

switch ($outputFormat) {
    "md"   { Add-MarkdownReport @reportParams }
    "txt"  { Add-TextReport @reportParams }
    "html" { Add-HtmlReport @reportParams }
    default {
        Write-Host "Unsupported output format." -ForegroundColor Red
        exit 1
    }
}

[System.IO.File]::WriteAllText($outputFilePath, $outputBuilder.ToString(), [System.Text.Encoding]::UTF8)

Write-Host ""
Write-Host "Export completed successfully." -ForegroundColor Green
Write-Host "Output file: $outputFilePath"
Write-Host "Total files considered: $($allFiles.Count)"
