import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/counseling_question.dart';
import '../models/medication.dart';
import 'patient_models.dart';
import 'patient_repository.dart';

class PatientState extends Equatable {
  final bool loading;
  final bool saving;
  final String? errorMessage;
  final PatientPlanLink? link;
  final PatientProfile? profile;
  final List<PatientInvite> pendingInvites;
  final List<Medication> medications;
  final List<CounselingQuestion> prompts;
  final Map<DateTime, List<Map<String, dynamic>>> recoveryMap;

  const PatientState({
    this.loading = false,
    this.saving = false,
    this.errorMessage,
    this.link,
    this.profile,
    this.pendingInvites = const [],
    this.medications = const [],
    this.prompts = const [],
    this.recoveryMap = const {},
  });

  PatientState copyWith({
    bool? loading,
    bool? saving,
    String? errorMessage,
    bool clearError = false,
    PatientPlanLink? link,
    bool clearLink = false,
    PatientProfile? profile,
    bool clearProfile = false,
    List<PatientInvite>? pendingInvites,
    List<Medication>? medications,
    List<CounselingQuestion>? prompts,
    Map<DateTime, List<Map<String, dynamic>>>? recoveryMap,
  }) {
    return PatientState(
      loading: loading ?? this.loading,
      saving: saving ?? this.saving,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      link: clearLink ? null : link ?? this.link,
      profile: clearProfile ? null : profile ?? this.profile,
      pendingInvites: pendingInvites ?? this.pendingInvites,
      medications: medications ?? this.medications,
      prompts: prompts ?? this.prompts,
      recoveryMap: recoveryMap ?? this.recoveryMap,
    );
  }

  @override
  List<Object?> get props => [
        loading,
        saving,
        errorMessage,
        link,
        profile,
        pendingInvites,
        medications,
        prompts,
        recoveryMap,
      ];
}

class PatientCubit extends Cubit<PatientState> {
  final FirestorePatientRepository repository;

  StreamSubscription<PatientPlanLink?>? _linkSubscription;
  StreamSubscription<PatientProfile?>? _profileSubscription;
  StreamSubscription<List<Medication>>? _medicationsSubscription;
  StreamSubscription<List<CounselingQuestion>>? _promptsSubscription;
  StreamSubscription<Map<DateTime, List<Map<String, dynamic>>>>?
      _recoverySubscription;

  String? _watchedPlanKey;

  PatientCubit({
    required this.repository,
  }) : super(const PatientState());

  Future<void> start() async {
    emit(
      state.copyWith(
        loading: true,
        clearError: true,
      ),
    );

    await _linkSubscription?.cancel();

    _linkSubscription = repository.watchMyLink().listen(
      _handleLink,
      onError: (Object error, StackTrace stackTrace) {
        _reportError('Could not load the patient plan', error, stackTrace);
      },
    );

    // Invitation lookup uses a callable function and must never delay loading
    // an already-linked patient's Firestore plan.
    unawaited(_refreshInvitesQuietly());
  }

