import 'dart:async';

class MockBLEService {
  // Simulates finding devices
  Future<List<String>> scanForDevices() async {
    await Future.delayed(const Duration(seconds: 1));
    return ["Dispenser_Unit_A1", "NODE_Pill_Box_04", "MedTracker_v2"];
  }

  // Simulates pairing
  Future<bool> pairWithDevice(String name) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return true; // Always succeeds for mock
  }

  // THIS IS THE MISSING METHOD
  Future<void> writeToDevice(String data) async {
    await Future.delayed(const Duration(milliseconds: 800));
    print("MOCK BLE: Received Configuration File:");
    print(data);
  }

  // Keep your existing mock fetch methods if they are used elsewhere
  Future<List<Map<String, dynamic>>> fetchMedications() async {
    return []; // No longer needed for our provider flow, but kept for compatibility
  }
}