// MOSAIC-GENERATED — do not edit
package com.example.demo_app.mosaic_generated

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import com.example.demo_app.R

/// Shared RemoteViewsService backing every Mosaic HWListView. The widget
/// provider attaches this service as the ListView's remote adapter and passes
/// the bound list key in the "hw_list_key" extra. One service instance serves
/// all lists; the factory dispatches on the key to pick the per-row item
/// layout and the field -> view-id mapping.
class MosaicListService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        val key = intent.getStringExtra("hw_list_key") ?: ""
        return MosaicListFactory(applicationContext, key)
    }

    companion object {
        /// Resolves the generated per-row item layout for a list [key].
        fun itemLayoutFor(key: String): Int {
            return when (key) {
            "tasks" -> R.layout.hw_listitem_tasks_tasks
                else -> 0
            }
        }

        /// Resolves the ordered (field, viewId, kind) triples the item layout
        /// binds for list [key]. Each field is set per row from the row map;
        /// kind is "text" (setTextViewText) or "image" (setImageViewUri).
        fun fieldsFor(key: String): List<Triple<String, Int, String>> {
            return when (key) {
            "tasks" -> listOf(Triple("marker", R.id.hw_item_marker, "text"), Triple("title", R.id.hw_item_title, "text"), Triple("due", R.id.hw_item_due, "text"))
                else -> emptyList()
            }
        }
    }
}

class MosaicListFactory(
    private val context: Context,
    private val key: String,
) : RemoteViewsService.RemoteViewsFactory {
    private var rows: List<Map<String, String>> = emptyList()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        rows = MosaicData.resolveList(context, key)
    }

    override fun onDestroy() {
        rows = emptyList()
    }

    override fun getCount(): Int = rows.size

    override fun getViewAt(position: Int): RemoteViews {
        val layout = MosaicListService.itemLayoutFor(key)
        val views = RemoteViews(context.packageName, layout)
        if (position in rows.indices) {
            val row = rows[position]
            for ((field, viewId, kind) in MosaicListService.fieldsFor(key)) {
                val value = row[field] ?: ""
                if (kind == "image") {
                    views.setImageViewUri(viewId, android.net.Uri.parse(value))
                } else {
                    views.setTextViewText(viewId, value)
                }
            }
        }
        return views
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = true
}
