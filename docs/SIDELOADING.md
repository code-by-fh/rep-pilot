# Install Rep Pilot on an iPhone

## Build and publication status

A Rep Pilot native build, public release, and signed iPhone installation have not yet been verified. The inherited template's earlier SideStart IPA is not evidence that Rep Pilot builds or runs. See [VALIDATION.md](VALIDATION.md).

The workflow builds Flutter in release mode for a physical iOS device on macOS, without Apple signing. `scripts/package_ipa.py` packages `Runner.app` as `Payload/Runner.app` in an IPA. A simulator build cannot be used for this installation path. The minimum configured iOS version is 15.0; the actual IPA metadata is authoritative.

## Installation after a successful release

Follow the current official [SideStore installation guide](https://docs.sidestore.io/docs/installation/install) for the required Windows setup, pairing, developer trust, signing, and renewal steps. Supply Apple credentials only to the signing software you choose; never place them in this repository or CI.

After the intended public repository has a successful release, add this source in SideStore:

```text
https://github.com/code-by-fh/rep-pilot/releases/latest/download/altstore-source.json
```

Alternatively, download `sidestart-ios-unsigned.ipa` from that release and import it using SideStore's IPA import action. Extract the outer ZIP first when downloading a GitHub Actions artifact. AltStore Classic is another personal signing option. Use the signing tool's current instructions for account limits and renewal requirements.

The shared `code-by-fh/ios-apps` source includes Rep Pilot only after separate registration and a manual catalog refresh. An app release does not refresh it automatically.

## Device acceptance checks

After signing and installation:

1. Launch Rep Pilot and add a strength exercise.
2. Record a dated workout with several sets, weights in kg, and repetition counts.
3. Edit a set and verify the workout and exercise history.
4. Rename and archive an exercise; confirm old workout records remain readable.
5. Close and reopen the app and verify the saved journal remains present.
6. Export JSON, save it outside the app, and verify restore after reading the replacement confirmation.
7. Copy CSV and check the resulting table in a spreadsheet.
8. Install a later build with the same signing identity and confirm the journal remains available.

Record the exact build, device, iOS version, and results in the validation record. Compilation and synthetic packaging tests do not establish device behavior.
