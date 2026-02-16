# PROJECT_RULES.md (MoveTo)

## Scope
- This file stores MoveTo-specific decisions, guardrails, and critical lessons.
- Keep entries concise and actionable.

## Non-Negotiable Rules
- For registry paths that include `*`, use `Registry::HKEY_CURRENT_USER\...` (not `HKCU:\...`).
- Do not run `Test-Path` or `Get-ChildItem` on `HKCU:\...*\...` paths.
- For dynamic context-menu destinations, use nested shell keys (`shell\dest_*`), not empty `SubCommands=""`.
- Keep `SyncMoveToMenu.ps1` as the source-of-truth sync step between `destinations\*.lnk` and registry entries.
- For RoboCopy engine, use adaptive `/MT` tuning by source/destination media path; do not hardcode one value globally.

## Current Stability Policy
- Treat the native engine (`MoveTo.vbs` + `MoveTo.exe`) as stable and high-risk to modify.
- Prefer side-by-side experiments (for example, RoboCopy-based flow) instead of replacing the native path directly.

## Decision Log
### 2026-02-15 - MoveTo parity sync: single-anchor stage guard + same-volume native move safety
- Problem: (1) Σε single-item stage μπορούσε να αποθηκευτεί path διαφορετικό από το clicked anchor. (2) Cut στο ίδιο volume δεν είχε native fast path/safety guards.
- Root cause: (1) COM selection fallback μπορούσε να επιστρέψει λάθος single path. (2) Η flow βασιζόταν πάντα σε robocopy+delete χωρίς explicit same-volume/native-move guardrails.
- Guardrail/rule:
  - `rcopySingle.ps1`: για single-item non-token selection, αν selected != anchor, γίνεται hard override στο anchor και γράφεται warning/debug marker.
  - `rcp.ps1`: προστέθηκαν `Test-IsSameVolumePath` + `Test-IsPathInside`, native same-volume move fast paths (directory/file/file-batch), και hard block για destination-inside-source σε move.
- Files affected: `rcopySingle.ps1`, `rcp.ps1`.
- Validation/tests run: PowerShell parser validation (`Parser::ParseFile`) OK και για τα δύο αρχεία.

### 2026-02-11 - Adaptive RoboCopy thread rule
- Problem: Fixed `/MT:32` is fast on NVMe but can underperform on HDD or same-drive copies.
- Root cause: Storage bottlenecks vary by media type and path topology.
- Guardrail: Choose `/MT` adaptively (`8` for HDD/network/same-physical-disk, `32` for SSD->SSD, `16` fallback).
- Files affected: `Robocopy/rcp.ps1`, `Robocopy/README.md`.
- Validation/tests: Use `__mtprobe` mode with representative source/destination paths.

### 2026-02-11 - RoboCopy benchmark and tuning controls
- Problem: Needed real-time speed visibility and manual MT tuning per partition route.
- Root cause: Performance depends on source/destination topology and workload shape.
- Guardrail: Use explicit `benchmark_mode` toggle; when ON keep paste window open with hotkey to `RoboTune.ps1`, when OFF close normally.
- Files affected: `Robocopy/rcp.ps1`, `Robocopy/RoboTune.ps1`, `Robocopy/README.md`.
- Validation/tests: Parse check + `__mtprobe` + interactive config load.

### 2026-02-10 - Registry wildcard path fix
- Problem: Context menu scripts could hang/fail when using registry paths with `*` under `HKCU:\`.
- Root cause: `*` interpreted as wildcard by PowerShell provider.
- Guardrail: Always use `Registry::HKEY_CURRENT_USER\...` for these paths.
- Files affected historically: `SyncMoveToMenu.ps1`, `MoveTo.reg`, `AddMoveToDestination.ps1`.

### 2026-02-11 - Conda shell initialization note
- Problem: `conda` command may be unavailable in some PowerShell sessions.
- Root cause: Shell PATH/profile may not load Conda shims in every terminal context.
- Guardrail: Use `E:\Compilers\miniconda\condabin\conda.bat` when plain `conda` is not recognized.
- Files affected: `AGENTS.md` (environment note).
- Validation/tests: `conda env list` succeeded via explicit `conda.bat` path.

### 2026-02-11 - RoboDelete baseline strategy
- Problem: Need fast permanent-delete tests for large folder workloads.
- Root cause: Explorer + Recycle Bin path is too slow for high file-count delete scenarios.
- Guardrail: Keep imported `robodelete.bat` as reference, and use `robodelete_fast.bat` as baseline test runner with summary/log.
- Files affected: `Robocopy/robodelete_fast.bat`, `Robocopy/README.md`.
- Validation/tests: Batch parse/read verification in workspace.

### 2026-02-11 - RoboDelete folder context menu
- Problem: Need one-click folder test entry from Explorer for permanent delete speed checks.
- Root cause: Manual drag/drop batch flow is slower to trigger repeatedly during benchmarks.
- Guardrail: Use folder-only context menu entry pointing to `robodelete_fast.bat` via VBS wrapper.
- Files affected: `Robocopy/RoboDelete_Folder.vbs`, `Robocopy/RoboDelete_Folder.reg`, `Robocopy/README.md`.
- Validation/tests: VBS syntax check (`cscript //nologo`) + file content verification.

### 2026-02-11 - RoboDelete MT and speed profile
- Problem: Needed explicit robocopy multi-thread tuning for delete benchmarks.
- Root cause: Baseline batch lacked `/MT` control.
- Guardrail: Default `robodelete_fast.bat` folder profile uses `/MT:64` plus `/R:0 /W:0 /NFL /NDL /NJH /NJS /NP /XJ`; allow override via `ROBODELETE_MT`.
- Files affected: `Robocopy/robodelete_fast.bat`, `Robocopy/README.md`.
- Validation/tests: Local temp-folder run with `ROBODELETE_MT=64` and summary/log verification.

### 2026-02-11 - RoboDelete low-overhead testing mode
- Problem: Benchmark view/progress output can distort delete-speed measurements.
- Root cause: Console progress rendering (`/ETA` and verbose output) adds non-trivial overhead in some workloads.
- Guardrail: Add `ROBODELETE_TEST` mode; default `1` sets silent fast profile + hold window for summary, with elapsed time as primary metric and minimal summary fields.
- Files affected: `Robocopy/robodelete_fast.bat`, `Robocopy/README.md`.
- Validation/tests: Batch parse/flow verification and config echo/log field checks for `TEST/VISUAL/HOLD`.

### 2026-02-11 - Nuclear delete hold-on-exit for testing
- Problem: Nuclear delete window could close too quickly after completion during benchmark checks.
- Root cause: Script exited immediately after success/cancel/not-found paths.
- Guardrail: Keep console open on all outcomes until key press, so elapsed/result is always visible.
- Files affected: `NuclearDelete/NuclearDeleteFolder.ps1`.
- Validation/tests: Script flow review for success/cancel/error branches using common `Wait-AndExit`.

### 2026-02-11 - Deletion strategy simplified (Nuclear only)
- Problem: RoboDelete (`robocopy /MIR` delete flow) was significantly slower than direct Nuclear delete in real tests.
- Root cause: Mirror/delete workflow requires extra enumeration and comparison overhead.
- Guardrail: Keep only `NuclearDelete` for permanent folder delete workflows; deprecate/remove RoboDelete scripts and menu entries.
- Files affected: `Robocopy/README.md`, `Robocopy/robodelete_fast.bat` (removed), `Robocopy/robodelete.bat` (removed), `Robocopy/RoboDelete_Folder.vbs` (removed), `Robocopy/RoboDelete_Folder.reg` (removed), `NuclearDelete/Remove_RoboDelete_ContextMenu.reg` (new).
- Validation/tests: Workspace file cleanup verification + grep for remaining RoboDelete references in active docs.

### 2026-02-11 - Nuclear delete menu placement for muscle memory
- Problem: Direct one-click delete entry risks misclick and should be near built-in Delete position.
- Root cause: Flat custom menu items are easier to trigger accidentally and can appear far from native delete block.
- Guardrail: Use submenu pattern `Delete to Oblivion -> Delete Permanently` with `Position=Bottom` and `SeparatorBefore` on `Directory\shell`.
- Files affected: `NuclearDelete/NuclearDeleteFolder.reg`.
- Validation/tests: Registry structure review (`shell\run`) + key ordering key-name prefix (`z_10_`).

