import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../GetStarted/get_started.dart';

class MockBLEScannerWidget extends StatelessWidget {
  const MockBLEScannerWidget({Key? key}) : super(key: key);


  @override
  Widget build(BuildContext context) {
    final mockDevice = MockBluetoothDevice(
      name: 'Mock BLE Device',
      id: '00:11:22:33:44:55',
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Mock BLE Scanner')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const GetStartedPage(
                  device: null,
                  isMockDevice: true, // This tells GetStartedPage to simulate a device
                ),
              ),
            );
          },
          child: const Text('Connect to Mock Device'),
        ),
      ),
    );
  }
}

class MockBluetoothDevice {
  final String name;
  final String id;

  MockBluetoothDevice({required this.name, required this.id});
}