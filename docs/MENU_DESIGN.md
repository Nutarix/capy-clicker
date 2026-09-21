# Main menu design — Grow! Capy!

Краткий дизайн-док для главного меню (title screen). Язык: RU.

## Рефы (consulted)

- **Stardew Valley title screen** — scenic full-bleed backdrop; compact vertical CTA list
  (New / Load / Co-op); logo as identity dominance; mute & secondary options peripheral
  (VidLii title overview; Spriters Resource Title Screen; Stardew modding TitleButtons).
- **Cozy farm/creature title patterns** — large readable wordmark, character as lower
  focal anchor, one clear Play CTA, quiet scenery that does not compete with UI
  (Cosmic Coop capsule notes; cozy main-menu UI reference packs; Spiritstead/community
  feedback: enlarge title & buttons, avoid empty mid-stack).
- **Typography** — Pixelify Sans (OFL, Google Fonts) as soft pixel display (friendlier
  than Press Start 2P for a warm cozy title); cream/gold fill + soft brown outline;
  Nunito for CTA/HUD Cyrillic.

## Правила, применённые в UI

1. **Большой доминирующий логотип сверху** — «Grow! Capy!» в верхней зоне портретной
   колонки (warm gold/cream Pixelify Sans + soft brown outline).
2. **Минимальный scannable CTA** — один ясный primary pill («Играть» / «Продолжить»);
   «Заново» только при наличии сейва, вторичный. Без лишнего chrome вокруг кнопок.
3. **Атмосферный forest BG** — `bg_forest` на весь экран; на desktop/web UI живёт в
   full-height **9:16** колонке по центру; боковые поля — forest blur + soft green wash
   (не тёмный letterbox и не phone bezel).
4. **Маскот внизу** — спрайт капибары в нижней зоне колонки; текст вверх, CTA mid,
   капибара вниз.
5. **Без phone chrome на меню** — никакого толстого phone frame / тёмного letterbox на
   title screen; игра по-прежнему в `PortraitPhoneFrame` (9:16) для playtest.
6. **Без tagline** — только wordmark «Grow! Capy!»; подзаголовок «цветы · стадо · уют»
   убран.
7. **Крупнее title** — default ~52px (clamp 44–64 по высоте колонки), soft outline/shadow.

## Иерархия экрана (сверху вниз)

| Зона | Содержание |
|------|------------|
| Top corner | Mute (discreet, внутри 9:16 колонки) |
| Top | Title «Grow! Capy!» |
| Mid | Primary CTA (+ optional «Заново») |
| Lower | Capybara sprite |
| Bottom edge | Quiet credit |

## Что сознательно избегаем

- Cramped center stack (иконка → title → button в середине).
- Material-generic AppBar / FAB look.
- Phone frame / тёмный letterbox / толстый bezel на title screen.
- Растягивание menu UI на весь landscape-window.
- Glow-soup на шрифте — только soft outline + лёгкий drop.
- Tagline под логотипом.

## Файлы

- `lib/features/menu/main_menu_screen.dart` — layout
- `lib/widgets/portrait_menu_stage.dart` — 9:16 column + forest gutters
- `lib/theme/cozy_theme.dart` — `menuTitleStyle`
- `lib/app.dart` — phone frame только вокруг `GameScreen`
