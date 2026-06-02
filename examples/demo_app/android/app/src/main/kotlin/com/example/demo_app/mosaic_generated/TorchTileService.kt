// MOSAIC-GENERATED — do not edit
package com.example.demo_app.mosaic_generated

import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.net.Uri
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import com.example.demo_app.R

/// Quick Settings tile for the Mosaic control. This is Android's closest analog
/// to an iOS Control. Quick Settings tiles are USER-ADDED — Android does not
/// auto-place them — and require API 24+ (declared in AndroidManifest with the
/// QS_TILE intent-filter + BIND_QUICK_SETTINGS_TILE permission).
///
/// State and actions flow through the shared "widget_data" SharedPreferences
/// store and the `com.example.demo_app.MOSAIC_CALLBACK` broadcast, mirroring the app-widget
/// callback path so Flutter's backgroundCallback receives it identically.
class TorchTileService : TileService() {
    private val mosaicCallbackAction = "com.example.demo_app.MOSAIC_CALLBACK"

    override fun onStartListening() {
        super.onStartListening()
        qsTile?.label = "Flashlight"
        val on = getSharedPreferences("widget_data", Context.MODE_PRIVATE)
            .getBoolean("torch_on", false)
        qsTile?.state = if (on) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        qsTile?.updateTile()
    }

    override fun onClick() {
        super.onClick()
        val prefs = getSharedPreferences("widget_data", Context.MODE_PRIVATE)
        val next = !prefs.getBoolean("torch_on", false)
        prefs.edit().putBoolean("torch_on", next).apply()
        qsTile?.state = if (next) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        qsTile?.updateTile()
        val callbackIntent = Intent(mosaicCallbackAction).apply {
            setPackage(packageName)
            putExtra("callbackName", "toggle_torch")
        }
        sendBroadcast(callbackIntent)
    }
}
