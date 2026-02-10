using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;

class MoveTo {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct SHFILEOPSTRUCT {
        public IntPtr hwnd;
        public uint wFunc;
        public IntPtr pFrom;
        public IntPtr pTo;
        public ushort fFlags;
        [MarshalAs(UnmanagedType.Bool)]
        public bool fAnyOperationsAborted;
        public IntPtr hNameMappings;
        [MarshalAs(UnmanagedType.LPWStr)]
        public string lpszProgressTitle;
    }

    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    static extern int SHFileOperation(ref SHFILEOPSTRUCT op);

    const uint FO_MOVE = 0x0001;
    // FOF_ALLOWUNDO | FOF_NOCONFIRMMKDIR
    // ALLOWUNDO = Undo-capable move (recycle bin aware)
    // NOCONFIRMMKDIR = auto-create dest subdirs without asking
    const ushort FOF_FLAGS = 0x0040 | 0x0200;

    [STAThread]
    static int Main(string[] args) {
        if (args.Length < 2) return 1;
        string sourcePath = args[0];
        string destPath = args[1];
        string sourceParent = Path.GetDirectoryName(sourcePath);

        // ===== Collect selected items from Explorer via COM =====
        var sourcePaths = new List<string>();
        Type shellType = Type.GetTypeFromProgID("Shell.Application");
        dynamic shell = Activator.CreateInstance(shellType);

        try {
            dynamic windows = shell.Windows();
            int wcount = windows.Count;
            for (int i = 0; i < wcount; i++) {
                try {
                    dynamic win = windows.Item(i);
                    string winPath = win.Document.Folder.Self.Path;
                    if (string.Equals(winPath, sourceParent,
                        StringComparison.OrdinalIgnoreCase)) {
                        dynamic items = win.Document.SelectedItems();
                        int icount = items.Count;
                        for (int j = 0; j < icount; j++) {
                            sourcePaths.Add((string)items.Item(j).Path);
                        }
                        break;
                    }
                } catch { }
            }
        } finally {
            Marshal.ReleaseComObject((object)shell);
        }

        // Fallback: if no Explorer window found, use the arg
        if (sourcePaths.Count == 0) sourcePaths.Add(sourcePath);

        // Release COM refs before file operation
        GC.Collect();
        GC.WaitForPendingFinalizers();

        // ===== Safety timeout: force exit after 5 minutes =====
        var timeout = new Thread(() => {
            Thread.Sleep(300000); // 5 min
            Environment.Exit(2);
        });
        timeout.IsBackground = true;
        timeout.Start();

        // ===== SHFileOperation — SYNCHRONOUS, returns when done =====
        // Double-null terminated strings as required by SHFileOperation
        string from = string.Join("\0", sourcePaths) + "\0";
        string to = destPath + "\0";
        IntPtr pFrom = Marshal.StringToHGlobalUni(from);
        IntPtr pTo = Marshal.StringToHGlobalUni(to);

        int result;
        try {
            var op = new SHFILEOPSTRUCT();
            op.wFunc = FO_MOVE;
            op.pFrom = pFrom;
            op.pTo = pTo;
            op.fFlags = FOF_FLAGS;
            result = SHFileOperation(ref op);

            if (op.fAnyOperationsAborted) return 3; // user cancelled
        } finally {
            Marshal.FreeHGlobal(pFrom);
            Marshal.FreeHGlobal(pTo);
        }

        return result;
    }
}
