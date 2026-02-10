# Move To Utility 🚀
**A "Send To" clone that MOVES files instead of copying them.**

Windows has a built-in "Send To" menu, but it creates copies. **MoveTo** gives you the same convenience but performs a **Cut & Paste** operation, helping you organize files instantly without leaving duplicates behind.

It integrates seamlessly with Windows Explorer, using the native progress dialogs you already know.

---

## ✨ Features

*   **✂️ Move, Don't Copy:** Acts exactly like "Send To", but moves the files.
*   **➕ Add Destinations Easily:** Right-click ANY folder -> **[Add as destination]** to instantly add it to your menu.
*   **✏️ Edit/Remove:** Built-in interactive menu to remove old destinations quickly.
*   **🎨 Native Experience:** Uses the standard Windows copy/move engine with support for Undo, Pause, Cancel, and Conflict Resolution (Skip/Replace).
*   **🛡️ Reliable:** Handles large transfers and process cleanup automatically.

---

## 🛠️ Installation

1.  Open PowerShell in this folder.
2.  **Register the Base Menu:**
    *   Double-click `MoveTo.reg` and confirm "Yes".
3.  **Initialize Destinations:**
    *   Run the sync script in PowerShell:
    ```powershell
    .\SyncMoveToMenu.ps1
    ```
4.  **Done!** Right-click any file/folder to see the new **"Move To"** menu.

---

## 🎮 Usage

### 1. Moving Files
*   Select one or more files/folders.
*   Right-click -> **Move To** -> Select your destination.
*   *Note:* The utility connects to your active Explorer window to grab the selection, ensuring all highlighted items are moved.

### 2. Adding a New Destination
*   Navigate to the folder you want to add as a destination.
*   Right-click the folder -> **Move To** -> **[Add as destination]**.
*   It will instantly appear in your "Move To" menu!

### 3. removing Destinations
*   Right-click any file -> **Move To** -> **[Edit destinations]**.
*   An interactive menu will open:
    *   Press the **number** of the destination to remove it.
    *   Type multiple numbers (e.g., `1,3`) to remove items in bulk.
    *   Press **[O]** to open the `destinations` folder manually.
    *   Press **[R]** to refresh the list.

---

## ⚙️ How it Works (Architecture)

The system is built on a robust 3-stage pipeline designed for stability:

### Stage 1: The Gatekeeper (`MoveTo.vbs`)
*   **Prevents Double-Launches:** Checks for a `marker file` to ensure only one move operation starts at a time.
*   **Crash Recovery:** Automatically cleans up "stale" markers if a previous run crashed (>5 mins old).
*   **Waits for Engine:** Launches the main executable and waits for it to finish before releasing the lock.

### Stage 2: The Engine (`MoveTo.exe` - C#)
*   **High Performance:** Compiled on-the-fly to native code for maximum speed.
*   **Global Layout:** Uses `Global\MoveTo_Operation` Mutex as a second layer of defense.
*   **Explorer Hook:** Connects to the active Explorer window via COM to retrieve the *exact* list of selected items (verified with 86,000 files).
*   **Retry Logic:** If Explorer returns 0 items (a common post-cancel bug), it intelligently retries until the selection is stable.

### Stage 3: The Watchdog (Background Thread)
*   **Monitors Progress:** Watches the progress dialog window handle.
*   **Auto-Exit Conditions:**
    *   Dialog closes (User Finished/Cancelled/Closed).
    *   Source files are gone (Move Complete).
    *   Timeout (60s no start / 30m hard limit).
*   **Clean Exit:** Forces a clean process termination when done, preventing the infamous "100% CPU" hang often seen with large file moves.

---

## 🐛 Troubleshooting

*   **Logs:** Detailed debug logs are written to `%TEMP%\MoveTo_debug.log`.
*   **Stuck Process?** The watchdog should kill it automatically. If not, run `Stop-Process -Name MoveTo`.
*   **Missing Icons?** The script tries to pull icons from the target folder's `desktop.ini` or the shortcut itself. Run `SyncMoveToMenu.ps1` to refresh them.

---

*Verified with 86,000 files in a single batch.* 💪
