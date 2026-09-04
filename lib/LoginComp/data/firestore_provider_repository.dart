import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../models/counseling_question.dart';
import '../../models/medication.dart';
import '../logic/provider/provider_user.dart';
import 'provider_repository.dart';

class FirestoreProviderRepository implements ProviderRepository {
  final FirebaseFirestore firestore;

  FirestoreProviderRepository({
    FirebaseFirestore? firestore,
  }) : firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _patients(
    String clinicId,
  ) {
    return firestore.collection('clinics').doc(clinicId).collection('patients');
  }

  DocumentReference<Map<String, dynamic>> _patient(
    String clinicId,
    String patientId,
  ) {
    return _patients(clinicId).doc(patientId);
  }

  CollectionReference<Map<String, dynamic>> _medications(
    String clinicId,
    String patientId,
  ) {
    return _patient(clinicId, patientId).collection('medications');
  }

  CollectionReference<Map<String, dynamic>> _prompts(
    String clinicId,
    String patientId,
  ) {
    return _patient(clinicId, patientId).collection('prompts');
  }

  CollectionReference<Map<String, dynamic>> _recoveryDays(
    String clinicId,
    String patientId,
  ) {
    return _patient(
      clinicId,
      patientId,
    ).collection('recoveryDays');
  }

  String _recoveryDateKey(DateTime date) {
    final normalized = DateTime(
      date.year,
      date.month,
      date.day,
    );

    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');

    return '${normalized.year}-$month-$day';
  }

  String _normalizeDeviceId(String value) {
    return value.trim().toLowerCase();
  }

