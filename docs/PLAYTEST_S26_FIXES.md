# Playtest S26+ fixes (Samsung) — Семья

Self-test notes after Nikita’s Galaxy S26+ playtest. Always **Семья**.

## 1. Not fullscreen → edge-to-edge meadow

**Cause:** Opaque system bars + gray `?android:colorBackground` window; HUD
`SafeArea` was fine, but the Android window did not draw under the cutout.

**Fix:**
- `main.dart`: `SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)` +
  transparent status/nav overlay styles (portrait kept).
- Android `LaunchTheme` / `NormalTheme`: solid cream `windowBackground`
  (`@color/meadow_cream` / `#FFF8EC`), transparent system bars,
  `windowLayoutInDisplayCutoutMode=shortEdges`.
- Launch drawables use cream (not white / `?android:colorBackground`).
- Game UI: meadow plate full-bleed; HUD padded with `MediaQuery.padding`
  (top inset) so chips clear the cutout while grass fills the screen.

## 2. Gray flash after every flower tap (P0)

**Likely causes (verified in code):**
1. **Android `NormalTheme`** used `?android:colorBackground` → system gray
   flashed behind Flutter on some Samsung rebuilds.
2. **`MeadowBackground` `AnimatedSwitcher`** lived in the same rebuild path as
   flower `setState` → plate could crossfade/reload even when `meadowId`
   was unchanged.
3. Floating gain layer was already `IgnorePointer` and not a full-screen
   barrier; tip overlay only shows once — not the per-tap flash.

**Fix:**
- Solid cream `NormalTheme` / launch backgrounds (never system gray).
- Isolate `_MeadowPlate` behind a `ValueKey(meadowId)` so only a real meadow
  change rebuilds/crossfades the image (`gaplessPlayback: true`).
- Scaffold / root cream `#FFF8EC` so any frame without Flutter content is
  meadow-cream, not gray.

## 3. Roles felt useless → visible Семья benefits

**Fix:**
- Assign toast: «Няня: +15% авто» / «Собиратель: +20% находки…» /
  «Сторож: +1 к мягкому лимиту…».
- Live bonus line in Уют → Роли (`activeRoleBonusesRu`).
- Plain-RU tip lines under the Роли tab for each role.
- Effect strings show concrete % / soft-cap numbers.

## 4. Glade unlock by count only → **сила семьи**

**Before:** raw `herdCount` bands 0–4 / 5–7 / 8–10 / 11–12.

**After:** family power = **Σ levels** on the active meadow:

| Поляна | Сила |
|--------|------|
| Тёплая опушка | 0–4 |
| Ягодная поляна | **≥5** (band 5–9) |
| Солнечный прогал | **≥10** (band 10–15) |
| Большой луг | **≥16** |

Soft-cap still limits **bodies** (12). 12×Lv1 = сила 12 → Солнечный, not
Большой. Merge frees a slot; calling a new Lv1 raises Σ levels — levels
matter; merge is the smart path to Большой луг.

Goals HUD: `сила N/need` (not misleading raw count). Docs/tests/sims
migrated (`WORLD_ZONES.md`, `BALANCE_V0.md`).

## 5. Collapsible quest / goal UI

Top cream «задания» block collapses to a thin bar (goal one-liner + chevron).
Preference persisted (`SharedPreferences` key
`capy_clicker_goals_collapsed_v1`). Spend panel left as-is (light). Priority
was freeing meadow vertical space on tall phones.

## Verification

- `flutter analyze` — clean
- `flutter test` — green
- Release: arm64-v8a APK in `store/` + GitHub Release (chat can’t attach >25MB)

## Out of scope

iOS-only polish, new biomes.
