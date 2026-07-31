package com.example.demo_app

import android.content.Intent
import com.example.demo_app.mosaic_generated.MosaicPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    // The whole Mosaic integration: method channel, App Group writes, widget
    // refreshes, Live Activity lifecycle, widget callbacks and deep links all
    // live in the generated MosaicPlugin.
    private val mosaic = MosaicPlugin()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        mosaic.register(this, flutterEngine)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        mosaic.handleIntent(intent)
    }
}
