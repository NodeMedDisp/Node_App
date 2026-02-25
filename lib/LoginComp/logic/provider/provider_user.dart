class ProviderUser {
  final String id;
  final String displayName;
  final String deviceId;
  final DateTime? startDate;
  final DateTime? latestEntryDate;

  ProviderUser({
    required this.id,
    required this.displayName,
    required this.deviceId,
    this.startDate,
    this.latestEntryDate,
  });
}