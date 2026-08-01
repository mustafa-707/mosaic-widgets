import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// View ids used to be derived from the bind key alone, so the same value shown
/// twice produced two views with the SAME id. RemoteViews acts on the first
/// match only, so every later occurrence silently never updated — no error, no
/// log, just a stale or blank view.
///
/// It bit binds (iteration 10) and MVisibility (iteration 27) before this sweep
/// found it in five more places at once. Showing one value in two spots is
/// ordinary — a figure in a header and a footer, an avatar twice, a unit toggle
/// driving two rows — so every per-key id is checked here.
void main() {
  /// Every node kind that allocates a view id from a bind key.
  const duplicatePairs = <String, List<Map<String, dynamic>>>{
    'text': [
      {
        '__type': 'HWText',
        'text': {'__type': 'HWBind', 'key': 'k'}
      },
      {
        '__type': 'HWText',
        'text': {'__type': 'HWBind', 'key': 'k'}
      },
    ],
    'progress': [
      {
        '__type': 'HWProgressBar',
        'value': {'__type': 'HWBind', 'key': 'k'},
        'max': 100
      },
      {
        '__type': 'HWProgressBar',
        'value': {'__type': 'HWBind', 'key': 'k'},
        'max': 100
      },
    ],
    'gauge': [
      {
        '__type': 'HWGauge',
        'value': {'__type': 'HWBind', 'key': 'k'},
        'max': 100
      },
      {
        '__type': 'HWGauge',
        'value': {'__type': 'HWBind', 'key': 'k'},
        'max': 100
      },
    ],
    'networkImage': [
      {
        '__type': 'HWNetworkImage',
        'url': {'__type': 'HWBind', 'key': 'k'}
      },
      {
        '__type': 'HWNetworkImage',
        'url': {'__type': 'HWBind', 'key': 'k'}
      },
    ],
    'sparkline': [
      {
        '__type': 'HWSparkline',
        'bind': {'__type': 'HWBind', 'key': 'k'}
      },
      {
        '__type': 'HWSparkline',
        'bind': {'__type': 'HWBind', 'key': 'k'}
      },
    ],
    'barChart': [
      {
        '__type': 'HWBarChart',
        'bind': {'__type': 'HWBind', 'key': 'k'}
      },
      {
        '__type': 'HWBarChart',
        'bind': {'__type': 'HWBind', 'key': 'k'}
      },
    ],
    'semantics': [
      {
        '__type': 'HWSemantics',
        'label': {'__type': 'HWBind', 'key': 'k'},
        'child': {'__type': 'HWText', 'text': 'a'}
      },
      {
        '__type': 'HWSemantics',
        'label': {'__type': 'HWBind', 'key': 'k'},
        'child': {'__type': 'HWText', 'text': 'b'}
      },
    ],
    'visibility': [
      {
        '__type': 'HWVisibility',
        'bind': {'__type': 'HWBind', 'key': 'k'},
        'child': {'__type': 'HWText', 'text': 'a'},
        'replacement': {'__type': 'HWText', 'text': 'b'}
      },
      {
        '__type': 'HWVisibility',
        'bind': {'__type': 'HWBind', 'key': 'k'},
        'child': {'__type': 'HWText', 'text': 'c'},
        'replacement': {'__type': 'HWText', 'text': 'd'}
      },
    ],
  };

  for (final entry in duplicatePairs.entries) {
    test('${entry.key}: the same key twice yields distinct ids', () async {
      final r = await runAndroid([
        irDef({'__type': 'HWColumn', 'children': entry.value})
      ]);
      final xml = r.file('android/app/src/main/res/layout/hw_testw.xml');
      final ids = RegExp(r'android:id="@\+id/([a-z0-9_]+)"')
          .allMatches(xml)
          .map((m) => m.group(1)!)
          .toList();
      expect(ids, isNotEmpty, reason: 'no ids emitted for ${entry.key}');
      expect(
        ids.length,
        ids.toSet().length,
        reason: 'duplicate ids for ${entry.key}: $ids',
      );
    });

    test('${entry.key}: every id is driven by the provider', () async {
      // A unique id that nothing updates is the same blank view by another
      // route.
      final r = await runAndroid([
        irDef({'__type': 'HWColumn', 'children': entry.value})
      ]);
      final xml = r.file('android/app/src/main/res/layout/hw_testw.xml');
      final kt = r.file(
          'android/app/src/main/kotlin/com/acme/app/mosaic_generated/TestWProvider.kt');
      final undriven = RegExp(r'android:id="@\+id/([a-z0-9_]+)"')
          .allMatches(xml)
          .map((m) => m.group(1)!)
          .where((id) => !kt.contains('R.id.$id'))
          .toList();
      expect(undriven, isEmpty,
          reason: '${entry.key}: ids never updated -> $undriven');
    });
  }
}
