# World zones — forest playfield

Normalized coordinates **(0–1)** relative to the portrait meadow playfield
(`SizedBox` under camera zoom in `GameScreen`). Same space as
`Capybara.position`, mud puddle, berry basket, and flower dots.

Source of truth: `lib/features/game/models/world_zones.dart` (`WorldZones`).

## Walkable meadow (grass clearing)

Axis-aligned rect approximating the open grass in `assets/images/bg_forest.png`:

| Edge | Value | Intent |
|---|---|---|
| `meadowLeft` | **0.10** | Inset from left trunk / shrub |
| `meadowRight` | **0.86** | Clear of large right-side tree |
| `meadowTop` | **0.52** | Below canopy / dense treeline |
| `meadowBottom` | **0.92** | Padding above bottom edge |

**Trees are blocked** — no spawn, no drag-end rest, no merge placement on
trunks or canopy edges. Helper: `WorldZones.clampToMeadow(Offset)`.

## Entities clamped / placed on meadow only

| Entity | How |
|---|---|
| Capybaras | Spawn, drag-end (`updatePosition`), merge result, mud wallow snap, load-time reclamp |
| Flowers | Fixed `WorldZones.flowerPositions` (all inside rect) |
| Berry basket | `BalanceV0.berryPosX/Y` must stay inside meadow |
| Mud puddle | `BalanceV0.mudCenterX/Y` must stay inside meadow |

Idle wander (if added later) must also use `clampToMeadow` / `randomInMeadow`.

## Visual

No heavy debug overlay in release. Soft background vignette in
`MeadowBackground` is enough; optional translucent oval is unused.
