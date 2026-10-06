import '../lib/models/medication.dart';
import '../lib/models/medication_schedule.dart';
import '../lib/HomePage/recovery_cache_codec.dart';

// Synthetic test data only. No dose here is a prescribing recommendation.
Medication med(DateTime start, int days, {
  String? id,
  String time = '8:00 AM',
  String name = 'Methadone',
  String frequency = 'Once daily',
}) => Medication(
  id: id, name: name, dose: 'test-dose', frequency: frequency,
  times: time, numDays: days, startDate: start,
);

void expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}

void rejects(void Function() operation) {
  try {
    operation();
  } on MedicationScheduleException {
    return;
  }
  throw StateError('Expected MedicationScheduleException, but the operation was accepted.');
}

void main() {
  var passed = 0;
  void test(String name, void Function() body) {
    body();
    passed++;
    print('PASS: $name');
  }
  final first = med(DateTime(2026, 9, 28), 5, id: 'course-a');
  test('same calendar day rejects a different time', () {
    rejects(() => MedicationSchedule.validateCandidate(
      med(DateTime(2026, 9, 28), 1, time: '9:00 PM'), [first],
    ));
  });
  test('final day is inclusive', () {
    expect(MedicationSchedule.dateLabel(MedicationSchedule.end(first)) == '2026-10-02', 'Wrong inclusive end.');
    rejects(() => MedicationSchedule.validateCandidate(med(DateTime(2026, 10, 2), 1), [first]));
  });
  test('the following day is allowed', () {
    MedicationSchedule.validateCandidate(med(DateTime(2026, 10, 3), 4), [first]);
  });
  test('an enclosing range conflicts', () {
    rejects(() => MedicationSchedule.validateCandidate(med(DateTime(2026, 9, 1), 40), [first]));
  });
  test('an enclosed range conflicts', () {
    rejects(() => MedicationSchedule.validateCandidate(med(DateTime(2026, 9, 29), 2), [first]));
  });
  test('date comparison ignores hour of day', () {
    rejects(() => MedicationSchedule.validateCandidate(med(DateTime(2026, 9, 28, 23, 59), 1), [first]));
  });
  test('editing excludes only the entry being edited', () {
    final second = med(DateTime(2026, 10, 3), 2, id: 'course-b');
    MedicationSchedule.validateCandidate(first.copyWith(times: '10:00 AM'), [second]);
    rejects(() => MedicationSchedule.validateCandidate(first.copyWith(numDays: 6), [second]));
  });
  test('future plans are accepted in the app', () {
    MedicationSchedule.validateEntry(med(DateTime(2027, 1, 1), 3));
  });
  test('one day starts and ends on the same date', () {
    final entry = med(DateTime(2026, 10, 3), 1);
    expect(MedicationSchedule.start(entry) == MedicationSchedule.end(entry), 'One-day range incorrect.');
  });
  test('nonpositive durations are rejected', () {
    rejects(() => MedicationSchedule.validateEntry(med(DateTime(2026, 9, 28), 0)));
    rejects(() => MedicationSchedule.validateEntry(med(DateTime(2026, 9, 28), -2)));
  });
  test('multiple times and multiple-dose frequencies are rejected', () {
    rejects(() => MedicationSchedule.validateEntry(first.copyWith(times: '8:00 AM, 8:00 PM')));
    rejects(() => MedicationSchedule.validateEntry(first.copyWith(frequency: 'Twice daily')));
  });
  test('another drug is rejected, not renamed', () {
    final original = first.copyWith(name: 'Another medication');
    rejects(() => MedicationSchedule.validateEntry(original));
    expect(original.name == 'Another medication', 'Original was modified.');
  });
  test('legacy missing dates fail closed without a supplied fallback', () {
    const legacy = Medication(name: 'Methadone', dose: 'test-dose', frequency: 'Daily', times: '08:00', numDays: 5);
    rejects(() => MedicationSchedule.validateProgram([legacy]));
    MedicationSchedule.validateProgram([legacy], fallbackStartDate: DateTime(2026, 9, 28));
    rejects(() => MedicationSchedule.validateCandidate(
      med(DateTime(2026, 10, 2), 1), [legacy], fallbackStartDate: DateTime(2026, 9, 28),
    ));
  });
  test('leap-year boundary', () {
    final entry = med(DateTime(2028, 2, 28), 3);
    expect(MedicationSchedule.dateLabel(MedicationSchedule.end(entry)) == '2028-03-01', 'Leap day lost.');
  });
  test('calendar date arithmetic across a daylight-saving boundary', () {
    final entry = med(DateTime(2026, 10, 31), 3);
    expect(MedicationSchedule.dateLabel(MedicationSchedule.end(entry)) == '2026-11-02', 'Calendar-day arithmetic incorrect.');
    expect(MedicationSchedule.isActive(entry, DateTime(2026, 11, 2)), 'Final day not active.');
    expect(!MedicationSchedule.isActive(entry, DateTime(2026, 11, 3)), 'An extra day was added.');
  });
  test('12-hour and 24-hour time parsing', () {
    expect(MedicationSchedule.minutes('12:00 AM') == 0, 'Midnight incorrect.');
    expect(MedicationSchedule.minutes('12:00 PM') == 720, 'Noon incorrect.');
    expect(MedicationSchedule.minutes('23:59') == 1439, '24-hour time incorrect.');
    expect(MedicationSchedule.minutes('24:00') == null, 'Invalid hour accepted.');
    expect(MedicationSchedule.minutes('8:60 AM') == null, 'Invalid minute accepted.');
    expect(MedicationSchedule.clock(17, 5) == '5:05 PM', 'Canonical time incorrect.');
  });
  test('JSON and editing preserve date, identity and rewards', () {
    final original = first.copyWith(streakEnabled: true, streakTitle: 'Test reward', tokenEnabled: true, tokenQuantity: 2);
    final restored = Medication.fromJson(original.toJson(), id: original.id);
    final edited = restored.copyWith(times: '9:00 AM');
    expect(edited.startDate == first.startDate, 'Start date lost.');
    expect(edited.id == 'course-a', 'Document ID lost.');
    expect(edited.streakTitle == 'Test reward' && edited.tokenQuantity == 2, 'Rewards lost.');
  });
  test('Hive dynamic maps become String-keyed maps without data deletion', () {
    final saved = <dynamic, dynamic>{
      '2026-09-28T00:00:00.000': <dynamic, dynamic>{
        'progress': <dynamic>[
          <dynamic, dynamic>{'type': 'medication', 'time': '8:00 AM'},
          <dynamic, dynamic>{'type': 'prompt', 'question': 'Test question', 'response': 'Yes'},
        ],
      },
    };
    final decoded = RecoveryCacheCodec.decode(saved);
    final entries = decoded[DateTime(2026, 9, 28)]!;
    expect(entries.length == 2 && entries.first['type'] == 'medication', 'History changed.');
    entries.first['time'] = 'Changed in memory';
    final original = ((saved.values.first as Map)['progress'] as List).first as Map;
    expect(original['time'] == '8:00 AM', 'Persisted input map was modified.');
  });
  test('unreadable cache items are skipped without clearing the input', () {
    var warnings = 0;
    final saved = <dynamic, dynamic>{
      'not-a-date': {'progress': []},
      '2026-09-28': {'progress': [42, <dynamic, dynamic>{7: 'not a string key'}, {'type': 'medication'}]},
    };
    final decoded = RecoveryCacheCodec.decode(saved, onWarning: (_) => warnings++);
    expect(warnings == 3 && decoded[DateTime(2026, 9, 28)]!.length == 1, 'Unexpected cache result.');
    expect(saved.length == 2 && (saved['2026-09-28']['progress'] as List).length == 3, 'Input records were deleted.');
  });
  test('future legacy transfer is blocked rather than starting early', () {
    rejects(() => MedicationSchedule.forLegacyTransfer([first], now: DateTime(2026, 9, 27)));
  });
  test('a later saved course is not silently omitted from a transfer', () {
    rejects(() => MedicationSchedule.forLegacyTransfer(
      [first, med(DateTime(2026, 10, 3), 3)], now: DateTime(2026, 9, 30),
    ));
  });
  test('a current course uses only its remaining calendar days', () {
    final transferred = MedicationSchedule.forLegacyTransfer([first], now: DateTime(2026, 9, 30));
    expect(transferred.single.numDays == 3, 'Course was incorrectly restarted.');
    expect(first.numDays == 5 && first.startDate == DateTime(2026, 9, 28), 'Saved original changed.');
  });
  test('expired courses are not rearmed', () {
    expect(MedicationSchedule.forLegacyTransfer([first], now: DateTime(2026, 10, 3)).isEmpty, 'Expired course sent again.');
  });
  print('PASS: all $passed daily-schedule/cache regression checks.');
}