### 2026-02-11 - Reliable cascade menu wiring for Explorer
- Problem: Parent menu appeared but did not open submenu; click produced app-association error.
- Root cause: Nested `shell` cascade under the parent key was not being resolved reliably by Explorer in this setup.
- Guardrail: Use `ExtendedSubCommandsKey` on parent menu and define actions under `HKCU\Software\Classes\Directory\ContextMenus\...`.
- Files affected: `NuclearDelete/NuclearDeleteFolder.reg`.
- Validation/tests: Registry content review for `ExtendedSubCommandsKey` and `ContextMenus\...\shell\run\command`.

### 2026-02-11 - Nuclear production mode (silent minimal) + backup variant
- Problem: Interactive prompts/timing/logging add friction for day-to-day delete workflow.
- Root cause: Existing Nuclear script still contained benchmark and confirmation UI logic.
- Guardrail: Keep active `NuclearDelete` path minimal and silent (no prompt, no elapsed/log output); store interactive/benchmark variant in dedicated backup folder.
- Files affected: `NuclearDelete/NuclearDeleteFolder.ps1`, `NuclearDelete/NuclearDeleteFolder.vbs`, `NuclearDelete/Backup_DialogBenchmark/NuclearDeleteFolder.interactive.ps1`, `NuclearDelete/Backup_DialogBenchmark/NuclearDeleteFolder.visible.vbs`, `NuclearDelete/Backup_DialogBenchmark/NuclearDeleteFolder.menu.reg`, `NuclearDelete/Backup_DialogBenchmark/README.md`.
- Validation/tests: PowerShell parse check for active script + VBS launch mode review (`shell.Run ... , 0, False`).

### 2026-02-11 - Nuclear launcher set visible for multi-select validation
- Problem: Need to confirm runtime behavior (single vs multiple `pwsh` instances) during multi-select delete tests.
- Root cause: Hidden launcher made process behavior hard to observe.
- Guardrail: Use visible VBS launch mode (`shell.Run ... , 1, False`) while validating behavior.
- Files affected: `NuclearDelete/NuclearDeleteFolder.vbs`.
- Validation/tests: VBS syntax check via `cscript //nologo`.

### 2026-02-11 - Nuclear multi-select invocation fix
- Problem: Selecting many folders triggered multiple PowerShell windows/processes.
- Root cause: Command used single-target `%1`, so Explorer invoked the verb per item.
- Guardrail: Use `%*` with `MultiSelectModel=Player`; make launcher/script accept multiple paths in one run.
- Files affected: `NuclearDelete/NuclearDeleteFolder.reg`, `NuclearDelete/NuclearDeleteFolder.vbs`, `NuclearDelete/NuclearDeleteFolder.ps1`.
- Validation/tests: PowerShell parse check + VBS syntax check + registry content review (`%*`, `MultiSelectModel`).

### 2026-02-11 - Nuclear queue/worker model for true single-process multi-select
- Problem: `%*` cascade invocation proved unreliable and produced no action in Explorer.
- Root cause: Explorer argument expansion behavior for this submenu path was inconsistent.
- Guardrail: Use per-item enqueue (`%1`) with hidden launcher and a mutex-protected queue; spawn one visible worker process to drain queue and delete all targets in one run.
- Files affected: `NuclearDelete/NuclearDeleteFolder.ps1`, `NuclearDelete/NuclearDeleteFolder.vbs`, `NuclearDelete/NuclearDeleteFolder.reg`.
- Validation/tests: PowerShell parse check + VBS syntax check + registry command review (`"%1"` enqueue path).

### 2026-02-11 - Nuclear worker race hardening
- Problem: Multi-select could still spawn multiple visible workers in fast successive invokes.
- Root cause: Queue worker lifetime/settle timing could end before all Explorer invokes had enqueued.
- Guardrail: Add dedicated worker mutex singleton and increase queue settle window before each batch run.
- Files affected: `NuclearDelete/NuclearDeleteFolder.ps1`.
- Validation/tests: PowerShell parse check + source check for singleton lock (`workerMutexName`) and settle loop (`idleRounds -lt 12`).

### 2026-02-11 - Nuclear startup race fix (PID-first worker detection)
- Problem: Multiple workers still appeared when several enqueue calls happened during worker startup.
- Root cause: Worker-running check preferred mutex state; before worker acquired mutex, next enqueue could start another worker.
- Guardrail: In worker detection, check live PID file/process first, then fallback to mutex check; keep settle window moderate (`idleRounds -lt 6`) to reduce close delay.
- Files affected: `NuclearDelete/NuclearDeleteFolder.ps1`.
- Validation/tests: PowerShell parse check + source check for PID-first `Test-WorkerRunning` and updated settle loop.

### 2026-02-11 - Nuclear in-process worker election (no spawned worker windows)
- Problem: Spawning a separate worker process from each enqueue path still caused multiple visible windows under multi-select.
- Root cause: Explorer invokes per item, and startup races around spawned workers were hard to eliminate completely.
- Guardrail: Remove spawned worker startup; each enqueue appends to queue, and exactly one enqueue process becomes worker via mutex (`WaitOne(0)`) and drains the queue in-process.
- Files affected: `NuclearDelete/NuclearDeleteFolder.ps1`.
- Validation/tests: PowerShell parse check + local 3-target concurrent invoke test (`Remaining=0`).

### 2026-02-11 - Nuclear mixed selection support (files + folders)
- Problem: Delete action needed to support mixed file/folder selections, not only folder paths.
- Root cause: Batch delete logic treated all targets as containers.
- Guardrail: Handle both path types: `Container` with `-Recurse -Force`, `Leaf` with `-Force`; register menu under `AllFilesystemObjects` for broad selection coverage.
- Files affected: `NuclearDelete/NuclearDeleteFolder.ps1`, `NuclearDelete/NuclearDeleteFolder.reg`.
- Validation/tests: PowerShell parse check + registry content review (`AllFilesystemObjects` keys and command path).

### 2026-02-11 - Explorer multi-select behavior for files (Document model)
- Problem: In large file-only selections, action could run for only one item.
- Root cause: Verb under `AllFilesystemObjects` without explicit multi-select model may default to single-item behavior.
- Guardrail: Set `MultiSelectModel=Document` on the run verb and keep queue/worker aggregation in script.
- Files affected: `NuclearDelete/NuclearDeleteFolder.reg`.
- Validation/tests: Registry review of `MultiSelectModel` and follow-up user test on large file-only selection.

### 2026-02-11 - Nuclear VBS-first synchronization to reduce CPU clone storms
- Problem: Per-item multi-select invocations still caused high CPU spikes due to many short-lived PowerShell enqueue processes.
- Root cause: Enqueue logic lived in PowerShell, so each selected item spawned another `pwsh` instance.
- Guardrail: Move enqueue + lock election to VBS; use one lock file worker (`worker.lock`), synchronous worker run, and stale lock cleanup (5 minutes).
- Files affected: `NuclearDelete/NuclearDeleteFolder.vbs`, `NuclearDelete/NuclearDeleteFolder.ps1`.
- Validation/tests: PowerShell parse check + VBS syntax run; registry command remains VBS `%1`.

### 2026-02-11 - Pending-file queue to remove enqueue lock contention
- Problem: Burst multi-select still produced heavy CPU spikes due to contention on one shared queue file.
- Root cause: Many parallel VBS invokes attempted repeated append/open retries against `queue.txt`.
- Guardrail: Replace single shared queue file with per-invoke pending files (`pending\*.txt`); worker atomically moves pending files into per-batch folder for processing.
- Files affected: `NuclearDelete/NuclearDeleteFolder.vbs`, `NuclearDelete/NuclearDeleteFolder.ps1`.
- Validation/tests: PowerShell parse check + VBS syntax run.

### 2026-02-11 - Recovery from legacy queue state + COM-safe enqueue filename
- Problem: Delete action could appear to do nothing due to incompatible leftover queue files and COM dependency in VBS filename generation.
- Root cause: Worker only read `*.txt` while old pending files had no extension; VBS used `Scriptlet.TypeLib` which may be blocked on some systems.
- Guardrail: Worker reads all pending files plus legacy `queue.txt`; VBS uses `FileSystemObject.GetTempName` for pending filenames (no Scriptlet COM dependency).
- Files affected: `NuclearDelete/NuclearDeleteFolder.ps1`, `NuclearDelete/NuclearDeleteFolder.vbs`.
- Validation/tests: PowerShell parse check + probe delete via VBS (`probe_deleted`) + state folder verification.

