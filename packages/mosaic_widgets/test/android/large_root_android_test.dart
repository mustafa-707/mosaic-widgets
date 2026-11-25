import 'package:mosaic_widgets/src/core/core.dart';
import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

IRNode _tree(String line) => IRNode.fromJson({
      '__type': 'HWColumn',
      'children': [text(bind('label')), text(line)],
    });

IRDefinition _def({bool compact = false, bool large = false}) => IRDefinition(
      name: 'TestW',
      root: _tree('medium layout'),
      compactRoot: compact ? _tree('small layout') : null,
      largeRoot: large ? _tree('large layout') : null,
      width: 4,
      height: 2,
    );

void main() {
  String provider(r) => r.file(
      'android/app/src/main/kotlin/com/acme/app/mosaic_generated/TestWProvider.kt');

  test('no large tree writes no large layout', () async {
    final r = await runAndroid([_def(compact: true)]);
    expect(r.fileOrNull('android/app/src/main/res/layout/hw_testw_large.xml'),
        isNull);
    expect(provider(r), isNot(contains('hw_testw_large')));
  });

  test('a large tree gets its own layout file', () async {
    final r = await runAndroid([_def(large: true)]);
    final large = r.file('android/app/src/main/res/layout/hw_testw_large.xml');
    expect(large, contains('large layout'));
    expect(large, isNot(contains('medium layout')));
    expect(r.file('android/app/src/main/res/layout/hw_testw.xml'),
        contains('medium layout'));
  });

  test('the size map holds all three trees, large two rows above the root',
      () async {
    final kt = provider(await runAndroid([_def(compact: true, large: true)]));
    expect(kt, contains('android.util.SizeF(1f, 1f)'));
    expect(kt, contains('R.layout.hw_testw_compact'));
    // 4 columns x 2 rows declares 250x110dp; two more rows start at 250x250dp.
    expect(kt, contains('android.util.SizeF(250f, 110f)'));
    expect(kt, contains('android.util.SizeF(250f, 250f)'));
    expect(kt, contains('R.layout.hw_testw_large'));
  });

  test('large without compact still maps the smallest size to the root',
      () async {
    final kt = provider(await runAndroid([_def(large: true)]));
    expect(kt, contains('android.os.Build.VERSION.SDK_INT >= 31'));
    expect(kt, contains('android.util.SizeF(1f, 1f)'));
    expect(kt, isNot(contains('hw_testw_compact')));
    expect(kt, contains('android.util.SizeF(250f, 250f)'));
  });
}
