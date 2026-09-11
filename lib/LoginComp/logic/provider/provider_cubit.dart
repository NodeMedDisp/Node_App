import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/counseling_question.dart';
import '../../../models/medication.dart';
import '../../data/provider_repository.dart';
import 'provider_state.dart';
import 'provider_user.dart';

class ProviderCubit extends Cubit<ProviderState> {
  final ProviderRepository repository;

  StreamSubscription<List<ProviderUser>>? _patientsSubscription;

  StreamSubscription<List<Medication>>? _medicationsSubscription;

  StreamSubscription<List<CounselingQuestion>>? _promptsSubscription;

  StreamSubscription<Map<DateTime, List<Map<String, dynamic>>>>?
      _recoverySubscription;

  String? _clinicId;
  String? _watchedPatientId;

  ProviderCubit({
    required this.repository,
  }) : super(const ProviderState());

  Future<void> loadClinicData(String? clinicCode) async {
    final normalizedClinicId = clinicCode?.trim();

    if (normalizedClinicId == null || normalizedClinicId.isEmpty) {
      emit(
        state.copyWith(
          loading: false,
          errorMessage: 'No clinic ID was supplied.',
        ),
      );

      debugPrint(
        'PROVIDER CUBIT ERROR: Clinic ID is empty',
      );
      return;
    }

    if (_clinicId == normalizedClinicId && _patientsSubscription != null) {
      debugPrint(
        'PROVIDER CUBIT: Clinic already loaded; '
        'skipping duplicate load',
      );
      return;
    }

    debugPrint(
      'PROVIDER CUBIT: Loading clinic=$normalizedClinicId',
    );

    await _cancelSubscriptions();

    _clinicId = normalizedClinicId;

    emit(
      state.copyWith(
        loading: true,
        saving: false,
        clearError: true,
        users: const [],
        clearSelectedUser: true,
        selectedMedications: const [],
        selectedPrompts: const [],
        recoveryMap: const {},
      ),
    );

    try {
      await repository.seedDemoPatientsIfMissing(
        normalizedClinicId,
      );

      _patientsSubscription =
          repository.watchPatients(normalizedClinicId).listen(
        _handlePatientSnapshot,
        onError: (
          Object error,
          StackTrace stackTrace,
        ) {
          _handleStreamError(
            'patient list',
            error,
            stackTrace,
          );
        },
      );
    } catch (error, stackTrace) {
      debugPrint(
        'PROVIDER CUBIT ERROR: Clinic load failed: $error',
      );
      debugPrintStack(stackTrace: stackTrace);

      emit(
        state.copyWith(
          loading: false,
          errorMessage: 'Could not load clinic data: $error',
        ),
      );
    }
  }

  void _handlePatientSnapshot(
    List<ProviderUser> patients,
  ) {
    if (isClosed) {
      return;
    }

    debugPrint(
      'PROVIDER CUBIT: Received '
      '${patients.length} patients',
    );

    ProviderUser? selectedPatient;
    final previousSelectedId = state.selectedUser?.id;

    if (previousSelectedId != null) {
      for (final patient in patients) {
        if (patient.id == previousSelectedId) {
          selectedPatient = patient;
          break;
        }
      }
    }

    if (selectedPatient == null && patients.isNotEmpty) {
      selectedPatient = patients.first;
    }

    emit(
      state.copyWith(
        loading: false,
        clearError: true,
        users: patients,
        selectedUser: selectedPatient,
        clearSelectedUser: selectedPatient == null,
      ),
    );

    if (selectedPatient == null) {
      unawaited(_stopProgramListeners());
      return;
    }

    if (_watchedPatientId != selectedPatient.id) {
      unawaited(
        _watchSelectedPatientProgram(selectedPatient),
      );
    }
  }

  void selectUser(ProviderUser user) {
    debugPrint(
      'PROVIDER CUBIT: Selecting patient '
      'id=${user.id} name=${user.displayName}',
    );

    emit(
      state.copyWith(
        selectedUser: user,
        selectedMedications: const [],
        selectedPrompts: const [],
        clearError: true,
        recoveryMap: const {},
      ),
    );

    unawaited(_watchSelectedPatientProgram(user));
  }

