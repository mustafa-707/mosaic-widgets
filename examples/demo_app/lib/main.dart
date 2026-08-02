import 'package:flutter/material.dart';
import 'package:mosaic_widgets/mosaic_widgets.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

@pragma('vm:entry-point')
Future<void> backgroundCallback(String name) async {
  if (name == "refresh_news" ||
      name == "refresh_crypto" ||
      name == "refresh_all") {
    await fetchAndSaveData();
    await MosaicBridge.refreshAll();
    return;
  }

  if (name == "toggle_torch") {
    // The widget and the Control Center tile have already flipped `torch_on`
    // on-device, so the state is correct even with the app closed. This is
    // where a real app would drive the camera's torch; the demo just mirrors
    // the flag so the two surfaces stay in step.
    await MosaicBridge.refreshAll();
    return;
  }

  if (name == "clear_ram") {
    // Honest scope: since Android 8 an app cannot free *other* apps' memory,
    // and iOS never allowed it. The "RAM booster" genre is largely theatre.
    // What is real is releasing what this process holds, then re-reading the
    // system figure — which is what the widget then shows.
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    // MosaicDevice.populate() runs at the top of every widget update, so the
    // refresh below re-reads free memory rather than redrawing a stale number.
    await MosaicBridge.refreshAll();
    return;
  }
}