### 2026-02-11 - Adopt MoveTo-style single-instance selection model for NuclearDelete
- Problem: Queue-based multi-select handling remained fragile under large selections and could degenerate to single-item behavior.
- Root cause: Explorer per-item invocation timing plus queue/lock choreography created edge cases and overhead.
- Guardrail: Follow `MoveTo.cs` pattern: VBS lock allows one worker launch, PowerShell uses named mutex (`Global\MoveTo_NuclearDelete_Operation`), reads full Explorer selection from the parent folder with retries, and falls back to anchor path.
- Files affected: `NuclearDelete/NuclearDeleteFolder.ps1`, `NuclearDelete/NuclearDeleteFolder.vbs`.
- Validation/tests: PowerShell parse check + direct delete test (`direct_deleted`) + VBS launch probe (`pwsh_started`, `file_deleted`).

### 2026-02-11 - RoboTune debug mode for copy diagnostics
- Problem: Needed a quick way to capture robocopy diagnostics for red-error cases during copy/paste tests.
- Root cause: Existing benchmark/run logs did not include full robocopy verbose file-level details.
- Guardrail: Add `debug_mode` in `RoboTune.json`; when ON, `rcp.ps1` appends `/TEE /LOG+:robocopy_debug.log /V /TS /FP /BYTES` (without duplicating user flags), when OFF keep fast default behavior.
- Files affected: `Robocopy/RoboTune.ps1`, `Robocopy/rcp.ps1`, `Robocopy/README.md`.
- Validation/tests: PowerShell parser validation OK for both scripts (`RoboTune.ps1`, `rcp.ps1`).

### 2026-02-12 - Suppress profile startup errors in Robocopy launchers
- Problem: Red startup errors appeared at the beginning of RoboCopy runs and were reproducible each time.
- Root cause: Launcher VBS started `pwsh` with user profile loading, and profile `PSReadLine` settings can error in non-interactive/redirected contexts.
- Guardrail: Launch Robocopy scripts with `-NoProfile` in VBS wrappers to avoid unrelated profile noise and keep output focused on transfer logs.
- Files affected: `Robocopy/RoboPaste_Admin.vbs`, `Robocopy/RoboCopy_Silent.vbs`, `Robocopy/README.md`.
- Validation/tests: Script inspection of generated command lines (contains `-NoProfile`) + repeated log check with no `rcp.ps1` runtime errors.

### 2026-02-12 - Robocopy multi-select hardening for files + folders
- Problem: Context-menu staging was unreliable for large/mixed multi-select and effectively kept one source path in edge cases.
- Root cause: Copy/Cut registration was directory-only and staging logic overwrote previous entry per invoke.
- Guardrail: Register Copy/Cut under `AllFilesystemObjects` with `MultiSelectModel=Document`; use VBS lock to enforce single staging worker per Explorer burst; capture full Explorer selection snapshot in `rcopySingle.ps1`; store staged paths as ordered `item_######` values in registry; update paste engine to handle both directory and file transfers.
- Files affected: `Robocopy/RoboCopy_StandAlone.reg`, `Robocopy/RoboCopy_Silent.vbs`, `Robocopy/rcopySingle.ps1`, `Robocopy/rcp.ps1`, `Robocopy/README.md`.
- Validation/tests: PowerShell parser validation (`rcp.ps1`, `rcopySingle.ps1`) + VBS syntax check + registry command review (`AllFilesystemObjects`, `MultiSelectModel=Document`, `%1` launcher arg).

### 2026-02-12 - Robocopy staging reliability + file-path error fix
- Problem: Multi-select still often collapsed to one item, and file copy path could throw `Parameter set cannot be resolved`.
- Root cause: Concurrent per-item invokes could overwrite staging state; file branch used fragile parent-path resolution (`Split-Path -LiteralPath`) in some cases.
- Guardrail: In `rcopySingle.ps1`, use named mutex (`Global\MoveTo_RoboCopy_Stage`), retry Explorer selection read, and session-window append (`item_######` + `__last_stage_utc`) so per-item invokes accumulate reliably; in `rcp.ps1`, resolve file parent from `sourceItem.DirectoryName` with fallback.
- Files affected: `Robocopy/rcopySingle.ps1`, `Robocopy/RoboCopy_Silent.vbs`, `Robocopy/rcp.ps1`, `Robocopy/README.md`.
- Validation/tests: PowerShell parser validation + runtime staging check in registry (`HKCU:\RCWM\rc`) + error log check (`error_log.txt`) for previous stack location (`rcp.ps1:692`).

### 2026-02-12 - Robocopy staging scalar-path and timestamp parsing fix
- Problem: Staging could write `item_000001 = D` (only drive letter) and keep failing with missing source list.
- Root cause: Single-item path handling could degrade to scalar-string indexing, and timestamp parse used an incompatible overload causing staging to abort before writing.
- Guardrail: Normalize staged path collections explicitly to `string[]` before save/merge and use safe datetime parse (`try { [DateTime]::Parse(...) } catch {}`) for session-window logic.
- Files affected: `Robocopy/rcopySingle.ps1`, `Robocopy/rcp.ps1`.
- Validation/tests: Smoke stage run wrote full paths (`item_000001..item_000009`) and `stage_log.txt` confirmed `selected=9`.

### 2026-02-12 - Robocopy file batching to avoid one-file-per-call slowdown
- Problem: File multi-select copy was effectively one `robocopy` process per file and felt very slow; folder paste could fail right after staging due malformed single-item registry value.
- Root cause: File flow in `rcp.ps1` invoked `robocopy` per file filter; staging merge/save paths in `rcopySingle.ps1` could collapse to scalar-string and write only first character (`D`).
- Guardrail: Force array normalization for staged selections/combined lists in `rcopySingle.ps1`; in `rcp.ps1` group files by source directory and run batched file-filter transfers (with chunking to avoid command-length limits), keeping folder flow unchanged.
- Files affected: `Robocopy/rcopySingle.ps1`, `Robocopy/rcp.ps1`.
- Validation/tests: PowerShell parser validation for both scripts + smoke staging check now writes full value (`item_000001 = D:\...`) instead of single drive letter.

### 2026-02-12 - Robocopy multi-file path overhead reduction (selection-heavy runs)
- Problem: Large file selections were slower than Explorer and produced heavy repeated console/check overhead compared to folder-level robocopy.
- Root cause: Multi-select path still paid high per-batch console rendering and pre-copy filesystem checks (`Test-Path` per selected item), with conservative filename chunk size causing too many robocopy invocations.
- Guardrail: In `rcp.ps1`, suppress per-file/dir listing in normal mode (`/NFL /NDL`), increase file batch chunk target (6500 -> 26000 chars), and replace per-item destination `Test-Path` checks with in-memory destination name set + duplicate-name tracking.
- Files affected: `Robocopy/rcp.ps1`, `Robocopy/README.md`.
- Validation/tests: PowerShell parser validation (`rcp.ps1`) + source inspection of new flags/chunk size/name-set conflict classification.

### 2026-02-12 - Robocopy multi-select second performance pass (lookup/output trimming)
- Problem: In very large file selections, overhead remained noticeable during classification and conflict-heavy flows.
- Root cause: Extra filesystem lookups (`Test-Path` + `Get-Item` pairs and second-pass `Get-Item` in file batches) plus full-list console dumps for large selections/conflicts.
- Guardrail: Remove redundant existence checks in collection pass, avoid second-pass `Get-Item` in file-batch builder (use staged path parsing), and truncate huge selection/conflict previews in normal mode.
- Files affected: `Robocopy/rcp.ps1`, `Robocopy/README.md`.
- Validation/tests: PowerShell parser validation (`rcp.ps1`) + source inspection for preview truncation and reduced lookup flow.

### 2026-02-12 - Robocopy context-menu fast path (no pre-conflict scan)
- Problem: Multi-file context-menu operations still spent time in conflict classification and interactive checks even when reliability did not require user prompts.
- Root cause: Single-mode flow (`mode=s`) reused merge-precheck pipeline designed for manual interactive mode.
- Guardrail: For context-menu single mode, bypass pre-scan conflict classification/prompt and execute direct transfer path; keep interactive merge prompt only for manual mode (`mode=m`). Also cache MT decisions and reduce per-transfer run-log writes unless benchmark/debug is enabled.
- Files affected: `Robocopy/rcp.ps1`, `Robocopy/README.md`.
- Validation/tests: PowerShell parser validation (`rcp.ps1`) + source inspection of `mode=s` direct path, decision cache, and conditional run-log writes.

### 2026-02-12 - Wildcard fast-path for full-folder file selections
- Problem: Even after batching improvements, very large "Select All files" runs still required multiple filename batches and extra overhead.
- Root cause: File mode passed explicit filename lists to robocopy; command-line size limits forced chunking.
- Guardrail: Detect when selected files equal all top-level files in a source directory and switch to a single wildcard file-filter call (`*`) for that group; fallback to filename batching otherwise.
- Files affected: `Robocopy/rcp.ps1`, `Robocopy/README.md`.
- Validation/tests: PowerShell parser validation (`rcp.ps1`) + source inspection for fast-path selection check and wildcard run-log marker.

