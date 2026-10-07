# Validation and device acceptance checks

## What was actually checked during preparation

Seven complete original files were reconstructed from the pinned GitHub source
and checked byte-for-byte against their Git blob SHA values. Three other files
(calendar, provider sender, and Firestore repository) were changed using exact
fetched source excerpts, not replacement files.

The combined patch passed git apply --check, apply, git diff --check, reverse
--check, and reverse in an isolated Git fixture. The seven complete files were
compared byte-for-byte with their edited versions. The three small integration
patches were exercised against isolated source-excerpt fixtures with untouched
placeholder gaps; this is NOT a full repository build or a full-checkout test.
No placeholder gaps are shipped in the patch.

The apply script checks all TEN original complete-file hashes on your real
checkout and performs a final git apply --check there before changing files.

The container has no Dart/Flutter SDK and no connected Android/NODE device.
The 26 supplied Dart/Flutter tests, flutter analyze, Android build, Firestore
integration, and real Bluetooth/dispensing tests HAVE NOT BEEN RUN here. Native
PowerShell execution is also not available; the PowerShell script was reviewed.
The Bash wrapper passed isolated dry-run/application/refusal checks; its private
fixtures substituted the three excerpt hashes. See VALIDATION.txt.
Use the commands below before relying on this patch.

## Automated tests supplied

```sh
flutter pub get
flutter test test/node_med_prompt_schedule_test.dart test/node_prompt_editor_test.dart
flutter analyze
```

19 schedule/formatter tests cover arbitrary names (including Unicode), unchanged
name/dose on the wire, blank/control-character rejection, overlapping/nonoverlapping
dates, editing exclusion, once-daily enforcement, remaining days, future-medication
guard, inclusive prompt dates, leap/DST dates, invalid duration, legacy fallback,
JSON/Timestamp reading, reward preservation, active/future/expired prompts, empty
program rejection, and protocol-field injection checks.

7 widget tests cover changing text/duration, selecting a start date, rejecting
zero days, preserving legacy number and yes_no encodings, preserving custom
options/rewards, and cancelling without changing the original record.

Existing unrelated analyzer issues may still be present. No claim is made that
this patch repairs the entire repository or the previous framework assertion.

## Manual app / Firestore checks

Use a test patient, not an active clinical program.

1. Add Example A with a supplied test dose/unit, one time, and a date range.
   Confirm that the name is editable and does not become Methadone after saving.
2. Try Example B on any overlapping date, even at another time. Expect a clear
   overlap error. Confirm Example A is unchanged. Try Example B starting the day
   after Example A ends; the save should succeed.
3. Edit Example A's own name/time/duration within nonoverlapping dates. It should
   update the same document ID, not add a second medication.
4. Add a prompt beginning on a future date for 3 days. Check exactly those 3 days
   on the calendar, including the start and end but not adjacent days.
5. Open Counseling -> pencil, change prompt text, dates, duration, response type,
   and rewards. Save and reopen. Confirm the same Firestore ID and only one record.
   Log out and back in; confirm the edit persists.
6. Edit an old prompt without changing its response/rewards; confirm they survive.
   Test a legacy number/yes_no prompt. Cancel another edit and confirm no changes.
7. Try zero/blank duration. Expect an error. Try repeated Save taps. Confirm one
   write/record. Open an edit, change the selected patient elsewhere, and confirm
   the form refuses to save to that different patient.
8. Delete a test prompt from another client while its edit form is open. Saving
   the stale form should fail and must not recreate the deleted document.

## Bluetooth bench checks (empty/test device)

1. Use a test program with one medication active TODAY, no pending future
   medication blocks, and no overlap. Choose a non-Methadone name and known-safe
   dummy values. Verify the Methadone-only error no longer occurs.
2. Compare the debug text labelled PROGRAM SENT TO NODE with the saved program.
   Medication name/dose must be unchanged. Confirm the device actually receives
   and displays the intended settings; a successful write alone is not proof of
   correct dispensing or device acknowledgement.
3. For a 3-day test course starting yesterday, confirm Days: 1 to 2 is sent. Do the
   same for an active prompt. Future and expired prompts must not appear in the
   transmitted file. Their app/Firestore records should remain intact.
4. Confirm a future medication course still produces the existing compatibility
   guard instead of starting early. Do not bypass this guard without matching
   firmware support and a separate validation.
5. On a future prompt's start date, reconnect and reprogram. Confirm the prompt
   appears then and that its completion date is not extended on later reconnects.
6. Verify device-specific name/character limits, units, stored schedules, alarm
   behavior, and prompt end-day behavior against the actually flashed firmware.
   This app-only patch does not establish hardware compatibility for arbitrary
   medication formulations or clinical use.
