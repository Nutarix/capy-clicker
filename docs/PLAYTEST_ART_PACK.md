# Playtest — art pack multipliers (вшивка)

**Дата:** 2026-09-22 (Europe/Minsk)  
**Сев-ин:** `7c81af6` · `feat(art): wire approved multipliers pack into Семья UI`  
**Вердикт:** ✅ OK — реальных багов по ассетам нет; мелкий фикс overflow + тесты.

Терминология: **Семья**. Self-test до хендоффа Никите.

## Что проверено

1. **`flutter analyze`** — без замечаний.
2. **`flutter test`** — полный прогон зелёный (включая новый `test/art_pack_playtest_test.dart`).
3. **Пути ассетов** — все 18 PNG (`role_*` / `food_*` / `place_*` / `decor_*` / `research_uyut`) есть на диске, в `pubspec.yaml` и грузятся через `rootBundle`.
4. **Ключи моделей** — `assetPath` у ролей/еды/мест/декора/науки совпадают с файлами sew-in.
5. **Chroma** — углы всех 18 иконок прозрачные (cream снят).
6. **`MultiplierIcon`** — `Image.asset` для каждого пути; `errorBuilder` не срабатывает.
7. **`CozyPlaceMarker`** — пень / тёплый камень / тент без краша; CD-лейбл ок.
8. **Уют sheet** — вкладки Еда / Роли / Дом / Наука рендерят иконки пака.
9. **Save/load** — роли + decor (+ еда, research, tent) через `GamePersistence`; после load `assetPath` всё ещё резолвятся.

## Баги / фиксы

| Статус | Что |
|--------|-----|
| OK | Сломанных `AssetImage` / пропусков в pubspec / null-иконок не найдено. |
| Fix | Кнопка «Покормить семью» в `_FoodTab`: `Row` + длинный текст → риск overflow на узком экране. Обёрнут текст в `Flexible` + `ellipsis`. |
| Tests | Добавлен `test/art_pack_playtest_test.dart` (ассеты, маркеры, sheet, persistence). |

## Команды

```bash
/home/box/flutter/bin/flutter analyze
/home/box/flutter/bin/flutter test
/home/box/flutter/bin/flutter test test/art_pack_playtest_test.dart
```

## Вне скоупа

Новые фичи, APK, перерисовка арта.