### 2026-02-12 - Staging lock in VBS to cut pwsh clone bursts
- Problem: Mixed file+folder selections could spawn many hidden `pwsh` processes during copy/cut staging.
- Root cause: Explorer multi-select invokes the verb per item (`%1`), and each invoke launched `rcopySingle.ps1`.
- Guardrail: Add short-lived lock file in `RoboCopy_Silent.vbs` (`state\stage.lock`) with stale cleanup so one selection burst launches only one hidden staging `pwsh`; other burst invokes exit immediately.
- Files affected: `Robocopy/RoboCopy_Silent.vbs`, `Robocopy/README.md`.
- Validation/tests: VBS script execution check (no-arg run), plus source inspection of lock acquire/release and stale lock cleanup.

### 2026-02-12 - Mixed-selection burst suppression marker
- Problem: Mixed selections still triggered additional hidden staging workers after the initial stage, creating `pwsh` bursts and CPU spikes.
- Root cause: Explorer could continue issuing per-item invokes from the same parent folder even after the first full-selection stage completed.
- Guardrail: `RoboCopy_Silent.vbs` now stores a short burst marker (`state\stage.burst`) for `mode+parent`; same-burst duplicate invokes are skipped for a few seconds. `rcopySingle.ps1` returns a dedicated exit code (`10`) when stage captured multi-item selection so VBS only marks true multi bursts.
- Files affected: `Robocopy/RoboCopy_Silent.vbs`, `Robocopy/rcopySingle.ps1`, `Robocopy/README.md`.
- Validation/tests: VBS no-arg run (`cscript //nologo`) + PowerShell parse check (`rcopySingle.ps1`) + hash sync check with standalone `D:\Users\joty79\scripts\Robocopy`.

### 2026-02-12 - Back-to-back copy/paste suppression reset
- Problem: Two very fast copy/paste cycles could make the second paste window open/close immediately (no staged items).
- Root cause: Burst suppression marker (`state\stage.burst`) could still be active from previous cycle when the next copy started.
- Guardrail: Clear `state\stage.burst` on all `Robo-Paste` exit paths (normal finish, early exit, and error) in `rcp.ps1`.
- Files affected: `Robocopy/rcp.ps1`, `Robocopy/README.md`.
- Validation/tests: PowerShell parser validation (`rcp.ps1`) + runtime A/B test with immediate second copy/paste cycle.

### 2026-02-12 - Burst suppression gated by active staged session
- Problem: Fast second copy from the same parent could be suppressed even when it was a valid new action, causing paste window to close with no transfer.
- Root cause: `RoboCopy_Silent.vbs` relied on `state\stage.burst` + parent match only, without confirming registry stage still existed.
- Guardrail: In `RoboCopy_Silent.vbs`, apply burst suppression only when staged registry session is active (`__last_stage_utc` and `item_000001` exist); otherwise clear stale burst marker and continue staging.
- Files affected: `Robocopy/RoboCopy_Silent.vbs`.
- Validation/tests: VBS no-arg execution (`cscript //nologo`) + log correlation (`run_log.txt` showed prior empty-start symptom).

### 2026-02-12 - Copy staging lock retry for first-click reliability
- Problem: In fast consecutive copy/paste cycles, first copy click could be dropped and only the second manual try would stage correctly.
- Root cause: `RoboCopy_Silent.vbs` exited immediately on lock contention, even when contention was short-lived from near-complete previous staging activity.
- Guardrail: Add bounded lock retry (`4 x 700ms`) after initial lock failure (while still respecting burst suppression), so first click waits briefly instead of being discarded.
- Files affected: `Robocopy/RoboCopy_Silent.vbs`.
- Validation/tests: VBS no-arg execution (`cscript //nologo`) + live sync to `D:\Users\joty79\scripts\Robocopy` + runtime retest requested.

### 2026-02-12 - Paste waits for stage readiness on ultra-fast copy/paste
- Problem: Ultra-fast copy->paste could fail on first paste (window opens/closes), then work on second attempt.
- Root cause: Paste could start before hidden staging (`rcopySingle.ps1`) had finished writing registry items.
- Guardrail: In `rcp.ps1`, replace immediate staged-list read with lock-aware wait/retry (`Get-StagedPathListWithWait`): short fast-fail when no stage activity is detected, but wait up to 6s when staging lock is active/observed.
- Files affected: `Robocopy/rcp.ps1`.
- Validation/tests: PowerShell parser validation for workspace + live copy, sync to `D:\Users\joty79\scripts\Robocopy`, remote push on `fix/second-paste-window-close`.

### 2026-02-12 - Fail-closed stage contract + stable selection capture
- Problem: In ultra-fast flows, dangerous partial copy could happen (subset copied) instead of clean fail/retry.
- Root cause: Staging could snapshot selection too early (breaking on first `count>1`) and paste accepted whatever registry list existed without readiness/integrity checks.
- Guardrail: `rcopySingle.ps1` now captures best/stable selection across retries and writes stage metadata (`__ready`, `__expected_count`, `__session_id`, `__last_stage_utc`); `rcp.ps1` now accepts stage only when metadata is valid (`ready=1` and expected count matches actual items), otherwise fail-closed (`NoListAvailable`).
- Files affected: `Robocopy/rcopySingle.ps1`, `Robocopy/rcp.ps1`.
- Validation/tests: PowerShell parser validation (workspace + live standalone folder) + sync to `D:\Users\joty79\scripts\Robocopy` + remote push (`aed5aef`) on `fix/second-paste-window-close`.

### 2026-02-12 - Restore stage-ready wait for metadata snapshots (old no-list regression)
- Problem: Old error returned (`NoListAvailable (mode=s)`) even though staging succeeded a moment later.
- Root cause: Paste switched to fail-closed metadata snapshots but lost the earlier wait/retry window; in fast copy->paste race, `rcp.ps1` read registry before stage write completed.
- Guardrail: Add metadata-aware wait resolver in `rcp.ps1` (`Resolve-ActiveStagedSnapshotWithWait`) that polls for a valid ready snapshot (`__ready=1` + expected count match) with lock/burst signal awareness, then selects active command; keep fail-closed behavior if readiness never materializes.
- Files affected: `Robocopy/rcp.ps1` (synced to `D:\Users\joty79\scripts\Robocopy\rcp.ps1`).
- Validation/tests: PowerShell parser validation on workspace and live copies; log correlation against failing window (`run start` before `stage OK`) to confirm fixed race point.

### 2026-02-12 - Narrow burst suppression window for same-folder rapid re-copy
- Problem: Very fast second copy from the same source folder could be treated as duplicate burst and fail in silent flow.
- Root cause: VBS burst suppression (`state\stage.burst`) allowed up to 6s same-parent suppression while stage session was active, which could catch intentional next copy action.
- Guardrail: In `RoboCopy_Silent.vbs`, keep burst marker lifetime but only suppress near-instant duplicates (`<=1s`) when active stage exists; for older marker ages, clear marker and allow restage.
- Files affected: `Robocopy/RoboCopy_Silent.vbs` (synced to `D:\Users\joty79\scripts\Robocopy\RoboCopy_Silent.vbs`).
- Validation/tests: VBS no-arg run (`cscript //nologo`) + live sync for immediate manual retest.

### 2026-02-12 - Fast same-folder second-copy hardening (lock retry + longer stage wait)
- Problem: In ultra-fast back-to-back copy/paste from same source folder, first attempt could fail (`NoListAvailable`) and only second retry work.
- Root cause: Silent staging invoke could be dropped under short lock contention windows; paste resolver wait window (6s) could expire before a delayed/late stage became ready.
- Guardrail: Increase silent lock acquire retry window in `RoboCopy_Silent.vbs` (`LOCK_RETRY_ATTEMPTS=10`, `LOCK_RETRY_DELAY_MS=600`) and reduce stale lock threshold (`STALE_LOCK_SECONDS=30`); increase stage-ready max wait in `rcp.ps1` to `12000ms` while keeping fast-fail when no signals exist.
- Files affected: `Robocopy/RoboCopy_Silent.vbs`, `Robocopy/rcp.ps1` (synced to `D:\Users\joty79\scripts\Robocopy`).
- Validation/tests: PowerShell parser validation on live `rcp.ps1` + live file sync for manual back-to-back scenario retest.

