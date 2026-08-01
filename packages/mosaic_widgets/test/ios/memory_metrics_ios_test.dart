import 'package:mosaic_widgets/src/core/core.dart';
import 'package:test/test.dart';
import 'support/gen_harness.dart';

/// Free/total RAM on iOS.
///
/// A first pass wrote only `os_proc_available_memory` — this process's own
/// headroom — and skipped total and used-percent entirely, on the belief that a
/// sandboxed app cannot see the device's RAM. It can: `physicalMemory` is
/// public Foundation and `host_statistics64` is Mach, not private API. Until
/// this read them properly the demo's memory widget rendered
/// "0 MB free / 0 MB total" on a real device.
IRDefinition _using(String key) => IRDefinition(
      name: 'TestW',
      root: IRNode.fromJson({
        '__type': 'HWText',
        'text': {'__type': 'HWBind', 'key': key},
        'style': {},
      }),
    );

void main() {
  String core(r) =>
      readFile(r.file('ios/HomeWidgetExtension/HomeWidgetCore.swift'));

  test('total RAM comes from ProcessInfo, which is public API', () async {
    final s = core(await runIos([_using('mosaic_memory_total_mb')]));
    expect(s, contains('ProcessInfo.processInfo.physicalMemory'));
    expect(s, contains('mosaic_memory_total_mb'));
  });

  test('free RAM reads the VM statistics', () async {
    final s = core(await runIos([_using('mosaic_memory_free_mb')]));
    expect(s, contains('host_statistics64'));
    expect(s, contains('HOST_VM_INFO64'));
    // Inactive pages are reclaimable on demand; counting only free_count reads
    // far below any figure a user would recognise from their settings screen.
    expect(s, contains('vmStats.inactive_count'));
  });

  test('a refused Mach call still writes something', () async {
    // Returning zero would render as "0 MB free", which reads as broken rather
    // than unavailable.
    final s = core(await runIos([_using('mosaic_memory_free_mb')]));
    expect(s, contains('KERN_SUCCESS'));
    expect(s, contains('os_proc_available_memory'));
  });

  test('used percent cannot exceed 100', () async {
    // free and total come from different APIs, so nothing guarantees free <=
    // total; an unclamped subtraction would underflow UInt64 and produce a
    // gigantic percentage.
    final s = core(await runIos([_using('mosaic_memory_used_percent')]));
    expect(s, contains('min(freeBytes, totalBytes)'));
  });

  test('a project using no memory metric reads none', () async {
    final s = core(await runIos([_using('something_else')]));
    expect(s, isNot(contains('host_statistics64')));
    expect(s, isNot(contains('physicalMemory')));
  });
}
