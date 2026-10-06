/// Decodes Hive's dynamic maps without assuming their runtime generic type.
/// This never deletes or rewrites saved data.
class RecoveryCacheCodec {
  const RecoveryCacheCodec._();

  static Map<DateTime, List<Map<String, dynamic>>> decode(
    Map<dynamic, dynamic> records, {
    void Function(String message)? onWarning,
  }) {
    final result = <DateTime, List<Map<String, dynamic>>>{};
    for (final record in records.entries) {
      final date = record.key is String ? DateTime.tryParse(record.key as String) : null;
      final data = record.value;
      if (date == null || data is! Map || data['progress'] is! List) {
        onWarning?.call('Ignoring an unreadable calendar record; the saved record was retained.');
        continue;
      }
      final entries = <Map<String, dynamic>>[];
      for (final rawEntry in data['progress'] as List) {
        if (rawEntry is! Map || rawEntry.keys.any((key) => key is! String)) {
          onWarning?.call('Ignoring an unreadable progress item; the saved record was retained.');
          continue;
        }
        entries.add(Map<String, dynamic>.from(rawEntry));
      }
      final normalized = DateTime(date.year, date.month, date.day);
      result.putIfAbsent(normalized, () => <Map<String, dynamic>>[]).addAll(entries);
    }
    return result;
  }
}