### 2026-02-12 - Burst suppression requires fully ready stage metadata
- Problem: Same-folder rapid second copy could be suppressed even when prior staged data was incomplete/corrupted, leading to timeout then `NoListAvailable`.
- Root cause: `RoboCopy_Silent.vbs` considered stage "active" based on weak markers (`__last_stage_utc` + first item), which can be true for partial/non-ready stage state.
- Guardrail: In `HasActiveStageSession`, require strict readiness (`__ready=1`, `__expected_count>0`, and `item_000001` exists) before allowing burst suppression; otherwise do not suppress and let restage proceed.
- Files affected: `Robocopy/RoboCopy_Silent.vbs` (synced to `D:\Users\joty79\scripts\Robocopy\RoboCopy_Silent.vbs`).
- Validation/tests: VBS no-arg execution (`cscript //nologo`) + log-driven root-cause correlation (`Stage rejected ... Ready=False | Expected= | Actual=...`).

### 2026-02-12 - Deterministic registry value cleanup (no wildcard clear)
- Problem: Stage keys could retain stale `item_######` entries, causing fail-closed mismatches (`Ready=True`, `Expected=N`, `Actual>>N`) and repeated `NoListAvailable`.
- Root cause: Wildcard property deletion (`Remove-ItemProperty ... -Name *`) proved unreliable for registry value cleanup in this flow, so old entries survived between stages.
- Guardrail: Replace wildcard deletion with explicit per-value cleanup by enumerating registry properties and removing each non-PS/non-default name (`Clear-RegistryValuesByName` / `Clear-StagedRegistryValues`).
- Files affected: `Robocopy/rcopySingle.ps1`, `Robocopy/rcp.ps1` (synced to `D:\Users\joty79\scripts\Robocopy`).
- Validation/tests: PowerShell parser validation (workspace + live), plus live registry snapshot check (`Ready=1`, `Expected=4944`, `Items=4944`) showing matched counts.

### 2026-02-12 - Atomic stage overwrite (disable session append/reuse)
- Problem: Re-copying from same source could intermittently fail with `NoListAvailable`, and stage logs showed inflated totals from previous actions.
- Root cause: `Save-StagedPaths` reused recent session data (`reused_session=True`) and appended old staged entries, making stage state non-deterministic under rapid consecutive actions.
- Guardrail: Make stage writes atomic per action: always replace staged list with current selection only (no append/reuse), while keeping deterministic value-by-value registry cleanup.
- Files affected: `Robocopy/rcopySingle.ps1` (runtime + workspace sync).
- Validation/tests: Parse validation for runtime/workspace scripts + log-driven confirmation target (`reused_session` expected to stay `False` after change).

### 2026-02-12 - Paste wait for ready snapshot (avoid fast-click no-list race)
- Problem: `NoListAvailable` still appeared when paste was invoked very quickly after copy/cut, even though staging completed moments later.
- Root cause: `rcp.ps1` used one-shot staged snapshot read in paste flow; if stage metadata was not ready yet, it failed immediately.
- Guardrail: Add `Get-ReadyStagedSnapshotWithWait` in `rcp.ps1` and use it before `NoListAvailable` to wait briefly for a valid ready snapshot (`__ready=1` + expected count match), with lock-aware timeout/fast-fail behavior.
- Files affected: `Robocopy/rcp.ps1` (runtime + workspace sync).
- Validation/tests: PowerShell parse validation on runtime/workspace + log expectation for `Stage wait resolved` on fast consecutive actions.

### 2026-02-12 - Robocopy pre-paste reset (atomic stage + strict ready contract)
- Problem: Μετά από μεγάλο mixed copy και άμεσο recopy από το ίδιο source, εμφανιζόταν unreliable behavior (`NoListAvailable`, partial stage, inconsistent retry behavior).
- Root cause: Συνδυασμός από session append/reuse στο staging, weak stage validation στο paste resolve, και permissive burst suppression/lock handling στο VBS wrapper.
- Guardrail: `rcopySingle.ps1` γράφει πλέον atomic stage ανά action (χωρίς reuse) με metadata contract (`__ready`, `__expected_count`, `__session_id`, `__last_stage_utc`, `__anchor_parent`), `rcp.ps1` αποδέχεται μόνο ready snapshots με expected=actual και κάνει bounded polling πριν fail-closed, ενώ `RoboCopy_Silent.vbs` κάνει suppression μόνο όταν υπάρχει valid ready stage + lock retry + μικρότερο burst window.
- Files affected: `Robocopy/rcopySingle.ps1`, `Robocopy/rcp.ps1`, `Robocopy/RoboCopy_Silent.vbs` (synced σε `D:\Users\joty79\scripts\Robocopy` και `MoveTo/Robocopy`).
- Validation/tests: PowerShell parser checks (`rcopySingle.ps1`, `rcp.ps1`) + `cscript //nologo RoboCopy_Silent.vbs` smoke run, manual runtime scenario test pending από user.

### 2026-02-12 - Adaptive stage-wait extension for copy->paste race
- Problem: Μετά από μεγάλο copy action, το αμέσως επόμενο paste μπορούσε να δώσει `NoListAvailable` στο πρώτο attempt και να δουλέψει στο δεύτερο.
- Root cause: Το stage resolver είχε fixed μικρό timeout χωρίς adaptive extension όταν υπήρχε ενεργό stage signal (`stage.lock`/`stage.burst`) από in-flight staging.
- Guardrail: `rcp.ps1` χρησιμοποιεί adaptive resolver timing (`StageResolveTimeoutMs=4000`, `StageResolveMaxTimeoutMs=12000`) και επεκτείνει προσωρινά την αναμονή μόνο όταν υπάρχουν lock/burst signals, αλλιώς fail-closed άμεσα.
- Files affected: `Robocopy/rcp.ps1` (runtime + `MoveTo/Robocopy` sync).
- Validation/tests: PowerShell parser validation + hash sync check μεταξύ runtime/workspace αντίγραφου.

### 2026-02-12 - Post-lock burst suppression re-check (queued invoke drain)
- Problem: Σε μεγάλο multi-select (`71 items`) εμφανίζονταν διαδοχικά πολλαπλά `stage_log OK` entries αντί για 1, αυξάνοντας CPU spike και race risk.
- Root cause: Πολλά VBS invocations περνούσαν το pre-lock suppression πριν γραφτεί burst marker και έμπαιναν queued στο lock, άρα κάθε queued invoke έκανε νέο staging.
- Guardrail: Στο `RoboCopy_Silent.vbs` προστέθηκε δεύτερο suppression check αμέσως μετά το lock acquire· αν πλέον υπάρχει active burst για ίδιο mode/parent, γίνεται immediate exit χωρίς νέο staging.
- Files affected: `Robocopy/RoboCopy_Silent.vbs` (runtime + `MoveTo/Robocopy` sync).
- Validation/tests: Hash sync check runtime/workspace + log-pattern review (`stage_log` πολλαπλά sessions στο ίδιο selection).

### 2026-02-12 - File staging backend (default) with backend abstraction
- Problem: Registry staging kept failing intermittently under high-frequency copy/cut->paste timing races.
- Root cause: Registry snapshot readiness and consume timing remained vulnerable to stale/partial state despite retries.
- Guardrail: Default stage backend switched to atomic file snapshots (`state\staging\rc.stage.json`, `state\staging\mv.stage.json`) with explicit backend abstraction (`file`/`registry`) in both stage writer and paste reader/clear paths.
- Files affected: `Robocopy/rcopySingle.ps1`, `Robocopy/rcp.ps1`, `Robocopy/RoboTune.ps1`, `Robocopy/README.md`.
- Validation/tests: PowerShell parser validation for modified scripts + static verification of backend precedence (`RCWM_STAGE_BACKEND` env -> `RoboTune.json.stage_backend` -> default `file`).

### 2026-02-12 - Auto-recover rollback (fail-closed only)
- Problem: Το `auto-recover` στο paste flow δεν ήταν αξιόπιστο στο real usage και πρόσθετε καθυστέρηση/πολυπλοκότητα χωρίς σταθερό όφελος.
- Root cause: Το fallback polling για late stage snapshot μπορούσε να δημιουργεί μη ντετερμινιστική συμπεριφορά σε edge timing windows.
- Guardrail: Αφαίρεση `auto-recover` path από `rcp.ps1` και επιστροφή σε strict fail-closed συμβόλαιο (`NoListAvailable` όταν δεν υπάρχει έτοιμο staged list).
- Files affected: `Robocopy/rcp.ps1` (sync σε `D:\Users\joty79\scripts\Robocopy\rcp.ps1` και `MoveTo/Robocopy/rcp.ps1`).
- Validation/tests: `Get-FileHash` equality check runtime/workspace + PowerShell parser validation και στα δύο `rcp.ps1`.

