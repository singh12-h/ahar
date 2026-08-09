import 'dart:io';

void main() {
  final file = File('c:/Project/ahar_flutter/lib/main.dart');
  final lines = file.readAsLinesSync();
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.contains('saasRegisteredDevices') || line.contains('deviceName') || line.contains('PIN:')) {
      print('main.dart:${i + 1}: ${line.trim()}');
    }
  }
}
