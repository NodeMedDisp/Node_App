import 'package:cloud_firestore/cloud_firestore.dart';

class ProviderUser {
  final String id;
  final String displayName;
  final String deviceId;
  final DateTime? startDate;
  final DateTime? latestEntryDate;

  /// demo, manual, or device
  final String source;

  const ProviderUser({
    required this.id,
    required this.displayName,
    required this.deviceId,
    this.startDate,
    this.latestEntryDate,
    this.source = 'manual',
  });

  ProviderUser copyWith({
    String? id,
    String? displayName,
    String? deviceId,
    DateTime? startDate,
    DateTime? latestEntryDate,
    String? source,
  }) {
    return ProviderUser(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      deviceId: deviceId ?? this.deviceId,
      startDate: startDate ?? this.startDate,
      latestEntryDate: latestEntryDate ?? this.latestEntryDate,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'deviceId': deviceId,
      'source': source,
      'startDate': startDate == null ? null : Timestamp.fromDate(startDate!),
      'latestEntryDate':
          latestEntryDate == null ? null : Timestamp.fromDate(latestEntryDate!),
    };
  }

  factory ProviderUser.fromFirestore(
    String documentId,
    Map<String, dynamic> data,
  ) {
    return ProviderUser(
      id: documentId,
      displayName: data['displayName']?.toString() ?? 'Unnamed Patient',
      deviceId: data['deviceId']?.toString() ?? '',
      source: data['source']?.toString() ?? 'manual',
      startDate: _readDate(data['startDate']),
      latestEntryDate: _readDate(data['latestEntryDate']),
    );
  }

  static DateTime? _readDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }
}
