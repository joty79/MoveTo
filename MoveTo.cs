using System;
using System.Collections.Generic;
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

    static List<string> sourcePaths;

    [STAThread]
    static void Main(string[] args) {
        if (args.Length < 2) return;
        string sourcePath = args[0];
        string destPath = args[1];
        string sourceParent = Path.GetDirectoryName(sourcePath);

        // Read selected items from Explorer via COM
        sourcePaths = new List<string>();
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

        if (sourcePaths.Count == 0) sourcePaths.Add(sourcePath);

        // Release all COM
        GC.Collect();
        GC.WaitForPendingFinalizers();

        // ===== Watchdog thread: force exit when all files moved =====
        var watchdog = new Thread(() => {
            Thread.Sleep(10000); // wait 10 sec before first check
            while (true) {
                Thread.Sleep(5000); // check every 5 sec
                bool allGone = true;
                foreach (string p in sourcePaths) {
                    if (File.Exists(p) || Directory.Exists(p)) {
                        allGone = false;
                        break;
                    }
                }
                if (allGone) {
                    Thread.Sleep(3000); // grace period
                    Environment.Exit(0); // force close — dialog closes too
                }
            }
        });
        watchdog.IsBackground = true;
        watchdog.Start();

        // ===== SHFileOperation on main STAThread =====
        string from = string.Join("\0", sourcePaths) + "\0";
        string to = destPath + "\0";
        IntPtr pFrom = Marshal.StringToHGlobalUni(from);
        IntPtr pTo = Marshal.StringToHGlobalUni(to);

        try {
            var op = new SHFILEOPSTRUCT();
            op.wFunc = 1;       // FO_MOVE
            op.pFrom = pFrom;
            op.pTo = pTo;
            op.fFlags = 0x0200; // FOF_NOCONFIRMMKDIR
            SHFileOperation(ref op);
        } finally {
            Marshal.FreeHGlobal(pFrom);
            Marshal.FreeHGlobal(pTo);
        }
    }
}
