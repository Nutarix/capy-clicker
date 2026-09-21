# World zones — «Солнечные поляны» (Sunny Glades)

Normalized coordinates **(0–1)** relative to the portrait meadow playfield
(`SizedBox` under camera zoom in `GameScreen`). Same space as
`Capybara.position`, mud puddle, berry basket, and flower dots.

Source of truth: `lib/features/game/models/world_zones.dart` (`WorldZones`,
`SunnyGlade`).

As the herd grows, the walkable grass **opens into wider sunny glades**.
Trees and the dense canopy stay a soft wall outside the active circle —
capybaras never rest on trunks.

## Четыре круга полян

| # | Название | Herd | Rect (L, T, R, B) | Base zoom | Feel |
|---|----------|------|-------------------|-----------|------|
| 0 | **Тёплая опушка** | 0–2 | 0.10, 0.52, 0.86, 0.92 | **1.00** | Small starter meadow by the tree line |
| 1 | **Ягодная поляна** | 3–5 | 0.06, 0.50, 0.90, 0.93 | **0.82** | Wider sides — room for berry bushes |
| 2 | **Солнечный прогал** | 6–8 | 0.05, 0.40, 0.91, 0.945 | **0.66** | Deeper into the forest (taller clearing) |
| 3 | **Большой луг** | 9–12 | 0.03, 0.34, 0.94, 0.96 | **0.50** | Most of the lower ~⅔; canopy stays wall |

API: `WorldZones.gladeForHerd(count)` → `SunnyGlade` (name, rect, `baseZoom`).
Clamp/spawn: `clampToMeadow` / `randomInMeadow` with `herdCount:`.

**Trees are blocked** outside the active glade rect.

## Camera — step back to admire the grove

Target scale = `min(glade.baseZoom, fitZoom)`:

1. **Glade baseline** — pulls out as each Sunny Glade opens.
2. **Fit zoom** — padded herd bbox span vs comfort span `0.48`; if the
   herd is spread wider, scale down further ("step back to admire the grove",
   floor `0.50`).

Smooth `AnimatedScale` ~450 ms. Soft, not FOMO.

## Unlock toast (once)

When a new glade opens for the first time (persisted
`sunnyGladeAnnounced`), a gentle snackbar:

- «Открылась Ягодная поляна»
- «Открылся Солнечный прогал»
- «Открылся Большой луг»

No toast on relaunch. A small 🌿 chip shows the current glade name under
the progress bar.

## Entities clamped / placed on meadow only

| Entity | How |
|---|---|
| Capybaras | Spawn, drag-end, merge, mud snap, load-time + glade-change reclamp |
| Flowers | Fixed `flowerPositions` inside **Тёплая опушка** (valid in every glade) |
| Berry basket | `BalanceV0.berryPosX/Y` inside starter glade |
| Mud puddle | `BalanceV0.mudCenterX/Y` inside starter glade |

Idle wander (if added later) must also use `clampToMeadow` / `randomInMeadow`
with the current herd count.

## Visual

No heavy debug overlay in release. Soft vignette in `MeadowBackground`;
glade chip is enough for orientation.