### 2026-02-13 - Separate SendTo destination editor path
- Problem: Χρειαζόταν ανεξάρτητο `Edit Destinations` flow για `SendTo`, χωρίς overlap με `MoveTo\destinations`.
- Root cause: Το υπάρχον editor ήταν hardcoded στο `MoveTo` destinations path και έκανε `SyncMoveToMenu` (registry workflow που δεν αφορά `SendTo` folder shortcuts).
- Guardrail: Προσθήκη dedicated `SendTo` editor scripts που δείχνουν αποκλειστικά στο `D:\Temp\SendTo` και δεν καλούν `SyncMoveToMenu.ps1`.
- Files affected: `EditSendToDestinations.ps1`, `EditSendToDestinations.vbs`.
- Validation/tests: Static review για path separation + VBS launcher path resolution μέσω `WScript.ScriptFullName`.

### 2026-02-13 - Menu root rename regression fix (MoveToCustom -> Z_MoveTo)
- Problem: Τα shortcuts υπήρχαν στο `Edit Destinations` αλλά δεν εμφανίζονταν στο context submenu.
- Root cause: Το `MoveTo.reg` μετονομάστηκε σε `Z_MoveTo` για ordering, αλλά το `SyncMoveToMenu.ps1` συνέχισε να γράφει dynamic `dest_*` entries στο παλιό root `MoveToCustom`.
- Guardrail: Το `SyncMoveToMenu.ps1` χρησιμοποιεί πλέον active menu root `Z_MoveTo` και καθαρίζει/μεταναστεύει και legacy root `MoveToCustom`.
- Files affected: `SyncMoveToMenu.ps1`.
- Validation/tests: PowerShell parser validation + static path check (`Z_MoveTo`/legacy cleanup).

### 2026-02-13 - Exclude menu infrastructure shortcuts from dynamic destinations
- Problem: `Add to Destinations` / `Edit Destinations` εμφανίζονταν διπλά στο submenu (ως static bottom entries και ως dynamic `dest_*` entries από `.lnk`).
- Root cause: Το `SyncMoveToMenu.ps1` συγχρόνιζε όλα τα `.lnk` από `destinations` χωρίς να εξαιρεί reserved/menu-infrastructure shortcuts.
- Guardrail: Στο sync έγινε exclude με normalized-name matching και command matching (`AddMoveToDestination.*`, `EditDestinations.*`) πριν τη δημιουργία `dest_*` keys.
- Files affected: `SyncMoveToMenu.ps1`.
- Validation/tests: Runtime sync run (`Done! 8 destinations`) χωρίς `Add/Edit` dynamic entries.

### 2026-02-13 - Submenu separator before static Add/Edit actions
- Problem: Τα static actions `[Add as destination]` / `[Edit destinations]` ήταν οπτικά ανακατεμένα με τα normal destinations.
- Root cause: Έλειπε separator marker στα static submenu keys.
- Guardrail: Στο `MoveTo.reg` μπήκε `SeparatorBefore=""` σε `shell\yyy_Add` (Directory submenu) και `shell\zzz_Edit` (file submenu) για να χωρίζονται από τα dynamic `dest_*` entries.
- Files affected: `MoveTo.reg`.
- Validation/tests: Registry import + visual submenu check (separator line πριν το static block).

### 2026-02-13 - Use explicit separator key for submenu grouping
- Problem: Σε κάποια Explorer paths το `SeparatorBefore=""` δεν εμφάνιζε separator line μέσα στο cascaded submenu.
- Root cause: Το separator behavior ήταν inconsistent για static submenu actions.
- Guardrail: Χρήση explicit separator item (`MUIVerb="-"`) με dedicated keys (`zzy_Separator`, `yyx_Separator`) πριν τα static actions.
- Files affected: `MoveTo.reg`.
- Validation/tests: Registry import + visual submenu check για γραμμή διαχωρισμού πριν `[Add as destination]`/`[Edit destinations]`.

### 2026-02-13 - Revert explicit '-' item; keep native SeparatorBefore
- Problem: Το explicit separator key (`MUIVerb="-"`) εμφανίστηκε ως ορατό item `-` αντί για καθαρή separator line.
- Root cause: Σε αυτό το submenu rendering path ο Explorer δεν το απέδωσε ως visual-only separator.
- Guardrail: Αφαίρεση explicit separator keys και επιστροφή σε native `SeparatorBefore=""` στα static actions (`shell\yyy_Add`, file `shell\zzz_Edit`).
- Files affected: `MoveTo.reg`.
- Validation/tests: Visual submenu check χωρίς ορατό `-` item.

### 2026-02-13 - Use [Actions] subgroup instead of separators
- Problem: Ο Explorer δεν απέδιδε σταθερά separator lines στο `Move To` submenu (είτε αγνοούσε `SeparatorBefore`, είτε έδειχνε `-` ως item).
- Root cause: Inconsistent submenu separator rendering σε cascaded context menus.
- Guardrail: Τα static actions μεταφέρθηκαν σε dedicated subgroup `zzz_Actions` (`[Actions]`) για καθαρό και deterministic οπτικό διαχωρισμό από τα dynamic `dest_*` entries.
- Files affected: `MoveTo.reg`.
- Validation/tests: Visual submenu check: normal destinations στο root + `[Actions]` subgroup στο bottom.

### 2026-02-13 - Final submenu separator method: CommandFlags 0x20
- Problem: Το submenu separation έμενε inconsistent με `SeparatorBefore=""` και με explicit `MUIVerb="-"` separator key.
- Root cause: Explorer rendering variance σε cascaded menu separators ανά mode/build.
- Guardrail: Χρήση `CommandFlags=dword:00000020` (SeparatorBefore) πάνω στα static action keys (`shell\yyy_Add` και `shell\zzz_Edit`) για σταθερό visual διαχωρισμό πριν το Add/Edit block.
- Files affected: `MoveTo.reg`.
- Validation/tests: User-confirmed visual result with separator line πριν τα static actions.
- Notes: Αυτό supersedes τα προηγούμενα separator experiments (`MUIVerb="-"` και `[Actions]` subgroup workaround) ως preferred pattern.

### 2026-02-13 - Workspace cleanup before Robocopy-based MoveTo track
- Problem: Το workspace είχε γίνει noisy από guidance/experimental folders και προσωρινά scripts, δυσκολεύοντας τη συνέχεια στο core `MoveTo`.
- Root cause: Πολύωρο troubleshooting σε παράλληλα tracks (`roboshift-main`, `Robocopy`, προσωρινά `EditSendToDestinations.*`) άφησε μη-core artifacts στο root.
- Guardrail: Μη-core items μεταφέρονται σε archive (όχι delete) πριν από νέο implementation phase.
- Files affected: Moved out of workspace root: `roboshift-main`, `Robocopy`, `EditSendToDestinations.ps1`, `EditSendToDestinations.vbs`.
- Validation/tests: Post-move root listing verified + archive path verified (`D:\Users\joty79\scripts\_archive\MoveTo_cleanup_2026-02-13_044832`).

### 2026-02-13 - MoveTo engine switched to Robocopy pipeline
- Problem: Το stable context-menu UX του `Move To` έπρεπε να κρατηθεί, αλλά το transfer engine να περάσει σε robocopy για reliability hardening.
- Root cause: Το legacy path (`MoveTo.exe`) ήταν ξεχωριστό από τις πρόσφατες βελτιώσεις staging/transfer που έγιναν στο `Robocopy`.
- Guardrail: Κρατάμε το ίδιο menu/destination contract (`MoveTo.vbs "%1" "<destName>"`) και αλλάζουμε μόνο backend: `MoveTo.vbs` κάνει stage με `Robocopy\rcopySingle.ps1` (mode `mv`) και execute με `Robocopy\rcp.ps1` (`mv s <dest> __moveto`). Στο `__moveto` mode το `rcp.ps1` τρέχει forced non-interactive (no benchmark hold/prompts).
- Files affected: `MoveTo.vbs`, `Robocopy/rcp.ps1`, `README.md`.
- Validation/tests: PowerShell parser check (`Robocopy/rcp.ps1`, `Robocopy/rcopySingle.ps1`) + `cscript //nologo MoveTo.vbs "C:\does_not_exist.txt" "__missing_dest__"` (expected graceful exit code 1).

