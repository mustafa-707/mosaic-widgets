// MOSAIC-GENERATED — do not edit
package com.example.demo_app.mosaic_generated

import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.media.tv.TvContract
import android.os.Build

/// Publishes rows of cards to the Android TV / Google TV home screen.
///
/// The launcher renders the cards, so there is no layout to generate — a
/// program is a title, a description, a poster and a deep link.
///
/// Written against the framework `TvContract` rather than
/// `androidx.tvprovider`: the support library only wraps these same
/// ContentValues, and requiring it would mean editing the app's build.gradle
/// for a feature most projects never enable. Preview programs are API 26+.
object MosaicTv {
    private val declared = listOf(
        "featured" to "Featured on Mosaic"
    )

    /// Channel ids are assigned by the provider on insert, so they are kept
    /// here rather than recomputed; losing one would orphan its row.
    private fun prefs(context: Context) =
        context.getSharedPreferences("mosaic_tv", Context.MODE_PRIVATE)

    /// Creates any declared channel that does not exist yet.
    ///
    /// Called from the INITIALIZE_PROGRAMS receiver so a row can appear as soon
    /// as the app is installed, before it has ever been opened.
    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        for ((name, title) in declared) {
            if (prefs(context).getLong(name, -1L) != -1L) continue
            val values = ContentValues().apply {
                put(TvContract.Channels.COLUMN_TYPE,
                    TvContract.Channels.TYPE_PREVIEW)
                put(TvContract.Channels.COLUMN_DISPLAY_NAME, title)
                put(TvContract.Channels.COLUMN_APP_LINK_INTENT_URI,
                    "mosaic://tv/$name")
            }
            val uri = try {
                context.contentResolver.insert(
                    TvContract.Channels.CONTENT_URI, values)
            } catch (e: Exception) {
                // No TV provider on this device — a phone, or a TV without the
                // launcher. Not an error worth crashing the app over.
                null
            } ?: continue
            val id = ContentUris.parseId(uri)
            prefs(context).edit().putLong(name, id).apply()
            // A channel stays hidden until the user accepts it; requesting
            // makes the system offer it rather than silently doing nothing.
            TvContract.requestChannelBrowsable(context, id)
        }
    }

    /// Replaces the programs in [channel] with [programs].
    ///
    /// Each entry needs "title"; "description", "poster" (a URI) and "link"
    /// (a deep link) are optional. Replacing wholesale rather than diffing
    /// keeps the row consistent with what the app just published.
    /// Returns true only when the row was actually written. A phone has no TV
    /// provider at all, and reporting success there would be a lie the caller
    /// cannot detect — the demo happily said "published" on a device where the
    /// provider does not exist.
    fun publish(context: Context, channel: String, programs: List<Map<String, String>>): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        ensureChannels(context)
        val id = prefs(context).getLong(channel, -1L)
        if (id == -1L) return false

        try {
            context.contentResolver.delete(
                TvContract.PreviewPrograms.CONTENT_URI,
                "${TvContract.PreviewPrograms.COLUMN_CHANNEL_ID} = ?",
                arrayOf(id.toString())
            )

            for (program in programs) {
                val title = program["title"] ?: continue
                val values = ContentValues().apply {
                    put(TvContract.PreviewPrograms.COLUMN_CHANNEL_ID, id)
                    put(TvContract.PreviewPrograms.COLUMN_TYPE,
                        TvContract.PreviewPrograms.TYPE_CLIP)
                    put(TvContract.PreviewPrograms.COLUMN_TITLE, title)
                    program["description"]?.let {
                        put(TvContract.PreviewPrograms.COLUMN_SHORT_DESCRIPTION, it)
                    }
                    program["poster"]?.let {
                        put(TvContract.PreviewPrograms.COLUMN_POSTER_ART_URI, it)
                    }
                    program["link"]?.let {
                        put(TvContract.PreviewPrograms.COLUMN_INTENT_URI, it)
                    }
                }
                context.contentResolver.insert(
                    TvContract.PreviewPrograms.CONTENT_URI, values)
            }
            return true
        } catch (e: Exception) {
            // Same reasoning as above: no provider means nothing to publish to.
            return false
        }
    }
}

class MosaicTvInitReceiver : android.content.BroadcastReceiver() {
    override fun onReceive(context: Context, intent: android.content.Intent) {
        MosaicTv.ensureChannels(context)
    }
}
