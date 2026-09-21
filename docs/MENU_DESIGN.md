# Main menu design — Grow! Capy!

Краткий дизайн-док для главного меню (title screen). Язык: RU.

## Рефы (consulted)

- **Stardew Valley title screen** — scenic full-bleed backdrop; compact vertical CTA
  close under the logo; logo as identity dominance; mute peripheral & discreet;
  character as lower focal hero (VidLii title overview; Spriters Resource Title Screen).
- **Cozy farm/creature title patterns** — large readable wordmark, character as lower
  half hero (not a tiny footer mascot), one clear Play CTA, quiet scenery that does
  not compete with UI; avoid empty mid-stack between title and button.
- **Typography** — Pixelify Sans (OFL, Google Fonts) for **title and primary CTA**
  (one cozy pixel family); Nunito only for dialogs / HUD / Cyrillic fallback — menu
  mute is icon-only (no text chip).

## Правила, применённые в UI

1. **Большой доминирующий логотип сверху** — «Grow! Capy!» в верхней зоне портретной
   колонки (warm gold/cream Pixelify Sans + soft brown outline).
2. **Плотный вертикальный ритм** — title сверху, CTA сразу под ним (небольшой gap,
   без пустого mid-spacer). Нижнюю половину занимает крупная капибара-герой.
3. **Компактный primary CTA** — «Играть» / «Продолжить» ясный, но не billboard:
   Pixelify (та же семья, что title), soft sage / cream–brown pill в духе game UI,
   не generic Material white-on-green. «Заново» только при сейве, вторичный.
4. **Капибара крупнее и выше** — hero нижней половины экрана (~0.38 высоты колонки),
   не крошечный маскот под гигантской кнопкой.
5. **Единая типографика меню** — Pixelify для title **и** primary CTA; Nunito —
   диалоги / HUD; mute без текста.
6. **Mute: только иконка** — top-right внутри 9:16 колонки; без cream chip и без
   подписи «звук» / «звук выкл» (Semantics label для a11y).
7. **Без footer** — credit «сделано с теплом · Nutarix» скрыт / убран с title screen.
8. **Мягкие scrim/gradient** — subtle darkening за title (читаемость) и за/под
   капибарой (ground anchor); не тяжёлый vignette.
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
| Top | Title «Grow! Capy!» (+ soft title scrim) |
| Tight under title | Primary CTA (+ optional «Заново») |
| Lower half | Large capybara hero (+ soft ground scrim) |

## Что сознательно избегаем

- Empty gap / Spacer между title и CTA (title → CTA → hero, не title → void → button).
- Tiny capy under a giant Material button.
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