### 2026-02-13 - Remove NuclearDelete track from MoveTo repo
- Problem: Το repo έπρεπε να μείνει focused στο MoveTo/Robocopy χωρίς παράλληλο delete tool track.
- Root cause: Το `NuclearDelete` ήταν πλέον out-of-scope για το τρέχον implementation phase.
- Guardrail: Remove `NuclearDelete` folder from git history going forward in this branch; keep decision log in `PROJECT_RULES.md` για traceability.
- Files affected: `NuclearDelete/*` (all tracked files removed).
- Validation/tests: `git rm -r NuclearDelete` completed successfully; pending final commit/push.

### 2026-02-13 - MoveTo robocopy engine relocated to repo root
- Problem: Ζητήθηκε το MoveTo να μην εξαρτάται από ξεχωριστό `Robocopy\...` subtree path για τα core engine scripts.
- Root cause: Το αρχικό integration έδειχνε σε `Robocopy\rcopySingle.ps1` και `Robocopy\rcp.ps1`.
- Guardrail: Τα core robocopy engine scripts μεταφέρονται στο root του MoveTo (`rcopySingle.ps1`, `rcp.ps1`) και το `MoveTo.vbs` καλεί μόνο root-local paths.
- Files affected: `MoveTo.vbs`, `rcopySingle.ps1` (moved), `rcp.ps1` (moved), `README.md`.
- Validation/tests: PowerShell parser checks + smoke move test after relocation.

### 2026-02-13 - MoveTo paste switched to visible interactive conflict flow
- Problem: Στο MoveTo robocopy mode το paste έτρεχε hidden + single mode, οπότε ο χρήστης δεν έβλεπε conflict prompts (`Overwrite/Merge`).
- Root cause: `MoveTo.vbs` καλούσε `rcp.ps1` ως `mv s` με `WindowStyle Hidden` και `wsh.Run(..., 0, True)`.
- Guardrail: Για MoveTo invoke, το paste τρέχει visible και interactive (`mv m` + `wsh.Run(..., 1, True)`) ώστε να εμφανίζονται τα merge/overwrite prompts.
- Files affected: `MoveTo.vbs`.
- Validation/tests: Static command-path review στο `MoveTo.vbs` (`mv m`, visible run mode) + dry-run wrapper exit check.

### 2026-02-13 - MoveTo paste elevation aligned with standalone Robocopy
- Problem: Το MoveTo robocopy flow χρειαζόταν admin rights στο paste path (όπως το standalone `RoboPaste_Admin`) για restricted destinations και consistent behavior.
- Root cause: Το MoveTo invoke έτρεχε non-elevated `pwsh -File rcp.ps1 ...`.
- Guardrail: Κρατάμε stage non-elevated, αλλά το paste εκτελεί `rcp.ps1` μέσω `Start-Process -Verb RunAs -Wait -PassThru` ώστε να υπάρχει UAC elevation και να επιστρέφεται exit code στο `MoveTo.vbs`.
- Files affected: `MoveTo.vbs`.
- Validation/tests: Static review command chain (`Verb RunAs` + `-Wait -PassThru`) και wrapper smoke check.

### 2026-02-13 - Elevated paste supports mapped network drive destinations
- Problem: Με UAC elevation, destination shortcuts που δείχνουν σε mapped drives (π.χ. `L:\...`) αποτύγχαναν με `Paste target path does not exist`.
- Root cause: Elevated process συχνά δεν βλέπει user mapped drive letters (split-token/session mapping behavior).
- Guardrail: Στο `MoveTo.vbs` γίνεται resolve drive-letter destination σε UNC path (μέσω `WScript.Network.EnumNetworkDrives`) πριν το elevated paste. Αν το UNC path δεν είναι reachable, γίνεται fallback στο original path με log warning.
- Files affected: `MoveTo.vbs`.
- Validation/tests: Log-correlated fix targeting (`L:\...` failures in `run_log.txt`) + static function path review (`ResolveDestinationForElevation`).

### 2026-02-13 - MoveTo paste launcher aligned to standalone WT experience
- Problem: Ζητήθηκε το MoveTo robocopy paste να ανοίγει το ίδιο visible WT admin flow με το standalone Robocopy.
- Root cause: Το MoveTo launcher χρησιμοποιούσε direct elevated `pwsh` path χωρίς `wt.exe`.
- Guardrail: `MoveTo.vbs` πλέον δοκιμάζει πρώτα `ShellExecute("wt.exe", "new-tab pwsh ...", "runas")` (visible admin WT tab) και κρατά fallback σε direct elevated `pwsh` μόνο αν αποτύχει το WT launch.
- Files affected: `MoveTo.vbs`.
- Validation/tests: Static command chain review + wrapper smoke check.

### 2026-02-13 - MoveTo paste command parity with standalone RoboPaste
- Problem: Το MoveTo flow έδειχνε διαφορετικό/βαρύ pre-confirm UI (`mv m`) με μεγάλο delay σε huge selections (π.χ. 4944 items), σε αντίθεση με το standalone RoboPaste.
- Root cause: Το MoveTo launcher καλούσε `rcp.ps1` με explicit `mv m` (interactive preview list) αντί για το standalone invocation style.
- Guardrail: Για parity/performance, MoveTo paste invoke πλέον χρησιμοποιεί ακριβώς `rcp.ps1 auto auto "<destination>"` (same as standalone), μέσω elevated WT launcher path με fallback.
- Files affected: `MoveTo.vbs`.
- Validation/tests: Static command review (`auto auto`) + runtime retest requested with large selection scenario.

### 2026-02-13 - Sync MoveTo stage-capture script with standalone Robocopy
- Problem: Το `MoveTo\rcopySingle.ps1` είχε drift από το standalone `Robocopy\rcopySingle.ps1` σε selection-capture logic.
- Root cause: Μεταφέρθηκε παλαιότερο variant κατά το initial migration στο MoveTo repo.
- Guardrail: Keep `MoveTo\rcopySingle.ps1` in sync με το standalone baseline για stage reliability (anchor-aware Explorer selection fallback behavior).
- Files affected: `rcopySingle.ps1`.
- Validation/tests: SHA256 equality check between `MoveTo\rcopySingle.ps1` and `D:\Users\joty79\scripts\Robocopy\rcopySingle.ps1`.

### 2026-02-13 - Sync MoveTo paste engine script with standalone Robocopy
- Problem: Το `MoveTo\rcp.ps1` είχε MoveTo-specific διαφοροποιήσεις που δημιουργούσαν mismatch συμπεριφοράς σε σχέση με standalone RoboPaste.
- Root cause: Προσωρινές custom αλλαγές για MoveTo invoke (`__moveto` path).
- Guardrail: Keep `MoveTo\rcp.ps1` byte-identical με `D:\Users\joty79\scripts\Robocopy\rcp.ps1` για behavior parity και χαμηλότερο maintenance risk.
- Files affected: `rcp.ps1`.
- Validation/tests: SHA256 equality check between `MoveTo\rcp.ps1` and standalone `Robocopy\rcp.ps1` + parser validation.

### 2026-02-13 - MoveTo launcher now delegates to same Robocopy wrappers
- Problem: MoveTo runtime behavior/UI timing still differed from standalone Robocopy flow during large selection moves.
- Root cause: `MoveTo.vbs` directly launched `rcopySingle.ps1`/`rcp.ps1` with custom elevation/invoke logic instead of wrapper parity.
- Guardrail: `MoveTo.vbs` now delegates to local wrapper equivalents (`RoboCopy_Silent.vbs` for hidden `mv` staging, `RoboPaste_Admin.vbs` for elevated `wt.exe` paste), while keeping destination/menu contract unchanged.
- Files affected: `MoveTo.vbs`, `RoboCopy_Silent.vbs` (new), `RoboPaste_Admin.vbs` (new).
- Validation/tests: `cscript //nologo` smoke checks on all wrappers + static command-path review.

### 2026-02-13 - MoveTo paste confirmation disabled for standalone parity
- Problem: Manual confirmation UI (`mv m`) made MoveTo paste window look/behave differently from standalone RoboPaste and added heavy filename preview noise.
- Root cause: `MoveTo\RoboPaste_Admin.vbs` had been switched to explicit manual mode.
- Guardrail: `MoveTo\RoboPaste_Admin.vbs` uses `rcp.ps1 auto auto "<dest>"` (same launcher semantics as standalone RoboPaste).
- Files affected: `RoboPaste_Admin.vbs`.
- Validation/tests: Static wrapper arg review (`auto auto`) + user retest requested.

