# Анимации v0 — луг Семьи

Дата: 2026-09-22 (Europe/Minsk). Связанные: [`ART.md`](ART.md),
[`WORLD_ZONES.md`](WORLD_ZONES.md), [`VOICE.md`](VOICE.md).

Терминология: всегда **Семья**, не «стадо».

## Принцип

- **Walk-cycle кадры** (обязательно лапы двигаются): уникальный 4-кадровый
  горизонтальный sheet на каждый тип капи → `assets/images/walk/`.
- **Idle** — procedural transform на кадре 0 (уникальная амплитуда / период /
  sway на тип).
- Позиция wander — ease-lerp + лёгкий bounce + flip спрайта.

## Walk sheets (одобрено Никитой как shipped)

Источник: `store/art-pack-walk/` → chroma cream + slice
(`tool/slice_walk_pack.py` / `tool/chroma_cream.py`).

| Тип | Файлы | Walk FPS | Idle |
|-----|-------|----------|------|
| **base** (Lv1–2, без роли) | `base_0..3.png` | ~9 | средняя амплитуда bob |
| **lv3** (Lv3+, без роли) | `lv3_0..3.png` | ~6.5 | тяжелее / медленнее bob |
| **nanny** (Няня) | `nanny_0..3.png` | ~7 | мягкий sway + soft bob |
| **gatherer** (Собиратель) | `gatherer_0..3.png` | ~10.5 | tiny ready bob (корзина в sheet) |
| **guard** (Сторож) | `guard_0..3.png` | ~8 | upright pulse (scaleY), мало Y |

Выбор sheet: `CapyWalk.sheetFor(level, role)` — **роль побеждает** уровень.
Пока капи ходит, body = walk sheet роли (не только `role_*.png` overlay).
Мелкий бейдж роли остаётся HUD-подсказкой.

## Капибары — поведение

Виджет: `MeadowDraggableCapybara` + `CapyWander` + `CapyWalk`.

| Анимация | Описание |
|----------|----------|
| **Walk cycle** | Кадры 0→3→0 на FPS типа; лапы реально меняют позу |
| **Idle** | Кадр 0 + уникальный bob/sway/squash по типу; фаза от `id` |
| **Wander** | `WorldZones.randomInMeadow` / clamp; ease; `faceRight` flip |
| **Walk bounce** | Два мягких hop’а по пути (поверх frame-cycle) |
| **Стоп** | drag / wallow / merge-flash → wander + walk-cycle pause (кадр 0) |
| **Persist** | По прибытии — `onDropPosition` |
| **Смена роли** | Сразу sheet роли (idle кадр 0 / walk cycle на её FPS) |

## Объекты луга

| Объект | Анимация |
|--------|----------|
| **Цветы** (`FlowerDot`) | Idle sway/rotate (±~6°) с фазой по индексу + tap punch/burst |
| **Грязь** (`MudPuddle`) | Idle glow + splash/bounce при wallow |
| **Корзина ягод** | Bob + soft glow |
| **Уют-места** (пень/камень/тент) | Soft pulse / active glow / CD dim |
| **Дом-декор** (`PlacedHomeDecorLayer`) | Pulse / sway |
| **Кусты** (`MeadowDecorLayer`) | Tiny sway |
| **Twin sparkle** | `TwinSparkleHalo` |
| **Progress bar** | Уже animated |

Не анимируем: HUD chips, кнопки меню, статичные UI.

## Техзаметки

- Тикеры локальны; `dispose` обязателен.
- `_walkCycle` крутится только пока `_walking`; иначе кадр 0.
- Wander не шлёт state каждый кадр — только по прибытии.
- Out of scope: Spine/Rive, 8-dir sheets, новые роли.

## Тесты

- `test/capy_wander_test.dart` — clamp/lerp/фаза; dispose; persist.
- `test/capy_walk_test.dart` — asset keys; sheet by role/level; FPS; frames.
