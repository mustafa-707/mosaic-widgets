import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every public DSL symbol must appear in `docs/DSL_REFERENCE.md`.
///
/// A third of the API had drifted out of the reference — `MIcon`, `MGauge`,
/// `MDivider`, `MBadge`, `MSemantics`, `MDeviceValue`, `MNetworkImage` and more
/// were all shipped, tested, and impossible to look up. Nothing failed, because
/// nothing was checking.
void main() {
  test('every public DSL symbol is in DSL_REFERENCE.md', () {
    final dsl = File('lib/dsl.dart').readAsStringSync();
    // The reference lives at the repo root, two levels up from platform/flutter.
    final refFile = File('../../docs/DSL_REFERENCE.md');
    expect(refFile.existsSync(), isTrue,
        reason: 'DSL_REFERENCE.md not found at ${refFile.absolute.path}');
    final ref = refFile.readAsStringSync();

    final symbols = RegExp(r'^(?:class|enum)\s+(M[A-Za-z0-9]+)', multiLine: true)
        .allMatches(dsl)
        .map((m) => m.group(1)!)
        .toSet()
        .toList()
      ..sort();

    expect(symbols, isNotEmpty, reason: 'no DSL symbols parsed');

    final undocumented = symbols
        .where((s) => !RegExp('\\b$s\\b').hasMatch(ref))
        .toList();

    expect(
      undocumented,
      isEmpty,
      reason: 'Add these to docs/DSL_REFERENCE.md: ${undocumented.join(', ')}',
    );
  });
}
