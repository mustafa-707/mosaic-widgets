import 'dart:io';

import 'package:mosaic_widgets/src/core/core.dart';
import 'package:path/path.dart' as p;

/// A single setup problem found by [validateProject] or [validateDrawables].
///
/// [fatal] problems break the native build, so `build` refuses to hand work to
/// Gradle/Xcode and `doctor` exits non-zero. Non-fatal ones are advisory.
class Problem {
  final String message;
  final bool fatal;

  const Problem(this.message, {this.fatal = false});

  @override
  String toString() => message;
}

/// Collects every `androidDrawable` name referenced by [definitions].
Set<String> referencedAndroidDrawables(List<IRDefinition> definitions) {
  final names = <String>{};

  void walk(Object? value) {
    if (value is Map) {
      final drawable = value['androidDrawable'];
      if (drawable is String && drawable.isNotEmpty) names.add(drawable);
      // Android branch only: an MAdaptive's iOS subtree never reaches the
      // Android generator, so requiring its drawables would fail a build over
      // a resource that is never referenced.
      mosaicWalkChildren(value, platform: 'android').forEach(walk);
    } else if (value is List) {
      value.forEach(walk);
    }
  }

  for (final def in definitions) {
    walk(def.root.toJson());
  }
  return names;
}

/// Verifies every `androidDrawable` referenced by a widget actually resolves.
///
/// Without this the first sign of a typo is an `AAPT: error: resource
/// drawable/x not found` minutes into a Gradle build.
List<Problem> validateDrawables(
  List<IRDefinition> definitions,
  String projectRoot, {
  List<Map<String, dynamic>> controls = const [],
}) {
  final resDir = Directory(p.join(projectRoot, 'android/app/src/main/res'));
  if (!resDir.existsSync()) return const [];

  const extensions = ['xml', 'png', 'webp', 'jpg', 'jpeg'];
  final drawableDirs = resDir
      .listSync()
      .whereType<Directory>()
      .where((d) => p.basename(d.path).startsWith('drawable'))
      .toList();
  // mipmap holds launcher icons, which android:src may also legitimately name.
  drawableDirs.addAll(resDir
      .listSync()
      .whereType<Directory>()
      .where((d) => p.basename(d.path).startsWith('mipmap')));

  bool exists(String name) => drawableDirs.any((dir) => extensions
      .any((ext) => File(p.join(dir.path, '$name.$ext')).existsSync()));

  // Where each name came from, so the message can name the right field. Control
  // tile icons live outside the widget node trees and so were never checked — a
  // wrong name surfaced as a Kotlin "Unresolved reference" instead.
  final sources = <String, String>{
    for (final n in referencedAndroidDrawables(definitions))
      n: 'a widget (androidDrawable)',
  };
  for (final c in controls) {
    final icon = c['androidIcon'];
    if (icon is! String || icon.isEmpty) continue;
    final name = (c['name'] as String?) ?? 'a control';
    sources[icon] = 'control "$name" (androidIcon)';
  }

  final missing = sources.keys.where((n) => !exists(n)).toList()..sort();

  return [
    for (final name in missing)
      Problem(
        'Android drawable "$name" is referenced by ${sources[name]} but no '
        '$name.{xml,png,webp} exists under android/app/src/main/res/drawable*. '
        'Note res/mipmap does not count for this — add the drawable, or fix '
        'the name.',
        fatal: true,
      ),
  ];
}

/// Collects every `MLocalized` key referenced by [definitions].
Set<String> referencedStringKeys(List<IRDefinition> definitions) {
  final keys = <String>{};

  void walk(Object? value) {
    if (value is Map) {
      if (value['__type'] == 'HWLocalized') {
        final key = value['key'];
        if (key is String && key.isNotEmpty) keys.add(key);
      }
      value.values.forEach(walk);
    } else if (value is List) {
      value.forEach(walk);
    }
  }

  for (final def in definitions) {
    walk(def.root.toJson());
  }
  return keys;
}

