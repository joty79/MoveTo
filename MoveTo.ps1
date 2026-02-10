# MoveTo.ps1 - SHFileOperation (native move, no Explorer window needed)
# ONE batch operation, native dialog + conflicts, cancel works, no ghost process.

param(
    [string]$SourcePath,
    [string]$DestPath
)

# ===== Debug Log =====
$logFile = "$env:TEMP\MoveTo_debug.log"
function Log($msg) {
    $ts = Get-Date -Format "HH:mm:ss.fff"
    "$ts | $msg" | Out-File -FilePath $logFile -Append -Encoding utf8
}

Log "===== START ====="
Log "Source: $SourcePath"
Log "Dest:   $DestPath"
Log "PID:    $PID"

# ===== Native SHFileOperation P/Invoke =====
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class NativeMove {
    private const uint FO_MOVE = 0x0001;
    private const ushort FOF_NOCONFIRMMKDIR = 0x0200;

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct SHFILEOPSTRUCT {
        public IntPtr hwnd;
        public uint   wFunc;
        public IntPtr pFrom;
        public IntPtr pTo;
        public ushort fFlags;
        [MarshalAs(UnmanagedType.Bool)]
        public bool   fAnyOperationsAborted;
        public IntPtr hNameMappings;
        [MarshalAs(UnmanagedType.LPWStr)]
        public string lpszProgressTitle;
    }

    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    private static extern int SHFileOperation(ref SHFILEOPSTRUCT lpFileOp);

    public static int Move(string[] sources, string destination) {
        string from = string.Join("\0", sources) + "\0";
        string to   = destination + "\0";

        IntPtr pFrom = Marshal.StringToHGlobalUni(from);
        IntPtr pTo   = Marshal.StringToHGlobalUni(to);

        try {
            SHFILEOPSTRUCT op = new SHFILEOPSTRUCT();
            op.wFunc  = FO_MOVE;
            op.pFrom  = pFrom;
            op.pTo    = pTo;
            op.fFlags = FOF_NOCONFIRMMKDIR;
            return SHFileOperation(ref op);
        } finally {
            Marshal.FreeHGlobal(pFrom);
            Marshal.FreeHGlobal(pTo);
        }
    }
}
"@

Log "Add-Type done"

# ===== Read ALL selected items from Explorer =====
$shell = New-Object -ComObject Shell.Application
$sourceParent = Split-Path $SourcePath -Parent
$selectedPaths = [System.Collections.Generic.List[string]]::new()

foreach ($win in $shell.Windows()) {
    try {
        $winPath = $win.Document.Folder.Self.Path
        if ($winPath -eq $sourceParent) {
            foreach ($item in $win.Document.SelectedItems()) {
                $selectedPaths.Add($item.Path)
            }
            break
        }
    } catch { }
}

if ($selectedPaths.Count -eq 0) {
    $selectedPaths.Add($SourcePath)
}

Log "Selected items: $($selectedPaths.Count)"

# Release COM before starting move
try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null } catch { }
$shell = $null
[System.GC]::Collect()

Log "COM released. Calling SHFileOperation..."

# ===== Move — native dialog, no Explorer window, cancel = clean exit =====
$result = [NativeMove]::Move($selectedPaths.ToArray(), $DestPath)

Log "SHFileOperation returned: $result"
Log "===== END ====="
