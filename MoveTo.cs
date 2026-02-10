// MoveTo.cs — IFileOperation + Watchdog
// PerformOperations() hangs in COM message pump after dialog closes.
// Watchdog thread detects dialog close → Environment.Exit(0).

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;

class MoveTo {

    // ===== COM Interfaces =====

    [ComImport, Guid("43826d1e-e718-42ee-bc55-a1e261c37bfe")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IShellItem {
        void BindToHandler(IntPtr pbc,
            [MarshalAs(UnmanagedType.LPStruct)] Guid bhid,
            [MarshalAs(UnmanagedType.LPStruct)] Guid riid,
            out IntPtr ppv);
        void GetParent(out IShellItem ppsi);
        void GetDisplayName(uint sigdnName,
            [MarshalAs(UnmanagedType.LPWStr)] out string ppszName);
        void GetAttributes(uint sfgaoMask, out uint psfgaoAttribs);
        void Compare(IShellItem psi, uint hint, out int piOrder);
    }

    [ComImport, Guid("947aab5f-0a5c-4c13-b4d6-4bf7836fc9f8")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IFileOperation {
        void Advise(IntPtr pfops, out uint pdwCookie);
        void Unadvise(uint dwCookie);
        void SetOperationFlags(uint dwOperationFlags);
        void SetProgressMessage([MarshalAs(UnmanagedType.LPWStr)] string pszMessage);
        void SetProgressDialog(IntPtr popd);
        void SetProperties(IntPtr pproparray);
        void SetOwnerWindow(IntPtr hwndOwner);
        void ApplyPropertiesToItem(IShellItem psiItem);
        void ApplyPropertiesToItems(IntPtr punkItems);
        void RenameItem(IShellItem psiItem,
            [MarshalAs(UnmanagedType.LPWStr)] string pszNewName, IntPtr pfopsItem);
        void RenameItems(IntPtr pUnkItems,
            [MarshalAs(UnmanagedType.LPWStr)] string pszNewName);
        void MoveItem(IShellItem psiItem, IShellItem psiDestinationFolder,
            [MarshalAs(UnmanagedType.LPWStr)] string pszNewName, IntPtr pfopsItem);
        void MoveItems(IntPtr punkItems, IShellItem psiDestinationFolder);
        void CopyItem(IShellItem psiItem, IShellItem psiDestinationFolder,
            [MarshalAs(UnmanagedType.LPWStr)] string pszNewName, IntPtr pfopsItem);
        void CopyItems(IntPtr punkItems, IShellItem psiDestinationFolder);
        void DeleteItem(IShellItem psiItem, IntPtr pfopsItem);
        void DeleteItems(IntPtr punkItems);
        void NewItem(IShellItem psiDestinationFolder, uint dwFileAttributes,
            [MarshalAs(UnmanagedType.LPWStr)] string pszName,
            [MarshalAs(UnmanagedType.LPWStr)] string pszTemplateName,
            IntPtr pfopsItem);
        void PerformOperations();
        void GetAnyOperationsAborted(
            [MarshalAs(UnmanagedType.Bool)] out bool pfAnyOperationsAborted);
    }

    // ===== P/Invoke =====

    [DllImport("shell32.dll", CharSet = CharSet.Unicode, PreserveSig = false)]
    static extern void SHCreateItemFromParsingName(
        string pszPath, IntPtr pbc,
        [MarshalAs(UnmanagedType.LPStruct)] Guid riid,
        [MarshalAs(UnmanagedType.Interface)] out IShellItem ppv);

    delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    static extern bool EnumWindows(EnumWindowsProc proc, IntPtr lParam);

    [DllImport("user32.dll")]
    static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);

    [DllImport("user32.dll")]
    static extern bool IsWindowVisible(IntPtr hWnd);

    // ===== Constants =====

    static readonly Guid CLSID_FileOperation =
        new Guid("3ad05575-8857-4850-9277-11b85bdb8e09");
    static readonly Guid IID_IShellItem =
        new Guid("43826d1e-e718-42ee-bc55-a1e261c37bfe");

    const uint FOF_ALLOWUNDO      = 0x0040;
    const uint FOF_NOCONFIRMMKDIR  = 0x0200;

    // ===== Helpers =====

    static string logFile = Path.Combine(
        Environment.GetEnvironmentVariable("TEMP") ?? ".", "MoveTo_debug.log");

    static void Log(string msg) {
        try {
            File.AppendAllText(logFile,
                DateTime.Now.ToString("HH:mm:ss.fff") + " | " + msg + "\r\n");
        } catch { }
    }

    static bool HasVisibleWindow() {
        bool found = false;
        uint myPid = (uint)Process.GetCurrentProcess().Id;
        EnumWindows(delegate(IntPtr hwnd, IntPtr lp) {
            uint pid;
            GetWindowThreadProcessId(hwnd, out pid);
            if (pid == myPid && IsWindowVisible(hwnd)) {
                found = true;
                return false;
            }
            return true;
        }, IntPtr.Zero);
        return found;
    }

    // ===== Main =====

    [STAThread]
    static int Main(string[] args) {
        if (args.Length < 2) return 1;
        string sourcePath   = args[0];
        string destPath     = args[1];
        string sourceParent = Path.GetDirectoryName(sourcePath);

        Log("===== START =====");
        Log("Source: " + sourcePath);
        Log("Dest:   " + destPath);

        // ----- Collect selected items from Explorer -----
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
                        Log("Explorer: " + icount + " selected items");
                        for (int j = 0; j < icount; j++) {
                            sourcePaths.Add((string)items.Item(j).Path);
                        }
                        Log("Collected all paths");
                        break;
                    }
                } catch { }
            }
        } finally {
            Marshal.ReleaseComObject((object)shell);
        }

        if (sourcePaths.Count == 0) {
            sourcePaths.Add(sourcePath);
            Log("Fallback: single arg path");
        }

        Log("Total items: " + sourcePaths.Count);
        GC.Collect();
        GC.WaitForPendingFinalizers();

        // ----- Queue items into IFileOperation -----
        Type foType = Type.GetTypeFromCLSID(CLSID_FileOperation);
        IFileOperation fileOp = (IFileOperation)Activator.CreateInstance(foType);

        try {
            fileOp.SetOperationFlags(FOF_ALLOWUNDO | FOF_NOCONFIRMMKDIR);

            IShellItem destItem;
            SHCreateItemFromParsingName(destPath, IntPtr.Zero,
                IID_IShellItem, out destItem);

            int queued = 0;
            foreach (string path in sourcePaths) {
                try {
                    IShellItem srcItem;
                    SHCreateItemFromParsingName(path, IntPtr.Zero,
                        IID_IShellItem, out srcItem);
                    fileOp.MoveItem(srcItem, destItem, null, IntPtr.Zero);
                    Marshal.ReleaseComObject(srcItem);
                    queued++;
                } catch (Exception ex) {
                    Log("SKIP: " + path + " | " + ex.Message);
                }
            }

            Log("Queued: " + queued);

            // ===== WATCHDOG: force exit when dialog closes =====
            // PerformOperations() HANGS after completion (COM message pump).
            // This thread detects dialog close → Environment.Exit.
            var watchdog = new Thread(() => {
                bool dialogSeen = false;
                DateTime start = DateTime.UtcNow;
                Thread.Sleep(3000);

                while (true) {
                    Thread.Sleep(1000);
                    bool hasWin = HasVisibleWindow();

                    if (hasWin) {
                        dialogSeen = true;
                    }
                    else if (dialogSeen) {
                        // Dialog appeared then closed = done or cancelled
                        Log("Watchdog: dialog closed → exit");
                        Thread.Sleep(500);
                        Environment.Exit(0);
                    }

                    // No dialog after 30s = instant transfer, force exit
                    double elapsed = (DateTime.UtcNow - start).TotalSeconds;
                    if (!dialogSeen && elapsed > 30) {
                        Log("Watchdog: no dialog after 30s → exit");
                        Environment.Exit(0);
                    }

                    // Hard timeout: 30 minutes
                    if (elapsed > 1800) {
                        Log("Watchdog: 30min timeout → exit");
                        Environment.Exit(2);
                    }
                }
            });
            watchdog.IsBackground = true;
            watchdog.Start();

            Log("PerformOperations starting...");
            fileOp.PerformOperations();

            // If we ever get here (unlikely), exit cleanly
            Log("PerformOperations returned!");
            Environment.Exit(0);

        } catch (Exception ex) {
            Log("FATAL: " + ex.ToString());
            Environment.Exit(4);
        }

        return 0;
    }
}
