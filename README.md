# Parked

A tiny macOS menu bar app for parking questions while studying, so you don't stop mid-review to go down a rabbit hole. Park the question, keep going, and clear the list later.

## Use

- **⌥⌘P**: opens the question box. ↩ adds a new line, **⌘↩** parks the question, and Esc cancels. Press ⌘V to attach a clipboard screenshot or image. Drag the box by its edges to move it. If the box is empty, clicking elsewhere closes it.
- **Menu bar icon**: shows how many questions are parked. Click it to see the list:
  - **Copy for Claude**: copies the question and its image together.
  - **Add answer → Copy as card**: copies `question >> answer` for RemNote.
  - **✓**: moves the question to `Done/`.
- **Topics**: a separate list of longer-term topics to revisit. Topics don't count toward the menu bar number.

Everything is stored as plain files in `~/Documents/Parked Questions/`:
- one `.md` file per question, plus a `.png` if it has an image
- `Topics.md` as a checklist

## Build

Requires macOS 14+ and Xcode / Swift 5.9+.

```bash
./build.sh
```

This builds `Parked.app`, ad-hoc signs it, and installs it to `~/Applications`.
