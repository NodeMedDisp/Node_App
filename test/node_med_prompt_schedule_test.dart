import 'package:flutter_test/flutter_test.dart';
import '../lib/models/medication.dart';
import '../lib/models/medication_schedule.dart';
import '../lib/models/counseling_question.dart';
import '../lib/models/prompt_schedule.dart';
import '../lib/Bluetooth/recovery_program_file_formatter.dart';

Medication medication({
  String name = 'Example medication',
  DateTime? start,
  int days = 3,
  String time = '8:00 AM',
}) =>
    Medication(
      id: 'med-a',
      name: name,
      dose: '1 test unit',
      frequency: 'Once daily',
      times: time,
      numDays: days,
      startDate: start ?? DateTime(2026, 10, 6),
      streakEnabled: true,
      streakTitle: 'Medication streak',
    );

CounselingQuestion prompt(
        {DateTime? start, int days = 3, String text = 'Check in'}) =>
    CounselingQuestion(
      id: 'prompt-a',
      prompt: text,
      resReq: 'Yes',
      options: const ['Yes', 'No'],
      numberOfDays: days,
      startDate: start ?? DateTime(2026, 10, 6),
      tokenEnabled: true,
      tokenTitle: 'Check in reward',
      tokenThreshold: 'Yes',
      tokenQuantity: 2,
    );

class TimestampLike {
  final DateTime date;
  TimestampLike(this.date);
  DateTime toDate() => date;
}