  Future<void> _watchSelectedPatientProgram(
    ProviderUser user,
  ) async {
    final clinicId = _requireClinicId();

    await _medicationsSubscription?.cancel();
    await _promptsSubscription?.cancel();
    await _recoverySubscription?.cancel();

    _watchedPatientId = user.id;

    debugPrint(
      'PROVIDER CUBIT: Watching program '
      'patient=${user.id}',
    );

    _medicationsSubscription = repository
        .watchMedications(
      clinicId: clinicId,
      patientId: user.id,
    )
        .listen(
      (medications) {
        if (isClosed || state.selectedUser?.id != user.id) {
          return;
        }

        debugPrint(
          'PROVIDER CUBIT: Updating UI with '
          '${medications.length} medications '
          'patient=${user.id}',
        );

        emit(
          state.copyWith(
            selectedMedications: medications,
          ),
        );
      },
      onError: (
        Object error,
        StackTrace stackTrace,
      ) {
        _handleStreamError(
          'medications',
          error,
          stackTrace,
        );
      },
    );

    _promptsSubscription = repository
        .watchPrompts(
      clinicId: clinicId,
      patientId: user.id,
    )
        .listen(
      (prompts) {
        if (isClosed || state.selectedUser?.id != user.id) {
          return;
        }

        debugPrint(
          'PROVIDER CUBIT: Updating UI with '
          '${prompts.length} prompts '
          'patient=${user.id}',
        );

        emit(
          state.copyWith(
            selectedPrompts: prompts,
          ),
        );
      },
      onError: (
        Object error,
        StackTrace stackTrace,
      ) {
        _handleStreamError(
          'prompts',
          error,
          stackTrace,
        );
      },
    );

    _recoverySubscription = repository
        .watchRecoveryProgress(
      clinicId: clinicId,
      patientId: user.id,
    )
        .listen(
      (recoveryMap) {
        if (isClosed || state.selectedUser?.id != user.id) {
          return;
        }

        debugPrint(
          'PROVIDER CUBIT: Updating UI with '
          '${recoveryMap.length} recovery days '
          'patient=${user.id}',
        );

        emit(
          state.copyWith(
            recoveryMap: recoveryMap,
          ),
        );
      },
      onError: (
        Object error,
        StackTrace stackTrace,
      ) {
        _handleStreamError(
          'recovery progress',
          error,
          stackTrace,
        );
      },
    );
  }

  Future<void> addMedicationToSelectedUser(
    Medication medication,
  ) async {
    final user = _requireSelectedUser();

    await _executeMutation(
      'add medication',
      () => repository.addMedication(
        clinicId: _requireClinicId(),
        patientId: user.id,
        medication: medication,
      ),
    );
  }

  Future<void> updateMedicationForSelectedUser(
    Medication medication,
  ) async {
    final user = _requireSelectedUser();

    await _executeMutation(
      'update medication',
      () => repository.updateMedication(
        clinicId: _requireClinicId(),
        patientId: user.id,
        medication: medication,
      ),
    );
  }

  Future<void> deleteMedicationFromSelectedUser(
    String medicationId,
  ) async {
    final user = _requireSelectedUser();

    await _executeMutation(
      'delete medication',
      () => repository.deleteMedication(
        clinicId: _requireClinicId(),
        patientId: user.id,
        medicationId: medicationId,
      ),
    );
  }

  Future<void> addPromptToSelectedUser(
    CounselingQuestion prompt,
  ) async {
    final user = _requireSelectedUser();

    await _executeMutation(
      'add prompt',
      () => repository.addPrompt(
        clinicId: _requireClinicId(),
        patientId: user.id,
        prompt: prompt,
      ),
    );
  }

  Future<void> updatePromptForSelectedUser(
    CounselingQuestion prompt,
  ) async {
    final user = _requireSelectedUser();

    await _executeMutation(
      'update prompt',
      () => repository.updatePrompt(
        clinicId: _requireClinicId(),
        patientId: user.id,
        prompt: prompt,
      ),
    );
  }

  Future<void> deletePromptFromSelectedUser(
    String promptId,
  ) async {
    final user = _requireSelectedUser();

    await _executeMutation(
      'delete prompt',
      () => repository.deletePrompt(
        clinicId: _requireClinicId(),
        patientId: user.id,
        promptId: promptId,
      ),
    );
  }

