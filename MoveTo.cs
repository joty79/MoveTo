using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows.Forms;

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

    [STAThread]
    static void Main(string[] args) {
        if (args.Length < 2) return;
        string sourcePath = args[0];
        string destPath = args[1];
        string sourceParent = Path.GetDirectoryName(sourcePath);

        // Read selected items from Explorer via COM
        var paths = new List<string>();
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
                            paths.Add((string)items.Item(j).Path);
                        }
                        break;
                    }
                } catch { }
            }
        } finally {
            Marshal.ReleaseComObject((object)shell);
        }

        if (paths.Count == 0) paths.Add(sourcePath);

        // Release all COM before move
        GC.Collect();
        GC.WaitForPendingFinalizers();

        // SHFileOperation — native move with dialog
        string from = string.Join("\0", paths) + "\0";
        string to = destPath + "\0";
        IntPtr pFrom = Marshal.StringToHGlobalUni(from);
        IntPtr pTo = Marshal.StringToHGlobalUni(to);

        try {
            var op = new SHFILEOPSTRUCT();
            op.wFunc = 1;      // FO_MOVE
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
