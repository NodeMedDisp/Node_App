# NODE app: medication names and editable prompt schedules

APP repository: NodeMedDisp/Node_App, branch jv_working.
Prepared against commit 25419d0fec037f66a78e538fc512254830478ded
("Limiting to one medication", October 6, 2026).

## What this patch changes

The Methadone restriction existed both in scheduling validation and in the
Bluetooth preparation code. This patch removes both. New and existing medication
names are editable and retained; they are never automatically replaced with
Methadone. The dose field accepts text and is labelled "Dose (include unit)".
No dose or unit conversion is performed and no new default dose is supplied.
Empty names and protocol-breaking control characters are still rejected.

The existing one-MEDICATION-EVENT-per-calendar-day rule is retained. This is
intentionally stricter than allowing several events for the same drug. A second
entry overlapping any day is rejected even if it uses the same name or a
different time. Different medications on nonoverlapping dates can be saved.
The existing Firestore medication transaction/overlap checks remain in place;
this does not add server enforcement for older apps or direct database writes.

Open a patient -> Edit Full Program -> Counseling. Tap the prompt or its pencil
icon to edit its text, response settings, start date, number of days, and rewards.
Save Changes updates that prompt's existing ID instead of adding another record.
The original response options/encoding and reward thresholds are retained unless
explicitly changed. Legacy yes_no, number, and custom-response entries can be
opened. Local drafts also have tap-to-edit. Cancel/back leaves the original alone.

Prompts have independent start dates and positive duration. Start and end dates
are inclusive: October 10 plus 3 days means October 10, 11, and 12. The form shows
the date range. Calendar filtering uses date-only arithmetic across daylight-saving
changes. Existing prompts without their own start date use the patient's existing
start date when available. Firestore Timestamp dates are recognized.

Prompt saving validates fields and uses update rather than upsert, so an entry
removed while its edit form was open is not recreated. Duplicate save taps are
blocked, and a changed selected patient prevents saving to the wrong patient.
No stored medications, prompts, or recovery history are automatically migrated,
renamed, or deleted. Editing a prompt does not rewrite old recorded responses.

## Important device limitation

THIS IS AN APP PATCH, NOT A FIRMWARE UPGRADE.

The current shared text formatter does not send an absolute start date. The
currently flashed firmware could not be verified. Therefore:

- An active medication can be prepared with any name, without the Methadone error.
- The existing future-medication/multiple-period transfer guard remains. A pending
  future medication course can still block transmission even when another course
  is active. Do not delete legitimate future prescriptions merely to bypass it.
- Future prompt dates ARE saved and shown in the app. Bluetooth sends only prompts
  active on the programming date and omits future/expired prompts. Reconnect and
  reprogram NODE on a future prompt's start date. Autonomous future starts on the
  physical device are NOT implemented or claimed here.
- Active medications and prompts are sent for their remaining calendar days,
  rather than restarting their original full duration at every connection.
- Changes saved in the app/Firestore do not update a disconnected device.

If a saved medication still has overlapping dates, multiple daily times, no usable
start date, or another validation problem, it remains blocked with the relevant
error. Existing invalid records are not silently corrected or removed.

Accepting arbitrary names/dose text in the app is not a claim that the physical
mechanism or firmware supports every drug, formulation, or dosing unit. Verify
that separately with an empty/test device before actual use. The patch cannot
verify delivery, acknowledgements, dispensing, or future date support on hardware.

## Apply on Windows / VS Code PowerShell

Stop a running Flutter debug session and save your editor files. Open the actual
Node_App repository folder (the folder containing pubspec.yaml). Do not apply this
to Node_device or edit a copy under an old patch folder.

First inspect your work:

```powershell
git status
```

Commit your current changes to a backup branch, or stash them before switching.
Do not use git reset --hard or git clean to make the patch fit. The apply script
refuses tracked changes; untracked files are left alone unless their paths would
collide with a file the patch adds.

```powershell
git switch jv_working
git pull --ff-only origin jv_working
git switch -c fix/medication-names-prompts
```

Extract this ZIP into the repository root. The layout should be:

```text
Node_App/
  pubspec.yaml
  lib/
  node_med_prompt_patch/
    APPLY.ps1
    manifest.json
    app_medication_names_prompt_editing.patch
    ...
```

Check first (this changes no files):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\node_med_prompt_patch\APPLY.ps1 -RepoPath . -CheckOnly
```

Apply:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\node_med_prompt_patch\APPLY.ps1 -RepoPath .
```

ExecutionPolicy Bypass above is scoped to that one PowerShell process. The script
checks the patch checksum, original source hashes, new-file collisions, and
`git apply --check` before applying. It never commits, pushes, resets, installs
dependencies, changes Firebase, or flashes a device. A baseline mismatch means
stop and reconcile the differing file; do not force, use --reject, or paste over it.
A newer branch tip is acceptable only if all affected original files still match.

For macOS/Linux/Git Bash, from the app root:

```sh
sh ./node_med_prompt_patch/APPLY.sh . check
sh ./node_med_prompt_patch/APPLY.sh . apply
```

Manual alternative from a clean matching baseline (do not run after the script):

```powershell
git apply --check .\node_med_prompt_patch\app_medication_names_prompt_editing.patch
git apply .\node_med_prompt_patch\app_medication_names_prompt_editing.patch
```

## Validate and run

```powershell
flutter pub get
flutter test test/node_med_prompt_schedule_test.dart test/node_prompt_editor_test.dart
flutter analyze
flutter run
```

Use a full stop/start, not only hot reload. Uninstalling the app is not required by
this patch and can erase local app data. The targeted tests avoid relying on the
repository's unrelated default widget_test.dart. See TESTING.md for the exact
validation coverage and the checks that still need local execution.

After review and successful tests, stage only the changed files listed in
SOURCE_MAP.md and commit them on the new branch. There is no need to commit the
extracted patch folder. No changes have been pushed to your GitHub repository.

## Undo

Before further edits or formatting, and while the patch is still an uncommitted
isolated change:

```powershell
git apply --reverse --check .\node_med_prompt_patch\app_medication_names_prompt_editing.patch
git apply --reverse .\node_med_prompt_patch\app_medication_names_prompt_editing.patch
```

Run the second command only when the first passes. This removes only the patch's
changes and its newly added files. If the patch has been committed, use git revert
on that dedicated commit after preserving other work. Reversing code does not undo
prompt/medication edits already saved in Firestore or reprogram a physical device.
