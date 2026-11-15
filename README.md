# Rep Pilot

Rep Pilot is an offline strength training journal built from the [SideStart Flutter template](https://github.com/code-by-fh/sidestart). Record workout dates, weights in kilograms, and repetitions, then review your training history. License: [MIT](LICENSE).

## Training journal

- Create, rename, and archive exercises while keeping their history.
- Record dated workouts with multiple exercises and sets.
- Edit weight and repetition counts and remove entries when needed.
- Review workouts and exercise history, including recent and highest weights.
- Keep data locally without an account or cloud service.
- Copy a JSON backup or CSV table to the clipboard. Paste a JSON backup to restore it after confirming replacement of existing data.

JSON is the restore format. CSV is intended for spreadsheets and cannot be imported. Save exported JSON outside the app; clipboard contents alone are not a durable backup. Uninstalling the app or clearing its local storage can remove your journal.

The initial implementation is in development. See [validation evidence](docs/VALIDATION.md) for checks actually performed; an unsigned iOS build and signed iPhone test are separate milestones.

## Develop locally

Requirements: Python 3.10+, Git, and the Flutter SDK pinned in `.fvmrc`. This project is already configured in `app-config.json` with project name `rep_pilot`, organization `dev.codebyfh`, and display name `Rep Pilot`. Configure identity before generating native projects in any new template copy.

```powershell
.\scripts\install-flutter.ps1
# Run the PATH command printed by the script, then:
.\setup.ps1 -Device chrome
```

`scripts/bootstrap.py` generates missing platform projects and preserves existing ones. Run these checks after relevant changes:

```powershell
python -m unittest discover -s scripts -p test_*.py
flutter pub get
flutter analyze
flutter test
```

## Distribution

The intended public repository is `code-by-fh/rep-pilot`. Do not use the inherited `publish.ps1` repository creation helper: it creates a private repository, while this app requires a reviewed public destination for source publication. No release or available download is claimed by this local implementation. Once that repository exists and its first release succeeds, its app source will be:

```text
https://github.com/code-by-fh/rep-pilot/releases/latest/download/altstore-source.json
```

The inherited workflow builds and publishes on `main`/`master` pushes and manual runs. Pull requests do not publish. iOS output is an unsigned release device IPA requiring personal signing in SideStore or AltStore Classic. Android output is an APK using development signing; a permanent signing key is needed for dependable updates across builds.

Source metadata comes from the actual IPA. Version history and immutable IPA downloads are preserved. The pipeline uses its supplied `GITHUB_TOKEN`; never add Apple credentials, certificates, or personal GitHub tokens to the repository.

The inherited IPA filename remains `sidestart-ios-unsigned.ipa` for compatibility with the packaging and publication scripts; the app identity and download repository belong to Rep Pilot.

See [source publication](SOURCE.md) and [iPhone installation](docs/SIDELOADING.md). Rep Pilot must be registered separately before it can appear in the shared `code-by-fh/ios-apps` catalog. That catalog only refreshes through its manual workflow; app releases do not update it automatically.

All project text and UI labels use English. See [AGENTS.md](AGENTS.md).
