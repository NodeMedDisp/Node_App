import 'package:equatable/equatable.dart';

import '../../../models/counseling_question.dart';
import '../../../models/medication.dart';
import 'provider_user.dart';

class ProviderState extends Equatable {
  final bool loading;
  final bool saving;
  final String? errorMessage;

  final List<ProviderUser> users;
  final ProviderUser? selectedUser;

  final Map<DateTime, List<Map<String, dynamic>>>? recoveryMap;

  final List<Medication> selectedMedications;
  final List<CounselingQuestion> selectedPrompts;

  const ProviderState({
    this.loading = false,
    this.saving = false,
    this.errorMessage,
    this.users = const [],
    this.selectedUser,
    this.recoveryMap,
    this.selectedMedications = const [],
    this.selectedPrompts = const [],
  });

  ProviderState copyWith({
    bool? loading,
    bool? saving,
    String? errorMessage,
    bool clearError = false,
    List<ProviderUser>? users,
    ProviderUser? selectedUser,
    bool clearSelectedUser = false,
    Map<DateTime, List<Map<String, dynamic>>>? recoveryMap,
    List<Medication>? selectedMedications,
    List<CounselingQuestion>? selectedPrompts,
  }) {
    return ProviderState(
      loading: loading ?? this.loading,
      saving: saving ?? this.saving,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      users: users ?? this.users,
      selectedUser:
          clearSelectedUser ? null : selectedUser ?? this.selectedUser,
      recoveryMap: recoveryMap ?? this.recoveryMap,
      selectedMedications: selectedMedications ?? this.selectedMedications,
      selectedPrompts: selectedPrompts ?? this.selectedPrompts,
    );
  }

  @override
  List<Object?> get props => [
        loading,
        saving,
        errorMessage,
        users,
        selectedUser,
        recoveryMap,
        selectedMedications,
        selectedPrompts,
      ];
}
