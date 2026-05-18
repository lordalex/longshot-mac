# LongShot

LongShot is a native macOS utility for capturing long vertical screenshots from scrollable pages and app views.

Select the visible scrollable area, and LongShot captures overlapping slices while scrolling, stitches them into one image, and saves the result as a PNG.

## Features

- Native macOS app with menu bar access
- Drag-to-select capture area
- Automatic scroll and stitch workflow
- ScreenCaptureKit-based capture path
- Capture presets for scroll speed, page length, and delay
- Preview window with copy, open, and reveal actions
- App icon and menu bar icon
- PNG output to `~/Pictures/LongShot`

## Requirements

- macOS 15.2 or newer is recommended for ScreenCaptureKit region capture.
- Xcode command line tools or Xcode with `swiftc`, `iconutil`, and `codesign`.
- Screen Recording permission.
- Accessibility permission for automated scrolling.

## Build

```sh
./build.sh
```

The local build is written to:

```text
build/LongShot.app
```

## Install

Install LongShot to `/Applications` before using it regularly:

```sh
./install.sh
```

macOS privacy permissions are tied to the signed app identity and location. Running repeatedly from `build/LongShot.app` can cause repeated permission prompts or blank captures.

## Use

1. Open `/Applications/LongShot.app`.
2. Enable Screen Recording and Accessibility permissions in System Settings.
3. Click `Capture Long Page`.
4. Drag over only the scrollable content area, not browser chrome or app toolbars.
5. Release the mouse. LongShot hides, focuses the selected area, scrolls, captures, stitches, and opens a preview.

Captures are saved in:

```text
~/Pictures/LongShot
```

## Permissions

LongShot needs two macOS permissions:

- **Screen Recording:** allows LongShot to read pixels from windows on screen.
- **Accessibility:** allows LongShot to send scroll events to the selected page or app.

If captures are black, blank, or show only the desktop wallpaper, remove old LongShot entries from Privacy & Security, then add `/Applications/LongShot.app` again and reopen the app.

## Troubleshooting

**The app keeps asking for permissions**

Use the installed app at `/Applications/LongShot.app`, not the copy in `build/`.

**The capture is black or blank**

Screen Recording is not active for the installed app. Re-enable it in System Settings, then quit and reopen LongShot.

**The capture does not scroll**

Accessibility permission is missing, or the selected area did not focus the scrollable content. Try selecting the inner page content and avoid browser chrome.

**The stitched output repeats headers**

Sticky headers, fixed footers, animations, and lazy-loaded content can confuse image overlap detection. Try a smaller selected area that excludes sticky browser/app UI.

## Current Limitations

- Sticky headers and footers may repeat.
- Animated content can reduce stitch quality.
- Protected media or apps may block capture.
- Selection should stay within one display.
- PNG is the only export format today.

## Development Notes

This project intentionally avoids an Xcode project file for now. The app is compiled directly with `swiftc` in `build.sh`.

Useful commands:

```sh
./build.sh
./install.sh
open /Applications/LongShot.app
```

## Roadmap

- PDF export
- Manual crop/trim in preview
- Raw frame debug mode
- Better sticky-header removal
- Browser-specific capture mode
- Signed/notarized release builds
