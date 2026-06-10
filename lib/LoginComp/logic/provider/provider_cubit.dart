import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../models/medication.dart';
import '../../../models/counseling_question.dart';
import 'provider_state.dart';
import 'provider_user.dart';

class ProviderCubit extends Cubit<ProviderState> {
  ProviderCubit() : super(const ProviderState());

  // Per-user demo data stored as model objects
  final Map<String, List<Medication>> _demoMedicationsByUser = {
    "u1": [
      Medication(
        name: "Aspirin",
        dose: "100mg",
        times: "8:00 PM",
        frequency: "Daily",
        numDays: 30,
      ),
      Medication(
        name: "Buprenorphine",
        dose: "8mg",
        times: "9:00 PM",
        frequency: "Daily",
        numDays: 30,
      ),
    ],
    "u2": [
      Medication(
        name: "Naloxone",
        dose: "4mg",
        times: "10:00",
        frequency: "Daily",
        numDays: 30,
      ),
      Medication(
        name: "Ibuprofen",
        dose: "200mg",
        times: "14:00",
        frequency: "Daily",
        numDays: 30,
      ),
    ],
  };

  final Map<String, List<CounselingQuestion>> _demoPromptsByUser = {
    "u1": [
      CounselingQuestion(
        prompt: "How stressed are you today?",
        resReq: "number",
        options: const [],
        numberOfDays: 30,
      ),
      CounselingQuestion(
        prompt: "Did you sleep well last night?",
        resReq: "yes_no",
        options: const [],
        numberOfDays: 30,
      ),
    ],
    "u2": [
      CounselingQuestion(
        prompt: "How is your pain level today?",
        resReq: "number",
        options: const [],
        numberOfDays: 30,
      ),
      CounselingQuestion(
        prompt: "Have you felt cravings today?",
        resReq: "yes_no",
        options: const [],
        numberOfDays: 30,
      ),
    ],
  };

  Future<void> loadClinicData(String? clinicCode) async {
    emit(state.copyWith(loading: true, demoMedications: [], demoPrompts: []));

    await Future.delayed(const Duration(milliseconds: 500));

    final demoUsers = <ProviderUser>[
      ProviderUser(
        id: 'u1',
        displayName: 'Demo User 1',
        deviceId: 'DEV-001',
        startDate: DateTime.now().subtract(const Duration(days: 10)),
        latestEntryDate: DateTime.now(),
      ),
      ProviderUser(
        id: 'u2',
        displayName: 'Demo User 2',
        deviceId: 'DEV-002',
        startDate: DateTime.now().subtract(const Duration(days: 5)),
        latestEntryDate: DateTime.now(),
      ),
    ];

    final firstUser = demoUsers.first;

    emit(
      state.copyWith(
        loading: false,
        users: demoUsers,
        selectedUser: firstUser,
        demoMedications: List.from(_demoMedicationsByUser[firstUser.id] ?? []),
        demoPrompts: List.from(_demoPromptsByUser[firstUser.id] ?? []),
      ),
    );
  }

  void selectUser(ProviderUser user) {
    // 1. Clear current demo data immediately to avoid leakage during transition
    emit(state.copyWith(demoMedications: [], demoPrompts: []));

    // 2. Load the specific user's data
    emit(
      state.copyWith(
        selectedUser: user,
        demoMedications: List.from(_demoMedicationsByUser[user.id] ?? []),
        demoPrompts: List.from(_demoPromptsByUser[user.id] ?? []),
      ),
    );
  }

  /// NEW: Creates a new patient based on data received from a Bluetooth device
  void importPatientFromDevice({
    required String deviceName,
    required List<Map<String, dynamic>> medications,
  }) {
    // Create a unique ID and new User object
    final String newId = "imported_${DateTime.now().millisecondsSinceEpoch}";
    final newUser = ProviderUser(
      id: newId,
      displayName: "Patient ($deviceName)",
      deviceId: deviceName,
      startDate: DateTime.now(),
      latestEntryDate: DateTime.now(),
    );

    // Convert raw maps from the parser into Medication model objects
    final List<Medication> medObjects = medications.map((m) {
      return Medication(
        name: m['name'] ?? 'Unknown Med',
        dose: m['dose'] ?? 'Unknown Dose',
        times: m['times'] ?? '12:00 PM',
        frequency: m['frequency'] ?? 'Daily',
        numDays: m['numDays'] ?? 30,
      );
    }).toList();

    // Store in our local maps
    _demoMedicationsByUser[newId] = medObjects;
    _demoPromptsByUser[newId] = []; // Start with no prompts for imported users

    // Update state with the new user list and select the new user
    final List<ProviderUser> updatedUsers = List.from(state.users)..add(newUser);

    emit(state.copyWith(
      users: updatedUsers,
      selectedUser: newUser,
      demoMedications: medObjects,
      demoPrompts: [],
    ));
  }

  void addMedicationToSelectedUser(Medication med) {
    final user = state.selectedUser;
    if (user == null) return;

    final currentMeds = _demoMedicationsByUser[user.id] ?? [];
    currentMeds.add(med);
    _demoMedicationsByUser[user.id] = currentMeds;

    emit(state.copyWith(demoMedications: List.from(currentMeds)));
  }

  void addPromptToSelectedUser(CounselingQuestion prompt) {
    final user = state.selectedUser;
    if (user == null) return;

    final currentPrompts = _demoPromptsByUser[user.id] ?? [];
    currentPrompts.add(prompt);
    _demoPromptsByUser[user.id] = currentPrompts;

    emit(state.copyWith(demoPrompts: List.from(currentPrompts)));
  }
}