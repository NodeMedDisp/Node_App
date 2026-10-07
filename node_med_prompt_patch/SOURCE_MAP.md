# Changed files and locations

All paths refer to the APP repository, not the device repository.
The patch contains exact insertions/replacements; do not paste them again manually.

| File | Location and change |
| --- | --- |
| `lib/models/medication_schedule.dart` | `validateEntry`: accept any nonempty single-line name. `forLegacyTransfer`: preserve the actual name. Existing overlap, once-daily and future-firmware guards stay. |
| `lib/LoginComp/core/widgets/MedicationEntryPage.dart` | `initState` and medication-name TextField: remove default/readonly restriction. Unit-neutral dose label. |
| `lib/GetStarted/enter_medication_data.dart` | Name controller, reset, and name/dose TextFields: editable name; dose text with explicit unit rather than mg-only. |
| `lib/GetStarted/enter_counseling_data.dart` | Constructor and `initState`: initialPrompt/start date/edit-mode state. `_addPrompt`: update existing ID or create; patient/save guards. Form: date picker, duration/end-date preview, editable drafts and existing responses/rewards. |
| `lib/GetStarted/provider_program_editor_screen.dart` | `_PromptList`: edit icon and row tap, dates, duration, error handling. |
| `lib/models/counseling_question.dart` | `_readDate`: read Firestore Timestamp as well as ISO dates. |
| `lib/models/prompt_schedule.dart` (new) | Shared inclusive date-only validation, activity filtering, and remaining-day preparation. |
| `lib/HomePage/calendar_widg.dart` | Import and `_getPromptsForDay`: use shared date-only helper. |
| `lib/GetStarted/provider_main_screen.dart` | Import, `_isPromptActiveOnDate`, formatter timestamp, and success message: consistent date handling and future-prompt notice. |
| `lib/Bluetooth/recovery_program_file_formatter.dart` | `build`: filter/clip prompts, retain actual medication names through the helper, reject empty active programs. |
| `lib/LoginComp/data/firestore_provider_repository.dart` | Prompt add/update: validate dates/fields. Update uses `update`, not upsert, so a deleted record is not recreated. Medication transaction logic is unchanged. |
| `test/node_med_prompt_schedule_test.dart` (new) | 19 model/schedule/formatter regression tests. |
| `test/node_prompt_editor_test.dart` (new) | 7 edit-form widget tests. |

Base commit: `25419d0fec037f66a78e538fc512254830478ded`.
No dependencies, Firebase rules, Android setup, device firmware, or historical patch folders are changed.
