/// Device metrics a widget can read natively, without the app running.
///
/// Each metric is exposed as a reserved bind key. The generators emit native
/// code that writes these keys into the same shared store every other binding
/// reads from, so a device metric composes anywhere an `MBind` does — text,
/// progress, visibility — with no special handling per node type.
///
/// Reading them in the widget process is the point: the app cannot be relied on
/// to be running, so an app-supplied battery level is stale the moment the app
/// is backgrounded.
enum MosaicDeviceMetric {
  /// Battery charge, 0–100.
  batteryLevel('mosaic_battery_level'),

  /// Whether the device is charging.
  batteryCharging('mosaic_battery_charging'),

  /// Free space on the data volume, in GB, one decimal place.
  storageFreeGb('mosaic_storage_free_gb'),

  /// Percentage of the data volume in use, 0–100.
  storageUsedPercent('mosaic_storage_used_percent'),

  /// Free RAM in MB.
  memoryFreeMb('mosaic_memory_free_mb'),

  /// Total RAM in MB.
  memoryTotalMb('mosaic_memory_total_mb'),

  /// Percentage of RAM in use, 0–100.
  memoryUsedPercent('mosaic_memory_used_percent');

  const MosaicDeviceMetric(this.key);

  /// The reserved bind key this metric is published under.
  final String key;

  /// The metric published under [key], or null when [key] is an ordinary bind.
  static MosaicDeviceMetric? forKey(String key) {
    for (final metric in values) {
      if (metric.key == key) return metric;
    }
    return null;
  }

  /// True when [key] is one of the reserved device-metric keys.
  static bool isDeviceKey(String key) => forKey(key) != null;
}

/// The device metrics referenced anywhere inside [json] — a widget definition's
/// serialized node tree.
///
/// Generators use this to emit native collection code only for the metrics a
/// widget actually shows: reading battery level enables battery monitoring, and
/// storage stats hit the filesystem, so collecting unused metrics is waste.
Set<MosaicDeviceMetric> deviceMetricsIn(Object? json) {
  final found = <MosaicDeviceMetric>{};

  void walk(Object? value) {
    if (value is Map) {
      if (value['__type'] == 'HWBind') {
        final key = value['key'];
        if (key is String) {
          final metric = MosaicDeviceMetric.forKey(key);
          if (metric != null) found.add(metric);
        }
      }
      value.values.forEach(walk);
    } else if (value is List) {
      value.forEach(walk);
    }
  }

  walk(json);
  return found;
}
