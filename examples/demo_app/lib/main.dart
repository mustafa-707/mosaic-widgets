import 'package:flutter/material.dart';
import 'package:mosaic/mosaic.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

@pragma('vm:entry-point')
Future<void> backgroundCallback(String name) async {
  if (name == "refresh_news" ||
      name == "refresh_crypto" ||
      name == "refresh_all") {
    await fetchAndSaveData();
    await MosaicBridge.refreshAll();
  }
}

Future<void> fetchAndSaveData() async {
  // try {
  // 1. Fetch Random News Headline
  final headlines = [
    "Global Markets Surge Amid Economic Optimism",
    "Tech Giants Announce Next-Gen AI Integration",
    "SpaceX Successfully Lands Starship Prototype",
    "New Breakthrough in Quantum Computing Research",
    "Global Health Initiative Reaches Major Milestone",
    "Sustainable Energy Production Hits Record High",
  ];
  final randomNews = headlines[DateTime.now().second % headlines.length];
  await MosaicBridge.saveString("news_title", randomNews);

  // 2. Mock System Stats (Dynamic based on time for demo)
  final battery = 75 - (DateTime.now().minute % 20);
  final memory = 4.2 + (DateTime.now().second % 10) / 10.0;
  final memoryProgress = (memory / 8.0) * 100.0;

  await MosaicBridge.saveString('battery_level', battery.toString());
  await MosaicBridge.saveString(
    'battery_progress',
    battery.toDouble().toString(),
  );
  await MosaicBridge.saveString('memory_usage', memory.toStringAsFixed(1));
  await MosaicBridge.saveString(
    'memory_progress',
    memoryProgress.toStringAsFixed(1),
  );
  await MosaicBridge.saveString('system_status', 'OPTIMIZED');

  // 3. Fetch Crypto Prices from CoinGecko (Real API)
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

    await MosaicBridge.saveString(
      'btc_price',
      '\$${price.toStringAsFixed(2)}',
    );
    await MosaicBridge.saveString(
      'btc_change',
      '${change > 0 ? "+" : ""}${change.toStringAsFixed(2)}%',
    );
  }
  // } catch (e) {
  //   debugPrint("Background Fetch Error: $e");
  // }
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

  @override
  void initState() {
    super.initState();
    _initializeData();
    MosaicBridge.onDeepLink.listen((url) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action: $url'), behavior: .floating),
        );
      }
    });
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    await MosaicBridge.saveString('battery_level', '85');
    await MosaicBridge.saveString('battery_progress', '85.0');
    await fetchAndSaveData();
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
          ],
        ),
      ),
    );
  }
}
