# Playtest v1.1 — Grow! Capy! (Game Lead QA)

Дата: 2026-09-22 (Europe/Minsk). Self-playtest loop v1 **до** handoff.

## Что тестировали

1. Документы `GAMELOOP_V1.md`, `BALANCE_V0.md` + код `BalanceV0` / `GameController` / goals / twin.
2. `flutter analyze` — clean; `flutter test` — все зелёные (включая новый `progression_sim_test.dart`).
3. Headless-симуляция ~12 мин cozy-play: тапы цветов, ягоды, лужа, вилка трат, merge, twin.
4. Ручной code review путей: отрицательная 🌿, soft-cap семьи, залипшая цель, twin spam, мёртвые кнопки трат, save/load grass/goals.

## Симуляция (seed 42, cozy cadence)

| Метрика | Результат |
|---|---|
| Первая поляна (Ягодная) | **~203 с (~3.4 мин)** — в цели 2–4 мин |
| Первая трата 🌿 | ~12 с (накопление → Ускорение/Позвать) |
| Вилка трат | и Call, и Boost используются (не «только спавн») |
| Twin merge bonus | срабатывает (≥1 за сессию); подсветка не permanent |
| Soft-cap 12 | соблюдается; Call отказан на полной семье |
| Цели | Berry complete → цель Sunny в прогрессе |
| Grass | ≥ 0 всегда |

## Баги найдены / исправлены

| Проблема | Фикс |
|---|---|
| Twin sparkle почти постоянный (`reroll` 18 с + всегда mark) | `twinRerollSeconds` 36; `twinMarkChance` 0.55; quiet gaps; post-merge cooldown 28 с (было 4 с) |
| Call-spam открывал Berry за ~1 мин | Доход 🌿 снижен; Call cost 8→12 |
| Первая поляна слишком рано (herd 3) | Банды полян сдвинуты: Berry с **5** капи |
| Нет гарантии clamp 🌿≥0 | `_setState` клампит grass к 0 |
| Не было регрессии save/load grass/goals / soft-cap spend | Добавлены unit-тесты |

## Баланс: before → after

| Параметр | Было | Стало |
|---|---|---|
| `autoProgressPerSecond` | 0.020 | **0.015** |
| `flowerTapGainMin…Max` | 0.03–0.06 | **0.025–0.045** |
| `flowerTapGrassMin…Max` | 1–2 | **1–1** |
| `autoGrassPerSecond` | 0.12 | **0.07** |
| `berryGrassMin…Max` | 8–12 | **5–8** |
| `callCapyGrassCost` | 8 | **12** |
| `twinRerollSeconds` | 18 | **36** |
| twin post-merge cooldown | 4 с | **28 с** |
| twin mark / linger | always / 0.55 | **0.55 / 0.35** |
| Поляны (herd) | 0–2 / 3–5 / 6–8 / 9–12 | **0–4 / 5–7 / 8–10 / 11–12** |

## Вне скоупа (как в мандате)

Phase 2 forest map UI, IAP, redesign меню.

## Вердикт

Loop v1.1 готов к handoff: analyze clean, tests green, баланс под cozy 10–15 мин, первая поляна ~3–4 мин active play.
