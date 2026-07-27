# Move To Utility

`MoveTo` is a context-menu "Send To" style tool that moves files/folders using a hardened Robocopy pipeline.

## Features

- Move items directly from Explorer submenu `Move To`.
- Add/remove destinations from the same submenu.
- Staged multi-select pipeline (files + folders).
- Select-all fast path for very large selections.
- Fresh-snapshot and late-callback guards prevent stale Explorer state from replacing a valid multi-item stage.
- Robust `cut -> paste` behavior on duplicate targets (`/IS`) without deleting the source root folder.

## Installation

1. Import `MoveTo.reg`.
2. Run:

```powershell
.\SyncMoveToMenu.ps1
```

## Usage

- Move:
  - Select items in Explorer.
  - Right click -> `Move To` -> destination.
- Add destination:
  - Right click a folder -> `Move To` -> `[Add as destination]`.
- Edit destinations:
  - Right click any item -> `Move To` -> `[Edit destinations]`.

## Runtime Architecture

1. `MoveTo.vbs`:
   - Resolves destination shortcut.
   - Deduplicates burst invokes.
   - Starts stage + paste wrappers.
2. `RoboCopy_Silent.vbs` + `rcopySingle.ps1`:
   - Captures actual Explorer selection.
   - Writes staged snapshot (`state\staging\*.stage.json`) while preserving a recent valid multi-item stage from late empty/mismatched callbacks.
3. `RoboPaste_Admin.vbs` + `rcp.ps1`:
   - Runs elevated paste in Windows Terminal.
   - Waits for a fresh snapshot when staging is still active.
   - Applies adaptive `/MT`.
   - Handles tokenized select-all move path while preserving source root folder identity.

## Repository Layout

- Root: active runtime scripts/wrappers (`MoveTo.vbs`, `rcopySingle.ps1`, `rcp.ps1`, `MoveTune.*`, destination scripts, sync script).
- `docs\`: project notes/rules and Gemini working files.
- `logs\`: runtime logs.
- `source\`: legacy/reference artifacts (`MoveTo.cs`, `MoveTo.ps1`, `MoveTo.exe`), not used by current runtime pipeline.

## Logs

- `logs\MoveTo_debug.log`
- `logs\run_log.txt`
- `logs\stage_log.txt`
- `logs\error_log.txt`
- `logs\robocopy_debug.log` (when debug mode is enabled in `MoveTune.json`)

## Troubleshooting

- If menu icons/entries drift, run `.\SyncMoveToMenu.ps1`.
- If paste fails, inspect `logs\error_log.txt` and `logs\run_log.txt`.