Future<void> fetchAndSaveData() async {
  try {
    // 1. Fetch the latest headline. Same endpoint and key as the widget's own
    //    refresh button (see `refresh:` in mosaic.yaml), so the app and the
    //    widget never disagree about what "latest" means.
    final newsResponse = await http.get(
      Uri.parse('https://api.spaceflightnewsapi.net/v4/articles/?limit=2'),
    );
    if (newsResponse.statusCode == 200) {
      final results = jsonDecode(newsResponse.body)['results'] as List;
      if (results.isNotEmpty) {
        await MosaicBridge.saveString('news_title', results.first['title']);
        await MosaicBridge.saveString(
          'news_source',
          results.first['news_site'] ?? '',
        );
        // Epoch MILLISECONDS — MFormat.date/relativeTime read millis on both
        // platforms. Seconds here rendered as "Jan 21, 1970".
        await MosaicBridge.saveString(
          'news_updated',
          '${DateTime.now().millisecondsSinceEpoch}',
        );
      }
      if (results.length > 1) {
        await MosaicBridge.saveString('news_title_2', results[1]['title']);
      }
    }

    // 2. Battery and storage are NOT written here. The widget reads them
    //    natively via MDeviceValue, so they stay correct while this app is
    //    closed — anything saved from here would be stale the moment the app is
    //    backgrounded.
    await MosaicBridge.saveString('system_status', 'OPTIMIZED');

    // 2b. A real list, pushed as maps whose keys the item template binds by
    //     name. Android renders these through a RemoteViewsService, so the row
    //     list scrolls with this app closed.
    final tasks = [
      {'marker': '●', 'title': 'Review widget layout on small screens', 'due': '09:30'},
      {'marker': '●', 'title': 'Ship the refresh-source retry fix', 'due': '11:00'},
      {'marker': '○', 'title': 'Localise the news strings for ar', 'due': '14:15'},
      {'marker': '○', 'title': 'Check Live Activity on the lock screen', 'due': '16:45'},
    ];
    await MosaicBridge.saveList('tasks', tasks);
    // A week of storage-used samples for the bar chart. A real app would read
    // these from its own history table.
    await MosaicBridge.saveList('storage_week', [12, 15, 11, 18, 22, 19, 24]);
    await MosaicBridge.saveString('tasks_count', '${tasks.length} due');

    // 3. Weather, stored in both units so the widget's °C/°F toggle can switch
    //    with no network call. Mirrors the widget's own refresh source.
    const weatherUrl =
        'https://api.open-meteo.com/v1/forecast?latitude=37.77&longitude=-122.42'
        '&current=temperature_2m'
        '&daily=temperature_2m_max,temperature_2m_min&forecast_days=1';

    Future<void> saveWeather(
        String unitSuffix, String tempKey, String suffixKey) async {
      final res = await http.get(Uri.parse('$weatherUrl$unitSuffix'));
      if (res.statusCode != 200) return;
      final body = jsonDecode(res.body);
      // Raw value, no suffix — the widget renders the degree sign, and the
      // native refresh path stores the same raw number.
      await MosaicBridge.saveString(
        tempKey,
        '${body['current']['temperature_2m']}',
      );
      // Raw values under the same keys the widget's own refresh source fills,
      // so both paths agree.
      final hi = (body['daily']['temperature_2m_max'] as List).first;
      final lo = (body['daily']['temperature_2m_min'] as List).first;
      await MosaicBridge.saveString('hi_$suffixKey', '${hi.round()}');
      await MosaicBridge.saveString('lo_$suffixKey', '${lo.round()}');
    }

    await saveWeather('', 'temp_c', 'c');
    await saveWeather('&temperature_unit=fahrenheit', 'temp_f', 'f');

    // 4. Global URL for widget tap action
    await MosaicBridge.saveString('global_url', 'hwdemo://dashboard');

    // 5. Fetch Crypto Prices from CoinGecko (Real API)
    final response = await http.get(
      Uri.parse(
        'https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd&include_24hr_change=true',
      ),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final btc = data['bitcoin'];
      final price = btc['usd'];
      final change = btc['usd_24h_change'];

      // Save price as raw number string so Swift Double() parsing works
      await MosaicBridge.saveString('btc_price', price.toStringAsFixed(2));
      // A 7-day series for the sparkline. A real app would fetch
      // /market_chart; this derives a plausible shape from the 24h change so
      // the example needs no extra API call.
      final base = price / (1 + change / 100);
      await MosaicBridge.saveList('btc_series', [
        for (var d = 6; d >= 0; d--)
          double.parse(
            (base + (price - base) * ((6 - d) / 6) +
                    (d.isEven ? base * 0.004 : -base * 0.003))
                .toStringAsFixed(2),
          ),
      ]);
      // The decorative disc behind the header takes its colour from the day's
      // direction, so the widget reads green or red at a glance before any
      // number is parsed. Bound rather than baked in, because the value is only
      // known at fetch time.
      await MosaicBridge.saveString(
        'accent',
        change >= 0 ? '#22C55E' : '#EF4444',
      );
      await MosaicBridge.saveString(
        'btc_change',
        '${change > 0 ? "+" : ""}${change.toStringAsFixed(2)}%',
      );
    }
  } catch (e) {
    debugPrint("Background Fetch Error: $e");
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MosaicBridge.setAppGroupId('group.com.example.demo_app.widgets');
  MosaicBridge.registerBackgroundCallback(backgroundCallback);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Premium Home Widgets',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Home Widget Dashboard'),
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const MyHomePage(title: 'Home Widget Dashboard'),
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _isLoading = false;
  bool _canPin = false;

  /// Names as declared in `mosaic.yaml`.
  static const _pinnableWidgets = [
    'Weather',
    'NewsWidget',
    'CryptoWidget',
    'ProfileVP',
    'SearchBar',
    'Tasks',
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
    MosaicBridge.canRequestPinWidget().then((can) {
      if (mounted) setState(() => _canPin = can);
    });
    MosaicBridge.onDeepLink.listen((url) {
      if (!mounted) return;
      // The SearchBar widget deep-links here: a widget cannot host a real text
      // field, so it hands off to the app with the intended mode.
      final uri = Uri.tryParse(url);
      final message = uri?.host == 'search'
          ? switch (uri?.queryParameters['mode']) {
              'voice' => 'Voice search',
              'lens' => 'Lens search',
              _ => 'Search',
            }
          : 'Action: $url';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: .floating),
      );
    });
  }

  /// Collects the APNs tokens WidgetKit issued for widgets declaring
  /// `push: true` and hands them to the server.
  ///
  /// Only the widget extension is told these tokens and it cannot make network
  /// calls to your backend, so the app has to relay them. Empty until a widget
  /// is placed, and always empty in the simulator and on Android.
  Future<void> _registerWidgetPushTokens() async {
    final tokens = await MosaicBridge.widgetPushTokens();
    for (final entry in tokens.entries) {
      // A real app POSTs this to its backend, which then pushes
      // {"aps":{"content-changed":true}} to reload the widget.
      debugPrint('[Mosaic] widget push token ${entry.key}: ${entry.value}');
    }
  }

  /// Android reports only that the dialog was shown, never whether the user
  /// accepted, so there is nothing to await beyond that.
  Future<void> _pin(String name) async {
    final shown = await MosaicBridge.requestPinWidget(name);
    if (!mounted || shown) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Launcher declined to add $name'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    // No battery seeding: the widget reads it natively via MDeviceValue.
    await fetchAndSaveData();
    await _registerWidgetPushTokens();
    await MosaicBridge.refreshAll();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _manualUpdate() async {
    setState(() => _isLoading = true);
    try {
      await fetchAndSaveData();
      await MosaicBridge.refreshAll();
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Widgets Synced with Live API'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // Clean up error message for display
        final errorMsg = e.toString().contains("APP_GROUP_ERROR")
            ? "CRITICAL: App Groups not configured in Xcode! See logs."
            : "Error: $e";

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: "Details",
              onPressed: () {
                // Show dialog if needed, but msg is enough
              },
            ),
          ),
        );
      }
    }
  }

  /// Id of the running delivery activity, or null when none is live.
  ///
  /// The demo declared an OrderTracker Live Activity but never started one, so
  /// its lock-screen and Dynamic Island layouts — and the Apple Watch variant
  /// added via `watch: true` — could not be seen at all.
  String? _activityId;

  Future<void> _startDelivery() async {
    if (!await MosaicLiveActivities.areEnabled()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Live Activities are off for this app in Settings.'),
        ),
      );
      return;
    }

    final id = await MosaicLiveActivities.start('OrderTracker', {
      'status': 'Preparing your order',
      'eta': '18 min',
      'progress': '0.1',
    });
    if (!mounted || id == null) return;
    setState(() => _activityId = id);

    // Walk it through a few states so the Dynamic Island and lock screen have
    // something to show. A real app would drive this from its own backend.
    const steps = [
      ('Picked up by courier', '12 min', '0.45'),
      ('Two streets away', '4 min', '0.8'),
      ('Arriving now', 'Any moment', '1.0'),
    ];
    for (final (status, eta, progress) in steps) {
      await Future<void>.delayed(const Duration(seconds: 6));
      if (!mounted || _activityId == null) return;
      await MosaicLiveActivities.update(_activityId!, {
        'status': status,
        'eta': eta,
        'progress': progress,
      });
    }
  }

  /// Renders a Flutter widget into the widget's file store.
  ///
  /// The escape hatch: anything the DSL cannot express — here a gradient ring
  /// with a CustomPaint-style arc — can be drawn in Flutter and shown through
  /// MFileImage. Kept small deliberately: on Android the bitmap crosses a
  /// Binder transaction with the RemoteViews update, and an oversized one
  /// silently drops the whole update.
  Future<void> _renderChart() async {
    final path = await MosaicBridge.renderFlutterWidget(
      Container(
        width: 120,
        height: 120,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(
            colors: [Color(0xFF34D399), Color(0xFF2563EB), Color(0xFF34D399)],
          ),
        ),
        child: const Center(
          child: Text(
            '72%',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      key: 'ring',
      logicalSize: const Size(120, 120),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(path == null ? 'render failed' : 'rendered: $path')),
    );
    if (path != null) {
      await MosaicBridge.saveString('ring_path', path);
      await MosaicBridge.refreshAll();
    }
  }

  /// Reads back what the widget itself wrote, which used to be impossible.
  Future<void> _readBack() async {
    final torch = await MosaicBridge.getValue<bool>('torch_on') ?? false;
    final placed = await MosaicBridge.installedWidgets();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('torch_on=$torch · ${placed.length} widget(s) placed'),
      ),
    );
  }

  Future<void> _endDelivery() async {
    final id = _activityId;
    if (id == null) return;
    await MosaicLiveActivities.end(id, finalState: {
      'status': 'Delivered',
      'eta': 'Done',
      'progress': '1.0',
    });
    if (mounted) setState(() => _activityId = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.widgets_outlined, size: 80, color: Colors.blue),
            const SizedBox(height: 24),
            const Text(
              'Premium Widget Dashboard',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              child: Text(
                'Your home screen widgets are now syncing with real-time Crypto and News APIs.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 32),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              ElevatedButton.icon(
                onPressed: _manualUpdate,
                icon: const Icon(Icons.refresh),
                label: const Text('Update Widgets Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _renderChart,
                  icon: const Icon(Icons.donut_large, size: 18),
                  label: const Text('Render Flutter widget'),
                  style:
                      OutlinedButton.styleFrom(foregroundColor: Colors.white70),
                ),
                OutlinedButton.icon(
                  onPressed: _readBack,
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Read widget state'),
                  style:
                      OutlinedButton.styleFrom(foregroundColor: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Live Activities need the app to start them; there is no way to
            // trigger one from a widget, so it belongs here.
            OutlinedButton.icon(
              onPressed: _activityId == null ? _startDelivery : _endDelivery,
              icon: Icon(
                _activityId == null
                    ? Icons.local_shipping_outlined
                    : Icons.stop_circle_outlined,
                size: 18,
              ),
              label: Text(
                _activityId == null
                    ? 'Start delivery activity'
                    : 'End delivery activity',
              ),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white70),
            ),
            const SizedBox(height: 12),
            // Most users never find the launcher's widget picker, so offer the
            // add-to-home-screen prompt in-app where it is discoverable.
            if (_canPin)
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  for (final name in _pinnableWidgets)
                    OutlinedButton.icon(
                      onPressed: () => _pin(name),
                      icon: const Icon(Icons.add_to_home_screen, size: 18),
                      label: Text(name),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                      ),
                    ),
                ],
              )
            else
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'This platform cannot add widgets for you. Long-press the '
                  'home screen, then pick Widgets.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
