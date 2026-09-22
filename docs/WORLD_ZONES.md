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

| # | Название | Family power (Σ levels) | Rect (L, T, R, B) | Base zoom | Feel |
|---|----------|-------------------------|-------------------|-----------|------|
| 0 | **Тёплая опушка** | 0–4 | 0.10, 0.52, 0.86, 0.92 | **1.00** | Small starter meadow by the tree line |
| 1 | **Ягодная поляна** | 5–9 | 0.06, 0.50, 0.90, 0.93 | **0.82** | Wider sides — room for berry bushes |
| 2 | **Солнечный прогал** | 10–15 | 0.05, 0.40, 0.91, 0.945 | **0.66** | Deeper into the forest (taller clearing) |
| 3 | **Большой луг** | **16+** | 0.03, 0.34, 0.94, 0.96 | **0.50** | Most of the lower ~⅔; canopy stays wall |

Unlock metric is **family power** = sum of capy levels on the active meadow
(not raw headcount). Soft-cap still limits **bodies** (12); merge + refill
raises power so levels matter (12×Lv1 = power 12 → Солнечный, not Большой).

API: `WorldZones.gladeForFamilyPower(power)` / legacy `gladeForHerd(power)`.
Clamp/spawn keys still use the active named meadow’s `minHerd` power key.

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

No toast on relaunch. HUD chips under the progress bar are split:

- **«семья N/12»** — body count (soft-cap)
- **«сила N/need»** — family power toward the next glade goal
- **«поляна: …»** — current Sunny Glade name only

Once a glade is unlocked (`sunnyGladeAnnounced`), merge that shrinks the herd
does **not** revoke it — walkable rect / camera baseline stay on the opened
glade (fixes playtest “Berry 4/12 → Warm after merge” regression feel).

## Entities clamped / placed on meadow only

| Entity | How |
|---|---|
| Capybaras | Spawn, drag-end, merge, mud snap, load-time + glade-change reclamp |
| Flowers | Fixed `flowerPositions` inside **Тёплая опушка** (valid in every glade) |
| Berry basket | `BalanceV0.berryPosX/Y` inside starter glade |
| Mud puddle | `BalanceV0.mudCenterX/Y` inside starter glade |

Idle wander (`CapyWander` / `MeadowDraggableCapybara`) uses `clampToMeadow` /
`randomInMeadow` with the current herd count; commits via `updatePosition`.

## Visual

No heavy debug overlay in release. Soft vignette in `MeadowBackground`;
glade chip is enough for orientation.

### Уникальные фоны полян

Каждая активная поляна / mist-биом показывает свой portrait PNG
(`assets/images/bg_*.png`). Маппинг:

| `meadowId` | Asset | Название |
|------------|-------|----------|
| `warm_edge` | `bg_warm_edge.png` | Тёплая опушка |
| `berry_glade` | `bg_berry_glade.png` | Ягодная поляна |
| `sunny_clearing` | `bg_sunny_clearing.png` | Солнечный прогал |
| `great_meadow` | `bg_great_meadow.png` | Большой луг |
| `mist_edge` | `bg_misty_woods.png` | Туманный бор |
| *(unknown)* | `bg_forest.png` | legacy fallback only |

API: `WorldZones.backgroundAssetForMeadow(id)`.
`MeadowBackground(meadowId: …)` берёт активный id из `GameState.activeMeadowId`
и плавно crossfade ~400 ms при смене поляны / биома.
