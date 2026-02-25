// lib/logic/provider/provider_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'provider_state.dart';
import 'provider_user.dart';

class ProviderCubit extends Cubit<ProviderState> {
  ProviderCubit() : super(const ProviderState());

  Future<void> loadClinicData(String? clinicCode) async {
    emit(state.copyWith(loading: true));

    // TODO: replace this with real data (from Hive/Firestore/BLE/etc.)
    await Future.delayed(const Duration(milliseconds: 500));

    final demoUsers = <ProviderUser>[
      ProviderUser(
        id: 'u1',
        displayName: 'Demo User 1',
        deviceId: 'DEV-001',
        startDate: DateTime.now().subtract(const Duration(days: 10)),
        latestEntryDate: DateTime.now().subtract(const Duration(days: 1)),
      ),
      ProviderUser(
        id: 'u2',
        displayName: 'Demo User 2',
        deviceId: 'DEV-002',
        startDate: DateTime.now().subtract(const Duration(days: 5)),
        latestEntryDate: DateTime.now(),
      ),
    ];

    // Demo recovery map
    final demoRecovery = <DateTime, List<String>>{
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day): [
        'Medication Taken: 08:00',
        'Prompt: How stressed are you? Response: 4',
      ],
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day): [
        'Medication Taken: 09:00',
        'Prompt: How stressed are you? Response: 6',
      ],
    };

    emit(
      state.copyWith(
        loading: false,
        users: demoUsers,
        selectedUser: demoUsers.first,
        recoveryMap: demoRecovery,
      ),
    );
  }

  void selectUser(ProviderUser user) {
    emit(state.copyWith(selectedUser: user));
  }

// Later you can add:
// void updateRecoveryMap(Map<DateTime, List<String>> map) { ... }
}