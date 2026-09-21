# Store prep — Capy Clicker (soft launch)

Portrait-only casual idle about capybaras. This folder holds listing copy
checklists. **No fake screenshot PNGs required** — capture real builds later.

## Icon (finalized)

| Item | Value |
|---|---|
| Status | **Finalized** — approved source wired in |
| Canonical file | `store/icon/app_icon.png` (1024×1024 PNG) |
| In-app asset | `assets/images/app_icon.png` (same bytes) |
| Shape | Soft rounded meadow / cream frame |
| Hero | Friendly pixel-ish capybara face |
| Accent | Tiny flowers on grass |
| Colors | Grass green `#6B9B4A`, cream `#FFF8EC`, warm brown `#5C3D1E` |

### Regenerate launcher icons

Uses [`flutter_launcher_icons`](https://pub.dev/packages/flutter_launcher_icons) configured in `pubspec.yaml` (`image_path` → `store/icon/app_icon.png`).

```bash
# From repo root; Flutter SDK on PATH
dart run flutter_launcher_icons
```

That refreshes Android mipmaps / adaptive icons and iOS `AppIcon.appiconset`.
Replace `store/icon/app_icon.png` (and copy to `assets/images/app_icon.png`) before re-running if the art changes.

## Portrait screenshots checklist (3 slots)

Capture on a tall phone frame (e.g. 1080×1920 or device defaults). Order matters.

### 1 — Herd + progress

- **EN caption:** Grow your cozy capybara herd — tap flowers, watch them multiply.
- **RU caption:** Собирай уютное стадо капибар — тапай цветы и смотри, как оно растёт.

### 2 — Merge + mud

- **EN caption:** Merge twins into bigger buddies. Drop one in the mud for a gentle boost.
- **RU caption:** Сливай одинаковых в более крупных. Кинь капибару в лужу — будет мягкий буст.

### 3 — Daily cozy / berries

- **EN caption:** Morning Cozy gift once a day. Rare berry baskets for a sweet burst.
- **RU caption:** «Утренний уют» раз в день. Редкие корзины ягод — сладкий burst прогресса.

## Listing notes (placeholders)

- **EN subtitle:** Cozy idle meadow · merge · mud · daily gift
- **RU subtitle:** Уютный idle-луг · слияние · лужа · ежедневный подарок
- **IAP:** none yet (soft launch) — monetization not approved
- **Audio:** SFX deferred — mobile uses light haptics on tap/merge; visuals carry the juice

## Capture tips

1. Fresh save or staged herd of 4–6 for readability.
2. Show cream progress bar + boost tint if mud active (shot 2).
3. Optional: gift chip «Уют» visible for shot 3 (before claim).
4. Keep system status bar clean / demo mode if available.
