# Reproduction Prompts

This file summarizes the prompt sequence used to create LongShot. It is written so another person can reproduce a similar outcome with an AI coding agent.

The exact code may differ, but this sequence preserves the product intent, implementation constraints, debugging path, and polish passes that shaped the app.

For a canonical single-prompt version, see [POM_PROMPT.md](POM_PROMPT.md).

## 1. Product Idea And Planning

```text
I need a Mac app that can screenshot a long vertical page automatically.

The user should select an area, press a button, and the app should scroll as needed to capture the whole page. Let's plan the product and technical approach before building.
```

Expected outcome:

- Decide on a native macOS app.
- Identify required permissions: Screen Recording and Accessibility.
- Define capture flow: select area, capture, scroll, stitch, preview, save.
- Note hard problems: sticky headers, lazy-loading, animations, protected content, multi-display scaling.

## 2. Build The First Native App

```text
Go build the app.

Create a native macOS app in the current workspace. It should let me select a screen area, automatically scroll, capture overlapping slices, stitch them into one image, preview the result, and save PNGs.
```

Expected outcome:

- Create a small native AppKit or SwiftUI macOS project.
- Include a build script.
- Create a menu bar item or small launch window.
- Implement a selection overlay.
- Implement a capture manager.
- Implement an image stitching engine.
- Save captures to `~/Pictures/LongShot`.

## 3. Make Launch Behavior Obvious

```text
The app is not running.

When I open it, I need to see something obvious. Add a visible launch window, not only a menu bar item.
```

Expected outcome:

- Add a normal control window.
- Keep the menu bar item.
- Add buttons for capture, permissions, and captures folder.
- Add reopen behavior so clicking the app again brings the window back.

## 4. Fix Focus And Scrolling

```text
It did not work. I selected the area, but I got a blank preview. It did not scroll and capture what I selected.

Fix the capture flow so the selected page gets focus and receives scroll events.
```

Expected outcome:

- Avoid modal dialogs after selection.
- Hide the app while capturing.
- Click/focus the selected region before sending scroll events.
- Return with a preview after capture.

## 5. Stabilize macOS Permissions

```text
It keeps asking for permissions even though I already gave them.

Fix the macOS permission loop. Use a stable installed app identity and do not keep prompting repeatedly.
```

Expected outcome:

- Sign the app consistently.
- Install to `/Applications`.
- Warn users not to run from `build/` for normal use.
- Add clearer permission diagnostics.
- Explain how to remove stale Privacy & Security entries.

## 6. Fix Wallpaper, Blank, And Black Captures

```text
It captured the wallpaper or behind the windows I wanted to capture.

Then it captured a blank or black page.

Fix the screen capture backend so it captures the real selected window content.
```

Expected outcome:

- Treat wallpaper/blank/black frames as permission or backend failures.
- Use ScreenCaptureKit for in-process capture.
- Add checks for mostly black output.
- Keep useful error messages for missing Screen Recording permission.

## 7. Fix Retina And Preview Scaling

```text
The capture looks zoomed in. I only see the left side of the content.

Think carefully about Retina scaling and preview behavior.
```

Expected outcome:

- Separate capture correctness from preview display.
- Do not force raw pixel dimensions into AppKit point-based preview views.
- Fit the preview image width to the preview window.
- Keep the saved PNG full resolution.

## 8. Add A Custom App Icon

```text
Use this image as the icon for the app where appropriate and also as the icon for the top macOS menu.
```

Expected outcome:

- Inspect whether the image has real transparency.
- If the checkerboard is baked in, extract the useful mark.
- Generate `AppIcon.icns`.
- Generate a small menu bar template icon.
- Update `Info.plist`.
- Copy icon resources into the app bundle.
- Use the template icon for the status item.

## 9. Improve UX And UI

```text
Create a team of macOS UX/UI experts and improve the app.

Focus on modern macOS utility UX: first-run guidance, permissions clarity, menu bar behavior, preview/export UX, capture settings, error states, and visual polish.
```

Expected outcome:

- Add permission status to the main window.
- Add capture presets for speed, page length, and delay.
- Persist settings with `UserDefaults`.
- Add toolbar actions in preview: reveal, open, copy.
- Disable menu actions when not applicable.
- Improve selection overlay copy.

## 10. Refine Visual Direction

```text
The UI is too plain. Add some glass look or color.
```

Then, after review:

```text
The green and blue do not look right. Look at the screenshot and rethink it.
```

Expected outcome:

- Try a translucent glass/macOS utility treatment.
- Avoid loud teal/blue/green if it fights the app icon.
- Prefer neutral graphite glass.
- Use muted permission indicators.
- Keep orange only for warnings or missing permissions.
- Keep the app icon as the main visual anchor.

## 11. Move Project And Keep Path Straight

```text
I changed the path of the project. It is now one level up. Do you see it?
```

Expected outcome:

- Detect duplicate project folders.
- Confirm the new canonical path.
- Continue all work in the new path.

Canonical path used:

```text
/Volumes/DEV/2026/LongShotMac
```

## 12. Put It In Git And Publish To GitHub

```text
Put this into git and upload it to GitHub. Do what is necessary to make that happen.
```

Expected outcome:

- Initialize git.
- Add `.gitignore`.
- Ignore `build/` and `.DS_Store`.
- Commit source, resources, scripts, and docs.
- Create a GitHub repo.
- Push `main`.
- Make repo public if requested.

## 13. Improve The Public README

```text
Is the README the best it can be?
```

Expected outcome:

- Replace a minimal README with a public-facing README.
- Cover features, requirements, build, install, use, permissions, troubleshooting, limitations, development notes, and roadmap.

## Suggested One-Shot Prompt

If you want to reproduce a similar app from scratch with a capable coding agent, use this condensed prompt:

```text
Build a native macOS app named LongShot.

Goal:
Create a utility that captures long vertical screenshots from any scrollable page or app view. The user opens the app, clicks Capture Long Page, drags over the scrollable content area, and the app automatically focuses that area, scrolls, captures overlapping slices, stitches them into one PNG, saves it to ~/Pictures/LongShot, and opens a preview.

Technical requirements:
- Use Swift/AppKit.
- Build with a simple ./build.sh script, no Xcode project required.
- Install with ./install.sh to /Applications/LongShot.app.
- Use ScreenCaptureKit for region capture where available.
- Use Accessibility/CGEvent scroll events for scrolling.
- Require Screen Recording and Accessibility permissions.
- Handle blank/black captures with clear errors.
- Save PNG output.
- Add a selection overlay with clear instructions.
- Add a preview window with Reveal, Open, and Copy toolbar actions.
- Add capture settings for scroll speed, page length, and delay, persisted with UserDefaults.
- Add a menu bar icon and app icon.
- Keep build artifacts out of git.

UX requirements:
- Show a compact utility window on launch.
- Show permission status in the main window.
- Use a restrained neutral graphite/glass macOS utility look.
- Avoid loud accent colors.
- Make the app usable from both the launch window and menu bar.
- Make failures actionable.

Repository requirements:
- Add README.md with build/install/use/permissions/troubleshooting/roadmap.
- Add .gitignore.
- Initialize git, commit, create a public GitHub repo, and push main.
```

## Notes

The hardest parts are not the window UI. They are:

- macOS privacy identity and permission stability.
- Correct screen coordinate handling across Retina and multiple displays.
- Keeping the selected page focused so scroll events go to the right app.
- Previewing full-resolution Retina PNGs without making the preview look zoomed.
- Stitching content with sticky headers, animations, and lazy loading.
