# S26+ gray flash — root cause (Семья)

Playtest 2026-09-30, Samsung Galaxy S26+. The cream-window fix in `c7f419c`
did **not** stop the full-screen gray flash after every flower tap.

## What was wrong with the previous theory

`NormalTheme.windowBackground = meadow cream` only paints the **Activity window
behind** the Flutter view. It cannot cover a color that Flutter or Samsung
draws **on top of** that window. Two things still did:

1. **Impeller + `RenderMode.surface` (SurfaceView).** Opaque Flutter uses a
   SurfaceView. That view punches a hole in the window. When a tap calls
   `setState` on the whole game tree, the meadow `Image` lives in the same
   layer and the raster thread can miss a frame. SurfaceFlinger then shows the
   undefined buffer — a full-screen **gray** — not `#FFF8EC`. Cream behind the
   hole never wins, which is why `c7f419c` looked correct and still flashed gray.
2. **Night theme still inherited gray.** `values-night` `NormalTheme` parented
   `Theme.Black`. Samsung One UI in dark mode reads `android:colorBackground`
   from that parent (dark gray), and `enforceNavigationBarContrast` (default
   **true**) composites a gray scrim when the nav bar is transparent. The
   previous patch set `windowBackground` only, so `colorBackground` stayed gray.
3. **Contributing, not sufficient alone:** Material 3's Android splash factory
   is `InkSparkle`. A broken sparkle pass draws a solid gray ripple. Flower
   dots use `GestureDetector` (no ink), but HUD `IconButton` / `InkWell` do not.
   `AnimatedSwitcher` on the meadow plate also rebuilt in the tap `setState`
   path, so the image could drop a frame even with `gaplessPlayback`.

Ruled out as the full-screen flash: `HapticFeedback` and `audioplayers` (method
channels, no platform view), the tip overlay (once per install), and the
floating «+N%» layer (`IgnorePointer`, not a barrier).

## Fix

- `MainActivity.getRenderMode() = texture`. TextureView keeps the last frame
  instead of clearing the SurfaceView hole to gray.
- Day **and** night themes: `windowBackground` **and** `colorBackground` are
  `#FFF8EC`. Nav-bar contrast enforcement is off. Night theme no longer
  parents `Theme.Black`.
- `CozyTheme`: `scaffoldBackgroundColor` / `canvasColor` = meadow cream,
  `splashFactory: NoSplash.splashFactory`, `highlightColor` / `splashColor`
  transparent. `SystemUiOverlayStyle` sets both contrast flags to false.
- Meadow plate: the `Image` widget instance is **cached** until `meadowId`
  changes, inside a `RepaintBoundary`. A tap `setState` does not update that
  element, so the plate is not invalidated. No `AnimatedSwitcher` on the hot path.
- First-frame `frameBuilder` paints cream, not an empty/gray box.

## Wallow + temporary puddle (same build)

- Drop on the puddle plays an obvious ~1s wallow (hop, spin, sink, splash).
  Hit uses sprite center **or** the finger, radius 0.16 (the old 0.11 missed
  the visible sprite, so the overlay often never started).
- Mud spawns on grass for 12–20s, despawns, waits 6–10s, respawns elsewhere.
  Position is not in the save. Toast «Лужа!».

## Emulator (this box, 2026-09-30)

Host is x86_64. `/dev/kvm` existed but was not group-readable; it was opened
for the session and the AVD ran with `-accel on` (no need for `-accel off`).

- Emulator 37.3.2, AVD `capy34`, API 34 google_apis x86_64, `-no-window`,
  SwiftShader. Boot completed.
- The **phone** release APK is arm64-v8a only. `adb install` of that APK
  succeeded, then launch crashed: `libflutter.so` is EM_AARCH64, the AVD is
  EM_X86_64 (no ARM translator). The same commit was rebuilt
  `--target-platform android-x64` and that APK was what the emulator ran.
- Shots in `store/emulator/`:
  - `04-meadow-before-tap.png` — puddle present («сюда!», left).
  - `05-immediately-after-tap.png` / `07-after-third-tap.png` — flower taps,
    grass 3→7, meadow stays painted. No full-screen gray.
  - `09-puddle-maybe-gone.png` — puddle has **moved** (center, under the nest).
  - `11-puddle-gone.png` — no puddle on the meadow (cooldown).
- `adb shell input swipe` did not register as a Flutter drag onto the hit
  circle, so the wallow frames were not captured. Hit path is covered by
  `isOverMud` / `tryMudWallow` tests (fails while despawned, succeeds on the
  live center).
