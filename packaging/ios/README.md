# VectorCraft for iPad

A small native app (Swift, ~300 lines) that bundles the WebAssembly build of VectorCraft and runs it
offline in a full-screen `WKWebView`. The drawing app itself is the same Rust code as everywhere
else; the Apple Pencil and touch handling lives in Rust too (`apps/vectorcraft-web/src/pencil.rs`,
`crates/ui-egui/src/touch.rs`).

| File | Role |
|---|---|
| `VectorCraft/VectorCraftApp.swift` | App entry, full screen, no status bar |
| `VectorCraft/WebViewController.swift` | The web view; Pencil double tap / squeeze; Save/Export to the Files picker; outside links to Safari |
| `VectorCraft/BundleSchemeHandler.swift` | Serves the bundled `web/` folder at `vectorcraft://localhost/` (a real origin: WebAssembly, localStorage, Web Locks) |
| `fetch-web.sh` | Puts the web build in `web/` (downloaded from CI, or `--build` locally) |

## Install it on your iPad

You need: a Mac with **Xcode 16 or later** (free, Mac App Store), an **Apple ID**, the iPad and a USB
cable. No Rust, no Homebrew.

1. **Get the code and the web build.** In Terminal:

   ```sh
   git clone https://github.com/gniax/vectorcraft-ipad.git
   cd vectorcraft-ipad
   packaging/ios/fetch-web.sh
   ```

   The script downloads the web build GitHub Actions made from this branch (about 20 MB) into
   `packaging/ios/web/`. Run it again to update.

2. **Open the project:** `open packaging/ios/VectorCraft.xcodeproj`

3. **Sign it.** Xcode › Settings › Accounts › `+` › Apple ID, sign in. Then click the *VectorCraft*
   project (left), the *VectorCraft* target, *Signing & Capabilities*: tick *Automatically manage
   signing* and pick your *Team* (your name, "Personal Team" with a free Apple ID). If Xcode says the
   bundle identifier is taken, change `io.github.gniax.vectorcraft` to something of yours, e.g.
   `com.yourname.vectorcraft`.

4. **Prepare the iPad** (first time only): plug it in, unlock it, tap *Trust This Computer*. Turn on
   *Settings › Privacy & Security › Developer Mode* and restart when asked (the switch appears
   once Xcode has seen the iPad).

5. **Run.** In Xcode's toolbar pick your iPad as the destination and press ▶ (Cmd+R). The first time,
   the iPad refuses to open the app: go to *Settings › General › VPN & Device Management*, tap your
   Apple ID under *Developer App*, then *Trust*. Open VectorCraft from the Home Screen.

From then on the app works without the Mac and without a connection.

### Free Apple ID or paid developer account

| | Free Apple ID ("Personal Team") | Apple Developer Program (99 USD/year) |
|---|---|---|
| App keeps opening for | **7 days**, then repeat step 5 (your documents stay) | 1 year |
| Devices | your own, up to 3 | up to 100, TestFlight possible |

With a free Apple ID, plug the iPad in and press Run again before the week is out; nothing is lost.

### Updating

```sh
git pull
packaging/ios/fetch-web.sh
```

then Run again from Xcode.

## Using it

- **Apple Pencil** draws (with pressure for pressure brushes); hold it still to get the context menu.
  Hover (iPad Pro, M2 and later) moves the pointer without drawing.
- **Fingers navigate:** pinch to zoom, two fingers to pan, two-finger tap undoes, three-finger tap
  redoes. Once you've used the Pencil, a finger or your palm never draws.
- **Pencil double tap** (2nd gen, Pro) or **squeeze** (Pro) does what *Settings › Apple Pencil* says:
  Eraser and back, previous tool, or the Color panel.
- **Files:** File › Open shows the iOS file picker (Files, iCloud Drive). Save and Export ask where to
  put the file. Unsaved work is kept by Data Recovery if the app is closed.
- **Keyboard:** a Magic Keyboard's shortcuts are the desktop ones (Tab hides the panels).

## For developers

- Build the web part yourself instead of downloading it: `packaging/ios/fetch-web.sh --build`
  (needs `rustup target add wasm32-unknown-unknown` and [trunk](https://trunkrs.dev)).
- Debug builds let Safari's Web Inspector attach (Safari › Develop › your iPad).
- CI (`.github/workflows/ipad.yml`) builds the web app, publishes it for `fetch-web.sh` (release
  `ipad-web-latest`) and to <https://gniax.github.io/vectorcraft-ipad/>, and builds this project for the
  simulator.
