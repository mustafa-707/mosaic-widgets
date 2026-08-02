# Changelog

## 0.2.0 - 2026-08-02
### Added
- `MosaicBridge.getValue<T>` — read the shared store back. The widget writes to
  it too (an `MToggleAction` flips its bool on-device), and none of that was
  visible to the app before.
- `MosaicBridge.saveFile` / `saveImage` — put a file where `MFileImage` can find
  it. The node was documented but unusable without this.
- `MosaicBridge.renderFlutterWidget` — rasterise any Flutter widget to a PNG,
  the escape hatch for what the DSL cannot express.
- `MosaicBridge.installedWidgets()` — which widgets the user actually placed.
- `MosaicTv` + `tv_channels:` — Android TV / Google TV home-screen channels.
  Not widgets: the TV launchers host no AppWidgets at all.
- macOS and watchOS: the generated Swift now compiles for both, including
  watch complications and the watchOS-only `accessoryCorner` family.

### Fixed
- `MPositioned` ignored its offsets on iOS, so every decorative element sat
  flush to its corner.
- `MListView` was always empty on iOS: `saveList` JSON-encodes, and the
  generator cast straight to an array.
- Battery never resolved on iOS — `isBatteryMonitoringEnabled` is a no-op in an
  app extension, so the app publishes it instead.
## 0.1.0 - 2026-08-01
### Added
- Initial release. Flutter-style Dart DSL for building native iOS and Android home-screen widgets, lock-screen widgets, and Live Activities from a single codebase.
