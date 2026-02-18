# PROJECT_RULES

This root file exists as the project entrypoint.
Primary project notes remain in `docs/PROJECT_RULES.md`.

## Critical Decisions

### 2026-02-17 - Robocopy Engine Parity Sync (MoveTo)
- Problem: MoveTo engine lagged behind Robocopy on recent stability fixes.
- Root cause: Divergence between `MoveTo` and `Robocopy` runtime scripts over multiple iterations.
- Guardrail/rule: Sync only engine/tuning scripts from validated Robocopy runtime; keep MoveTo context-menu integration layer untouched.
- Files affected:
  - `rcopySingle.ps1`
  - `rcp.ps1`
  - `MoveTune.ps1`
- Validation/tests run:
  - PowerShell parser validation (`Parser::ParseFile`) passed for all 3 files.

### 2026-02-18 - MoveTune-only runtime policy
- Problem: Legacy `RoboTune*` compatibility files created ambiguity in runtime/config ownership.
- Root cause: Transitional migration kept parallel `RoboTune.ps1` / `RoboTune.json` paths.
- Guardrail/rule: MoveTo runtime uses only `MoveTune.ps1` + `MoveTune.json`; no fallback to `RoboTune*` in engine or installer launch path.
- Files affected:
  - `Install.ps1`
  - `MoveTune.ps1`
  - `rcp.ps1`
  - `rcopySingle.ps1`
  - `RoboTune.ps1` (removed)
- Validation/tests run:
  - PowerShell parser validation (`Parser::ParseFile`) passed for modified scripts.

### 2026-02-17 - MoveTo submenu not opening (SubCommands encoding)
- Problem: `Move To` flyout stopped opening in Explorer.
- Root cause: Installer helper wrote empty registry values as literal `""` text (not true empty REG_SZ), breaking `SubCommands` semantics on cascade roots.
- Guardrail/rule: For registry writes via `reg.exe`, pass real empty argument (`''`) for empty REG_SZ; never serialize empty as literal quote text.
- Files affected:
  - `Install.ps1`
  - `SyncMoveToMenu.ps1`
- Validation/tests run:
  - PowerShell parser validation (`Parser::ParseFile`) passed for both files.
