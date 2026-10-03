# 002 — Шаги

План: [`plan.md`](plan.md). Каждый шаг кончается зелёным: `flutter analyze` без замечаний, `flutter test` (весь, с отпечатком). Перед коммитом — `git checkout -- linux`.

- [x] 1. Отпечаток поведения на старом коде (`test/support/fingerprint.dart`, `test/behavior_fingerprint_test.dart`, строки в симуляциях, `test/fixtures/fingerprint/`). Отдельный коммит.
- [x] 2. `plan.md`, `tasks.md`. Замер перестроек на старом коде.
- [x] 3. Ядро: `GameCore` и части в `lib/features/game/core/`, `GameController` — фасад. Перенос без изменения логики. Отпечаток тот же.
- [x] 4. Т3: быстрый путь шкалы (`normalized`), список семьи сохраняет тождество, если не менялся.
- [x] 5. Т4: `GameMessages`, поток `events`; уход `lastRoleToast`, `acknowledgeRoleToast`, `isAnyBoostActive`, `activeBoostRemainingSeconds`, `placeAt`, `isOverPlace`, сеттеров `lastTapGrass` / `lastDroppedFood`.
- [x] 6. Т5: запись сейва без `jsonDecode`.
- [x] 7. Т9: стили шрифтов один раз.
- [ ] 8. `GameSelector`. Т10/Т6: `GameScreen` → HUD, луг, сообщения, оверлеи; экран слушает части; сообщения — событиями.
- [ ] 9. Т11: таблица позиций бродящих капи у `MeadowLayer`.
- [ ] 10. Т7: «Уют» по вкладкам.
- [ ] 11. Т8: `RepaintBoundary` вокруг непрерывных анимаций.
- [ ] 12. Т13: тест перестроек; проверить, что падает с `setState` на каждое уведомление.
- [ ] 13. Сдача: analyze, тесты дважды, строки файлов, статус в `specs/README.md`.