/// Verifies every `MLocalized` key resolves, and reports partial translations.
///
/// A key missing from the **default** locale is fatal: that locale becomes
/// Android's unqualified `values/` table and iOS's fallback bundle, so without
/// it the key has nothing to fall back to — Android throws at inflate time and
/// iOS renders the raw key. Neither failure names the Dart line responsible.
///
/// A key the default locale has but a secondary locale lacks only falls back,
/// so it is advisory — usually an unfinished translation rather than a bug.
List<Problem> validateStringKeys(
  List<IRDefinition> definitions,
  MosaicConfig config,
) {
  final referenced = referencedStringKeys(definitions);
  if (referenced.isEmpty) return const [];

  final defaultLocale = config.defaultLocale;
  if (defaultLocale == null) {
    return [
      for (final key in referenced.toList()..sort())
        Problem(
          'MLocalized("$key") is used but mosaic.yaml declares no `strings:` '
          'block. Add one listing the locales you support.',
          fatal: true,
        ),
    ];
  }

  final fallback = config.strings[defaultLocale] ?? const {};
  final problems = <Problem>[
    for (final key
        in referenced.where((k) => !fallback.containsKey(k)).toList()..sort())
      Problem(
        'MLocalized("$key") is used but "$key" is missing from the default '
        'locale "$defaultLocale" under `strings:` in mosaic.yaml. The default '
        'locale is the fallback for every other language, so every key must '
        'appear there.',
        fatal: true,
      ),
  ];

  // Advisory: the fallback covers these, so they build and run.
  for (final locale in config.strings.keys.where((l) => l != defaultLocale)) {
    final table = config.strings[locale] ?? const {};
    final untranslated = referenced
        .where((k) => fallback.containsKey(k) && !table.containsKey(k))
        .toList()
      ..sort();
    if (untranslated.isEmpty) continue;
    problems.add(Problem(
      'Locale "$locale" is missing ${untranslated.length} translated '
      'key(s): ${untranslated.join(', ')}. These fall back to '
      '"$defaultLocale".',
    ));
  }

  return problems;
}

/// Collects every `MLaunchUrlAction` URL referenced by [definitions].
Set<String> referencedLaunchUrls(List<IRDefinition> definitions) {
  final urls = <String>{};

  void walk(Object? value) {
    if (value is Map) {
      if (value['__type'] == 'HWLaunchUrlAction') {
        final url = value['url'];
        if (url is String && url.isNotEmpty) urls.add(url);
      }
      value.values.forEach(walk);
    } else if (value is List) {
      value.forEach(walk);
    }
  }

  for (final def in definitions) {
    walk(def.root.toJson());
  }
  return urls;
}

/// Verifies every custom-scheme `MLaunchUrlAction` matches `deep_link_scheme`.
///
/// Only the declared scheme is registered as an intent filter (Android) or a
/// URL type (iOS), so a URL on any other custom scheme produces a button that
/// resolves to nothing — a dead tap with no error anywhere. `http`/`https` are
/// left alone: those legitimately open a browser.
List<Problem> validateLaunchUrls(
  List<IRDefinition> definitions,
  MosaicConfig config,
) {
  final scheme = config.app.deepLinkScheme;
  final problems = <Problem>[];

  for (final url in referencedLaunchUrls(definitions).toList()..sort()) {
    final parsed = Uri.tryParse(url);
    final urlScheme = parsed?.scheme ?? '';
    // A relative or scheme-less URL cannot be routed at all.
    if (urlScheme.isEmpty) {
      problems.add(Problem(
        'MLaunchUrlAction("$url") has no scheme. Use "$scheme://..." for a '
        'deep link into your app, or an http(s) URL for the browser.',
        fatal: true,
      ));
      continue;
    }
    if (urlScheme == 'http' || urlScheme == 'https') continue;
    if (urlScheme == scheme) continue;
    problems.add(Problem(
      'MLaunchUrlAction("$url") uses scheme "$urlScheme", but only '
      '"$scheme" is registered (mosaic.yaml `app.deep_link_scheme`, which '
      'defaults to "mosaic"). The button would resolve to nothing. Either set '
      '`deep_link_scheme: $urlScheme` or change the URL to '
      '"$scheme://...".',
      fatal: true,
    ));
  }

  return problems;
}

