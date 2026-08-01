import 'package:mosaic_widgets/src/core/core.dart';
import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// Android's answer to `@Environment(\.widgetFamily)` is
/// `RemoteViews(Map<SizeF, RemoteViews>)` on API 31+: the launcher picks the
/// largest entry whose minimum size still fits.
///
/// Each variant needs its own `RemoteViews` with its own update calls applied,
/// which is why the provider builds trees through `buildViews(layoutRes)` rather
/// than mutating one instance.
IRDefinition _def({IRNode? compact, int width = 2, int height = 2}) =>
    IRDefinition(
      name: 'TestW',
      root: IRNode.fromJson({
        '__type': 'HWColumn',
        'children': [text(bind('label')), text('full layout')],
      }),
      compactRoot: compact,
      width: width,
      height: height,
    );

IRNode _compact() => IRNode.fromJson({
      '__type': 'HWColumn',
      'children': [text(bind('label'))],
    });

void main() {
  String provider(r) => r.file(
      'android/app/src/main/kotlin/com/acme/app/mosaic_generated/TestWProvider.kt');

  test('no compact tree keeps a single layout and no size map', () async {
    final r = await runAndroid([_def()]);
    expect(
        provider(r),
        contains(
            'buildViews(context, appWidgetManager, appWidgetId, R.layout.hw_testw)'));
    expect(provider(r), isNot(contains('SizeF')));
    expect(r.fileOrNull('android/app/src/main/res/layout/hw_testw_compact.xml'),
        isNull);
  });

  test('a compact tree gets its own layout file', () async {
    final r = await runAndroid([_def(compact: _compact())]);
    final compact =
        r.file('android/app/src/main/res/layout/hw_testw_compact.xml');
    expect(compact, contains('LinearLayout'));
    // The full tree's second line must not appear in the compact one.
    expect(compact, isNot(contains('full layout')));
    expect(r.file('android/app/src/main/res/layout/hw_testw.xml'),
        contains('full layout'));
  });

  test('the provider maps sizes to the two trees on API 31+', () async {
    final kt = provider(await runAndroid([_def(compact: _compact())]));
    expect(kt, contains('android.os.Build.VERSION.SDK_INT >= 31'));
    expect(kt, contains('R.layout.hw_testw_compact'));
    // Below 31 there is no way to switch, so the full tree still renders.
    expect(kt, contains('} else {'));
  });

  test('the breakpoint is the widget\'s own declared minimum size', () async {
    // Android sizes a cell at 70dp minus 30dp of inter-cell padding, so a 3x2
    // widget declares a 180x110dp minimum. The full tree should appear at the
    // size it was designed for, not an arbitrary constant.
    final kt =
        provider(await runAndroid([_def(compact: _compact(), width: 3)]));
    expect(kt, contains('android.util.SizeF(180f, 110f)'));
    expect(kt, contains('android.util.SizeF(1f, 1f)'));
  });

  test('both trees receive the update calls for the key they share', () async {
    // The two trees bind the same key, so each needs its own view id and its
    // own setTextViewText. A single shared id would update only the first match.
    final r = await runAndroid([_def(compact: _compact())]);
    final kt = provider(r);
    expect(kt, contains('setTextViewText(R.id.hw_text_label,'));
    expect(kt, contains('setTextViewText(R.id.hw_text_label_2,'));

    final full = r.file('android/app/src/main/res/layout/hw_testw.xml');
    final compact =
        r.file('android/app/src/main/res/layout/hw_testw_compact.xml');
    // One id per tree, and they are different — an action naming an id absent
    // from a layout is skipped by RemoteViews, which is what makes one set of
    // calls safe for both.
    expect(full, contains('@+id/hw_text_label"'));
    expect(compact, contains('@+id/hw_text_label_2"'));
  });

  test('the update calls live in a reusable builder, not inlined', () async {
    final kt = provider(await runAndroid([_def(compact: _compact())]));
    expect(
        kt,
        contains('private fun buildViews(context: Context, '
            'appWidgetManager: AppWidgetManager, appWidgetId: Int, '
            'layoutRes: Int): RemoteViews'));
    expect(kt, contains('RemoteViews(context.packageName, layoutRes)'));
  });
}
