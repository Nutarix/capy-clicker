# Playtest — карта леса (Phase 2)

**Дата:** 2026-09-22 (Europe/Minsk)  
**Вердикт:** ✅ OK — багов не найдено; тесты расширены.

## Что проверено

1. **Переключение полян** — `switchToMeadow` восстанавливает семью каждой поляны; трава общая и не сбрасывается.
2. **Unlock 5 / 8 / 11** — при семье на активной поляне: Ягодная → Солнечный прогал → Большой луг; стартер 2× Lv.1; активная поляна не меняется сама.
3. **Миграция Act 1** — старый JSON без `meadows` → семья в `warm_edge`, открытые пустые поляны получают starter при `init`.
4. **Персистенс** — save/load сохраняет multi-meadow семьи и `activeMeadowId`.
5. **Трава ≥ 0** — clamp в `_setState`; spend/switch не уводят в минус.
6. **Нет soft-lock** при одной поляне — `warm_edge` всегда доступна; закрытые отказывают; flower/progress работают.
7. **Скриптовый multi-meadow flow** — grow → berry → return → unlock sunny → hop — семьи изолированы, трава общая.

## Команды

```bash
flutter test
flutter analyze
# плюс forest_map_test.dart (11 кейсов)
```

`flutter test` + `flutter analyze` — чисто.

## Баги / фиксы

Реальных багов в рантайме не всплыло. Добавлены/расширены тесты в `test/forest_map_test.dart` (пороги 5/8/11, soft-lock, shared spend, scripted flow).

## Вне скоупа

Phase 3 (леса/биомы), ракета, IAP.
