# Implementation notes

Rep Pilot derives its build and sideload distribution tooling from the [SideStart template](https://github.com/code-by-fh/sidestart). Earlier research and native build evidence for that starter are not Rep Pilot validation.

The app is a local strength training journal. Its first version uses exercise records, dated workouts, sets with kg and repetition counts, history views, JSON backup and restore, and CSV export. No Apple Health integration, cloud accounts, or additional native capabilities are part of this implementation.

## Source metadata

The [official AltStore source schema](https://faq.altstore.io/developers/make-a-source), checked November 15, 2026, lists `lifestyle` among supported category values and has no health and fitness value. Rep Pilot uses `lifestyle`. The source listing has a generated dumbbell icon; this is distinct from native launcher assets.

The metadata generator reads identity, version, size, minimum iOS version, entitlements, and privacy descriptions from the actual IPA. It retains source history and uses version-specific IPA URLs in the app's public repository.

## Build boundaries

Flutter is pinned in `.fvmrc`. Native projects must be generated only after configuring app identity. `bootstrap.py` preserves existing platform files. An iOS release device build requires macOS and Xcode; see [Flutter's iOS deployment documentation](https://docs.flutter.dev/deployment/ios).

The inherited workflows build unsigned iOS device output and an Android APK. Personal signing and installation remain separate from compilation. Consult the current [SideStore installation instructions](https://docs.sidestore.io/docs/installation/install) for the user's device setup.

## Publication boundaries

The intended app repository is `code-by-fh/rep-pilot`. App releases and the shared `code-by-fh/ios-apps` catalog have separate lifecycles. Source registration and a manual catalog refresh are needed before a new app appears there. No scheduled or automatic catalog publication is added.
