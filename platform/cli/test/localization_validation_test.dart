import 'package:mosaic_cli/src/validate.dart';
import 'package:mosaic_core/mosaic_core.dart';
import 'package:test/test.dart';

MosaicConfig configWith(Map<String, Map<String, String>> strings) =>
    MosaicConfig.fromJson({
      'app': {
        'bundle_id': 'com.acme.app',
        'android_package': 'com.acme.app',
        'ios_app_group': 'group.com.acme.app.widgets',
      },
      'widgets': [
        {
          'name': 'TestW',
          'entry': 'TestW',
          'android': {'min_sdk': 21, 'sizes': ['medium']},
          'ios': {'families': ['systemMedium']},
        },
      ],
      if (strings.isNotEmpty) 'strings': strings,
    });

IRDefinition defWithKeys(List<String> keys) => IRDefinition.fromJson({
      'name': 'TestW',
      'width': 4,
      'height': 2,
      'root': {
        '__type': 'HWColumn',
        'children': [
          for (final k in keys)
            {
              '__type': 'HWText',
              'text': {'__type': 'HWLocalized', 'key': k},
            },
        ],
      },
    });

void main() {
  test('finds every MLocalized key in the tree', () {
    final keys = referencedStringKeys([defWithKeys(['a', 'b'])]);
    expect(keys, {'a', 'b'});
  });

  test('a plain-text widget references no keys', () {
    final def = IRDefinition.fromJson({
      'name': 'TestW',
      'width': 4,
      'height': 2,
      'root': {'__type': 'HWText', 'text': 'literal'},
    });
    expect(referencedStringKeys([def]), isEmpty);
  });

  test('no strings: block at all is fatal, and names the key', () {
    final problems =
        validateStringKeys([defWithKeys(['greeting'])], configWith({}));
    expect(problems, hasLength(1));
    expect(problems.single.fatal, isTrue);
    expect(problems.single.message, contains('greeting'));
    expect(problems.single.message, contains('`strings:`'));
  });

  test('a key missing from the default locale is fatal', () {
    // Present in `ar` only: Android would write it to values-ar/ with no entry
    // in the unqualified values/ table, so an English device has no fallback.
    final problems = validateStringKeys(
      [defWithKeys(['greeting'])],
      configWith({
        'en': {'other': 'Other'},
        'ar': {'greeting': 'مرحبا'},
      }),
    );
    expect(problems.where((p) => p.fatal), hasLength(1));
    expect(problems.first.message, contains('default locale "en"'));
  });

  test('a key missing from a secondary locale is advisory, not fatal', () {
    final problems = validateStringKeys(
      [defWithKeys(['greeting'])],
      configWith({
        'en': {'greeting': 'Hello'},
        'ar': <String, String>{},
      }),
    );
    expect(problems.any((p) => p.fatal), isFalse);
    expect(problems, hasLength(1));
    expect(problems.single.message, contains('Locale "ar"'));
    expect(problems.single.message, contains('greeting'));
  });

  test('fully declared keys produce no problems', () {
    final problems = validateStringKeys(
      [defWithKeys(['greeting', 'bye'])],
      configWith({
        'en': {'greeting': 'Hello', 'bye': 'Bye'},
        'ar': {'greeting': 'مرحبا', 'bye': 'وداعا'},
      }),
    );
    expect(problems, isEmpty);
  });

  test('unused declared keys are not reported', () {
    final problems = validateStringKeys(
      [defWithKeys(['greeting'])],
      configWith({
        'en': {'greeting': 'Hello', 'never_used': 'x'},
      }),
    );
    expect(problems, isEmpty);
  });

  test('widgets with no localized text skip the check entirely', () {
    final def = IRDefinition.fromJson({
      'name': 'TestW',
      'width': 4,
      'height': 2,
      'root': {'__type': 'HWText', 'text': 'literal'},
    });
    expect(validateStringKeys([def], configWith({})), isEmpty);
  });
}
