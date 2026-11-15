# Rep Pilot source publication

Rep Pilot is configured locally for the intended public repository `code-by-fh/rep-pilot`. The repository, releases, and shared catalog registration have not been created by this implementation.

After a successful public release, the stable app source URL will be:

```text
https://github.com/code-by-fh/rep-pilot/releases/latest/download/altstore-source.json
```

The app's source and versioned IPA downloads live in its own repository. Metadata is derived from the actual IPA: display name, bundle identifier, version, build number, minimum iOS version, size, and permissions. The source generator supplies a Rep Pilot workout journal description and a deterministic dumbbell listing icon. The `lifestyle` category is used because the [AltStore source schema](https://faq.altstore.io/developers/make-a-source) does not define a health and fitness category.

The native launcher icon is a separate platform asset and must be checked in the actual generated native build.

Do not use the inherited `publish.ps1` repository creation helper for this app: it creates a private repository. Set up and review a public `code-by-fh/rep-pilot` destination explicitly before publishing.

## Release workflow

Pushes to `main`/`master` and manual workflow runs build configured apps and publish from a public repository. Pull requests do not publish. Generated version/build tags do not trigger another run. Source history is preserved, and published version/build identities cannot be reused with different IPA bytes.

The unsigned release device IPA is packaged as `sidestart-ios-unsigned.ipa`, retaining the template pipeline's expected filename. It still contains Rep Pilot's native identity. Personal Apple signing happens afterward on the user's device installation path, outside CI.

For an existing validated build, the inherited local publisher accepts:

```powershell
python scripts/publish_source.py --ipa downloads/run-123/sidestart-ios-unsigned.ipa --repository code-by-fh/rep-pilot
```

Run publication only after creating and reviewing the intended public repository and release files. No Apple credentials, certificates, or personal GitHub tokens belong in source or CI.

## Shared catalog

The shared source is:

```text
https://raw.githubusercontent.com/code-by-fh/ios-apps/main/altstore-source.json
```

Register Rep Pilot's public app source in that repository after a working app release exists. Publishing Rep Pilot does not update the shared catalog. Its refresh is manual on `main`, after any required registry change:

```powershell
gh workflow run refresh-catalog.yml --repo code-by-fh/ios-apps --ref main
```

There is no scheduled or automatic catalog publication. This implementation does not register the app or trigger the catalog workflow.
