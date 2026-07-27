# PROJECT_RULES.md (MoveTo)

## Scope
- This file stores MoveTo-specific decisions, guardrails, and critical lessons.
- Keep entries concise and actionable.
- Do not move Robocopy/NuclearDelete-only items here.

## Decision Log
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

### 2026-02-20 - Rules file persistence policy (critical)
- Problem: Project memory was effectively lost when `PROJECT_RULES.md` was deleted and recreated as a tiny file.
- Root cause: Documentation reset replaced cumulative decision history.
- Guardrail/rule: Never delete/recreate `PROJECT_RULES.md`; only append or surgically edit while preserving chronology.
- Files affected:
  - `PROJECT_RULES.md`
- Validation/tests run:
  - History audit in `MoveTo` and `Robocopy` repositories.

### 2026-02-13 - Remove NuclearDelete track from MoveTo repo
- Problem: Το repo έπρεπε να μείνει focused στο MoveTo/Robocopy χωρίς παράλληλο delete tool track.
- Root cause: Το `NuclearDelete` ήταν πλέον out-of-scope για το τρέχον implementation phase.
- Guardrail: Remove `NuclearDelete` folder from git history going forward in this branch; keep decision log in `PROJECT_RULES.md` για traceability.
- Files affected: `NuclearDelete/*` (all tracked files removed).
- Validation/tests: `git rm -r NuclearDelete` completed successfully; pending final commit/push.

### 2026-07-28 - Controlled Robocopy engine safety backport
- Problem: The clean MoveTo branch had fallen behind committed Robocopy engine safety fixes, while the historical byte-identical rule conflicted with the newer MoveTune-only runtime policy.
- Root cause: Shared staging fixes landed in the standalone Robocopy repo after MoveTo adopted project-specific `MoveTune.ps1` / `MoveTune.json` names and retained a safer initialized temporary-path cleanup guard.
- Guardrail/rule: Backport validated shared behavior deliberately; preserve the MoveTune-only contract and documented MoveTo-safe deviations. Engine parity means safety/behavior parity, not blind byte identity.
- Files affected: `rcp.ps1`, `rcopySingle.ps1`, `.gitattributes`, `tests/EngineParity.Tests.ps1`, `README.md`, `CHANGELOG.md`, `PROJECT_RULES.md`.
- Validation/tests: PowerShell parser validation, engine regression check, PSScriptAnalyzer error scan, intentional-difference review against the clean Robocopy sibling, `git diff --check`, and `git ls-files --eol`.

## Entry Template
### YYYY-MM-DD - Short decision title
- Problem:
- Root cause:
- Guardrail/rule:
- Files affected:
- Validation/tests:

