import 'counseling_question.dart';
import 'medication_schedule.dart';

/// Date-only prompt scheduling. The start and end dates are both inclusive.
/// This does not claim that unverified firmware supports future start dates.
class PromptSchedule {
  const PromptSchedule._();

  static DateTime start(CounselingQuestion prompt, {DateTime? fallbackStartDate}) {
    final date = prompt.startDate ?? fallbackStartDate;
    if (date == null) {
      throw const MedicationScheduleException('Set the prompt start date.');
    }
    return MedicationSchedule.day(date);
  }

  static DateTime lastDay(DateTime startDate, int numberOfDays) {
    if (numberOfDays <= 0) {
      throw const MedicationScheduleException('Enter a positive number of days.');
    }
    final first = MedicationSchedule.day(startDate);
    // Avoid integer overflow in date construction on all Dart targets.
    final maximum = DateTime.utc(9999, 12, 31).difference(first).inDays + 1;
    if (numberOfDays > maximum) {
      throw const MedicationScheduleException('The prompt duration is too large.');
    }
    return DateTime.utc(first.year, first.month, first.day + numberOfDays - 1);
  }

  static DateTime end(CounselingQuestion prompt, {DateTime? fallbackStartDate}) =>
      lastDay(start(prompt, fallbackStartDate: fallbackStartDate), prompt.numberOfDays);

  static void validateEntry(CounselingQuestion prompt, {DateTime? fallbackStartDate}) {
    final control = RegExp(r'[\x00-\x1F\x7F]');
    void oneLine(String value, String label, {bool mustHaveValue = true}) {
      if ((mustHaveValue && value.trim().isEmpty) || control.hasMatch(value)) {
        throw MedicationScheduleException('$label must be on one line without control characters.');
      }
    }
    oneLine(prompt.prompt, 'The prompt');
    oneLine(prompt.resReq, 'The response type');
    for (final option in prompt.options) {
      oneLine(option, 'Each response option');
    }
    if (prompt.streakEnabled) {
      oneLine(prompt.streakTitle, 'The streak title');
      oneLine(prompt.streakThreshold, 'The streak threshold', mustHaveValue: false);
    }
    if (prompt.tokenEnabled) {
      oneLine(prompt.tokenTitle, 'The token title');
      oneLine(prompt.tokenThreshold, 'The token threshold', mustHaveValue: false);
      if (prompt.tokenQuantity <= 0) {
        throw const MedicationScheduleException('Enter a token quantity greater than zero.');
      }
    }
    end(prompt, fallbackStartDate: fallbackStartDate);
  }

  static bool isActive(CounselingQuestion prompt, DateTime onDay, {DateTime? fallbackStartDate}) {
    if (prompt.numberOfDays <= 0 || (prompt.startDate == null && fallbackStartDate == null)) {
      return false;
    }
    try {
      final date = MedicationSchedule.day(onDay);
      return !date.isBefore(start(prompt, fallbackStartDate: fallbackStartDate)) &&
          !date.isAfter(end(prompt, fallbackStartDate: fallbackStartDate));
    } on MedicationScheduleException {
      return false;
    }
  }

  static String dateRangeLabel(DateTime startDate, int? numberOfDays) {
    if (numberOfDays == null || numberOfDays <= 0) return 'Enter a positive duration. Includes the start date.';
    try {
      return '${MedicationSchedule.dateLabel(startDate)} to '
          '${MedicationSchedule.dateLabel(lastDay(startDate, numberOfDays))} (inclusive)';
    } on MedicationScheduleException catch (error) {
      return error.message;
    }
  }

  static String rangeLabel(CounselingQuestion prompt, {DateTime? fallbackStartDate}) {
    final first = prompt.startDate ?? fallbackStartDate;
    if (first == null) return 'Start date not set | ${prompt.numberOfDays} days';
    return '${dateRangeLabel(first, prompt.numberOfDays)} | ${prompt.numberOfDays} days';
  }

  /// The legacy format is relative to the time of programming, not the saved
  /// app start date. Omit future/expired prompts and send only remaining days.
  /// The originals (including IDs and rewards) are not mutated.
  static List<CounselingQuestion> forLegacyTransfer(
    List<CounselingQuestion> prompts, {
    required DateTime now,
    DateTime? fallbackStartDate,
  }) {
    final today = MedicationSchedule.day(now);
    final result = <CounselingQuestion>[];
    for (final prompt in prompts) {
      final dated = prompt.startDate != null
          ? prompt : prompt.copyWith(startDate: fallbackStartDate ?? now);
      validateEntry(dated);
      if (!isActive(dated, today)) continue;
      result.add(dated.copyWith(
        startDate: DateTime(now.year, now.month, now.day),
        numberOfDays: end(dated).difference(today).inDays + 1,
      ));
    }
    return result;
  }
}
