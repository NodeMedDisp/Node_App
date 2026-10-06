# NODE: one medication event per day

## Scope and baseline

**APP repository:** `NodeMedDisp/Node_App`  
**Branch:** GitHub's `jv_working`  
**Exact base commit:** `9e877a10436e65aec340622f6bff610e9e0faca1`

This package does NOT depend on the previous prompt-link preparation package. Do not apply that earlier package first. It adds no medication-to-prompt associations and changes no counseling model or prompt editor.

### What this patch implements

The medication entry and edit screens use Methadone and one daily time. Both show a start-date picker and number of days. The start date counts as day 1. A candidate that shares ANY calendar date with another entry for that patient is rejected, even when the two times differ. Adjacent, nonoverlapping date ranges are allowed. An edit excludes its own record from the overlap check, but cannot overlap a different record.

Provider saves are checked again against fresh server data. New medication entries receive new Firestore document IDs; they do not use the drug name as an ID. Existing entries are not automatically deleted, merged, renamed, or converted. Valid edits preserve the entry's document ID and existing rewards. Rapid repeated saves are disabled while a write is pending.

The calendar safely converts Hive's restored dynamic maps instead of assuming they are already `Map<String, dynamic>`. Unreadable items are skipped in memory and reported in debug output; their saved records are NOT deleted. Provider calendars use a patient-specific ValueKey rather than imperative access through the former GlobalKey. Relevant asynchronous callbacks are guarded against disposed widgets.

## Important: saving a future plan is not the same as arming the device

This is an APP patch, not a firmware patch. `NodeMedDisp/Node_device` was not accessible during preparation.

The existing transfer file contains medication blocks with `Days: 1 to N`, but has no medication start date. Sending a future course unchanged would tell that format it begins now. The receiver's behavior when it sees several blocks is also unverified.

Accordingly, future/nonoverlapping plans can be saved in the provider app and displayed on the correct calendar dates, but the send path rejects programs containing a pending future course. It does not silently pick one course, drop the others, alter the device clock, or claim those future doses were programmed. A valid single course active today can use the legacy path; its transmitted duration is reduced to its remaining calendar days without changing the saved original. Expired courses are not rearmed by the formatter. This duration behavior still needs a hardware bench test.

Multiple `Medication:` blocks are additionally rejected before Bluetooth writes. No new wire fields are invented. There is no firmware-level programming acknowledgment in this package. Preventing duplicate physical dispensing after reboot, reprogramming, or retries still requires verifying the device's actual implementation. Test with a test patient and no medication loaded.

## Files in this package

- `app_single_daily_medication.patch`: the standard Git patch. This installs all APP changes and the Dart test.
- `APPLY.ps1`: checks the base commit, requires clean tracked files, and runs `git apply --check` on your complete checkout before applying.
- `CHANGES.md`: every APP filename, exact function/anchor, and complete BEFORE/AFTER blocks. Use this for review or manual edits; do not manually duplicate changes after applying the patch.
- `new_files/`: copies of the three new source/test files for inspection. The patch already creates them.
- `BASELINE.json`: baseline and changed-file manifest.
- `VALIDATION.txt`: what was and was not tested.

## Installation on Windows / VS Code

### 1. Leave the previous experimental work alone

Stop the running Flutter debug session. Open a terminal in your existing Node_App checkout and run:

```powershell
git fetch origin
git worktree add -b node-single-daily-dose ..\Node_App_single_daily origin/jv_working
cd ..\Node_App_single_daily
code .
```

This creates a separate working folder based on GitHub's branch. Do not use `git reset --hard` or `git clean` to get rid of the earlier feature experiment. A worktree lets that work remain in its original folder.

A failure such as an existing branch/folder name should be resolved before continuing; do not point the next steps at the wrong folder.

### 2. Extract the package

Extract the ZIP so the folder containing this README appears next to `pubspec.yaml`:

```text
Node_App_single_daily/
  pubspec.yaml
  lib/
  node_daily_schedule_patch/
    APPLY.ps1
    app_single_daily_medication.patch
    README.md
    ...
```

### 3. Check and apply

In PowerShell, from the Node_App_single_daily root:

```powershell
.\node_daily_schedule_patch\APPLY.ps1
```

The script stops before changing files when the baseline or patch check does not match. Do not force a failed patch, use `--reject`, or apply pieces over unrelated changes.

When local policy does not permit scripts, use the manual equivalent below. Run each check before moving to the next command:

```powershell
git rev-parse HEAD
# Must print 9e877a10436e65aec340622f6bff610e9e0faca1.

git status --short --untracked-files=no
# Must print nothing before applying this patch.

git apply --check .\node_daily_schedule_patch\app_single_daily_medication.patch
# Must succeed before the next command; successful checks normally print nothing.

git apply .\node_daily_schedule_patch\app_single_daily_medication.patch
```

The package folder itself is not application source; avoid accidentally committing the ZIP or review copies with your code.

### 4. Analyze, test and launch

```powershell
flutter pub get
flutter analyze
dart run tool/check_daily_medication_schedule.dart
flutter run
```

The pure-Dart test contains 23 checks and should end with:

```text
PASS: all 23 daily-schedule/cache regression checks.
```

