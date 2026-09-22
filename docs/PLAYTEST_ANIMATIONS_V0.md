# Self-test — анимации v0 + walk-cycle (2026-09-22, Europe/Minsk)

Исполнитель: агент. Термин: **Семья**.

## Чеклист

| # | Проверка | Результат |
|---|----------|-----------|
| 1 | Капи Lv1 / Lv3 bobят не в фазе | OK (phase от id) |
| 2 | Wander: двигаются, flip, пауза, стоп на drag | OK |
| 3 | Wallow / merge flash останавливает wander + walk cycle | OK (`_wanderBlocked` / `_cancelWalk`) |
| 4 | Роль-бейдж едет с bob, текст не зеркалится | OK (faceRight только на sprite) |
| 5 | Цветы качаются с разной фазой | OK |
| 6 | Грязь / ягоды glow+bob | OK |
| 7 | Пень/камень/тент pulse / active glow / CD dim | OK |
| 8 | Placed декор на лугу светится/качается | OK |
| 9 | Twin sparkle shimmer | OK |
| 10 | `flutter analyze` clean + full tests green | OK (analyze clean, 118 tests) |
| 11 | **Paws move** — 4-frame walk cycle на каждый тип | OK (`CapyWalk` + sheets) |
| 12 | Unique sheets: base / lv3 / nanny / gatherer / guard | OK (не один cycle + badge) |
| 13 | FPS: base~9, lv3~6.5, nanny~7, gatherer~10.5, guard~8 | OK |
| 14 | Idle уникален: nanny sway, gatherer ready bob, guard upright pulse | OK |
| 15 | Role → role walk sheet (не только overlay) | OK |
| 16 | Art pack walk approved-as-shipped | OK (`ART.md`) |

## Как отличаются типы

| Тип | Walk | Idle |
|-----|------|------|
| base | 9 fps, обычный шаг | amp ~5 |
| lv3 | 6.5 fps, тяжелее | amp ~6.2, период дольше |
| nanny | 7 fps, gentler | soft sway X + amp ~3 |
| gatherer | 10.5 fps, busier (корзина в art) | tiny ready bob amp ~2.4 |
| guard | 8 fps, firmer march | upright scaleY pulse, мало Y |

## Известные лимиты

- Нет 8 направлений — flip горизонтальный.
- Idle без отдельных idle-sheets — кадр 0 + procedural.
- Wander цели не избегают грязи/цветов осознанно.

## Команды

```bash
/home/box/flutter/bin/flutter analyze
/home/box/flutter/bin/flutter test
```
