// MOSAIC-GENERATED — do not edit
package com.example.demo_app.mosaic_generated

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.text.InputType
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.Spinner
import androidx.appcompat.widget.SwitchCompat
import android.widget.TextView
import com.example.demo_app.R

/// Configuration Activity for the "CryptoWidget" widget. Launched by the OS via
/// the APPWIDGET_CONFIGURE action after the widget is placed. Persists the
/// chosen param values into the shared "widget_data" SharedPreferences store
/// (the same store [MosaicData] reads) and triggers a widget update.
class CryptoWidgetConfigActivity : Activity() {
    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    private fun prefs(): android.content.SharedPreferences =
        getSharedPreferences("widget_data", Context.MODE_PRIVATE)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Per the config-activity contract the default result is CANCELED so
        // that backing out leaves no widget placed.
        setResult(RESULT_CANCELED)

        appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        val prefs = prefs()

        // Build the UI programmatically (no XML layout) to keep AAPT simple.
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(32, 32, 32, 32)
        }

        layout.addView(TextView(this).apply { text = "Trading Pair" })
        val saved0 = prefs.getString("pair", "BTC/USD") ?: "BTC/USD"
        val choices0 = listOf<String>("BTC/USD", "ETH/USD", "SOL/USD")
        val field0 = Spinner(this).apply {
            adapter = ArrayAdapter(
                this@CryptoWidgetConfigActivity,
                android.R.layout.simple_spinner_dropdown_item,
                choices0,
            )
            val idx0 = choices0.indexOf(saved0)
            if (idx0 >= 0) setSelection(idx0)
        }
        layout.addView(field0)
        layout.addView(TextView(this).apply { text = "Custom Label" })
        val saved1 = prefs.getString("label", "BITCOIN") ?: "BITCOIN"
        val field1 = EditText(this).apply {
            inputType = InputType.TYPE_CLASS_TEXT
            setText(saved1)
        }
        layout.addView(field1)
        layout.addView(TextView(this).apply { text = "Decimals" })
        val saved2 = prefs.getString("decimals", "2") ?: "2"
        val field2 = EditText(this).apply {
            inputType = InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_FLAG_DECIMAL or InputType.TYPE_NUMBER_FLAG_SIGNED
            setText(saved2)
        }
        layout.addView(field2)
        layout.addView(TextView(this).apply { text = "Compact Mode" })
        val saved3 = prefs.getString("compact", "false") ?: "false"
        val field3 = SwitchCompat(this).apply {
            isChecked = saved3.trim().lowercase() in setOf("true", "1", "yes")
        }
        layout.addView(field3)

        val saveButton = Button(this).apply { text = "Save" }
        saveButton.setOnClickListener {
            val editor = prefs.edit()
        editor.putString("pair", field0.selectedItem?.toString() ?: "")
        editor.putString("label", field1.text.toString())
        editor.putString("decimals", field2.text.toString())
        editor.putString("compact", if (field3.isChecked) "true" else "false")

            editor.apply()

            // Update the widget by re-running the provider's update path.
            val appWidgetManager = AppWidgetManager.getInstance(this)
            val provider = CryptoWidgetProvider()
            provider.onUpdate(this, appWidgetManager, intArrayOf(appWidgetId))

            // Also broadcast an update so any other instances refresh.
            sendBroadcast(Intent(this, CryptoWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(
                    AppWidgetManager.EXTRA_APPWIDGET_IDS,
                    appWidgetManager.getAppWidgetIds(
                        ComponentName(this@CryptoWidgetConfigActivity, CryptoWidgetProvider::class.java),
                    ),
                )
            })

            val resultValue = Intent().apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            }
            setResult(RESULT_OK, resultValue)
            finish()
        }
        layout.addView(saveButton)

        val scroll = ScrollView(this).apply { addView(layout) }
        setContentView(scroll)
    }
}
