
class MockBLEService {
  final List<String> mockDevices = ['MockDevice_01', 'MockDevice_02', 'TheraTouch_Dev'];

  Future<List<String>> scanForDevices() async {
    await Future.delayed(Duration(seconds: 2)); // Simulate scan delay
    return mockDevices;
  }

  Future<bool> pairWithDevice(String deviceName) async {
    await Future.delayed(Duration(seconds: 1)); // Simulate pairing
    return mockDevices.contains(deviceName);
  }

  Future<List<Map<String, String>>> fetchPrompts() async {
    return [
      {'title': 'Drink Water', 'time': '08:00 AM'},
      {'title': 'Take Medication', 'time': '12:00 PM'},
    ];
  }

  Future<List<Map<String, String>>> fetchMedications() async {
    return [
      {'name': 'Ibuprofen', 'dose': '200mg'},
      {'name': 'Vitamin D', 'dose': '1000 IU'},
    ];
  }
}