Stop on test failures. Analyze results can also include warnings already present in the baseline; do not assume every warning was introduced by this patch. Dart/Flutter were unavailable in the preparation environment, so these commands have NOT already been run for you.

Use a full stop/start for the first run. Do not rely on hot reload to rerun `initState()` or to recreate changed widget identities. Do not uninstall, clear storage, or delete the Hive calendarData box as the routine fix.

## Acceptance checks with a NEW test patient

Use synthetic test data; do not interpret any value as a dose recommendation.

1. Save Methadone at a chosen time starting September 28, 2026 for five days. Confirm it appears on September 28 through October 2, inclusive.
2. Attempt another entry starting October 2, 2026, at a different time. Confirm an error appears and the existing record remains unchanged.
3. Save another entry starting October 3, 2026. Confirm both separate records remain visible and neither overwrites the other.
4. Edit the first entry's time without changing its range. It should save. Extend that first range into October 3. It must fail, leaving the previously saved range unchanged.
5. Log out and back into the provider account, select the same test patient, and confirm dates/durations remain in Firestore and on the calendar.
6. Close and restart the app WITHOUT uninstalling it after progress has been stored. Confirm valid previously stored progress still displays. Check debug output for `CALENDAR CACHE:` warnings without deleting the source records.
7. Switch patients and open/close the edit screens. Confirm the calendar uses the selected patient's data and does not raise a lifecycle assertion.
8. Attempt to send a plan containing a future course. Confirm a clear 'Nothing sent' compatibility error. It must NOT report a future device program as successful. Test any allowed single-current-course transfer only on an unloaded bench device.

## Why the Flutter assertion may have appeared

The reported `_elements.contains(element)` assertion concerns Flutter's internal element lifecycle. Its line number alone does not prove the original failure. The baseline also has this concrete unsafe cache read in `CalendarWidgetState._loadRecoveryProgress()`:

```dart
List<Map<String, dynamic>>.from(data['progress'])
```

That outer list conversion expects each restored element to already have the required map type. It does not convert each Hive-restored `Map<dynamic, dynamic>` into a String-keyed map. The replacement constructs `Map<String, dynamic>.from(rawEntry)` for each valid item, checks record shapes/dates, and retains the original storage.

An exception while restoring saved state could explain why an uninstall appeared to help. This remains a code-supported diagnosis, not a reproduced root-cause proof. The calendar key and mounted/discovery guards also remove unnecessary lifecycle risk. The patch does not edit Flutter's framework.dart or suppress framework assertions.

A remaining failure needs the FIRST exception and its stack trace above the framework assertion, plus `flutter --version`; the last red-screen assertion alone may be a secondary error.

## Data and concurrency limits

The authoritative overlap check applies per clinic/patient medication collection in the provider repository. Before a write it reads the parent revision and medications from the server, then validates and commits the medication change plus a revision increment in one Firestore transaction. An intervening updated-client medication write causes a refresh/retry. This requires connectivity; it deliberately fails closed offline.

The new parent field is `medicationScheduleRevision`. All add/edit/delete paths in this patched repository participate. Older app versions, other tools, direct administrative writes, or separately implemented clients do not participate automatically. This is not a database-wide security-rule guarantee. Your existing Firestore permissions must permit the patient's revision update; a permission error prevents the entire transaction rather than approving the medication anyway.

No new collections, database migrations, security-rule changes, or backend services are installed. Existing valid provider medication dates remain valid. For legacy undated records, checks use the patient's existing start date when available, matching the provider calendar; do not interpret a fallback as newly verified historical information. Records with unresolvable dates must be reviewed explicitly. Invalid device imports are rejected before creating a new imported patient/program.

Existing demo records are not modified. A newly seeded demo patient starts with no medication entries instead of overlapping multi-drug examples. Existing old overlapping or non-Methadone examples can prevent new saves/sends until you deliberately correct/remove the test entries. Do not silently relabel another drug to Methadone or reuse its dose.

The local patient setup receives and checks the medication list supplied by the current screen. This patch does not add new patient-account cloud persistence or recover schedules that the baseline never loaded. The provider workflow is the persistent Firestore-backed workflow.

## Validation actually performed

The generated patch was checked forward and in reverse on source-excerpt fixtures, including a second layout with shifted line offsets. Applied output matched the intended replacements and passed Git's whitespace check. The full original provider program editor was recovered and its blob hash verified against GitHub before its two edits were checked.

A complete application checkout was not available in the build environment. Other file checks used retrieved source excerpts, not a Flutter build. `APPLY.ps1` performs the necessary complete-checkout dry run on your machine before changing files. The Dart tests, Flutter analyzer/build, Firebase transactions, Android lifecycle, and device hardware behavior still require running locally. See VALIDATION.txt.

## Source references

Baseline: https://github.com/NodeMedDisp/Node_App/tree/9e877a10436e65aec340622f6bff610e9e0faca1

Flutter GlobalKey: https://api.flutter.dev/flutter/widgets/GlobalKey-class.html

Flutter hot reload/restart: https://docs.flutter.dev/tools/hot-reload

Dart Map.from: https://api.dart.dev/dart-core/Map/Map.from.html

Firestore transactions: https://firebase.google.com/docs/firestore/manage-data/transactions
