# Move To - The "86k Files" Saga 🚀

Αυτό το app ξεκίνησε απλά, αλλά εξελίχθηκε σε τέρας αξιοπιστίας για να χειριστεί τη μεταφορά **86.000+ αρχείων** χωρίς να κρεμάει το σύστημα.

Εδώ είναι το χρονικό των προβλημάτων και των λύσεων (aka "The Struggles"):

---

## � Τα Προβλήματα (The Struggles)

### 1. **Silent Crash στα ~20k αρχεία**
Η πρώτη έκδοση χρησιμοποιούσε το παλιό `SHFileOperation` API (Win32).
*   **Συμπτώματα:** Η μεταφορά ξεκινούσε καλά, αλλά σταματούσε ξαφνικά χωρίς error message.
*   **Αιτία:** Το `SHFileOperation` έχει **buffer limits** και δεν αντέχει τόσο μεγάλο όγκο αρχείων.

### 2. **Το Process "Zombie" (100% CPU Hang)**
Ακόμα και όταν η μεταφορά τελείωνε, το `MoveTo.exe` έμενε ανοιχτό και έτρωγε 100% CPU.
*   **Αιτία:** Το COM message pump κολλούσε μετά το κλείσιμο του dialog.

### 3. **Το Watchdog που δεν έβλεπε τίποτα**
Προσπαθήσαμε να βάλουμε watchdog να σκοτώνει το process, αλλά το `IFileOperation` δημιουργεί ένα "κρυφό" internal window που μπέρδευε τον watchdog. Αποτέλεσμα: Ο watchdog νόμιζε ότι το dialog είναι ακόμα ανοιχτό.

### 4. **Η "Επίθεση" των Κλώνων (Multiple Launcher Instances)**
Η VBScript διέγραφε το marker file **πριν** ξεκινήσει το EXE.
*   **Αποτέλεσμα:** Αν επέλεγες 86k αρχεία, τα Windows καλούσαν το script 86.000 φορές. Επειδή το marker έφευγε νωρίς, ξεκινούσαν εκατοντάδες `MoveTo.exe`, γονατίζοντας το PC.

### 5. **Το "1 File" Bug μετά από Cancel**
Αν έκανες Cancel σε μια μεγάλη μεταφορά, η επόμενη προσπάθεια μετέφερε μόνο **1 αρχείο** αντί για όλα τα επιλεγμένα.
*   **Αιτία:** Το flag `FOF_ALLOWUNDO` άφηνε "σκουπίδια" στο Shell state αν η διαδικασία σκοτωνόταν βίαια. Επίσης, ο Explorer ήθελε λίγο χρόνο (hysteresis) για να αναφέρει σωστά τα `SelectedItems()` μετά από cancel.

---

## ✅ Οι Λύσεις (The Fixes)

Για να φτάσουμε σε **100% αξιοπιστία**, κάναμε τα εξής:

### 🔧 1. Αναβάθμιση σε `IFileOperation` (Vista+)
Πετάξαμε το παλιό API. Το νέο `IFileOperation`:
*   Χειρίζεται **απεριόριστα αρχεία** σε μία λίστα.
*   Έχει ένα native progress dialog για όλα τα operations.
*   Υποστηρίζει σωστά Pause/Resume/Cancel.

### 🔧 2. Ο "Εξυπνος" Watchdog
Επειδή το `PerformOperations()` κολλάει (κλασικό COM bug), φτιάξαμε ένα δικό μας Watchdog thread που τρέχει παράλληλα:
*   Παρακολουθεί το Window Handle του progress dialog.
*   **Exit Conditions:**
    1.  Αν το dialog εμφανιστεί και μετά κλείσει -> **KILL**.
    2.  Αν ΟΛΑ τα source αρχεία εξαφανιστούν (μεταφέρθηκαν) -> **KILL**.
    3.  Αν περάσουν 60s χωρίς να εμφανιστεί dialog (instant move) -> **KILL**.
    4.  Hard Timeout 30 λεπτών -> **KILL**.

### � 3. Named Mutex & VBS Synchronization
Για να αποφύγουμε τους "Κλώνους":
*   **VBS:** Περιμένει το EXE να τελειώσει (`wsh.Run ..., True`) πριν καθαρίσει το marker.
*   **EXE:** Χρησιμοποιεί **Named Mutex** (`Global\MoveTo_Operation`). Μόνο ΤΟ ΠΡΩΤΟ instance τρέχει. Τα άλλα 85.999 πεθαίνουν ακαριαία.
*   **Stale Cleanup:** Αν κάτι κρασάρει, η VBS καθαρίζει markers παλιότερα των 5 λεπτών αυτόματα.

### 🔧 4. Explorer Reliability Fixes
*   **Αφαίρεση `FOF_ALLOWUNDO`:** Σταματάει το corruption του Shell state μετά από cancel.
*   **Retry Logic:** Αν το `SelectedItems()` γυρίσει 0, το script ξαναδοκιμάζει μέχρι 3 φορές, δίνοντας χρόνο στον Explorer να συνέλθει.
*   **Optimized Delays:** Μειώσαμε τα safety delays από 4.5s σε **~1.5s** για να είναι snappy.

---

## 🎯 Αποτέλεσμα
*   **86,000+ Files:** ✅ Done.
*   **Conflicts Handling:** ✅ Native Windows Dialog.
*   **Cancel Stability:** ✅ Clean exit, no side effects.
*   **Performance:** ✅ Snappy start, no hanging processes.
