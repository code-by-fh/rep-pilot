# Rep Pilot validation record

## Implementation status

Rep Pilot was configured from the SideStart template on November 15, 2026. This copy uses project name `rep_pilot`, organization `dev.codebyfh`, and display name `Rep Pilot`.

Earlier SideStart builds and tests are inherited template history, not evidence for the Rep Pilot application. No Rep Pilot native build, public GitHub release, or signed iPhone installation has been recorded.

## Local tooling check on November 15, 2026

`python -m unittest discover -s scripts -p test_*.py`: **41 tests passed**, including the Rep Pilot source metadata fixture. These are Python tooling tests, not a native build.

Flutter commands are unavailable in this session. The first SDK installer attempt was blocked by the Windows script execution policy. A later process-scoped invocation reached the installer, but the network sandbox blocked the official SDK download. `flutter pub get`, `flutter analyze`, and `flutter test` have not run.

## Required checks

Run and record results for the final source state:

```powershell
python -m unittest discover -s scripts -p test_*.py
flutter pub get
flutter analyze
flutter test
```

The development session initially has no usable Flutter SDK. Flutter dependency resolution, analysis, and tests remain unverified until the pinned SDK can be run. The final development report must state any unavailable checks explicitly.

Python script tests use synthetic IPA bundles, fake native tools, and mocked GitHub responses. They verify tooling behavior without compiling a native app or installing one. Added Rep Pilot source tests verify journal metadata, supported category, destination URLs, and identity derived from an IPA fixture.

## Native and device validation still required

- Build the exact reviewed commit with the pinned Flutter SDK.
- Generate and inspect the unsigned release device IPA and Android APK.
- Verify the app's identity, native launcher icon, minimum iOS version, and source metadata against the build.
- Sign and install on an iPhone, then perform the journal, persistence, history, backup/restore, and update checks in [SIDELOADING.md](SIDELOADING.md).
- Record build identifiers and actual device results separately from local tests.

No public repository was created, no release was published, and no shared catalog registration or refresh was performed as part of this implementation.

## Application implementation review

The application sources now include the immutable journal model, native file storage, browser storage, training editor, exercise history, and clipboard backup/restore. Dart tests cover model integrity, replacement failures, persistence ordering, input validation, restore confirmation, same-day prefills, and compact screens. These tests are written but have not executed because no usable Flutter SDK is available. Static review is not compilation evidence.

The publication helper passed the PowerShell parser after its public repository defaults and origin checks were updated. No publication command was executed. No runtime packages were downloaded, and no dependency lock file was generated. Run `flutter pub get` with the pinned SDK and commit its lock file before release.

The complete development copy was initially prepared in the permitted temporary workspace. After CI exposed the scaffold-only model.dart, the complete implementation was restored into the app repository at `sidestart/rep-pilot`. Flutter analysis and tests must run on this restored source before publication.

## CI widget failure correction

The reported CI run passed Flutter analysis and 18 of 21 Flutter tests. Three widget tests failed because Save training was a lazy child at the bottom of the form list: its hit target moved below the viewport after errors, and long forms did not build it until scrolled. The editor now keeps Save training and bounded, scrollable error feedback outside the form list.

Regression coverage now treats missed taps as failures, checks the Save hit target, scrolls an invalid set out of view before validating, verifies correction and retry, and checks a compact viewport with large text and keyboard insets. The installed Dart formatter parsed the changed files using Dart language version 3.13. This syntax check does not execute the tests or verify Flutter 3.47.9 behavior. The pinned Flutter SDK remains unavailable locally; the next CI run must confirm the full Flutter suite and native builds.

## German default UI and inline exercise creation

The app now sets a German locale with Flutter SDK localization delegates, German date and decimal-weight displays, German starter exercise names, and German CSV headings. Existing stored exercise names and JSON technical identifiers are preserved. Runtime dependency resolution must include the SDK flutter_localizations package.

The training exercise picker offers creation even with no active library exercises. A new exercise is persisted before being referenced by a draft. Creation failures preserve existing draft fields and stored bytes; successfully created exercises remain in the library after discarding a training draft. Widget and model regression tests were added for these behaviors. Local Dart parsing and Python checks do not substitute for a pinned Flutter runtime test and native build.

## Compact exercise picker correction

The reported CI run passed 25 Flutter tests and failed the large-text keyboard regression before reaching the form: the squat row existed but its center was outside the exercise list's hit-test area. With a 320-by-568 viewport and double text size, the fixed picker heading and creation button consumed too much of the sheet height. The heading now scrolls with the exercise list, leaving more space for selectable rows while creation stays accessible.

The selection helper asserts that a full exercise row fits in the list viewport, centers the row before tapping, and retains strict hit-test checks. The existing compact-screen test still validates the Save target with keyboard insets and validation feedback. Local Python tooling tests and Dart formatting/parsing passed; pinned Flutter dependency resolution, analysis, and widget tests remain unavailable locally and require CI confirmation.
