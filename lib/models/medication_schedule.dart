import 'medication.dart';

/// A user-facing scheduling error, not a partially completed save.
class MedicationScheduleException implements Exception {
  final String message;
  const MedicationScheduleException(this.message);
  @override
  String toString() => message;
}

/// NODE's current app rule: Methadone, one event per calendar day.
/// UTC is used only for date-only arithmetic, not to change the dose's local time.
class MedicationSchedule {
  const MedicationSchedule._();

  static DateTime day(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);

  static String dateLabel(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static DateTime start(Medication medication, {DateTime? fallbackStartDate}) {
    final value = medication.startDate ?? fallbackStartDate;
    if (value == null) {
      throw MedicationScheduleException(
        'The existing entry "${medication.name}" has no start date. '
        'Set its start date before adding or sending another entry.',
      );
    }
    return day(value);
  }

  static DateTime end(Medication medication, {DateTime? fallbackStartDate}) {
    if (medication.numDays <= 0) {
      throw MedicationScheduleException(
        'The entry "${medication.name}" needs a positive number of days.',
      );
    }
    final first = start(medication, fallbackStartDate: fallbackStartDate);
    try {
      return DateTime.utc(first.year, first.month, first.day + medication.numDays - 1);
    } on ArgumentError {
      throw const MedicationScheduleException('The number of days is too large.');
    }
  }

  /// Accepts one 24-hour or English AM/PM time, never a list of times.
  static int? minutes(String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})\s*([aApP][mM])?$')
        .firstMatch(value.trim());
    if (match == null) return null;
    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final suffix = match.group(3)?.toUpperCase();
    if (minute > 59) return null;
    if (suffix != null) {
      if (hour < 1 || hour > 12) return null;
      hour = hour % 12 + (suffix == 'PM' ? 12 : 0);
    } else if (hour > 23) {
      return null;
    }
    return hour * 60 + minute;
  }

  /// A stable wire representation regardless of the phone's language settings.
  static String clock(int hour, int minute) =>
      '${hour % 12 == 0 ? 12 : hour % 12}:'
      '${minute.toString().padLeft(2, '0')} ${hour < 12 ? 'AM' : 'PM'}';

  static void validateEntry(Medication medication) {
    if (medication.name.trim().toLowerCase() != 'methadone') {
      throw const MedicationScheduleException(
        'Only Methadone is supported by this program. '
        'Existing entries are not automatically renamed or converted.',
      );
    }
    if (medication.dose.trim().isEmpty ||
        medication.dose.contains('\n') || medication.dose.contains('\r')) {
      throw const MedicationScheduleException('Enter a medication dose on one line.');
    }
    final frequency = medication.frequency.trim().toLowerCase();
    if ((frequency != 'once daily' && frequency != 'daily') ||
        minutes(medication.times) == null) {
      throw const MedicationScheduleException(
        'Choose exactly one medication time per day. Multiple daily times are not allowed.',
      );
    }
    end(medication); // Also validates the start date and duration.
  }

  /// [others] must exclude the record currently being edited.
  /// On create, it must contain every already saved/scheduled entry.
  static void validateCandidate(
    Medication candidate,
    Iterable<Medication> others, {
    DateTime? fallbackStartDate,
  }) {
    validateEntry(candidate);
    final first = start(candidate);
    final last = end(candidate);
    for (final other in others) {
      final otherFirst = start(other, fallbackStartDate: fallbackStartDate);
      final otherLast = end(other, fallbackStartDate: fallbackStartDate);
      if (!last.isBefore(otherFirst) && !first.isAfter(otherLast)) {
        final collision = first.isAfter(otherFirst) ? first : otherFirst;
        throw MedicationScheduleException(
          'A medication event already exists on ${dateLabel(collision)} '
          '(${other.name}, ${other.times}). Only one medication event per day is allowed. '
          'The existing entry was not changed.',
        );
      }
    }
  }

  static void validateProgram(
    List<Medication> medications, {
    DateTime? fallbackStartDate,
  }) {
    final checked = <Medication>[];
    for (final medication in medications) {
      final dated = medication.startDate != null
          ? medication
          : medication.copyWith(startDate: fallbackStartDate);
      validateCandidate(dated, checked, fallbackStartDate: fallbackStartDate);
      checked.add(dated);
    }
  }

  static bool isActive(
    Medication medication,
    DateTime onDay, {
    DateTime? fallbackStartDate,
  }) {
    if (medication.numDays <= 0 ||
        (medication.startDate == null && fallbackStartDate == null)) return false;
    final today = day(onDay);
    return !today.isBefore(start(medication, fallbackStartDate: fallbackStartDate)) &&
        !today.isAfter(end(medication, fallbackStartDate: fallbackStartDate));
  }

  /// Compatibility guard, NOT a firmware upgrade.
  /// The existing text protocol has no absolute medication start date.
  /// Never silently send a future entry as though it starts today.
  static List<Medication> forLegacyTransfer(
    List<Medication> medications, {
    required DateTime now,
    DateTime? fallbackStartDate,
  }) {
    validateProgram(medications, fallbackStartDate: fallbackStartDate);
    final today = day(now);
    final pending = medications.where((medication) =>
        !end(medication, fallbackStartDate: fallbackStartDate).isBefore(today)).toList();
    if (pending.any((medication) =>
        start(medication, fallbackStartDate: fallbackStartDate).isAfter(today))) {
      throw const MedicationScheduleException(
        'Nothing sent. Future doses can be saved in the app, but the current NODE '
        'transfer format does not include a start date. Matching device firmware '
        'must be verified before sending a future or multi-period schedule.',
      );
    }
    if (pending.length > 1) {
      throw const MedicationScheduleException(
        'Nothing sent. The current NODE transfer supports only one active medication block.',
      );
    }
    return pending.map((medication) => medication.copyWith(
      // Do not restart a partly completed course with its original full duration.
      numDays: end(medication, fallbackStartDate: fallbackStartDate)
          .difference(today).inDays + 1,
      startDate: DateTime(now.year, now.month, now.day),
      name: 'Methadone',
      frequency: 'Once daily',
      times: clock(minutes(medication.times)! ~/ 60, minutes(medication.times)! % 60),
    )).toList();
  }
}
