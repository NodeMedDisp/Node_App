import 'medication.dart';

/// A user-facing scheduling error, not a partially completed save.
class MedicationScheduleException implements Exception {
  final String message;
  const MedicationScheduleException(this.message);
  @override
  String toString() => message;
}

/// Any medication name/type; only one medication event per calendar day.
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
      return DateTime.utc(
          first.year, first.month, first.day + medication.numDays - 1);
    } on ArgumentError {
      throw const MedicationScheduleException(
          'The number of days is too large.');
    }
  }

  /// Accepts one 24-hour or English AM/PM time, never a list of times.
  static int? minutes(String value) {
    final match =
        RegExp(r'^(\d{1,2}):(\d{2})\s*([aApP][mM])?$').firstMatch(value.trim());
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
    if (medication.name.trim().isEmpty ||
        RegExp(r'[\x00-\x1F\x7F]').hasMatch(medication.name)) {
      throw const MedicationScheduleException(
        'Enter a medication name on one line, without control characters.',
      );
    }
    if (medication.dose.trim().isEmpty ||
        medication.dose.contains('\n') ||
        medication.dose.contains('\r')) {
      throw const MedicationScheduleException(
          'Enter a medication dose on one line.');
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
        (medication.startDate == null && fallbackStartDate == null))
      return false;
    final today = day(onDay);
    return !today.isBefore(
            start(medication, fallbackStartDate: fallbackStartDate)) &&
        !today.isAfter(end(medication, fallbackStartDate: fallbackStartDate));
  }

  /// Build the medication portion of a legacy NODE transfer for [now].
  ///
  /// Schedule overlap enforcement happens when a medication is saved or edited.
  /// Bluetooth should consume that already-validated schedule rather than reject a
  /// transfer because of expired or future records that are not active today.
  static List<Medication> forLegacyTransfer(
    List<Medication> medications, {
    required DateTime now,
    DateTime? fallbackStartDate,
  }) {
    final today = day(now);
    final activeToday = medications
        .where((medication) => isActive(
              medication,
              today,
              fallbackStartDate: fallbackStartDate,
            ))
        .toList();

    // Defensive only: save/update validation should prevent this. Keep the guard
    // so corrupted or legacy data can never send two medications on one day.
    if (activeToday.length > 1) {
      throw MedicationScheduleException(
        'More than one medication is scheduled for ${dateLabel(today)}. '
        'Only one medication is allowed per day. Nothing was sent to NODE.',
      );
    }

    if (activeToday.isEmpty) return const [];

    final medication = activeToday.single;
    final dated = medication.startDate != null
        ? medication
        : medication.copyWith(startDate: fallbackStartDate);

    // Validate the record we are actually about to transmit, but do not re-check
    // historical or future schedule overlaps during Bluetooth programming.
    validateEntry(dated);

    return [
      medication.copyWith(
        // Do not restart a partly completed course with its original full duration.
        numDays: end(medication, fallbackStartDate: fallbackStartDate)
                .difference(today)
                .inDays +
            1,
        startDate: DateTime(now.year, now.month, now.day),
        // Keep the saved name/type. Never substitute a different medication.
        name: medication.name,
        frequency: 'Once daily',
        times: clock(
          minutes(medication.times)! ~/ 60,
          minutes(medication.times)! % 60,
        ),
      ),
    ];
  }

  /// Build the single prescription that NODE can store.
  ///
  /// If a medication is active today, send only its remaining days beginning
  /// today. Otherwise send the earliest future medication with its saved start
  /// date and full duration. Expired entries are ignored.
  static List<Medication> forDeviceTransfer(
    List<Medication> medications, {
    required DateTime now,
    DateTime? fallbackStartDate,
  }) {
    final active = forLegacyTransfer(
      medications,
      now: now,
      fallbackStartDate: fallbackStartDate,
    );
    if (active.isNotEmpty) return active;

    final today = day(now);
    final future = <Medication>[];

    for (final medication in medications) {
      final dated = medication.startDate != null
          ? medication
          : medication.copyWith(startDate: fallbackStartDate);

      // Legacy entries with no usable date cannot be scheduled in the future.
      if (dated.startDate == null) continue;

      final first = start(dated);
      if (!first.isAfter(today)) continue;

      validateEntry(dated);
      future.add(dated);
    }

    if (future.isEmpty) return const [];

    future.sort((a, b) => start(a).compareTo(start(b)));
    final medication = future.first;
    final first = start(medication);
    final timeMinutes = minutes(medication.times)!;

    return [
      medication.copyWith(
        startDate: DateTime(first.year, first.month, first.day),
        name: medication.name,
        frequency: 'Once daily',
        times: clock(timeMinutes ~/ 60, timeMinutes % 60),
      ),
    ];
  }

}
