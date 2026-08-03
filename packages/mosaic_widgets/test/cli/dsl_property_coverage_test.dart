import 'dart:io';

import 'package:test/test.dart';

/// Every property the DSL puts on the wire has to be read by both generators,
/// or be a deliberate, documented platform difference.
///
/// Node-level gaps are easy to notice — a whole widget renders as nothing.
/// Property-level gaps are not: the widget appears, looks almost right, and one
/// argument the developer passed is quietly discarded. `MSemantics.excludeChildren`
/// sat unread on Android that way, behind a doc claim that RemoteViews made it
/// impossible; it took one attribute in a layout this repo already writes.
///
/// When this fails, either read the key in that generator, or add it below with
/// the reason. Adding to the allowlist without documenting the limit in
/// `docs/DSL_REFERENCE.md` is the failure this guards against.
void main() {
  /// key -> the DSL symbol whose documented platform note covers it. The
  /// reference has to mention that symbol, so the developer can find out the
  /// argument does nothing on their platform.
  const androidExempt = {
    // SF Symbols are an Apple font; Android uses androidDrawable.
    'sfSymbol': 'sfSymbol',
    // Widget tinting is iOS 18+; Android has no equivalent.
    'accentedMode': 'MAccentedRendering',
    // SwiftUI numeric content transition; RemoteViews cannot animate text.
    'contentTransition': 'contentTransition',
    // The island is iOS hardware, so the region tree is never read.
    'dynamicIsland': 'MDynamicIsland',
  };
  const iosExempt = {
    // Android drawable resource; iOS uses sfSymbol.
    'androidDrawable': 'androidDrawable',
    // SwiftUI has no proportional flex — siblings share space equally.
    'flex': 'MFlexible',
    // MFlipper is Android-only; iOS renders the first child.
    'intervalMs': 'MFlipper',
    // Android launcher icon for a control tile; iOS uses sfSymbol.
    'androidIcon': 'androidIcon',
  };

  /// Whole wire types one platform has no counterpart for. Listing the type
  /// rather than each of its keys keeps a new Dynamic Island region from
  /// needing an entry here just to stay green.
  const androidExemptTypes = {
    // No Android counterpart: the Dynamic Island is iPhone hardware.
    'HWDynamicIsland': 'MDynamicIsland',
    'HWExpanded': 'MExpanded',
  };

  /// Types where each generator reading only *part* of the node is the point.
  ///
  /// `MAdaptive` holds one subtree per platform and each generator emits only
  /// its own, so "Android never reads .ios" is the feature working, not a
  /// dropped property.
  const bothExemptTypes = {'HWAdaptive': 'MAdaptive'};

  /// Keys the DSL emits, grouped by wire type.
  Map<String, Set<String>> emittedByType() {
    final src = File('lib/dsl.dart').readAsStringSync();
    final out = <String, Set<String>>{};
    final blocks = RegExp(r'toJson\(\)\s*(?:=>|\{\s*return)\s*\{(.*?)\n\s*\};',
        dotAll: true);
    for (final m in blocks.allMatches(src)) {
      final body = m.group(1)!;
      final type = RegExp(r"'__type':\s*'(\w+)'").firstMatch(body)?.group(1);
      if (type == null) continue;
      final keys = RegExp(r"'(\w+)':")
          .allMatches(body)
          .map((k) => k.group(1)!)
          .where((k) => k != '__type')
          .toSet();
      (out[type] ??= <String>{}).addAll(keys);
    }
    return out;
  }

  /// Every `['key']` subscript any file under a generator's lib/ reads.
  ///
  /// Deliberately not just `data['key']`: controls, Dynamic Island regions and
  /// binds are consumed through their own maps (`control['kind']`,
  /// `island['compactLeading']`), and narrowing to one variable name reported
  /// all of them as gaps.
  Set<String> keysReadBy(String libDir) {
    final keys = <String>{};
    for (final f in Directory(libDir)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      keys.addAll(RegExp(r"\['(\w+)'\]")
          .allMatches(f.readAsStringSync())
          .map((m) => m.group(1)!));
    }
    return keys;
  }

  test('the DSL emits something to read', () {
    // A regex that silently matches nothing would make every check below pass.
    final emitted = emittedByType();
    expect(emitted.length, greaterThan(20));
    expect(emitted['HWSemantics'], contains('excludeChildren'));
  });

  test('no DSL property is silently dropped by a generator', () {
    final emitted = emittedByType();
    final platforms = {
      'Android': (
        keys: keysReadBy('lib/src/android'),
        exempt: androidExempt,
        types: {...androidExemptTypes.keys, ...bothExemptTypes.keys},
      ),
      'iOS': (
        keys: keysReadBy('lib/src/ios'),
        exempt: iosExempt,
        types: bothExemptTypes.keys.toSet(),
      ),
    };

    final gaps = <String>[];
    for (final entry in platforms.entries) {
      for (final type in emitted.keys.toList()..sort()) {
        if (entry.value.types.contains(type)) continue;
        for (final key in emitted[type]!.toList()..sort()) {
          if (entry.value.keys.contains(key)) continue;
          if (entry.value.exempt.containsKey(key)) continue;
          gaps.add('${entry.key}: $type.$key');
        }
      }
    }

    expect(gaps, isEmpty,
        reason: 'These DSL properties reach the wire and are never read:\n'
            '  ${gaps.join('\n  ')}\n'
            'Implement them, or add the key to the exempt map above with the '
            'reason and document the limit in docs/DSL_REFERENCE.md.');
  });

  test('every exemption is documented for developers', () {
    // An exemption is a promise to the developer that the argument does nothing
    // on that platform. If the reference does not say so, they cannot know.
    final ref = File('../../docs/DSL_REFERENCE.md').readAsStringSync();
    for (final entry in {
      ...androidExempt,
      ...iosExempt,
      ...androidExemptTypes,
      ...bothExemptTypes,
    }.entries) {
      expect(ref, contains(entry.value),
          reason: '${entry.key} is exempted from one platform, but '
              '${entry.value} is never mentioned in docs/DSL_REFERENCE.md');
    }
  });
}
