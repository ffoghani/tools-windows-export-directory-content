function Add-HtmlReport {
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

    [void]$Builder.AppendLine("<!DOCTYPE html>")
    [void]$Builder.AppendLine("<html lang=""en"">")
    [void]$Builder.AppendLine("<head>")
    [void]$Builder.AppendLine("<meta charset=""utf-8"">")
    [void]$Builder.AppendLine("<title>Directory Export Report</title>")
    [void]$Builder.AppendLine("<style>")
    [void]$Builder.AppendLine("  body { font-family: Arial, sans-serif; margin: 24px; line-height: 1.5; color: #222; }")
    [void]$Builder.AppendLine("  h1, h2, h3 { color: #111; }")
    [void]$Builder.AppendLine("  pre { background: #f4f4f4; border: 1px solid #ddd; padding: 12px; overflow-x: auto; white-space: pre-wrap; word-break: break-word; }")
    [void]$Builder.AppendLine("  code { background: #f4f4f4; padding: 2px 4px; border-radius: 3px; }")
    [void]$Builder.AppendLine("  .meta { background: #fafafa; border: 1px solid #ddd; padding: 12px; margin-bottom: 20px; }")
    [void]$Builder.AppendLine("  .file-block { margin-bottom: 24px; border-top: 1px solid #dd; padding-top: 16px; }")
    [void]$Builder.AppendLine("  .toc ul { padding-left: 20px; }")
    [void]$Builder.AppendLine("  .status-ok { color: #2a7; }")
    [void]$Builder.AppendLine("  .status-binary { color: #a70; }")
    [void]$Builder.AppendLine("  .status-error { color: #c00; }")
    [void]$Builder.AppendLine("</style>")
    [void]$Builder.AppendLine("</head>")
    [void]$Builder.AppendLine("<body>")

    # Header
    [void]$Builder.AppendLine("<h1>Directory Export Report</h1>")

    # Summary
    [void]$Builder.AppendLine("<div class=""meta"">")
    [void]$Builder.AppendLine("  <h2>Summary</h2>")
    [void]$Builder.AppendLine("  <p><strong>Source Directory:</strong> <code>$(Escape-Html -Text $SourcePath)</code></p>")
    [void]$Builder.AppendLine("  <p><strong>Generated at:</strong> $(Escape-Html -Text $Summary.GeneratedAt)</p>")
    [void]$Builder.AppendLine("  <p><strong>Total files considered:</strong> $($Summary.TotalFiles)</p>")
    [void]$Builder.AppendLine("  <p><strong>Text files exported:</strong> $($Summary.TextFiles)</p>")
    [void]$Builder.AppendLine("  <p><strong>Binary files:</strong> $($Summary.BinaryFiles)</p>")
    [void]$Builder.AppendLine("  <p><strong>Skipped by size:</strong> $($Summary.SkippedBySize)</p>")
    [void]$Builder.AppendLine("  <p><strong>Read errors:</strong> $($Summary.ReadErrors)</p>")
    [void]$Builder.AppendLine("  <p><strong>Hidden files included:</strong> $($Summary.IncludeHidden)</p>")
    [void]$Builder.AppendLine("  <p><strong>File contents included:</strong> $($Summary.IncludeContents)</p>")
    [void]$Builder.AppendLine("  <p><strong>Max file size (bytes):</strong> $($Summary.MaxFileSizeBytes)</p>")
    [void]$Builder.AppendLine("</div>")

    # Exclude patterns
    if ($ExcludePatterns.Count -gt 0) {
        [void]$Builder.AppendLine("<div class=""meta"">")
        [void]$Builder.AppendLine("  <h2>Exclude Patterns</h2>")
        [void]$Builder.AppendLine("  <ul>")
        foreach ($pattern in $ExcludePatterns) {
            [void]$Builder.AppendLine("    <li><code>$(Escape-Html -Text $pattern)</code></li>")
        }
        [void]$Builder.AppendLine("  </ul>")
        [void]$Builder.AppendLine("</div>")
    }

    # Extension filter
    if ($UseExtensionFilter) {
        [void]$Builder.AppendLine("<div class=""meta"">")
        [void]$Builder.AppendLine("  <h2>Extension Filter</h2>")
        [void]$Builder.AppendLine("  <p><strong>Mode:</strong> <code>$(Escape-Html -Text $ExtensionFilterMode)</code></p>")
        [void]$Builder.AppendLine("  <p><strong>Extensions:</strong> <code>$(Escape-Html -Text ($Extensions -join ', '))</code></p>")
        [void]$Builder.AppendLine("</div>")
    }

    # Directory tree
    [void]$Builder.AppendLine("<h2>Directory Tree</h2>")
    [void]$Builder.AppendLine("<pre>")
    foreach ($line in $TreeLines) {
        [void]$Builder.AppendLine((Escape-Html -Text $line))
    }
    [void]$Builder.AppendLine("</pre>")

    # Table of contents + file contents
    if ($Summary.IncludeContents) {
        [void]$Builder.AppendLine("<div class=""toc"">")
        [void]$Builder.AppendLine("  <h2>Table of Contents</h2>")
        [void]$Builder.AppendLine("  <ul>")
        foreach ($entry in $FileEntries) {
            $anchor = New-HtmlAnchor -Text $entry.FullName
            $escapedName = Escape-Html -Text $entry.FullName
            [void]$Builder.AppendLine("    <li><a href=""#$anchor"">$escapedName</a></li>")
        }
        [void]$Builder.AppendLine("  </ul>")
        [void]$Builder.AppendLine("</div>")

        [void]$Builder.AppendLine("<h2>File Contents</h2>")

        foreach ($entry in $FileEntries) {
            $anchor = New-HtmlAnchor -Text $entry.FullName
            $escapedName = Escape-Html -Text $entry.FullName

            $statusClass = switch ($entry.Status) {
                "ok"             { "status-ok" }
                "binary"         { "status-binary" }
                "skipped-binary" { "status-binary" }
                "skipped-size"   { "status-binary" }
                "read-error"     { "status-error" }
                default          { "" }
            }

            [void]$Builder.AppendLine("<div class=""file-block"">")
            [void]$Builder.AppendLine("  <h3 id=""$anchor"">$escapedName</h3>")
            [void]$Builder.AppendLine("  <p>Status: <span class=""$statusClass"">$(Escape-Html -Text $entry.Status)</span></p>")

            if (-not [string]::IsNullOrEmpty($entry.Content)) {
                [void]$Builder.AppendLine("  <pre>$(Escape-Html -Text $entry.Content)</pre>")
            }

            [void]$Builder.AppendLine("</div>")
        }
    }

    [void]$Builder.AppendLine("</body>")
    [void]$Builder.AppendLine("</html>")
}
