import 'package:mosaic_cli/src/commands/add_widget_command.dart';
import 'package:test/test.dart';

void main() {
  test('scaffold imports the mosaic package, not flutter', () {
    final out = widgetTemplate('Profile');
    // Widget definitions import the pure-Dart DSL (not the Flutter-dependent
    // barrel), so the build runner can execute them under `dart run`.
    expect(out, contains("import 'package:mosaic_widgets/dsl.dart';"));
    expect(out, isNot(contains("package:mosaic_widgets/mosaic_widgets.dart")));
    expect(out, isNot(contains("package:flutter/hw_dsl.dart")));
    expect(out, contains('buildProfile'));
  });

  group('widget name validation', () {
    test('PascalCase passes', () {
      expect(widgetNameProblem('StepCounter'), isNull);
    });

    test('a hyphenated name is rejected with a PascalCase suggestion', () {
      // `build my-widget()` is not parseable Dart, so this used to fail deep
      // inside the generated runner instead of here.
      final problem = widgetNameProblem('my-widget');
      expect(problem, isNotNull);
      expect(problem, contains('MyWidget'));
    });

    test('a leading digit is rejected', () {
      expect(widgetNameProblem('2Fast'), isNotNull);
    });

    test('lowerCamelCase is corrected rather than rejected outright', () {
      expect(widgetNameProblem('steps'), contains('"Steps"'));
    });

    test('an empty name is rejected', () {
      expect(widgetNameProblem(''), isNotNull);
    });

    test('underscores and digits inside the name are allowed', () {
      expect(widgetNameProblem('Widget_2'), isNull);
    });
  });

  group('choosing the target directory', () {
    test('follows where existing entries live', () {
      const yaml = '''
widgets:
  - name: News
    entry: lib/platform/widgets/news.widget.dart
  - name: Weather
    entry: lib/platform/widgets/weather.widget.dart
''';
      expect(widgetsDirFor(yaml), 'lib/platform/widgets');
    });

    test('the most common parent wins over an outlier', () {
      const yaml = '''
widgets:
  - name: A
    entry: lib/w/a.widget.dart
  - name: B
    entry: lib/w/b.widget.dart
  - name: C
    entry: lib/odd/c.widget.dart
''';
      expect(widgetsDirFor(yaml), 'lib/w');
    });

    test('falls back to lib/home_widgets with no config', () {
      expect(widgetsDirFor(null), 'lib/home_widgets');
    });

    test('falls back when the config declares no widgets', () {
      expect(widgetsDirFor('app:\n  bundle_id: x\n'), 'lib/home_widgets');
    });

    test('non-Dart entries are ignored', () {
      // Live activities and controls also use `entry:`.
      const yaml = '''
widgets:
  - name: A
    entry: lib/w/a.widget.dart
controls:
  - name: T
    entry: lib/c/t.control.txt
''';
      expect(widgetsDirFor(yaml), 'lib/w');
    });
  });

  group('registering in mosaic.yaml', () {
    const snippet = '  - name: Steps\n    entry: lib/w/steps.widget.dart\n';

    test('appends to the end of the widgets list', () {
      const yaml = '''
app:
  bundle_id: com.acme.app
widgets:
  - name: News
    entry: lib/w/news.widget.dart
''';
      final out = insertWidgetEntry(yaml, snippet)!;
      expect(out, contains('name: Steps'));
      expect(out.indexOf('name: News'), lessThan(out.indexOf('name: Steps')));
    });

    test('inserts before the next top-level key, not after it', () {
      const yaml = '''
widgets:
  - name: News
    entry: lib/w/news.widget.dart
refresh:
  refresh_news:
    url: https://example.com
''';
      final out = insertWidgetEntry(yaml, snippet)!;
      expect(out.indexOf('name: Steps'), lessThan(out.indexOf('refresh:')));
      expect(out, contains('url: https://example.com'));
    });

    test('a blank line before the next key is preserved', () {
      const yaml = '''
widgets:
  - name: News
    entry: lib/w/news.widget.dart

strings:
  en: {}
''';
      final out = insertWidgetEntry(yaml, snippet)!;
      expect(out.indexOf('name: Steps'), lessThan(out.indexOf('strings:')));
      expect(out, contains('\n\nstrings:'));
    });

    test('a widgets list at end of file is handled', () {
      const yaml = 'widgets:\n  - name: News\n    entry: lib/w/news.dart\n';
      expect(insertWidgetEntry(yaml, snippet), contains('name: Steps'));
    });

    test('returns null when there is no widgets key', () {
      expect(insertWidgetEntry('app:\n  bundle_id: x\n', snippet), isNull);
    });
  });

  group('the scaffolded template', () {
    test('declares the builder the config will look for', () {
      expect(widgetTemplate('Steps'),
          contains('MosaicDefinition buildSteps()'));
      expect(widgetTemplate('Steps'), contains('name: "Steps"'));
    });

    test('sets an explicit grid size', () {
      // Omitting these silently falls back to 2x2, which is rarely intended.
      expect(widgetTemplate('Steps'), contains('width: 2'));
      expect(widgetTemplate('Steps'), contains('height: 2'));
    });

    test('the generated snippet needs no platform blocks', () {
      // android:/ios: are optional now, so a minimal entry is two lines.
      final snip = widgetConfigSnippet('Steps', 'lib/w/steps.widget.dart');
      expect(snip, contains('name: Steps'));
      expect(snip, isNot(contains('min_sdk')));
      expect(snip, isNot(contains('families')));
    });
  });

  group('live activity and control scaffolds', () {
    test('the live activity template supplies every required island slot', () {
      // MDynamicIsland requires all four; omitting `minimal` failed the build
      // with "Required named parameter 'minimal' must be provided".
      final out = liveActivityTemplate('Delivery');
      expect(out, contains('MosaicLiveActivity buildDelivery()'));
      for (final slot in ['compactLeading', 'compactTrailing', 'minimal', 'expanded']) {
        expect(out, contains('$slot:'), reason: '$slot missing');
      }
    });

    test('the control template sets valueKey for a toggle', () {
      // A toggle without it has no bound bool to reflect, and the iOS generator
      // used to hard-cast the key and die.
      final out = controlTemplate('Flashlight');
      expect(out, contains('MControl buildFlashlight()'));
      expect(out, contains('valueKey: "flashlight_on"'));
      expect(out, contains('MToggleAction("flashlight_on")'));
    });

    test('the control template references no drawable by default', () {
      // ic_launcher lives in res/mipmap, not res/drawable, so referencing it
      // failed Kotlin compilation on a fresh Flutter project.
      final out = controlTemplate('Flashlight');
      expect(out, isNot(contains(RegExp(r'^\s*androidIcon:', multiLine: true))));
    });
  });

  group('inserting under an arbitrary key', () {
    const snippet = '  - name: Order\n    entry: lib/order.live.dart\n';

    test('a missing key is created', () {
      // live_activities:/controls: are optional and usually absent.
      final out = insertUnderKey('widgets: []\n', 'live_activities', snippet)!;
      expect(out, contains('live_activities:'));
      expect(out, contains('name: Order'));
    });

    test('an existing key is appended to', () {
      const yaml = 'live_activities:\n  - name: A\n    entry: lib/a.dart\n';
      final out = insertUnderKey(yaml, 'live_activities', snippet)!;
      expect('name:'.allMatches(out).length, 2);
    });

    test('createIfMissing false returns null for an absent key', () {
      expect(
        insertUnderKey('widgets: []\n', 'controls', snippet,
            createIfMissing: false),
        isNull,
      );
    });
  });
}
