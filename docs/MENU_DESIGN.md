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

1. **Большой доминирующий логотип сверху** — «Grow! Capy!» в верхней трети экрана
   (warm gold/cream Pixelify Sans + soft brown outline). Identity занимает большую
   долю вертикального real estate, как wordmark Stardew.
2. **Минимальный scannable CTA** — один ясный primary pill («Играть» / «Продолжить»);
   «Заново» только при наличии сейва, вторичный. Без лишнего chrome вокруг кнопок.
3. **Атмосферный full-bleed BG** — `bg_forest` на весь экран; лёгкий cream wash;
   низкий UI-хром, чтобы не конкурировать с CTA.
4. **Маскот внизу** — спрайт капибары в нижней трети, крупнее (~168px); текст вверх,
   капибара вниз (не stacked mid).
5. **Без phone letterbox на меню** — меню full-bleed на desktop/web; игра по-прежнему
   в `PortraitPhoneFrame` (9:16) для playtest.
6. **Крупнее title** — default ~52px (clamp 44–64 по высоте), сильнее outline/shadow
   чем v0 mid-stack (было 34px в cream-плашке).

## Иерархия экрана (сверху вниз)

| Зона | Содержание |
|------|------------|
| Top corner | Mute (discreet) |
| Top third | Title + короткий tagline |
| Lower-mid | Primary CTA (+ optional «Заново») |
| Lower third | Capybara sprite |
| Bottom edge | Quiet credit |

## Что сознательно избегаем

- Cramped center stack (иконка → title → button в середине).
- Material-generic AppBar / FAB look.
- Phone frame / letterbox на title screen.
- Glow-soup на шрифте — только soft outline + лёгкий drop.

## Файлы

- `lib/features/menu/main_menu_screen.dart` — layout
- `lib/theme/cozy_theme.dart` — `menuTitleStyle` / `menuTaglineStyle`
- `lib/app.dart` — frame только вокруг `GameScreen`
