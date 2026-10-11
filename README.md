# Parked

<img src="Resources/AppIcon.png" width="128" alt="Parked app icon">

A tiny macOS menu bar app for parking questions while studying, so you don't stop mid-review to go down a rabbit hole. Park the question, keep going, and clear the list later.

## Download

1. Get `Parked-<version>.zip` from the [latest release](https://github.com/GoooDUFO/parked/releases/latest).
2. Unzip it and drag **Parked.app** into Applications.
3. Open it. The app isn't notarized by Apple, so the first launch is blocked with an "Apple could not verify…" message. To allow it, go to **System Settings → Privacy & Security** and click **Open Anyway**.

   Or remove the download quarantine flag in Terminal:

   ```bash
   xattr -dr com.apple.quarantine /Applications/Parked.app
   ```

Works on macOS 14+, on both Apple Silicon and Intel.

## Use

- **⌥⌘P** (changeable in ⚙ Settings): opens the question box. ↩ adds a new line, **⌘↩** parks the question, and Esc cancels. Press ⌘V to attach a clipboard screenshot or image. Drag the box by its edges to move it. If the box is empty, clicking elsewhere closes it.
- **Menu bar icon**: shows how many questions are parked. Click it to see the list:
  - **Copy for Claude**: copies the question and its image together.
  - **Add answer → Copy as card**: copies `question >> answer` for RemNote.
  - **✓**: moves the question to `Done/`.
- **⚙ Settings**: change the shortcut, turn "Open at login" on or off, or quit.
- **Topics**: a separate list of longer-term topics to revisit. Topics don't count toward the menu bar number.

Everything is stored as plain files in `~/Documents/Parked Questions/`:
- one `.md` file per question, plus a `.png` if it has an image
- `Topics.md` as a checklist

## Build

Requires macOS 14+ and Xcode / Swift 5.9+.

```bash
./build.sh
```

This builds a universal `Parked.app`, ad-hoc signs it, and installs it to `~/Applications`. Run `./build.sh --release` to package `build/Parked-<version>.zip` instead.

To regenerate the app icon after editing `scripts/make-icon.swift`, run `swift scripts/make-icon.swift`.

## License

[MIT](LICENSE)