void main() {
  final now = DateTime(2026, 10, 7, 12);
  final scheduleError = isA<MedicationScheduleException>();

  test('arbitrary medication names are accepted and kept on the wire', () {
    for (final name in [
      'Example A',
      'Example B / liquid',
      'TEST-123',
      'M\u00e9dicament'
    ]) {
      final value = medication(name: name);
      expect(() => MedicationSchedule.validateEntry(value), returnsNormally);
      final wire = RecoveryProgramFileFormatter.build(
        medications: [value],
        prompts: [],
        generatedAt: now,
      );
      expect(wire, contains('Medication: $name\n'));
      expect(wire, contains('Dose: 1 test unit\n'));
      expect(wire, isNot(contains('Medication: Methadone')));
    }
  });

  test('blank and control-character medication names are rejected', () {
    for (final name in ['', '   ', 'A\nMedication: B', 'A\rB', 'A\u0000B']) {
      expect(() => MedicationSchedule.validateEntry(medication(name: name)),
          throwsA(scheduleError));
    }
  });

  test('different names are allowed on nonoverlapping calendar days', () {
    expect(
        () => MedicationSchedule.validateProgram([
              medication(name: 'A', days: 2),
              medication(name: 'B', start: DateTime(2026, 10, 8), days: 1),
            ]),
        returnsNormally);
  });

  test('same and different names cannot overlap even at different times', () {
    for (final name in ['A', 'B']) {
      expect(
          () => MedicationSchedule.validateProgram([
                medication(name: 'A'),
                medication(
                    name: name, start: DateTime(2026, 10, 8), time: '9:00 PM'),
              ]),
          throwsA(scheduleError));
    }
  });

  test('an edit excludes itself but still checks other medication records', () {
    final changed = medication().copyWith(name: 'Changed');
    expect(() => MedicationSchedule.validateCandidate(changed, []),
        returnsNormally);
    expect(() => MedicationSchedule.validateCandidate(changed, [medication()]),
        throwsA(scheduleError));
  });

  test('multiple times and invalid dose/duration remain rejected', () {
    for (final value in [
      medication(time: '8:00 AM, 8:00 PM'),
      medication().copyWith(frequency: 'Twice daily'),
      medication().copyWith(dose: ''),
      medication(days: 0),
    ]) {
      expect(() => MedicationSchedule.validateEntry(value),
          throwsA(scheduleError));
    }
  });

  test('legacy medication transfer clips days without mutating the record', () {
    final original = medication(name: 'Original Name');
    final sent =
        MedicationSchedule.forLegacyTransfer([original], now: now).single;
    expect(sent.name, original.name);
    expect(sent.dose, original.dose);
    expect(sent.id, original.id);
    expect(sent.streakTitle, original.streakTitle);
    expect(sent.numDays, 2);
    expect(original.numDays, 3);
    expect(original.startDate, DateTime(2026, 10, 6));
  });

  test('future medication is ignored until its scheduled day', () {
    final result = MedicationSchedule.forLegacyTransfer([
      medication(start: DateTime(2026, 10, 10)),
    ], now: now);
    expect(result, isEmpty);
  });

  test('expired historical overlap does not block todays medication', () {
    final result = MedicationSchedule.forLegacyTransfer([
      medication(
        name: 'Old A',
        start: DateTime(2026, 9, 24),
        days: 3,
      ),
      medication(
        name: 'Old B',
        start: DateTime(2026, 9, 24),
        days: 2,
        time: '9:00 AM',
      ),
      medication(
        name: 'Today',
        start: DateTime(2026, 10, 7),
        days: 5,
      ),
    ], now: now);

    expect(result, hasLength(1));
    expect(result.single.name, 'Today');
    expect(result.single.startDate, DateTime(2026, 10, 7));
    expect(result.single.numDays, 5);
  });

  test('future medication does not block an active medication', () {
    final result = MedicationSchedule.forLegacyTransfer([
      medication(
        name: 'Active',
        start: DateTime(2026, 10, 6),
        days: 3,
      ),
      medication(
        name: 'Future',
        start: DateTime(2026, 10, 10),
        days: 3,
      ),
    ], now: now);

    expect(result, hasLength(1));
    expect(result.single.name, 'Active');
    expect(result.single.numDays, 2);
  });

  test('bluetooth keeps a defensive guard against two active medications', () {
    expect(
        () => MedicationSchedule.forLegacyTransfer([
              medication(
                name: 'A',
                start: DateTime(2026, 10, 7),
                days: 2,
              ),
              medication(
                name: 'B',
                start: DateTime(2026, 10, 7),
                days: 2,
                time: '9:00 AM',
              ),
            ], now: now),
        throwsA(scheduleError));
  });

  test('prompt date range is inclusive', () {
    final value = prompt(start: DateTime(2026, 10, 10), days: 3);
    expect(PromptSchedule.isActive(value, DateTime(2026, 10, 9)), isFalse);
    expect(PromptSchedule.isActive(value, DateTime(2026, 10, 10)), isTrue);
    expect(
        PromptSchedule.isActive(value, DateTime(2026, 10, 12, 23, 59)), isTrue);
    expect(PromptSchedule.isActive(value, DateTime(2026, 10, 13)), isFalse);
    expect(
        PromptSchedule.rangeLabel(value), contains('2026-10-10 to 2026-10-12'));
  });

  test('one-day prompt is active only on its start date', () {
    final value = prompt(days: 1);
    expect(PromptSchedule.isActive(value, DateTime(2026, 10, 6)), isTrue);
    expect(PromptSchedule.isActive(value, DateTime(2026, 10, 7)), isFalse);
  });

  test('date-only arithmetic crosses leap days and DST without drifting', () {
    expect(PromptSchedule.lastDay(DateTime(2028, 2, 28), 3),
        DateTime.utc(2028, 3, 1));
    expect(PromptSchedule.lastDay(DateTime(2026, 10, 31), 3),
        DateTime.utc(2026, 11, 2));
    expect(PromptSchedule.lastDay(DateTime(2026, 3, 7), 3),
        DateTime.utc(2026, 3, 9));
  });

  test('invalid prompt durations are rejected instead of overflowing', () {
    for (final days in [0, -1, 1000000000]) {
      expect(() => PromptSchedule.validateEntry(prompt(days: days)),
          throwsA(scheduleError));
      expect(PromptSchedule.isActive(prompt(days: days), now), isFalse);
    }
  });

  test('legacy missing prompt date can use the patient start date', () {
    const value = CounselingQuestion(
      prompt: 'Legacy',
      resReq: 'number',
      options: [],
      numberOfDays: 3,
    );
    expect(PromptSchedule.isActive(value, now), isFalse);
    expect(
        PromptSchedule.isActive(value, now,
            fallbackStartDate: DateTime(2026, 10, 6)),
        isTrue);
  });

  test('prompt serialization preserves dates, IDs, options, and rewards', () {
    final value = prompt();
    final decoded = CounselingQuestion.fromJson(value.toJson(), id: value.id);
    expect(decoded.id, value.id);
    expect(decoded.startDate, value.startDate);
    expect(decoded.numberOfDays, value.numberOfDays);
    expect(decoded.options, value.options);
    expect(decoded.tokenQuantity, value.tokenQuantity);
    expect(decoded.tokenThreshold, value.tokenThreshold);
  });

  test('prompt model reads a Firestore Timestamp-like object', () {
    final date = DateTime(2026, 10, 10);
    final decoded = CounselingQuestion.fromJson({
      ...prompt().toJson(),
      'startDate': TimestampLike(date),
    });
    expect(decoded.startDate, date);
  });

  test('prompt preparation clips remaining days and preserves its original',
      () {
    final original = prompt();
    final sent = PromptSchedule.forLegacyTransfer([original], now: now).single;
    expect(sent.numberOfDays, 2);
    expect(sent.id, original.id);
    expect(sent.tokenThreshold, original.tokenThreshold);
    expect(sent.options, original.options);
    expect(original.numberOfDays, 3);
    expect(original.startDate, DateTime(2026, 10, 6));
  });

  test('formatter omits future and expired prompts and keeps the active one',
      () {
    final wire = RecoveryProgramFileFormatter.build(
      medications: [medication(name: 'A')],
      prompts: [
        prompt(text: 'Active'),
        prompt(text: 'Future', start: DateTime(2026, 10, 10)),
        prompt(text: 'Expired', start: DateTime(2026, 10, 1)),
      ],
      generatedAt: now,
    );
    expect(wire, contains('Prompt: Active\n'));
    expect(wire, isNot(contains('Prompt: Future')));
    expect(wire, isNot(contains('Prompt: Expired')));
    expect(wire, contains('Days: 1 to 2\n'));
    expect(wire, isNot(contains('EOF')));
  });

  test('an empty active program is rejected before Bluetooth transfer', () {
    expect(
        () => RecoveryProgramFileFormatter.build(
              medications: [],
              prompts: [prompt(start: DateTime(2026, 10, 10))],
              generatedAt: now,
            ),
        throwsA(scheduleError));
  });

  test('prompt and reward newlines cannot inject protocol fields', () {
    expect(() => PromptSchedule.validateEntry(prompt(text: 'A\nPrompt: B')),
        throwsA(scheduleError));
    expect(
        () =>
            PromptSchedule.validateEntry(prompt().copyWith(tokenTitle: 'A\nB')),
        throwsA(scheduleError));
  });
}