  Future<void> _refreshInvitesQuietly() async {
    try {
      await refreshInvites(reportErrors: false);
    } catch (error, stackTrace) {
      debugPrint('PATIENT CUBIT: Invitation check failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> refreshInvites({bool reportErrors = true}) async {
    try {
      final invites = await repository.listPendingInvites();

      if (isClosed) {
        return;
      }

      emit(
        state.copyWith(
          pendingInvites: invites,
          clearError: true,
        ),
      );
    } catch (error, stackTrace) {
      if (!reportErrors) {
        rethrow;
      }

      _reportError('Could not check invitations', error, stackTrace);
    }
  }

  Future<void> acceptInvite(PatientInvite invite) async {
    await _runMutation(
      'Could not accept the invitation',
      () async {
        await repository.acceptInvite(invite.id);
        await refreshInvites(reportErrors: false);
      },
    );
  }

  Future<void> declineInvite(PatientInvite invite) async {
    await _runMutation(
      'Could not decline the invitation',
      () async {
        await repository.declineInvite(invite.id);
        await refreshInvites(reportErrors: false);
      },
    );
  }

  Future<void> saveRecoveryProgress({
    required DateTime date,
    required List<Map<String, dynamic>> entries,
  }) async {
    final link = state.link;

    if (link == null || entries.isEmpty) {
      return;
    }

    try {
      await repository.saveRecoveryProgress(
        date: date,
        entries: entries,
      );
    } catch (error, stackTrace) {
      _reportError(
        'Medication progress was saved on this phone but could not sync',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  void clearError() {
    if (state.errorMessage == null) {
      return;
    }

    emit(state.copyWith(clearError: true));
  }

  void _handleLink(PatientPlanLink? link) {
    if (isClosed) {
      return;
    }

    if (link == null) {
      unawaited(_stopPlanListeners());

      emit(
        state.copyWith(
          loading: false,
          clearLink: true,
          clearProfile: true,
          medications: const [],
          prompts: const [],
          recoveryMap: const {},
          clearError: true,
        ),
      );
      return;
    }

    final planKey = '${link.clinicId}/${link.patientId}';

    emit(
      state.copyWith(
        loading: false,
        link: link,
        clearError: true,
      ),
    );

    if (_watchedPlanKey != planKey) {
      unawaited(_watchPlan(link));
    }
  }

  Future<void> _watchPlan(PatientPlanLink link) async {
    await _stopPlanListeners();
    _watchedPlanKey = '${link.clinicId}/${link.patientId}';

    _profileSubscription = repository.watchPatientProfile(link).listen(
      (profile) {
        if (!isClosed && _matchesCurrentLink(link)) {
          emit(
            state.copyWith(
              profile: profile,
              clearProfile: profile == null,
              clearError: true,
            ),
          );
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        _reportError('Could not load patient information', error, stackTrace);
      },
    );

    _medicationsSubscription = repository.watchMedications(link).listen(
      (medications) {
        if (!isClosed && _matchesCurrentLink(link)) {
          emit(state.copyWith(medications: medications, clearError: true));
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        _reportError('Could not load medications', error, stackTrace);
      },
    );

    _promptsSubscription = repository.watchPrompts(link).listen(
      (prompts) {
        if (!isClosed && _matchesCurrentLink(link)) {
          emit(state.copyWith(prompts: prompts, clearError: true));
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        _reportError('Could not load recovery prompts', error, stackTrace);
      },
    );

    _recoverySubscription = repository.watchRecoveryProgress(link).listen(
      (recoveryMap) {
        if (!isClosed && _matchesCurrentLink(link)) {
          emit(state.copyWith(recoveryMap: recoveryMap, clearError: true));
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        _reportError('Could not load recovery progress', error, stackTrace);
      },
    );
  }

  bool _matchesCurrentLink(PatientPlanLink link) {
    final current = state.link;
    return current != null &&
        current.clinicId == link.clinicId &&
        current.patientId == link.patientId;
  }

  Future<void> _runMutation(
    String errorPrefix,
    Future<void> Function() operation,
  ) async {
    emit(state.copyWith(saving: true, clearError: true));

    try {
      await operation();

      if (!isClosed) {
        emit(state.copyWith(saving: false, clearError: true));
      }
    } catch (error, stackTrace) {
      _reportError(errorPrefix, error, stackTrace, saving: false);
      rethrow;
    }
  }

  void _reportError(
    String prefix,
    Object error,
    StackTrace stackTrace, {
    bool? saving,
  }) {
    debugPrint('PATIENT CUBIT ERROR: $prefix: $error');
    debugPrintStack(stackTrace: stackTrace);

    if (isClosed) {
      return;
    }

    emit(
      state.copyWith(
        loading: false,
        saving: saving ?? state.saving,
        errorMessage: '$prefix: $error',
      ),
    );
  }

  Future<void> _stopPlanListeners() async {
    await _profileSubscription?.cancel();
    await _medicationsSubscription?.cancel();
    await _promptsSubscription?.cancel();
    await _recoverySubscription?.cancel();

    _profileSubscription = null;
    _medicationsSubscription = null;
    _promptsSubscription = null;
    _recoverySubscription = null;
    _watchedPlanKey = null;
  }

  @override
  Future<void> close() async {
    await _linkSubscription?.cancel();
    _linkSubscription = null;
    await _stopPlanListeners();
    return super.close();
  }
}