/// Verifies each control carries what its kind needs.
///
/// A toggle without `valueKey` has no bound bool to reflect, so it renders in a
/// fixed state forever. The iOS generator used to hard-cast the key and die with
/// `type 'Null' is not a subtype of type 'String'`, naming neither the control
/// nor the field.
List<Problem> validateControls(List<Map<String, dynamic>> controls) {
  final problems = <Problem>[];
  for (final c in controls) {
    final name = (c['name'] as String?) ?? '(unnamed)';
    if (c['kind'] == 'toggle' && ((c['valueKey'] as String?) ?? '').isEmpty) {
      problems.add(Problem(
        'Control "$name" is a toggle but declares no valueKey, so nothing '
        'tells it whether it is currently on. Set valueKey to the bound bool '
        'the toggle reflects — usually the same key its MToggleAction flips.',
        fatal: true,
      ));
    }
  }
  return problems;
}

/// Static setup checks that need no widget execution: iOS App Group
/// entitlements, host-plugin wiring, and `refresh:` sanity.
List<Problem> validateProject(MosaicConfig config, String projectRoot) {
  final problems = <Problem>[];
  final appGroup = config.app.iosAppGroup;

  String path(String rel) => p.join(projectRoot, rel);

  // --- Identifiers -------------------------------------------------------
  // Apple requires the `group.` prefix; without it UserDefaults(suiteName:)
  // returns nil and every read silently yields nothing. The widget renders
  // blank with no error on either side.
  if (!appGroup.startsWith('group.')) {
    problems.add(Problem(
      'ios_app_group "$appGroup" must start with "group." — iOS rejects any '
      'other form, so UserDefaults(suiteName:) returns nil and the widget '
      'reads nothing. Use "group.$appGroup".',
      fatal: true,
    ));
  }

  // A package mismatch puts the manifest's receivers in a package that holds no
  // generated classes, so Android registers providers it cannot instantiate —
  // which the launcher shows as "Can't load widget" on every widget in the app.
  final declaredPackage = config.app.androidPackage;
  for (final gradleName in const ['build.gradle.kts', 'build.gradle']) {
    final gradle = File(path('android/app/$gradleName'));
    if (!gradle.existsSync()) continue;
    final m = RegExp(r'''applicationId\s*=?\s*["']([^"']+)["']''')
        .firstMatch(gradle.readAsStringSync());
    final actual = m?.group(1);
    if (actual != null && actual != declaredPackage) {
      problems.add(Problem(
        'mosaic.yaml android_package is "$declaredPackage" but '
        'android/app/$gradleName declares applicationId "$actual". Generated '
        'classes land in one package while the manifest points at the other, '
        'so every widget fails to load. Set android_package to "$actual".',
        fatal: true,
      ));
    }
    break; // Only the first gradle file present governs.
  }

  // --- iOS App Group entitlements -----------------------------------------
  // A mismatch here is invisible until the widget renders empty, because both
  // processes silently read different UserDefaults suites.
  // Each file is only required once the target it belongs to exists: a
  // Dart-only package has no Runner, and a project mid-setup may have no
  // extension yet.
  final entitlementsRequired = {
    'ios/Runner/Runner.entitlements':
        Directory(path('ios/Runner')).existsSync(),
    'ios/HomeWidgetExtension/HomeWidgetExtension.entitlements':
        Directory(path('ios/HomeWidgetExtension')).existsSync(),
  };
  for (final entitlement in entitlementsRequired.keys) {
    final file = File(path(entitlement));
    if (!file.existsSync()) {
      // Skipping an absent file hid the most common state of all: the App Group
      // was never added, so the widget reads an empty suite and renders blank
      // with nothing logged anywhere.
      if (entitlementsRequired[entitlement]!) {
        problems.add(Problem(
          '$entitlement is missing, so the App Group "$appGroup" is not '
          'configured. Whichever side lacks it reads a different '
          'UserDefaults suite, and bound values never appear in the widget. '
          'Add the App Group capability to both the Runner and '
          'HomeWidgetExtension targets in Xcode (Signing & Capabilities).',
          fatal: true,
        ));
      }
      continue;
    }
    if (!file.readAsStringSync().contains(appGroup)) {
      problems.add(Problem(
        '$entitlement does not list the App Group "$appGroup". The app and '
        'the widget would read different storage, so bound values never '
        'appear. Add it under App Groups in Signing & Capabilities.',
        fatal: true,
      ));
    }
  }

  // --- Host plugin wiring --------------------------------------------------
  final appDelegate = File(path('ios/Runner/AppDelegate.swift'));
  if (appDelegate.existsSync() &&
      !appDelegate.readAsStringSync().contains('MosaicPlugin.register')) {
    problems.add(Problem(
      'ios/Runner/AppDelegate.swift never calls MosaicPlugin.register(with: self). '
      'Without it the mosaic_bridge channel is dead: saves, refreshes and '
      'Live Activities all fail at runtime.',
      fatal: true,
    ));
  }

  final pbxproj = File(path('ios/Runner.xcodeproj/project.pbxproj'));
  if (pbxproj.existsSync() &&
      File(path('ios/Runner/MosaicPlugin.swift')).existsSync() &&
      !pbxproj.readAsStringSync().contains('MosaicPlugin.swift')) {
    problems.add(Problem(
      'ios/Runner/MosaicPlugin.swift is not a member of the Runner target, so '
      'the build fails with "Cannot find \'MosaicPlugin\' in scope". Drag it '
      'into the Runner group in Xcode once.',
      fatal: true,
    ));
  }

  // A generated Swift file with no target to compile it is inert: the app
  // builds, ships no .appex, and the widget never appears in the gallery. The
  // directory alone proves nothing — `build` creates it.
  final extensionDir = Directory(path('ios/HomeWidgetExtension'));
  final pbx = File(path('ios/Runner.xcodeproj/project.pbxproj'));
  if (extensionDir.existsSync() && pbx.existsSync()) {
    final proj = pbx.readAsStringSync();
    final hasExtensionTarget =
        proj.contains('com.apple.product-type.app-extension');
    if (!hasExtensionTarget) {
      problems.add(Problem(
        'ios/HomeWidgetExtension/ holds generated Swift but Runner.xcodeproj '
        'has no app-extension target, so nothing compiles it: the app builds, '
        'ships no .appex, and no widget appears in the gallery. In Xcode add a '
        'Widget Extension target named HomeWidgetExtension (File > New > '
        'Target > Widget Extension) — see §1 of docs/IOS_SETUP.md.',
        fatal: true,
      ));
    } else if (!proj.contains('HomeWidgetExtension')) {
      problems.add(Problem(
        'Runner.xcodeproj has an app-extension target but nothing named '
        'HomeWidgetExtension. Mosaic writes its Swift into '
        'ios/HomeWidgetExtension/, so the target must use that folder — see '
        '§1 of docs/IOS_SETUP.md.',
        fatal: true,
      ));
    }
  }

  // Generated layouts use start/end gravity and padding so they mirror in RTL
  // locales, but the manifest has to opt in for Android to honour it. Advisory,
  // not fatal: an LTR-only app is a legitimate choice. ANDROID_SETUP.md already
  // told developers doctor warned about this, so it needed to be true.
  final manifest = File(path('android/app/src/main/AndroidManifest.xml'));
  if (manifest.existsSync()) {
    final xml = manifest.readAsStringSync();
    if (RegExp(r'android:supportsRtl\s*=\s*"false"').hasMatch(xml)) {
      problems.add(const Problem(
        'AndroidManifest.xml sets android:supportsRtl="false", so generated '
        'layouts will not mirror in right-to-left locales even though they use '
        'start/end gravity. Set it to "true" unless that is deliberate.',
      ));
    } else if (!xml.contains('android:supportsRtl')) {
      problems.add(const Problem(
        'AndroidManifest.xml does not set android:supportsRtl. Add '
        'android:supportsRtl="true" to <application> so generated layouts '
        'mirror in right-to-left locales.',
      ));
    }
  }

  // The Android half of the same failure: without register() the
  // mosaic_bridge channel is dead, so every MosaicBridge call throws
  // MissingPluginException. Only iOS was checked, so a project could pass
  // doctor and still have no working bridge on Android.
  final mainActivity =
      _findMainActivity(projectRoot, config.app.androidPackage);
  if (mainActivity != null &&
      !mainActivity.readAsStringSync().contains('MosaicPlugin')) {
    problems.add(Problem(
      '${p.relative(mainActivity.path, from: projectRoot)} never registers '
      'MosaicPlugin. Without it the mosaic_bridge channel is dead on Android: '
      'saves, refreshes and background callbacks all throw '
      'MissingPluginException. See §3 of docs/ANDROID_SETUP.md — it is two '
      'overrides.',
      fatal: true,
    ));
  }

  // --- Live Activities opt-in ---------------------------------------------
  if (config.liveActivities.isNotEmpty) {
    final plist = File(path('ios/Runner/Info.plist'));
    if (plist.existsSync() &&
        !plist.readAsStringSync().contains('NSSupportsLiveActivities')) {
      problems.add(Problem(
        'This project declares live_activities but ios/Runner/Info.plist is '
        'missing NSSupportsLiveActivities. Live Activities will not start. '
        'Add the key with <true/>.',
        fatal: true,
      ));
    }
  }

  // --- refresh: sources ----------------------------------------------------
  config.refresh.forEach((callback, sources) {
    if (sources.isEmpty) {
      problems.add(Problem(
        'refresh."$callback" declares no sources, so the button would fall '
        'back to waking the app.',
      ));
    }
    for (final source in sources) {
      final uri = Uri.tryParse(source.url);
      if (uri == null || !uri.isAbsolute || !uri.scheme.startsWith('http')) {
        problems.add(Problem(
          'refresh."$callback" has a url that is not absolute http(s): '
          '"${source.url}".',
          fatal: true,
        ));
      }
      if (source.map.isEmpty) {
        problems.add(Problem(
          'refresh."$callback" has a source with no map:, so fetching it '
          'would store nothing.',
        ));
      }
    }
  });

  return problems;
}

/// Locates `MainActivity.kt` (or `.java`) for [androidPackage].
///
/// Looked up by the declared package path first, then by a shallow search, so a
/// project that moved the file still gets checked instead of silently skipped.
File? _findMainActivity(String projectRoot, String androidPackage) {
  final byPackage = File(p.join(
    projectRoot,
    'android/app/src/main/kotlin',
    androidPackage.replaceAll('.', '/'),
    'MainActivity.kt',
  ));
  if (byPackage.existsSync()) return byPackage;

  for (final lang in ['kotlin', 'java']) {
    final dir = Directory(p.join(projectRoot, 'android/app/src/main', lang));
    if (!dir.existsSync()) continue;
    for (final f in dir.listSync(recursive: true).whereType<File>()) {
      final name = p.basename(f.path);
      if (name == 'MainActivity.kt' || name == 'MainActivity.java') return f;
    }
  }
  return null;
}
