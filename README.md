# LongShot

LongShot is a native macOS app for capturing long vertical screenshots from any scrollable area on screen.

## Build

```sh
./build.sh
```

The built app is written to:

```text
build/LongShot.app
```

For macOS privacy permissions, install the app to a stable location:

```sh
./install.sh
```

## Use

1. Open `/Applications/LongShot.app`.
2. Grant Screen Recording and Accessibility permissions when macOS asks.
3. Click `Capture Long Page` in the LongShot window or choose it from the menu bar item.
4. Drag over the visible scrollable content area.
5. Confirm capture.

The app scrolls the selected area, captures overlapping slices, stitches them, and saves a PNG in `~/Pictures/LongShot`.

## MVP Limitations

- Sticky headers and animated content can reduce stitching quality.
- The selected area should be inside one display.
- Some protected apps or media surfaces may block screenshots.
- Browser-specific full-page capture can be added later as a more reliable mode.
