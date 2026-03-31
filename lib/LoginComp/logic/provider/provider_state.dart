import 'package:equatable/equatable.dart';
import '../../../models/medication.dart';
import '../../../models/counseling_question.dart';
import 'provider_user.dart';

class ProviderState extends Equatable {
  final bool loading;
  final List<ProviderUser> users;
  final ProviderUser? selectedUser;

  // Recovery progress (BLE-style structured entries)
  final Map<DateTime, List<Map<String, dynamic>>>? recoveryMap;

  // Using Medication model
  final List<Medication> demoMedications;

  // Using CounselingQuestion model
  final List<CounselingQuestion> demoPrompts;

  const ProviderState({
    this.loading = false,
    this.users = const [],
    this.selectedUser,
    this.recoveryMap,
    this.demoMedications = const [],
    this.demoPrompts = const [],
  });

  ProviderState copyWith({
    bool? loading,
    List<ProviderUser>? users,
    ProviderUser? selectedUser,
    Map<DateTime, List<Map<String, dynamic>>>? recoveryMap,
    List<Medication>? demoMedications,
    List<CounselingQuestion>? demoPrompts,
  }) {
    return ProviderState(
      loading: loading ?? this.loading,
      users: users ?? this.users,
      selectedUser: selectedUser ?? this.selectedUser,
      recoveryMap: recoveryMap ?? this.recoveryMap,
      demoMedications: demoMedications ?? this.demoMedications,
      demoPrompts: demoPrompts ?? this.demoPrompts,
    );
  }

  @override
  List<Object?> get props => [
        loading,
        users,
        selectedUser,
        recoveryMap,
        demoMedications,
        demoPrompts,
      ];
}
