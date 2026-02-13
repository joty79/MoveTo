# Move To Utility 🚀
**A "Send To" clone that MOVES files instead of copying them.**

Windows has a built-in "Send To" menu, but it creates copies. **MoveTo** gives you the same convenience but performs a **Cut & Paste** operation, helping you organize files instantly without leaving duplicates behind.

It integrates with Windows Explorer context menus and uses a hardened `robocopy` backend for the actual transfer.

---

## ✨ Features

*   **✂️ Move, Don't Copy:** Acts exactly like "Send To", but moves the files.
*   **➕ Add Destinations Easily:** Right-click ANY folder -> **[Add as destination]** to instantly add it to your menu.
*   **✏️ Edit/Remove:** Built-in interactive menu to remove old destinations quickly.
*   **⚡ RoboCopy Backend:** Uses staged `robocopy` move flow optimized for mixed multi-select (files + folders).
*   **🛡️ Reliability First:** Reuses the same staging/paste hardening from the standalone RoboCopy pipeline.

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
*   **Prevents Double-Launches:** Checks a `marker file` so only one move operation per destination runs.
*   **Crash Recovery:** Auto-cleans stale markers (>5 min).
*   **Destination Resolve:** Reads the destination `.lnk` and validates target path.

### Stage 2: Selection Staging (`Robocopy\rcopySingle.ps1`)
*   **Explorer Selection Capture:** Grabs the full active selection from Explorer (not only `%1`).
*   **Race Hardening:** Uses named mutex + retries + ready metadata.
*   **Atomic Snapshot:** Writes the staged payload (`mv.stage.json`) before transfer.

### Stage 3: Transfer Execution (`Robocopy\rcp.ps1`)
*   **Move Mode:** Runs in `mv` mode and transfers into the chosen destination.
*   **Adaptive `/MT`:** Thread count is selected by media/path topology.
*   **Fail-Closed Contract:** If staged payload is missing/invalid, operation exits cleanly.
*   **Cleanup:** Clears staged payload and burst markers after completion.

---

## 🐛 Troubleshooting

*   **MoveTo launcher log:** `%TEMP%\MoveTo_debug.log`
*   **RoboCopy run log:** `Robocopy\run_log.txt`
*   **Staging log:** `Robocopy\stage_log.txt`
*   **Missing Icons?** Run `SyncMoveToMenu.ps1` to refresh menu entries/icons.

---

*Verified with 86,000 files in a single batch.* 💪
