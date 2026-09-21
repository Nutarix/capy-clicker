# Main menu design — Grow! Capy!

Краткий дизайн-док для главного меню (title screen). Язык: RU.

## Рефы (consulted)

- **Stardew Valley title screen** — scenic full-bleed backdrop; logo as identity
  dominance; mute peripheral & discreet; character as mid-stack focal (not footer
  chrome); one clear Play CTA; quiet scenery that does not compete with UI.
- **Cozy farm/creature title patterns** — large readable wordmark, character between
  title and Play, clear CTA near mid/lower third, empty lower scenery band.
- **Typography** — Pixelify Sans (OFL, Google Fonts) for **title and primary CTA**
  (one cozy pixel family); Nunito only for dialogs / HUD / Cyrillic fallback — menu
  mute is icon-only (no text chip).

## Правила, применённые в UI

1. **Большой доминирующий логотип в верхней трети** — «Grow! Capy!» only (warm
   gold/cream Pixelify Sans + soft brown outline); без tagline.
2. **Вертикальные трети портретной колонки** — upper: title; middle: меньшая
   капибара над Play; lower: пустой forest / soft ground scrim.
3. **Play крупнее** — «Играть» / «Продолжить» внизу средней трети (~55–70% высоты),
   soft-sage Pixelify pill (не Material billboard). «Заново» только при сейве,
   вторичный, сразу под Play.
4. **Капибара меньше прежнего hero** — mid-band mascot (~0.22 высоты колонки),
   между title и Play (не нижний гигант и не крошечный footer).
5. **Единая типографика меню** — Pixelify для title **и** primary CTA; Nunito —
   диалоги / HUD; mute без текста.
6. **Mute: только иконка** — top-right внутри 9:16 колонки; без cream chip и без
   подписи «звук» / «звук выкл» (Semantics label для a11y).
7. **Без footer** — credit «сделано с теплом · Nutarix» скрыт / убран с title screen.
8. **Мягкие scrim/gradient** — subtle darkening за title (читаемость) и в нижней
   трети (ground anchor); не тяжёлый vignette.
9. **Атмосферный forest BG** — `bg_forest` на весь экран; на desktop/web UI живёт в
   full-height **9:16** колонке по центру; боковые поля — forest blur + soft green wash
   (не тёмный letterbox и не phone bezel).
10. **Без phone chrome на меню** — никакого толстого phone frame / тёмного letterbox на
    title screen; игра по-прежнему в `PortraitPhoneFrame` (9:16) для playtest.
11. **Без tagline** — только wordmark «Grow! Capy!»; подзаголовок «цветы · стадо · уют»
    убран.
12. **Крупный title** — default ~52px (clamp ~44–62 по высоте колонки), soft outline/shadow.

## Иерархия экрана (сверху вниз)

| Зона | Содержание |
|------|------------|
| Top corner | Mute icon-only (внутри 9:16 колонки) |
| Upper third | Title «Grow! Capy!» only (+ soft title scrim) |
| Middle third | Smaller capy → bigger Play at band end (~2/3) (+ optional «Заново») |
| Lower third | Empty forest / soft ground scrim |

Rough order: Title → (space) → Capy → Play (≈55–70% height) → empty lower.

## Что сознательно избегаем

- Title → CTA tight → giant lower-half hero (старый ритм).
- Tiny capy under a giant Material button **or** CTA immediately under title with
  empty mid void.
- Material-generic AppBar / FAB / Discord-green billboard CTA.
- Cream mute chip with «звук» label on the menu.
- Footer credit on the title screen.
- Phone frame / тёмный letterbox / толстый bezel на title screen.
- Растягивание menu UI на весь landscape-window.
- Glow-soup на шрифте — только soft outline + лёгкий drop.
- Tagline под логотипом.
- Heavy vignette (scrims stay subtle).

## Файлы

- `lib/features/menu/main_menu_screen.dart` — layout
- `lib/widgets/portrait_menu_stage.dart` — 9:16 column + forest gutters
- `lib/theme/cozy_theme.dart` — `menuTitleStyle`, `menuPrimaryCtaStyle`
- `lib/app.dart` — phone frame только вокруг `GameScreen`