### 2026-02-13 - MoveTo popup latency reduction (async stage launch)
- Problem: Στο MoveTo one-click flow το WT paste window εμφανιζόταν πολύ αργά σε μεγάλα selections, γιατί περίμενε πρώτα να ολοκληρωθεί όλο το stage.
- Root cause: `MoveTo.vbs` εκτελούσε stage wrapper με blocking wait (`wsh.Run(..., True)`).
- Guardrail: Launch stage wrapper asynchronously (`wsh.Run(..., False)`) και ξεκίνα paste wrapper μετά από μικρό settle delay (`250ms`) ώστε το window να ανοίγει άμεσα ενώ το stage συνεχίζει in-flight.
- Files affected: `MoveTo.vbs`.
- Validation/tests: Static flow review (async stage + delayed paste launch), user runtime retest pending.

### 2026-02-13 - MoveTo synced to Robocopy v3 engine baseline
- Problem: Το MoveTo branch έμενε σε pre-optimization robocopy engine ενώ το standalone Robocopy είχε ήδη v3 staging/performance/reliability fixes.
- Root cause: Drift μεταξύ `D:\Users\joty79\scripts\MoveTo` και `D:\Users\joty79\scripts\Robocopy` στα core engine scripts.
- Guardrail: Keep `MoveTo\rcopySingle.ps1` και `MoveTo\rcp.ps1` byte-identical με το Robocopy v3 baseline, εκτός αν υπάρχει explicit MoveTo-specific requirement.
- Files affected: `rcopySingle.ps1`, `rcp.ps1`, `PROJECT_RULES.md`.
- Validation/tests: SHA256 equality checks (`True` και στα δύο αρχεία) + PowerShell parser validation (`OK` και στα δύο scripts).

### 2026-02-13 - Keep source folder after tokenized select-all move
- Problem: Σε move από μέσα σε folder (select-all files/folders), το source folder μπορούσε να διαγραφεί όταν άδειαζε.
- Root cause: Το tokenized move path χρησιμοποιεί `/MOVE` στο source directory, που μπορεί να αφαιρέσει και το root source folder όταν μείνει empty.
- Guardrail: Μετά από successful tokenized move, αν λείπει το source directory, γίνεται explicit recreate ώστε να παραμένει άδειο.
- Files affected: `rcp.ps1`, `PROJECT_RULES.md`.
- Validation/tests: PowerShell parser validation (`rcp.ps1`) + runtime retest pending (select-all cut μέσα από source folder).

### 2026-02-13 - Preserve source folder identity (no recreate/reorder)
- Problem: Το recreate-after-delete workaround διατηρούσε μεν folder name, αλλά μπορούσε να αλλάζει η θέση/sort order του source folder στο Explorer.
- Root cause: Το source root folder διαγραφόταν πρώτα από `/MOVE` και μετά ξαναδημιουργούνταν.
- Guardrail: Στο tokenized move path δημιουργείται προσωρινό keep-root marker file στο source root και περνάει exclude (`/XF <marker>`), ώστε ο root folder να μη διαγράφεται ποτέ. Μετά το transfer ο marker αφαιρείται.
- Files affected: `rcp.ps1`, `PROJECT_RULES.md`.
- Validation/tests: PowerShell parser validation (`rcp.ps1`) + runtime retest pending (select-all cut, verify source folder remains same object/position).

### 2026-02-13 - Centralize MoveTo runtime logs under `logs\`
- Problem: Runtime logs ήταν διασκορπισμένα (root `.txt` και `%TEMP%`), κάνοντας το housekeeping δύσκολο.
- Root cause: `rcp.ps1`, `rcopySingle.ps1` και `MoveTo.vbs` είχαν hardcoded log paths εκτός `logs\`.
- Guardrail: Όλα τα runtime logs γράφουν πλέον σε `logs\`:
  - `logs\run_log.txt`
  - `logs\stage_log.txt`
  - `logs\error_log.txt`
  - `logs\robocopy_debug.log`
  - `logs\MoveTo_debug.log`
- Files affected: `rcp.ps1`, `rcopySingle.ps1`, `MoveTo.vbs`, `README.md`, `.gitignore`, `docs/PROJECT_RULES.md`.
- Validation/tests: PowerShell parser validation (`rcp.ps1`, `rcopySingle.ps1`) + static path review στα log echoes/writes.

### 2026-02-15 - Refresh self-heals static MoveTo actions (Add/Edit)
- Problem: Μετά από `Refresh` στο `EditDestinations`, μπορούσαν να λείπουν τα static actions (`[Add as destination]`, `[Edit destinations]`) παρότι τα dynamic destinations (`dest_*`) εμφανίζονταν.
- Root cause: Το `SyncMoveToMenu.ps1` συγχρόνιζε μόνο dynamic `dest_*` entries και δεν έκανε explicit ensure των static `yyy_Add`/`zzz_Edit` keys σε κάθε refresh.
- Guardrail: Το `SyncMoveToMenu.ps1` κάνει πλέον self-heal των static action keys σε κάθε run:
  - Files branch: `zzz_Edit` με `CommandFlags=0x20`.
  - Directory branch: `yyy_Add` (with `%1`) + `zzz_Edit`.
  - Επεκτάθηκε και το reserved shortcut filter για bracketed action names ώστε να μην ξαναμπαίνουν ως normal destinations.
- Files affected: `SyncMoveToMenu.ps1`, `docs/PROJECT_RULES.md`.
- Validation/tests: PowerShell parser validation (`SyncMoveToMenu.ps1`) + registry query verify (`*\shell\Z_MoveTo\shell\zzz_Edit`, `Directory\shell\Z_MoveTo\shell\yyy_Add`, `...\\zzz_Edit`).

### 2026-02-15 - Static action writes hardened with `reg.exe` on wildcard shell keys
- Problem: Τα static action keys εμφανίζονταν intermittently να "χάνονται" μετά από refresh/sync σε ορισμένα runs.
- Root cause: Registry provider writes σε wildcard-heavy paths (`*\shell\...`) δεν ήταν αρκετά deterministic στο συγκεκριμένο flow.
- Guardrail: Στο `SyncMoveToMenu.ps1`, τα static `yyy_Add`/`zzz_Edit` writes γίνονται πλέον με `reg.exe add` (MUIVerb/Icon/CommandFlags/(Default) command), με deterministic key/value creation.
- Files affected: `SyncMoveToMenu.ps1`, `docs/PROJECT_RULES.md`.
- Validation/tests: PowerShell parser validation (`SyncMoveToMenu.ps1`) + live registry readback (`reg query` στα 3 static keys).

### 2026-02-15 - Actions submenu to avoid child-item render cap
- Problem: Με πολλά destinations (π.χ. 16+), το static submenu renderer του Explorer έδειχνε μόνο τα πρώτα entries και τα `[Add as destination]` / `[Edit destinations]` έμεναν εκτός ορατού range.
- Root cause: Τα action entries ήταν siblings στο ίδιο level με τα `dest_*` και sort-άρονταν στο τέλος (`yyy_Add`, `zzz_Edit`), άρα κόβονταν όταν ξεπερνιόταν το practical child cap.
- Guardrail: Νέο σταθερό layout με `[Actions]` child submenu (`aaa_Actions`) που μένει ορατό:
  - Files: `[Actions] -> [Edit destinations]`
  - Directories: `[Actions] -> [Add as destination]`, `[Edit destinations]`
  - Το sync κάνει migration cleanup από παλιό layout (`yyy_Add`, `zzz_Edit`) και self-heal τα νέα keys σε κάθε run.
- Files affected: `SyncMoveToMenu.ps1`, `MoveTo.reg`, `docs/PROJECT_RULES.md`.
- Validation/tests: PowerShell parser validation (`SyncMoveToMenu.ps1`) + static diff check (`aaa_Actions`, `yy_Add`, `zz_Edit` keys).

### 2026-02-15 - Empty-string-safe registry helper params in sync script
- Problem: Το `SyncMoveToMenu.ps1` έσκαγε με `Cannot bind argument to parameter 'Data' because it is an empty string` σε writes όπως `SubCommands=""`.
- Root cause: Ο helper param `Data` ήταν mandatory string χωρίς `[AllowEmptyString()]`.
- Guardrail: Το helper `Add-RegValue` δηλώνει πλέον `Data` ως `[AllowEmptyString()][string]` ώστε empty string registry values να γράφονται deterministic.
- Files affected: `SyncMoveToMenu.ps1`, `docs/PROJECT_RULES.md`.
- Validation/tests: PowerShell parser validation (`SyncMoveToMenu.ps1`) + runtime sync run χωρίς bind errors.

## Entry Template
### YYYY-MM-DD - Short decision title
- Problem:
- Root cause:
- Guardrail/rule:
- Files affected:
- Validation/tests:
