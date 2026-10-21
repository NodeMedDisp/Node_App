import 'package:cloud_firestore/cloud_firestore.dart';

class PatientPlanLink {
  final String clinicId;
  final String patientId;
  final String patientDisplayName;
  final DateTime? linkedAt;

  const PatientPlanLink({
    required this.clinicId,
    required this.patientId,
    required this.patientDisplayName,
    this.linkedAt,
  });

  factory PatientPlanLink.fromFirestore(Map<String, dynamic> data) {
    return PatientPlanLink(
      clinicId: data['clinicId']?.toString() ?? '',
      patientId: data['patientId']?.toString() ?? '',
      patientDisplayName:
          data['patientDisplayName']?.toString() ?? 'My Recovery Plan',
      linkedAt: readPatientDate(data['linkedAt']),
    );
  }
}

class PatientProfile {
  final String id;
  final String displayName;
  final String deviceId;
  final DateTime? startDate;
  final DateTime? latestEntryDate;

  const PatientProfile({
    required this.id,
    required this.displayName,
    required this.deviceId,
    this.startDate,
    this.latestEntryDate,
  });

  factory PatientProfile.fromFirestore(
    String documentId,
    Map<String, dynamic> data,
  ) {
    return PatientProfile(
      id: documentId,
      displayName: data['displayName']?.toString() ?? 'Patient',
      deviceId: data['deviceId']?.toString() ?? '',
      startDate: readPatientDate(data['startDate']),
      latestEntryDate: readPatientDate(data['latestEntryDate']),
    );
  }
}

class PatientInvite {
  final String id;
  final String clinicId;
  final String clinicDisplayName;
  final String patientId;
  final String patientDisplayName;
  final String providerEmail;
  final DateTime? createdAt;

  const PatientInvite({
    required this.id,
    required this.clinicId,
    required this.clinicDisplayName,
    required this.patientId,
    required this.patientDisplayName,
    required this.providerEmail,
    this.createdAt,
  });

  factory PatientInvite.fromCallable(Map<String, dynamic> data) {
    return PatientInvite(
      id: data['id']?.toString() ?? '',
      clinicId: data['clinicId']?.toString() ?? '',
      clinicDisplayName:
          data['clinicDisplayName']?.toString() ?? 'NODE Recovery',
      patientId: data['patientId']?.toString() ?? '',
      patientDisplayName:
          data['patientDisplayName']?.toString() ?? 'Recovery Plan',
      providerEmail: data['providerEmail']?.toString() ?? '',
      createdAt: readPatientDate(data['createdAt']),
    );
  }
}

DateTime? readPatientDate(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }

  if (value is DateTime) {
    return value;
  }

  if (value is String) {
    return DateTime.tryParse(value);
  }

  if (value is Map) {
    final seconds = value['_seconds'] ?? value['seconds'];
    final nanoseconds = value['_nanoseconds'] ?? value['nanoseconds'] ?? 0;

    if (seconds is num && nanoseconds is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        (seconds * 1000).round() + (nanoseconds / 1000000).round(),
        isUtc: true,
      ).toLocal();
    }
  }

  return null;
}
