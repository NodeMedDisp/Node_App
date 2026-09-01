import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class NodeBleFileTransferService {
  const NodeBleFileTransferService();

  static const String _nodeServiceUuid = 'ffe0';
  static const String _nodeFileCharacteristicUuid = 'ffe1';

  /// Twenty bytes preserves compatibility with the current NODE firmware
  /// and the existing patient Recovery Summary transfer.
  static const int _chunkSize = 20;

  Future<void> send({
    required BluetoothDevice device,
    required String fileContents,
  }) async {
    if (fileContents.trim().isEmpty) {
      throw StateError('The recovery-program file is empty.');
    }

    debugPrint(
      'NODE BLE: Discovering services on ${device.remoteId}',
    );

    final services = await device.discoverServices();

    BluetoothCharacteristic? targetCharacteristic;

    for (final service in services) {
      debugPrint('NODE BLE: Service ${service.uuid}');

      if (!_uuidMatches(service.uuid, _nodeServiceUuid)) {
        continue;
      }

      for (final characteristic in service.characteristics) {
        debugPrint(
          'NODE BLE: Characteristic ${characteristic.uuid} '
          'write=${characteristic.properties.write}',
        );

        if (_uuidMatches(
              characteristic.uuid,
              _nodeFileCharacteristicUuid,
            ) &&
            characteristic.properties.write) {
          targetCharacteristic = characteristic;
          break;
        }
      }

      if (targetCharacteristic != null) {
        break;
      }
    }

    if (targetCharacteristic == null) {
      final discoveredServices =
          services.map((service) => service.uuid.toString()).join(', ');

      throw StateError(
        'NODE characteristic FFE1 was not found. '
        'Discovered services: $discoveredServices',
      );
    }

    // EOF is a transport marker. It is not part of the clean local file.
    final payload = '${fileContents.trimRight()}\nEOF\n';
    final bytes = utf8.encode(payload);

    debugPrint(
      'NODE BLE: Sending ${bytes.length} bytes '
      'in $_chunkSize-byte chunks',
    );

    for (var offset = 0; offset < bytes.length; offset += _chunkSize) {
      final end = (offset + _chunkSize < bytes.length)
          ? offset + _chunkSize
          : bytes.length;

      final chunk = bytes.sublist(offset, end);

      await targetCharacteristic.write(
        chunk,
        withoutResponse: false,
      );
    }

    debugPrint(
      'NODE BLE: Transfer completed for ${device.remoteId}',
    );
  }

  static bool _uuidMatches(
    Object uuid,
    String shortUuid,
  ) {
    final normalized =
        uuid.toString().toLowerCase().replaceAll(RegExp('[^0-9a-f]'), '');

    return normalized == shortUuid || normalized.startsWith('0000$shortUuid');
  }
}
