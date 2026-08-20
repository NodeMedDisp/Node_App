import '../models/counseling_question.dart';
import '../models/medication.dart';

/// Generates the exact configuration-file format understood by NODE.
///
/// Important:
/// - This method does not append EOF.
/// - EOF is a Bluetooth transport marker and is added by the BLE service.
/// - Both patient and provider flows must use this formatter.
class RecoveryProgramFileFormatter {
  const RecoveryProgramFileFormatter._();

  static String build({
    required List<Medication> medications,
    required List<CounselingQuestion> prompts,
    DateTime? generatedAt,
  }) {
    final timestamp = generatedAt ?? DateTime.now();
    final buffer = StringBuffer();

    buffer.writeln('Current Time: ${_formatDateTime(timestamp)}');
    buffer.writeln();

    for (final medication in medications) {
      buffer.writeln('Medication: ${medication.name}');
      buffer.writeln('Dose: ${medication.dose}');
      buffer.writeln('Frequency: ${medication.frequency}');
      buffer.writeln('Times: ${medication.times}');
      buffer.writeln('Days: 1 to ${medication.numDays}');

      _appendRewardSection(
        buffer,
        sectionName: 'Streak',
        enabled: medication.streakEnabled,
        title: medication.streakTitle,
        threshold: medication.streakThreshold,
      );

      _appendRewardSection(
        buffer,
        sectionName: 'Token',
        enabled: medication.tokenEnabled,
        title: medication.tokenTitle,
        threshold: medication.tokenThreshold,
        quantity: medication.tokenQuantity,
      );

      // A blank line ends this medication block.
      buffer.writeln();
    }

    for (final prompt in prompts) {
      buffer.writeln('Prompt: ${prompt.prompt}');
      buffer.writeln('Required Response: ${prompt.resReq}');
      buffer.writeln('Options: ${prompt.options.join(', ')}');
      buffer.writeln('Days: 1 to ${prompt.numberOfDays}');

      _appendRewardSection(
        buffer,
        sectionName: 'Streak',
        enabled: prompt.streakEnabled,
        title: prompt.streakTitle,
        threshold: prompt.streakThreshold,
      );

      _appendRewardSection(
        buffer,
        sectionName: 'Token',
        enabled: prompt.tokenEnabled,
        title: prompt.tokenTitle,
        threshold: prompt.tokenThreshold,
        quantity: prompt.tokenQuantity,
      );

      // A blank line ends this prompt block.
      buffer.writeln();
    }

    return buffer.toString();
  }

  static void _appendRewardSection(
    StringBuffer buffer, {
    required String sectionName,
    required bool enabled,
    required String title,
    required String threshold,
    int? quantity,
  }) {
    buffer.writeln('$sectionName: ${enabled ? 'Yes' : 'No'}');

    if (!enabled) {
      return;
    }

    buffer.writeln('Title: ${title.trim()}');

    final cleanThreshold =
        threshold.trim().isEmpty ? 'None' : threshold.trim();

    buffer.writeln('Threshold: $cleanThreshold');

    if (sectionName == 'Token') {
      buffer.writeln('Quantity: ${quantity ?? 0}');
    }
  }

  static String _formatDateTime(DateTime value) {
    String pad(int number) => number.toString().padLeft(2, '0');

    return '${value.year.toString().padLeft(4, '0')}-'
        '${pad(value.month)}-'
        '${pad(value.day)} '
        '${pad(value.hour)}:'
        '${pad(value.minute)}:'
        '${pad(value.second)}';
  }
}