  Future<ProviderUser?> createPatient({
    required String displayName,
    String deviceId = '',
  }) async {
    final trimmedName = displayName.trim();

    if (trimmedName.isEmpty) {
      emit(
        state.copyWith(
          errorMessage: 'Enter a patient name.',
        ),
      );
      return null;
    }

    final patient = ProviderUser(
      id: '',
      displayName: trimmedName,
      deviceId: deviceId.trim(),
      source: 'manual',
      startDate: DateTime.now(),
      latestEntryDate: DateTime.now(),
    );

    final createdPatient = await _executeMutation<ProviderUser>(
      'create patient',
      () => repository.createPatient(
        clinicId: _requireClinicId(),
        patient: patient,
      ),
    );

    selectUser(createdPatient);
    return createdPatient;
  }

  Future<PatientImportResult> importPatientFromDevice({
    required String displayName,
    required String deviceId,
    required List<Medication> medications,
    List<CounselingQuestion> prompts = const [],
  }) async {
    final result = await _executeMutation<PatientImportResult>(
      'import patient from device',
      () => repository.importPatientFromDevice(
        clinicId: _requireClinicId(),
        displayName: displayName,
        deviceId: deviceId,
        medications: medications,
        prompts: prompts,
      ),
    );

    selectUser(result.patient);
    return result;
  }

  Future<T> _executeMutation<T>(
    String name,
    Future<T> Function() operation,
  ) async {
    debugPrint(
      'PROVIDER CUBIT: Starting mutation="$name"',
    );

    emit(
      state.copyWith(
        saving: true,
        clearError: true,
      ),
    );

    try {
      final result = await operation();

      if (!isClosed) {
        emit(
          state.copyWith(
            saving: false,
            clearError: true,
          ),
        );
      }

      debugPrint(
        'PROVIDER CUBIT: Completed mutation="$name"',
      );

      return result;
    } catch (error, stackTrace) {
      debugPrint(
        'PROVIDER CUBIT ERROR: '
        'Mutation="$name" failed: $error',
      );
      debugPrintStack(stackTrace: stackTrace);

      if (!isClosed) {
        emit(
          state.copyWith(
            saving: false,
            errorMessage: '$name failed: $error',
          ),
        );
      }

      rethrow;
    }
  }

  ProviderUser _requireSelectedUser() {
    final user = state.selectedUser;

    if (user == null) {
      throw StateError(
        'No provider patient is selected.',
      );
    }

    return user;
  }

  String _requireClinicId() {
    final clinicId = _clinicId;

    if (clinicId == null || clinicId.isEmpty) {
      throw StateError(
        'No clinic is currently loaded.',
      );
    }

    return clinicId;
  }

  void _handleStreamError(
    String streamName,
    Object error,
    StackTrace stackTrace,
  ) {
    debugPrint(
      'PROVIDER CUBIT ERROR: '
      '$streamName stream failed: $error',
    );
    debugPrintStack(stackTrace: stackTrace);

    if (!isClosed) {
      emit(
        state.copyWith(
          loading: false,
          errorMessage: 'Could not load $streamName: $error',
        ),
      );
    }
  }

  Future<void> saveRecoveryProgress({
    required DateTime date,
    required List<Map<String, dynamic>> entries,
  }) async {
    final patient = state.selectedUser;

    if (patient == null) {
      debugPrint(
        'PROVIDER CUBIT: Cannot save recovery; '
        'no patient selected',
      );
      return;
    }

    if (entries.isEmpty) {
      return;
    }

    debugPrint(
      'PROVIDER CUBIT: Saving recovery '
      'patient=${patient.id} '
      'date=$date '
      'entries=${entries.length}',
    );

    await repository.saveRecoveryProgress(
      clinicId: _requireClinicId(),
      patientId: patient.id,
      date: date,
      entries: entries,
    );
  }

  Future<void> _stopProgramListeners() async {
    await _medicationsSubscription?.cancel();
    await _promptsSubscription?.cancel();
    await _recoverySubscription?.cancel();

    _medicationsSubscription = null;
    _promptsSubscription = null;
    _recoverySubscription = null;
    _watchedPatientId = null;
  }

  Future<void> _cancelSubscriptions() async {
    await _patientsSubscription?.cancel();
    _patientsSubscription = null;

    await _stopProgramListeners();
  }

  @override
  Future<void> close() async {
    debugPrint('PROVIDER CUBIT: Closing');

    await _cancelSubscriptions();

    return super.close();
  }
}
