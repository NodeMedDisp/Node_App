import '../../models/counseling_question.dart';
import '../../models/medication.dart';
import '../logic/provider/provider_user.dart';

class PatientImportResult {
  final ProviderUser patient;
  final bool created;

  const PatientImportResult({
    required this.patient,
    required this.created,
  });
}

abstract class ProviderRepository {
  Stream<List<ProviderUser>> watchPatients(String clinicId);

  Stream<List<Medication>> watchMedications({
    required String clinicId,
    required String patientId,
  });

  Stream<List<CounselingQuestion>> watchPrompts({
    required String clinicId,
    required String patientId,
  });

  Future<void> seedDemoPatientsIfMissing(String clinicId);

  Future<ProviderUser> createPatient({
    required String clinicId,
    required ProviderUser patient,
  });

  Future<ProviderUser?> findPatientByDeviceId({
    required String clinicId,
    required String deviceId,
  });

  Future<String> addMedication({
    required String clinicId,
    required String patientId,
    required Medication medication,
  });

  Future<void> updateMedication({
    required String clinicId,
    required String patientId,
    required Medication medication,
  });

  Future<void> deleteMedication({
    required String clinicId,
    required String patientId,
    required String medicationId,
  });

  Future<String> addPrompt({
    required String clinicId,
    required String patientId,
    required CounselingQuestion prompt,
  });

  Future<void> updatePrompt({
    required String clinicId,
    required String patientId,
    required CounselingQuestion prompt,
  });

  Future<void> deletePrompt({
    required String clinicId,
    required String patientId,
    required String promptId,
  });

  Future<PatientImportResult> importPatientFromDevice({
    required String clinicId,
    required String displayName,
    required String deviceId,
    required List<Medication> medications,
    required List<CounselingQuestion> prompts,
  });
}
