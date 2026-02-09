# Move To Context Menu - Προβλήματα & Διορθώσεις

## 🔵 Κύριο Πρόβλημα: Registry Path με `*`

Το Codex προσπαθούσε να χρησιμοποιήσει:
```powershell
$regPath = "HKCU:\Software\Classes\*\shell\MoveToCustom\shell"
```

### ❌ Γιατί δεν δούλευε:
Το `*` στο PowerShell ερμηνεύεται ως **wildcard** (glob pattern), όχι literal χαρακτήρας.
Όταν το script έτρεχε `Test-Path` ή `Get-ChildItem` σε αυτό το path, **κολλούσε επ' αόριστον**.

### ✅ Διόρθωση:
Χρήση του `Registry::` prefix:
```powershell
$regPath = "Registry::HKEY_CURRENT_USER\Software\Classes\*\shell\MoveToCustom\shell"
```
Αυτό λέει στο PowerShell να το αντιμετωπίσει ως **literal path**.

---

## 🔵 Δευτερεύοντα Προβλήματα

### 1. MoveTo.reg: `SubCommands=""`
Το `.reg` αρχείο είχε κενό `SubCommands`, χωρίς actual entries.
Λύση: Χρήση **nested shell keys** (`shell\dest_Name`) αντί για SubCommands.

### 2. Sync Script έλειπε
Δεν υπήρχε τρόπος να συγχρονιστούν τα shortcuts με το registry menu.
Λύση: `SyncMoveToMenu.ps1` που διαβάζει τα `.lnk` αρχεία και ενημερώνει το registry.

---

## 🔵 Αρχεία που διορθώθηκαν

| Αρχείο | Πρόβλημα | Λύση |
|--------|----------|------|
| `SyncMoveToMenu.ps1` | `HKCU:\*` wildcard issue | `Registry::HKEY_CURRENT_USER\*` |
| `MoveTo.reg` | Άδειο SubCommands | Nested shell structure |
| `AddMoveToDestination.ps1` | Δεν έτρεχε sync | Καλεί το SyncMoveToMenu.ps1 |

---

## 🔵 Εκκρεμότητες

- [ ] Remove destination functionality
- [ ] Refresh destinations option
- [ ] Testing για edge cases
