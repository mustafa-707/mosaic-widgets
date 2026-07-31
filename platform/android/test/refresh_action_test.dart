import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

/// `MRefreshAction` reloads the widget. On iOS that is a `MosaicRefreshIntent`
/// reloading the timeline in-process.
///
/// Android had no branch for it at all: it fell into the catch-all that fires
/// an `MActionCallback` named `refresh_all` — a magic string no developer ever
/// writes. Unless they happened to declare a refresh source under that exact
/// name it fetched nothing, and if they *did* use `MActionCallback('refresh_all')`
/// for something else, the two were indistinguishable.
void main() {
  String provider(r) => r.file(
      'android/app/src/main/kotlin/com/acme/app/mosaic_generated/TestWProvider.kt');

  Map<String, dynamic> refreshButton() => {
        '__type': 'HWButton',
        'action': {'__type': 'HWRefreshAction'},
        'child': text('Reload'),
      };

  test('a refresh button no longer fires the phantom refresh_all callback',
      () async {
    final kt = provider(await runAndroid([
      irDef({
        '__type': 'HWColumn',
        'children': [text(bind('price')), refreshButton()],
      })
    ]));
    expect(kt, contains('mosaicRefreshAction'));
    expect(kt, isNot(contains('"refresh_all"')));
  });

  test('it refetches the sources supplying this widget\'s own keys', () async {
    final kt = provider(await runAndroid([
      irDef({
        '__type': 'HWColumn',
        'children': [text(bind('price')), text(bind('change')), refreshButton()],
      })
    ]));
    // Sorted, so the generated file is stable between builds.
    expect(kt, contains('runKeys(context, listOf("change", "price"))'));
    // The refreshing flag brackets the fetch, so an MActivityIndicator bound to
    // mosaic_refreshing has something to show while it is in flight.
    expect(kt, contains('setRefreshing(context, true)'));
    expect(kt, contains('setRefreshing(context, false)'));
    // goAsync keeps the broadcast alive; without it the process may be killed
    // mid-request and the widget silently never updates.
    expect(kt, contains('goAsync()'));
  });

  test('a widget with no refresh button carries none of the plumbing', () async {
    // An unused private val is a Kotlin warning in code the developer cannot
    // edit, so the constant must not be emitted unconditionally.
    final kt = provider(await runAndroid([irDef(text(bind('price')))]));
    expect(kt, isNot(contains('mosaicRefreshAction')));
    expect(kt, isNot(contains('runKeys')));
  });

  test('refresh and a real callback of the same name stay distinct', () async {
    final kt = provider(await runAndroid([
      irDef({
        '__type': 'HWColumn',
        'children': [
          text(bind('price')),
          refreshButton(),
          {
            '__type': 'HWButton',
            'action': {
              '__type': 'HWActionCallback',
              'callbackName': 'refresh_all',
            },
            'child': text('Sync'),
          },
        ],
      })
    ]));
    // The developer's own callback still reaches the callback path...
    expect(kt, contains('putExtra("callbackName", "refresh_all")'));
    // ...while the refresh button takes its own action, not that one.
    expect(kt, contains('action = mosaicRefreshAction'));
  });
}
