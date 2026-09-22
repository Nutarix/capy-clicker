# Playtest — зоны BG + cozy-кнопки

Дата: 2026-09-22 (Europe/Minsk). Терминология: всегда **Семья**.

## Что проверено

### A — Уникальные фоны полян
- Portrait PNG скопированы в `assets/images/` и зарегистрированы в `pubspec.yaml`.
- `WorldZones.backgroundAssetForMeadow` возвращает верный ключ для всех 4 Sunny
  Glades + `mist_edge` → `bg_misty_woods.png`.
- Неизвестный id → только `bg_forest.png` (fallback).
- `MeadowBackground` получает `meadowId` из `GameState.activeMeadowId` на
  игровом экране; меню/лоадер — `warm_edge` по умолчанию.
- Crossfade `AnimatedSwitcher` ~400 ms при смене id.
- Документация: `docs/ART.md`, `docs/WORLD_ZONES.md` (Visual).

### B — Soft-pixel кнопки
- Виджеты `CozyPixelButton` / `CozyPixelIconButton` (`lib/widgets/cozy_pixel_button.dart`):
  primary sage bevel, secondary cream outline, disabled muted; Pixelify/Nunito.
- Заменены Material CTA:
  - tips (`tip_overlay`) — Пропуск / Далее
  - morning cozy — Забрать уют / Позже
  - Уют hub — Покормить семью, Купить (еда/декор), Открыть (наука)
  - карта леса — close
  - spend panel pills
  - главное меню — Играть/Продолжить/Заново (+ диалог)
- Mute / pause — `CozyPixelIconButton` (круглая pixel-рамка).
- HUD layout **не** переделывался.

### C — Self-test
- `flutter analyze` — без issues (см. отчёт прогона).
- Полный `flutter test` — зелёный.
- Юнит/виджет-тесты: ключи BG по поляне/биому + smoke кнопок.

## Баги / правки по ходу
- Pause/mute стали icon-only (`CozyPixelIconButton`); `widget_test` ищет
  `Icons.pause_rounded` вместо текста «меню».

- Spend-pill accent-цвета убраны в пользу единого secondary cozy-стиля (без
  Material InkWell).
- При ошибке загрузки zone-PNG `MeadowBackground` пробует `bg_forest`, затем
  градиент-fallback — старый лес не ломает старт.

## Вне скоупа
- Новые механики, APK.
