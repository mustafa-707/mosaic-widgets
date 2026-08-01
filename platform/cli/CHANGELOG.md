# Changelog

## Unreleased
### Added
- `add live-activity <Name>` and `add control <Name>`, matching `add widget`.
  Both scaffold a compiling template and create `live_activities:` / `controls:`
  in `mosaic.yaml` when absent.
- `list` — every declared entry with its status (missing builder, native output
  not generated), plus refresh callbacks and locales. `--paths` shows the
  generated file paths.
- `doctor --fix` — repairs the setup problems with one unambiguous answer:
  `android:supportsRtl`, `android_package` vs the real `applicationId`, the
  required `group.` prefix on `ios_app_group`, missing entitlements files, and
  `NSSupportsLiveActivities`. Converges in a single pass and never edits
  `project.pbxproj`.
- `--version`, kept in step with `pubspec.yaml` by a test.
- `add widget` now registers the widget in `mosaic.yaml` itself and places the
  file wherever existing entries live, instead of printing YAML to paste.
- `init` reads `applicationId` from `build.gradle*` and the Runner target's
  `PRODUCT_BUNDLE_IDENTIFIER`, so the derived App Group is correct immediately
  rather than defaulting to `com.example.app`.
- Build-time validation with actionable messages for: undeclared `MLocalized`
  keys, `MLaunchUrlAction` schemes that are not registered, missing
  `build<Name>()` functions, toggles missing `valueKey`, and control tile icons
  that do not resolve.
- `doctor` now checks that an Xcode app-extension target actually compiles the
  generated Swift, that `MainActivity` registers `MosaicPlugin` (previously only
  iOS was checked), that entitlements files exist at all, and
  `android:supportsRtl` — which the Android guide already claimed it checked.
- `build` deletes generated files orphaned by a removed or renamed widget,
  logging each path.

### Fixed
- `add widget` crashed with `PathNotFoundException` whenever the target
  directory did not already exist, and ignored where the project actually keeps
  its widgets.
- A widget omitting `android:` or `ios:` crashed the build with
  `type 'Null' is not a subtype of type 'Map<String, dynamic>'`. Both blocks are
  now optional; `min_sdk` and `sizes` reach no generated output and are
  documented as reserved.
- Repeated builds corrupted `ios/Runner/Info.plist`: the generated
  `CFBundleURLTypes` block was removed only up to its inner `</array>`, orphaning
  the outer tag a little more each run until Xcode refused to parse the file.
- Changing `deep_link_scheme` left the previous scheme registered in
  `AndroidManifest.xml` alongside the new one.
- Documentation links pointed at `DOCS/` where the directory is `docs/` — broken
  on case-sensitive filesystems.

## 0.1.0 - 2026-08-01
### Added
- Initial release: `init`, `add widget`, `build`, `doctor`, and `clean` for
  generating native home widgets across iOS and Android.
