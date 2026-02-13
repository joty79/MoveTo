This is a common performance cliff in PowerShell-based context menu handlers. When you hit ~1,000+ files, the overhead of PowerShell object creation, path validation, and JSON serialization (the "Stage" phase) usually takes longer than the actual file copy for small files.

Here is the **Optimization Strategy** to make this handle 5,000+ files instantly.

### The Core Philosophy: "Lazy Staging"

Right now, your script is doing "Heavy Validation" during the click (Checking if files exist, resolving paths, normalizing, converting to JSON).
**The Fix:** Stop validating. Trust Explorer. Dump raw paths to a flat text file immediately and exit. Let the *Paste* process handle the validation later (async).

---

### Optimization 1: Remove `Resolve-Path` and `Test-Path` in the Staging Phase

In your `rcopySingle.ps1`, you are calling `Resolve-NormalPath` inside loops.

* **Why it's slow:** Every time you call `Resolve-Path` or `Test-Path`, PowerShell hits the hard drive MFT (Master File Table). Doing this 5,000 times freezes the UI.
* **The Fix:** Explorer COM objects already give you the full path. Use it directly.

**Change this in `rcopySingle.ps1`:**

```powershell
# BAD (Current - Hits disk 5000 times)
function Get-UniqueExistingPaths {
    # ...
    foreach ($candidate in @($Candidates)) {
        $resolved = Resolve-NormalPath -PathValue $candidate # <-- SLOW
        # ...
    }
}

# GOOD (Optimized - In-memory string only)
function Get-UniqueRawPaths {
    param([string[]]$Candidates)
    # Use a HashSet for O(1) lookups, case-insensitive
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $out = New-Object System.Collections.Generic.List[string]

    foreach ($path in $Candidates) {
        if (-not [string]::IsNullOrWhiteSpace($path)) {
            # Just add the string. Don't check the disk.
            if ($seen.Add($path)) {
                [void]$out.Add($path)
            }
        }
    }
    return [string[]]$out.ToArray()
}
```

### Optimization 2: Switch from JSON to Flat Text (StreamWriter)

`ConvertTo-Json` is computationally expensive for massive arrays.
**The Fix:** Use a simple `.NET StreamWriter` to blast text to the disk. It is instant.

**Replace `Save-StagedPathsToFile` with this:**

```powershell
function Save-StagedPathsToFastFile {
    param(
        [string]$CommandName,
        [string[]]$Paths,
        [string]$AnchorParent,
        [string]$SessionId
    )

    Ensure-StageStateDirectories
    $stagedFile = Get-StagedJsonPath -CommandName $CommandName # Rename this to .txt later

    # Use .NET StreamWriter for raw speed (bypasses PowerShell pipeline overhead)
    $stream = [System.IO.StreamWriter]::new($stagedFile, $false, [System.Text.Encoding]::UTF8)

    # Write Header (Metadata)
    $stream.WriteLine("V2|{0}|{1}|{2}" -f $CommandName, $SessionId, $AnchorParent)

    # Write Paths (One per line)
    foreach ($path in $Paths) {
        $stream.WriteLine($path)
    }

    $stream.Close()
    $stream.Dispose()
}
```

*Note: You will need to update your `rcp.ps1` (Reader) to read this format (`Get-Content` is fine there since Paste is async).*

### Optimization 3: Optimize the Explorer COM Loop

The function `Get-ExplorerSelectionFromParent` iterates through open windows.
**The Fix:** The moment you find the matching window, **break the loop**. Do not continue searching other windows.

```powershell
# In Get-ExplorerSelectionFromParent
foreach ($window in @($shell.Windows())) {
    # ... (checking window logic) ...

    if ($windowFolderNormalized -eq $parentNormalized) {
        # ... (capture items logic) ...

        # CRITICAL OPTIMIZATION:
        if ($current.Count -gt 0) {
            return [string[]]$current.ToArray() # Return immediately! Don't look at other windows.
        }
    }
}
```

### Optimization 4: The "Wildcard" Trick (Paste Phase)

If you select 5,000 files in a folder that contains 5,000 files, you are currently generating a Robocopy command with 5,000 arguments. This hits the 32,000 character command line limit and is slow to parse.

**The Fix:** inside `rcp.ps1` (The paste script):

1. Count the files in the Source Directory.
2. Count the files in your Staged List for that directory.
3. **If (Staged Count == Source Count):**
   Do not pass file names. Pass `*` (Wildcard).

```powershell
# Pseudocode logic for rcp.ps1
$filesInSource = (Get-ChildItem $SourceDir -File).Count
$filesSelected = $batch.Count

if ($filesInSource -eq $filesSelected) {
    # FAST PATH
    robocopy $SourceDir $DestDir * /E ...
} else {
    # STANDARD PATH (Batching)
    robocopy $SourceDir $DestDir file1 file2 file3 ...
}
```

### Optimization 5: Grouping by Parent (Paste Phase)

If the user selects files from Search Results (different folders), Robocopy fails if you try to pass them all at once.
**The Fix:** In `rcp.ps1`, before running robocopy:

1. Read the staged list.
2. Group the paths by **DirectoryName**.
3. Loop through the groups and run one Robocopy instance per source folder.

### Summary of Changes required

1. **In `rcopySingle.ps1`**: Remove all `Test-Path`, `Resolve-Path`, and `Get-Item`. Treat paths as simple strings.
2. **In `rcopySingle.ps1`**: Stop using `ConvertTo-Json`. Write a flat line-by-line text file.
3. **In `rcp.ps1`**: Update the reader to read the flat text file.
4. **In `rcp.ps1`**: Add logic to check if "All files in folder are selected". If yes, use `*` instead of listing files.

If you implement #1 and #2, your "Loading..." time for 5,000 files will drop from ~10 seconds to < 1 second. PowerShell is slow at objects, but very fast at raw string manipulation.