  Map<String, dynamic> _patientData(
    ProviderUser patient, {
    required bool creating,
  }) {
    return {
      ...patient.toFirestore(),
      'deviceIdNormalized': _normalizeDeviceId(patient.deviceId),
      if (creating) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> _programData(
    Map<String, dynamic> data, {
    required bool creating,
  }) {
    return {
      ...data,
      if (creating) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  @override
  Stream<List<ProviderUser>> watchPatients(String clinicId) {
    debugPrint(
      'FIRESTORE: Watching patients for clinic=$clinicId',
    );

    return _patients(clinicId).snapshots().map((snapshot) {
      final patients = snapshot.docs
          .map(
            (document) => ProviderUser.fromFirestore(
              document.id,
              document.data(),
            ),
          )
          .toList();

      patients.sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );

      debugPrint(
        'FIRESTORE: Patient snapshot count=${patients.length}',
      );

      return patients;
    });
  }

  @override
  Stream<List<Medication>> watchMedications({
    required String clinicId,
    required String patientId,
  }) {
    debugPrint(
      'FIRESTORE: Watching medications patient=$patientId',
    );

    return _medications(clinicId, patientId).snapshots().map((snapshot) {
      final medications = snapshot.docs
          .map(
            (document) => Medication.fromJson(
              document.data(),
              id: document.id,
            ),
          )
          .toList();

      medications.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      debugPrint(
        'FIRESTORE: Medication snapshot '
        'patient=$patientId count=${medications.length}',
      );

      return medications;
    });
  }

  @override
  Stream<List<CounselingQuestion>> watchPrompts({
    required String clinicId,
    required String patientId,
  }) {
    debugPrint(
      'FIRESTORE: Watching prompts patient=$patientId',
    );

    return _prompts(clinicId, patientId).snapshots().map((snapshot) {
      final prompts = snapshot.docs
          .map(
            (document) => CounselingQuestion.fromJson(
              document.data(),
              id: document.id,
            ),
          )
          .toList();

      prompts.sort(
        (a, b) => a.prompt.toLowerCase().compareTo(b.prompt.toLowerCase()),
      );

      debugPrint(
        'FIRESTORE: Prompt snapshot '
        'patient=$patientId count=${prompts.length}',
      );

      return prompts;
    });
  }

  @override
  Stream<Map<DateTime, List<Map<String, dynamic>>>> watchRecoveryProgress({
    required String clinicId,
    required String patientId,
  }) {
    debugPrint(
      'FIRESTORE: Watching recovery progress '
      'patient=$patientId',
    );

    return _recoveryDays(
      clinicId,
      patientId,
    ).snapshots().map((snapshot) {
      final recoveryMap = <DateTime, List<Map<String, dynamic>>>{};

      for (final document in snapshot.docs) {
        try {
          final date = DateTime.parse(document.id);

          final normalizedDate = DateTime(
            date.year,
            date.month,
            date.day,
          );

          final data = document.data();

          final rawEntries = data['entries'] as List<dynamic>? ?? const [];

          recoveryMap[normalizedDate] = rawEntries.map((entry) {
            return Map<String, dynamic>.from(
              entry as Map,
            );
          }).toList();
        } catch (error) {
          debugPrint(
            'FIRESTORE: Could not parse recovery day '
            'id=${document.id} error=$error',
          );
        }
      }

      debugPrint(
        'FIRESTORE: Recovery snapshot '
        'patient=$patientId days=${recoveryMap.length}',
      );

      return recoveryMap;
    });
  }

  @override
  Future<void> saveRecoveryProgress({
    required String clinicId,
    required String patientId,
    required DateTime date,
    required List<Map<String, dynamic>> entries,
  }) async {
    if (entries.isEmpty) {
      return;
    }

    final dateKey = _recoveryDateKey(date);

    final reference = _recoveryDays(
      clinicId,
      patientId,
    ).doc(dateKey);

    debugPrint(
      'FIRESTORE: Saving recovery progress '
      'patient=$patientId '
      'date=$dateKey '
      'entries=${entries.length}',
    );

    await reference.set(
      {
        'date': dateKey,

        // arrayUnion is important:
        // receiving the same NODE record twice
        // will not duplicate identical entries.
        'entries': FieldValue.arrayUnion(
          entries,
        ),

        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    debugPrint(
      'FIRESTORE: Recovery progress saved '
      'patient=$patientId date=$dateKey',
    );
  }

  @override
  Future<void> seedDemoPatientsIfMissing(
    String clinicId,
  ) async {
    debugPrint(
      'FIRESTORE SEED: Checking demo patients '
      'clinic=$clinicId',
    );

    await _seedDemoPatient(
      clinicId: clinicId,
      patient: ProviderUser(
        id: 'u1',
        displayName: 'Demo User 1',
        deviceId: 'DEV-001',
        source: 'demo',
        startDate: DateTime.now().subtract(const Duration(days: 10)),
        latestEntryDate: DateTime.now(),
      ),
      medications: const [
        Medication(
          name: 'Aspirin',
          dose: '100mg',
          times: '8:00 PM',
          frequency: 'Daily',
          numDays: 30,
        ),
        Medication(
          name: 'Buprenorphine',
          dose: '8mg',
          times: '9:00 PM',
          frequency: 'Daily',
          numDays: 30,
        ),
      ],
      prompts: const [
        CounselingQuestion(
          prompt: 'How stressed are you today?',
          resReq: 'number',
          options: [],
          numberOfDays: 30,
        ),
        CounselingQuestion(
          prompt: 'Did you sleep well last night?',
          resReq: 'yes_no',
          options: [],
          numberOfDays: 30,
        ),
      ],
    );

    await _seedDemoPatient(
      clinicId: clinicId,
      patient: ProviderUser(
        id: 'u2',
        displayName: 'Demo User 2',
        deviceId: 'DEV-002',
        source: 'demo',
        startDate: DateTime.now().subtract(const Duration(days: 5)),
        latestEntryDate: DateTime.now(),
      ),
      medications: const [
        Medication(
          name: 'Naloxone',
          dose: '4mg',
          times: '10:00',
          frequency: 'Daily',
          numDays: 30,
        ),
        Medication(
          name: 'Ibuprofen',
          dose: '200mg',
          times: '14:00',
          frequency: 'Daily',
          numDays: 30,
        ),
      ],
      prompts: const [
        CounselingQuestion(
          prompt: 'How is your pain level today?',
          resReq: 'number',
          options: [],
          numberOfDays: 30,
        ),
        CounselingQuestion(
          prompt: 'Have you felt cravings today?',
          resReq: 'yes_no',
          options: [],
          numberOfDays: 30,
        ),
      ],
    );
  }

  Future<void> _seedDemoPatient({
    required String clinicId,
    required ProviderUser patient,
    required List<Medication> medications,
    required List<CounselingQuestion> prompts,
  }) async {
    final patientReference = _patient(clinicId, patient.id);

    final existingPatient = await patientReference.get();

    if (existingPatient.exists) {
      debugPrint(
        'FIRESTORE SEED: ${patient.id} already exists; '
        'not overwriting edits',
      );
      return;
    }

    final batch = firestore.batch();

    batch.set(
      patientReference,
      _patientData(patient, creating: true),
    );

    for (var index = 0; index < medications.length; index++) {
      final reference =
          patientReference.collection('medications').doc('med-${index + 1}');

      batch.set(
        reference,
        _programData(
          medications[index].toJson(),
          creating: true,
        ),
      );
    }

    for (var index = 0; index < prompts.length; index++) {
      final reference =
          patientReference.collection('prompts').doc('prompt-${index + 1}');

      batch.set(
        reference,
        _programData(
          prompts[index].toJson(),
          creating: true,
        ),
      );
    }

    await batch.commit();

    debugPrint(
      'FIRESTORE SEED: Created ${patient.displayName}',
    );
  }

  @override
  Future<ProviderUser> createPatient({
    required String clinicId,
    required ProviderUser patient,
  }) async {
    final reference = _patients(clinicId).doc();

    final createdPatient = patient.copyWith(
      id: reference.id,
    );

    debugPrint(
      'FIRESTORE: Creating patient '
      'clinic=$clinicId '
      'id=${reference.id} '
      'name=${createdPatient.displayName}',
    );

    try {
      await reference.set(
        _patientData(
          createdPatient,
          creating: true,
        ),
      );

      debugPrint(
        'FIRESTORE: Patient created successfully '
        'clinic=$clinicId '
        'id=${reference.id} '
        'name=${createdPatient.displayName}',
      );

      return createdPatient;
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'FIRESTORE CREATE PATIENT ERROR: '
        'code=${error.code} '
        'message=${error.message}',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      rethrow;
    } catch (error, stackTrace) {
      debugPrint(
        'FIRESTORE CREATE PATIENT UNKNOWN ERROR: $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      rethrow;
    }
  }

  @override
  Future<ProviderUser?> findPatientByDeviceId({
    required String clinicId,
    required String deviceId,
  }) async {
    final normalized = _normalizeDeviceId(deviceId);

    if (normalized.isEmpty) {
      return null;
    }

    final snapshot = await _patients(clinicId)
        .where(
          'deviceIdNormalized',
          isEqualTo: normalized,
        )
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    final document = snapshot.docs.first;

    return ProviderUser.fromFirestore(
      document.id,
      document.data(),
    );
  }

  @override
  Future<String> addMedication({
    required String clinicId,
    required String patientId,
    required Medication medication,
  }) async {
    final reference = _medications(clinicId, patientId).doc();

    debugPrint(
      'FIRESTORE: Adding medication '
      'patient=$patientId '
      'medication=${medication.name}',
    );

    final medicationToSave = medication.startDate == null
        ? medication.copyWith(startDate: DateTime.now())
        : medication;

    await reference.set(
      _programData(
        medicationToSave.toJson(),
        creating: true,
      ),
    );

    return reference.id;
  }

  @override
  Future<void> updateMedication({
    required String clinicId,
    required String patientId,
    required Medication medication,
  }) async {
    final medicationId = medication.id;

    if (medicationId == null || medicationId.isEmpty) {
      throw StateError(
        'Cannot update a medication without a Firestore ID.',
      );
    }

    debugPrint(
      'FIRESTORE: Updating medication '
      'patient=$patientId id=$medicationId',
    );

    await _medications(clinicId, patientId).doc(medicationId).set(
          _programData(
            medication.toJson(),
            creating: false,
          ),
          SetOptions(merge: true),
        );
  }

  @override
  Future<void> deleteMedication({
    required String clinicId,
    required String patientId,
    required String medicationId,
  }) async {
    debugPrint(
      'FIRESTORE: Deleting medication '
      'patient=$patientId id=$medicationId',
    );

    await _medications(clinicId, patientId).doc(medicationId).delete();
  }

  @override
  Future<String> addPrompt({
    required String clinicId,
    required String patientId,
    required CounselingQuestion prompt,
  }) async {
    final reference = _prompts(clinicId, patientId).doc();

    debugPrint(
      'FIRESTORE: Adding prompt '
      'patient=$patientId prompt=${prompt.prompt}',
    );

    final promptToSave = prompt.startDate == null
        ? prompt.copyWith(startDate: DateTime.now())
        : prompt;

    await reference.set(
      _programData(
        promptToSave.toJson(),
        creating: true,
      ),
    );

    return reference.id;
  }

  @override
  Future<void> updatePrompt({
    required String clinicId,
    required String patientId,
    required CounselingQuestion prompt,
  }) async {
    final promptId = prompt.id;

    if (promptId == null || promptId.isEmpty) {
      throw StateError(
        'Cannot update a prompt without a Firestore ID.',
      );
    }

    debugPrint(
      'FIRESTORE: Updating prompt '
      'patient=$patientId id=$promptId',
    );

    await _prompts(clinicId, patientId).doc(promptId).set(
          _programData(
            prompt.toJson(),
            creating: false,
          ),
          SetOptions(merge: true),
        );
  }

  @override
  Future<void> deletePrompt({
    required String clinicId,
    required String patientId,
    required String promptId,
  }) async {
    debugPrint(
      'FIRESTORE: Deleting prompt '
      'patient=$patientId id=$promptId',
    );

    await _prompts(clinicId, patientId).doc(promptId).delete();
  }

  @override
  Future<PatientImportResult> importPatientFromDevice({
    required String clinicId,
    required String displayName,
    required String deviceId,
    required List<Medication> medications,
    required List<CounselingQuestion> prompts,
  }) async {
    final existingPatient = await findPatientByDeviceId(
      clinicId: clinicId,
      deviceId: deviceId,
    );

    if (existingPatient != null) {
      debugPrint(
        'FIRESTORE IMPORT: Existing patient found '
        'id=${existingPatient.id} device=$deviceId',
      );

      return PatientImportResult(
        patient: existingPatient,
        created: false,
      );
    }

    final patientReference = _patients(clinicId).doc();

    final patient = ProviderUser(
      id: patientReference.id,
      displayName: displayName,
      deviceId: deviceId,
      source: 'device',
      startDate: DateTime.now(),
      latestEntryDate: DateTime.now(),
    );

    final batch = firestore.batch();

    batch.set(
      patientReference,
      _patientData(patient, creating: true),
    );

    for (final medication in medications) {
      final reference = patientReference.collection('medications').doc();

      batch.set(
        reference,
        _programData(
          medication.toJson(),
          creating: true,
        ),
      );
    }

    for (final prompt in prompts) {
      final reference = patientReference.collection('prompts').doc();

      batch.set(
        reference,
        _programData(
          prompt.toJson(),
          creating: true,
        ),
      );
    }

    await batch.commit();

    debugPrint(
      'FIRESTORE IMPORT: Created patient '
      'id=${patient.id} device=$deviceId',
    );

    return PatientImportResult(
      patient: patient,
      created: true,
    );
  }
}
