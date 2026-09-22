# Self-test — анимации v0 (2026-09-22, Europe/Minsk)

Исполнитель: агент. Термин: **Семья**.

## Чеклист

| # | Проверка | Результат |
|---|----------|-----------|
| 1 | Капи Lv1 / Lv3 bobят не в фазе | OK (phase от id) |
| 2 | Wander: двигаются, flip, пауза, стоп на drag | OK (код + widget test persist) |
| 3 | Wallow / merge flash останавливает wander | OK (`_wanderBlocked`) |
| 4 | Роль-бейдж едет с bob, текст не зеркалится | OK (faceRight только на sprite) |
| 5 | Цветы качаются с разной фазой | OK (`swayPhase`) |
| 6 | Грязь / ягоды glow+bob | OK (сохранено) |
| 7 | Пень/камень/тент pulse / active glow / CD dim | OK |
| 8 | Placed декор на лугу светится/качается | OK (`PlacedHomeDecorLayer`) |
| 9 | Twin sparkle shimmer | OK (`TwinSparkleHalo`) |
| 10 | `flutter analyze` clean + full tests green | OK (analyze clean, 110 tests) |
| 11 | Новых walk-frame PNG нет | OK (procedural only) |

## Известные лимиты

- Нет покадрового walk-cycle / 8 направлений — только transform.
- Wander цели не избегают грязи/цветов осознанно (только clamp в поляну).
- Дом-декор на лугу — фиксированные слоты (не drag-place).

## Команды

```bash
/home/box/flutter/bin/flutter analyze
/home/box/flutter/bin/flutter test
```
