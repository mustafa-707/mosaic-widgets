# Publishing Mosaic to pub.dev

Everything is **prepared** for publishing (MIT licenses, real pubspec metadata, topics,
Keep-a-Changelog entries, per-package READMEs, `mosaic` `example/`, dartdoc). This guide is
the one-shot publish procedure — **do not run it until you intend to publish.**

`mosaic_core` already passes `dart pub publish --dry-run` with **0 warnings**.

## Prerequisites
1. A real Git repository. Replace the placeholder `repository:` URL (`https://github.com/logatta/mosaic`)
   in all 5 `pubspec.yaml` files — each has a `# TODO: update to the real repo URL` marker.
2. A pub.dev account; ideally a verified publisher for the org.
3. `publish_to: none` is currently present in every package **on purpose** (it prevents accidental
   publishing of this path-dependency monorepo). Remove it per package only at publish time (below).

## Why a multi-step publish
The packages depend on each other via local `path:` deps, which pub.dev rejects. Each package must
be published, then its dependents switched from `path:` to a version constraint. Publish in
dependency order:

```
mosaic_core            (no sibling deps)
  ├── mosaic_android   (→ mosaic_core)
  ├── mosaic_ios       (→ mosaic_core)
  └── mosaic           (→ mosaic_core)
        └── mosaic_cli  (→ mosaic_core, mosaic_android, mosaic_ios)
```

## Procedure (per package, in order)

For each package directory, in the order **core → android → ios → mosaic → cli**:

1. Edit its `pubspec.yaml`:
   - Remove the `publish_to: none` line.
   - Replace any sibling `path:` dependency with the published version, e.g.
     ```yaml
     dependencies:
       mosaic_core: ^1.0.0   # was: { path: ../core }
     ```
2. `dart pub get`
3. `dart pub publish --dry-run`  → confirm **0 warnings** (fix any that appear).
4. `dart pub publish`  → confirm on pub.dev.

Concretely:
- **mosaic_core** (`platform/core`): no path deps — just remove `publish_to: none`, dry-run, publish.
- **mosaic_android** (`platform/android`): swap `mosaic_core` path→`^1.0.0`, publish.
- **mosaic_ios** (`platform/ios`): swap `mosaic_core` path→`^1.0.0`, publish.
- **mosaic** (`platform/flutter`): swap `mosaic_core` path→`^1.0.0`, publish. (The `example/` uses a
  `path: ../` dep, which is allowed for an example and does not block the parent's publish.)
- **mosaic_cli** (`platform/cli`): swap `mosaic_core`, `mosaic_android`, `mosaic_ios` path→`^1.0.0`, publish.

## After publishing
- Optionally update `examples/demo_app/pubspec.yaml` to consume the published versions instead of paths.
- Tag the release in git and add the version to each `CHANGELOG.md`.
- Consider a `melos`/workspace setup to manage the monorepo + versioning going forward.

## Versioning
All packages are currently aligned at **1.0.0**. Keep them in lockstep for now (a shared version
simplifies the cross-package constraints). Follow semver per package thereafter.

## Do NOT commit the path→version swap to the working monorepo
The path deps are what make local development and the demo build work. Perform the swap only in the
publish working copy (or via a release script that reverts afterward) so day-to-day development in
this repo keeps using `path:`.
