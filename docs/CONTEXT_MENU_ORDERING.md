# Context Menu Ordering Notes

## Goal

Να εμφανίζεται το `Move To` κοντά/κάτω από το `Manage Ownership` στο classic context menu.

## What Worked

- Χρήση ίδιου naming pattern στα registry key names: `Z_*`.
- Αλλαγή key από `MoveToCustom` σε `Z_MoveTo`.
- Χωρίς `Position="Bottom"` (το `Bottom` το έστελνε πολύ χαμηλά).

## Effective Pattern

- `Manage Ownership`: `...\\shell\\Z_ManageOwnership`
- `Move To`: `...\\shell\\Z_MoveTo`

## Why This Helps

- Το order στο Explorer δεν είναι καθαρά alphabetical.
- Παίζουν ρόλο shell buckets + heuristics.
- Το `Z_*` alignment βοήθησε να μπουν στην ίδια "ζώνη" με σωστή σχετική σειρά.

## Guardrails

- Μην βασίζεσαι σε απόλυτο deterministic order για όλα τα Windows builds.
- Απόφυγε `Position="Bottom"` όταν θες το item κοντά σε άλλα custom entries.
- Κράτα καθαρό submenu structure (`shell\\dest_*`, `shell\\zzz_Edit`) για σταθερότητα.

## Submenu Separation (Final)

- Preferred method: `CommandFlags=dword:00000020` στα static action keys (`yyy_Add`, `zzz_Edit`).
- `0x20` = `SeparatorBefore` και αποδείχτηκε πιο reliable από:
  - `SeparatorBefore=""`
  - explicit separator key (`MUIVerb="-"`)
  - temporary `[Actions]` subgroup workaround
- Χρησιμοποίησε το pattern αυτό όταν θέλεις τα `[Add as destination]` / `[Edit destinations]` να μένουν οπτικά χωριστά από τα normal destinations.

## If Order Breaks Again

1. Επιβεβαίωσε ότι τα keys παραμένουν `Z_ManageOwnership` και `Z_MoveTo`.
2. Κάνε re-import `.reg`.
3. Κάνε restart Explorer.
4. Έλεγξε στο classic menu (`Show more options`).
