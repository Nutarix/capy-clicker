# Анимации v0 — луг Семьи

Дата: 2026-09-22 (Europe/Minsk). Связанные: [`ART.md`](ART.md),
[`WORLD_ZONES.md`](WORLD_ZONES.md), [`VOICE.md`](VOICE.md).

Терминология: всегда **Семья**, не «стадо».

## Принцип

Предпочитаем **transform / procedural** анимации на существующих спрайтах
(translate, rotate, scale, opacity, glow). Новых walk-cycle кадров нет —
капи «ходят» смещением позиции + лёгкий bounce + flip спрайта.

## Капибары (все уровни + роли)

Виджет: `MeadowDraggableCapybara` + хелперы `CapyWander`.

| Анимация | Описание |
|----------|----------|
| **Idle bob** | Мягкий вертикальный bob + лёгкий squashY, цикл ~1.5–2.5 с, фаза от `id` |
| **Wander walk** | Случайная точка через `WorldZones.randomInMeadow` / `clampToMeadow`; ease-перемещение; flip спрайта (`faceRight`); пауза 1.8–5 с |
| **Walk bounce** | Два мягких hop’а по пути |
| **Стоп** | Во время drag / wallow / merge-flash wander останавливается |
| **Persist** | По прибытии — `onDropPosition` → `GameController.updatePosition` (как drag-end) |
| **Роли** | Бейдж роли едет вместе с bob; спрайт флипается отдельно от текста Lv |

Спрайты: `capy_lv1` (Lv1–2), `capy_lv3` (Lv3+) + warmth tint. Overlay ролей
без отдельного walk-art.

## Объекты луга

| Объект | Анимация |
|--------|----------|
| **Цветы** (`FlowerDot`) | Idle sway/rotate (±~6°) с фазой по индексу + прежний tap punch/burst |
| **Грязь** (`MudPuddle`) | Idle glow + splash/bounce при wallow (сохранено/чуть ярче) |
| **Корзина ягод** | Bob + soft glow (сохранено, чуть сильнее glow) |
| **Уют-места** (пень/камень/тент) | Soft pulse когда готово; сильнее glow + scale когда boost; dim на CD |
| **Дом-декор** (`PlacedHomeDecorLayer`) | Фонарик / гирлянда / лампа — opacity+glow pulse; остальное — tiny sway/bob |
| **Кусты** (`MeadowDecorLayer`) | Tiny sway; камень статичен |
| **Twin sparkle** | `TwinSparkleHalo` — shimmer opacity/blur на отмеченной паре |
| **Progress bar** | Уже animated — без изменений |

Не анимируем: HUD chips, кнопки меню, статичные UI.

## Техзаметки

- Тикеры локальны в виджетах; `dispose` обязателен (покрыто тестами).
- Wander не шлёт state каждый кадр — только по прибытии.
- Камера / fit-zoom читает persisted позиции Семьи (после commit).
- Out of scope: Spine/Rive, 8-dir walk sheets, новые биомы.

## Тесты

- `test/capy_wander_test.dart` — clamp/lerp/фаза; dispose; wander → clamped persist.
