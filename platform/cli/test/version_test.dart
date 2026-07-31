import 'dart:io';

import 'package:mosaic_cli/src/version.dart';
import 'package:test/test.dart';

void main() {
  test('--version matches pubspec.yaml', () {
    // A hard-coded constant drifts silently; this makes a release bump fail
    // loudly until both are updated.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final declared =
        RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec);
    expect(declared, isNotNull, reason: 'pubspec.yaml has no version');
    expect(packageVersion, declared!.group(1));
  });
}
