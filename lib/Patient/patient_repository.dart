import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/counseling_question.dart';
import '../models/medication.dart';
import 'patient_models.dart';

class FirestorePatientRepository {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  FirestorePatientRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : auth = auth ?? FirebaseAuth.instance,
        firestore = firestore ?? FirebaseFirestore.instance,
        functions = functions ??
            FirebaseFunctions.instanceFor(
              region: 'us-central1',
            );

  User _requireUser() {
    final user = auth.currentUser;

    if (user == null) {
      throw StateError('No patient is signed in.');
    }

    return user;
  }

  DocumentReference<Map<String, dynamic>> _linkDocument() {
    return firestore.collection('patientLinks').doc(_requireUser().uid);
  }

  DocumentReference<Map<String, dynamic>> _patientDocument(
    PatientPlanLink link,
  ) {
    return firestore
        .collection('clinics')
        .doc(link.clinicId)
        .collection('patients')
        .doc(link.patientId);
  }

  CollectionReference<Map<String, dynamic>> _medications(
    PatientPlanLink link,
  ) {
    return _patientDocument(link).collection('medications');
  }

  CollectionReference<Map<String, dynamic>> _prompts(
    PatientPlanLink link,
  ) {
    return _patientDocument(link).collection('prompts');
  }

  CollectionReference<Map<String, dynamic>> _recoveryDays(
    PatientPlanLink link,
  ) {
    return _patientDocument(link).collection('recoveryDays');
  }

  Stream<PatientPlanLink?> watchMyLink() {
    return _linkDocument().snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }

      final data = snapshot.data();
      if (data == null) {
        return null;
      }

      final link = PatientPlanLink.fromFirestore(data);

      if (link.clinicId.isEmpty || link.patientId.isEmpty) {
        throw StateError('The patient link is incomplete.');
      }

      return link;
    });
  }

  Future<List<PatientInvite>> listPendingInvites() async {
    _requireUser();

    final callable = functions.httpsCallable(
      'listMyPendingPatientInvites',
    );

    final result = await callable.call<Map<String, dynamic>>();
    final data = _asStringMap(result.data);
    final rawInvites = data['invites'];

    if (rawInvites is! List) {
      return const [];
    }

    return rawInvites
        .whereType<Map>()
        .map(
          (value) => PatientInvite.fromCallable(
            Map<String, dynamic>.from(value),
          ),
        )
        .where((invite) => invite.id.isNotEmpty)
        .toList();
  }

  Future<void> acceptInvite(String inviteId) async {
    _requireUser();

    if (inviteId.trim().isEmpty) {
      throw ArgumentError('An invitation ID is required.');
    }

    final callable = functions.httpsCallable('acceptPatientInvite');
    await callable.call<Map<String, dynamic>>(
      <String, dynamic>{
        'inviteId': inviteId.trim(),
      },
    );
  }

  Future<void> declineInvite(String inviteId) async {
    _requireUser();

    if (inviteId.trim().isEmpty) {
      throw ArgumentError('An invitation ID is required.');
    }

    final callable = functions.httpsCallable('declinePatientInvite');
    await callable.call<Map<String, dynamic>>(
      <String, dynamic>{
        'inviteId': inviteId.trim(),
      },
    );
  }

  Stream<PatientProfile?> watchPatientProfile(PatientPlanLink link) {
    return _patientDocument(link).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }

      final data = snapshot.data();
      if (data == null) {
        return null;
      }

      return PatientProfile.fromFirestore(snapshot.id, data);
    });
  }

  Stream<List<Medication>> watchMedications(PatientPlanLink link) {
    return _medications(link).snapshots().map((snapshot) {
      final medications = snapshot.docs
          .map(
            (document) => Medication.fromJson(
              document.data(),
              id: document.id,
            ),
          )
          .toList();

      medications.sort((a, b) {
        final aStart = a.startDate ?? DateTime(1970);
        final bStart = b.startDate ?? DateTime(1970);
        final dateComparison = aStart.compareTo(bStart);
        if (dateComparison != 0) {
          return dateComparison;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      return medications;
    });
  }

  Stream<List<CounselingQuestion>> watchPrompts(PatientPlanLink link) {
    return _prompts(link).snapshots().map((snapshot) {
      final prompts = snapshot.docs
          .map(
            (document) => CounselingQuestion.fromJson(
              document.data(),
              id: document.id,
            ),
          )
          .toList();

      prompts.sort((a, b) {
        final aStart = a.startDate ?? DateTime(1970);
        final bStart = b.startDate ?? DateTime(1970);
        final dateComparison = aStart.compareTo(bStart);
        if (dateComparison != 0) {
          return dateComparison;
        }
        return a.prompt.toLowerCase().compareTo(b.prompt.toLowerCase());
      });

      return prompts;
    });
  }

  Stream<Map<DateTime, List<Map<String, dynamic>>>> watchRecoveryProgress(
    PatientPlanLink link,
  ) {
    return _recoveryDays(link).snapshots().map((snapshot) {
      final recoveryMap = <DateTime, List<Map<String, dynamic>>>{};

      for (final document in snapshot.docs) {
        final date = DateTime.tryParse(document.id);
        if (date == null) {
          debugPrint(
            'PATIENT FIRESTORE: Ignoring invalid recovery day ${document.id}',
          );
          continue;
        }

        final normalizedDate = DateTime(date.year, date.month, date.day);
        final rawEntries = document.data()['entries'];

        if (rawEntries is! List) {
          recoveryMap[normalizedDate] = const [];
          continue;
        }

        recoveryMap[normalizedDate] = rawEntries
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList();
      }

      return recoveryMap;
    });
  }

  Future<void> saveRecoveryProgress({
    required DateTime date,
    required List<Map<String, dynamic>> entries,
  }) async {
    _requireUser();

    if (entries.isEmpty) {
      return;
    }

    final normalizedDate = DateTime(date.year, date.month, date.day);
    final month = normalizedDate.month.toString().padLeft(2, '0');
    final day = normalizedDate.day.toString().padLeft(2, '0');
    final dateKey = '${normalizedDate.year}-$month-$day';

    final sanitizedEntries = entries
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);

    final callable = functions.httpsCallable(
      'savePatientRecoveryProgress',
    );

    await callable.call<Map<String, dynamic>>(
      <String, dynamic>{
        'date': dateKey,
        'entries': sanitizedEntries,
      },
    );
  }

  Map<String, dynamic> _asStringMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    throw StateError('The server returned an invalid response.');
  }
}
