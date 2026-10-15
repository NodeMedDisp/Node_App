import 'package:flutter_test/flutter_test.dart';
import '../lib/Bluetooth/recovery_program_file_formatter.dart';
import '../lib/models/counseling_question.dart';
import '../lib/models/medication.dart';
import '../lib/models/medication_schedule.dart';
import '../lib/models/prompt_schedule.dart';

Medication medication({
  required String name,
  required DateTime start,
  int days = 3,
  String time = '8:00 AM',
}) =>
    Medication(
      id: name,
      name: name,
      dose: '1 test unit',
      frequency: 'Once daily',
      times: time,
      numDays: days,
      startDate: start,
    );

CounselingQuestion prompt({
  required String text,
  required DateTime start,
  int days = 3,
}) =>
    CounselingQuestion(
      id: text,
      prompt: text,
      resReq: 'Yes',
      options: const ['Yes', 'No'],
      numberOfDays: days,
      startDate: start,
    );

void main() {
  final now = DateTime(2026, 10, 7, 12);

  test('device transfer selects the earliest future medication', () {
    final sent = MedicationSchedule.forDeviceTransfer([
      medication(name: 'Expired', start: DateTime(2026, 10, 1), days: 2),
      medication(name: 'Future', start: DateTime(2026, 10, 10), days: 3),
      medication(name: 'Later', start: DateTime(2026, 10, 20), days: 5),
    ], now: now);

    expect(sent, hasLength(1));
    expect(sent.single.name, 'Future');
    expect(sent.single.startDate, DateTime(2026, 10, 10));
    expect(sent.single.numDays, 3);
  });

  test('active medication still sends only its remaining days', () {
    final sent = MedicationSchedule.forDeviceTransfer([
      medication(name: 'Active', start: DateTime(2026, 10, 6), days: 3),
      medication(name: 'Future', start: DateTime(2026, 10, 20), days: 3),
    ], now: now);

    expect(sent, hasLength(1));
    expect(sent.single.name, 'Active');
    expect(sent.single.startDate, DateTime(2026, 10, 7));
    expect(sent.single.numDays, 2);
  });

  test('device prompt transfer keeps future prompts and clips active prompts', () {
    final sent = PromptSchedule.forDeviceTransfer([
      prompt(text: 'Expired', start: DateTime(2026, 10, 1), days: 2),
      prompt(text: 'Active', start: DateTime(2026, 10, 6), days: 3),
      prompt(text: 'Future', start: DateTime(2026, 10, 10), days: 2),
    ], now: now);

    expect(sent.map((value) => value.prompt), ['Active', 'Future']);
    expect(sent[0].startDate, DateTime(2026, 10, 7));
    expect(sent[0].numberOfDays, 2);
    expect(sent[1].startDate, DateTime(2026, 10, 10));
    expect(sent[1].numberOfDays, 2);
  });

  test('formatter sends explicit future start dates to NODE', () {
    final wire = RecoveryProgramFileFormatter.build(
      medications: [
        medication(name: 'Future', start: DateTime(2026, 10, 10), days: 3),
      ],
      prompts: [
        prompt(text: 'Future prompt', start: DateTime(2026, 10, 11), days: 2),
      ],
      generatedAt: now,
    );

    expect(wire, contains('Medication: Future\n'));
    expect(wire, contains('Start Date: 2026-10-10\n'));
    expect(wire, contains('Prompt: Future prompt\n'));
    expect(wire, contains('Start Date: 2026-10-11\n'));
    expect(wire, contains('Days: 1 to 3\n'));
    expect(wire, contains('Days: 1 to 2\n'));
  });
}
