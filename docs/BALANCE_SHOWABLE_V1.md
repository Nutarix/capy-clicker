# Balance Showable v1 — spreadsheet-in-docs

**Дата:** 2026-09-22 (Europe/Minsk)  
**Цель:** показуемая cozy-сессия 10–15′ без mid-session 🌿=0 despair и пустых Дом/Наука.  
**Терминология:** всегда **Семья** (не «стадо»).  
**Код:** `lib/features/game/models/balance.dart`, `multipliers/home_decor.dart`, `uyut_research.dart`.  
**Связанные:** [`BALANCE_V0.md`](BALANCE_V0.md), [`MULTIPLIERS_V0.md`](MULTIPLIERS_V0.md), [`PLAYTEST_SHOWABLE_V1.md`](PLAYTEST_SHOWABLE_V1.md).

---

## Target beats (минуты)

| Beat | Casual cozy | Goal-oriented show | Комментарий |
|------|-------------|--------------------|-------------|
| Первая **Ягодная поляна** | **2–5′** | ~1–3′ | zoom + toast + 10🌿 |
| Первый **permanent** (Фонарик / Больше цветов) | **сразу после Ягодной … ≤12′** | ≤3′ | glade grant + buffer |
| **Солнечный прогал** | опционально к 12–15′ | ~2–5′ | call > merge |
| **Большой луг** + **Капи Lv.4** | редко в casual 15′ | ~8–15′ | show run |
| **Туманный бор** + ✨ | тизер на карте | **~12–20′** | prestige soft |

Симы showable (seed 42 / 99): berry ~175 с; permanent @ berry; mist ~687 с goal-oriented.

---

## Income model (трава)

| Источник | Формула / число | Роль в сессии |
|----------|-----------------|---------------|
| Авто | `0.110` 🌿/с × multipliers (~9 с на 1🌿) | mid-session drip (P2.4) |
| Цветы | +1🌿 + % прогресса / тап | основной earn |
| Ягоды | +7…10🌿 + большой % | burst каждые ~22–38 с |
| Twin-merge | +5🌿 | skill window |
| Открытие поляны | +10🌿 | wow → funds Дом/Наука |
| Цель сессии | +6🌿 | soft celebration |
| Уют prestige | +3% к авто-прогрессу и авто-траве / ✨ | после mist |

Прогресс спавна (не трава): `autoProgressPerSecond = 0.015` + тапы + лужа/еда/места.

---

## Sink model (траты)

| Sink | Стоимость | Когда |
|------|-----------|-------|
| **Позвать капи** | **12🌿** | рост Семьи / поляны |
| **Ускорение** | **5🌿** ×1.5 / 6 с | короткий spike (слабее лужи) |
| Еда Травка / Ягоды / Орешки | 4 / **6** / 12 | temp слой Уюта |
| Декор (первый) | Фонарик **12**, Коврик **14** | permanent Дом |
| Research (первый) | Больше цветов **12**, Долгая лужа **18** | permanent Наука |
| Поздние узлы | 22–60🌿 (+✨) | за горизонтом одной casual-сессии |

### Рекомендуемый приоритет трат (casual show)

1. Копить на **Позвать капи** до Ягодной (цель HUD).  
2. Бесплатно: лужа / Пень / Камень.  
3. После Ягодной: **один** permanent (Фонарик *или* Больше цветов) — пока 🌿≥12.  
4. Лёгкая еда (Травка), если buffer ≥ call+4.  
5. Ускорение — если call не нужен и хочется spike.  
6. Не сливать всё в boost spam — иначе Дом/Наука снова пустые.

Call vs boost остаётся вилкой: 12 vs 5; soft-cap 12 (+роли/research) всё ещё режет call.

---

## Before → After (все тюны showable v1)

### `BalanceV0` (трава / loop)

| Константа | Before (v1.1 / UX V2) | After (showable v1) |
|-----------|----------------------|---------------------|
| `autoGrassPerSecond` | 0.07 | **0.110** |
| `flowerTapGrassMin…Max` | 1…1 | 1…1 (без изменения) |
| `berryGrassMin…Max` | 5…8 | **7…10** |
| `gladeUnlockGrass` | 6 | **10** |
| `goalCompleteGrass` | 4 | **6** |
| `twinMergeBonusGrass` | 5 | 5 |
| `callCapyGrassCost` | 12 | 12 (вилка сохранена) |
| `grassBoostCost` | 5 | 5 |
| `grassToYagodyCost` | 7 | **6** |
| `autoProgressPerSecond` | 0.015 | 0.015 |
| Twin CD / chance | 36 / 28 / 0.55 | без изменения |

### Декор (`HomeDecor.grassCost`)

| Предмет | Before | After |
|---------|--------|-------|
| Фонарик | 12 | 12 |
| Коврик | 16 | **14** |
| Вазон | 28 | **24** |
| Гирлянда | 32 | **28** |
| Подушка | 36 | **32** |
| Скворечник | 40 | **36** |
| Лампа | 45 | **42** |
| Кормушка | 50 | **48** |

### Research (`UyutResearch`)

| Узел | Before | After |
|------|--------|-------|
| more_flowers | 12 | 12 |
| longer_mud | 25 | **18** |
| more_berries | 30 | **22** |
| food_pouch | 35 | **28** |
| unlock_tent | 40 | **34** |
| cozy_lamp | 48 | **42** |
| role_slot_2 | 55 | **48** |
| soft_cap_plus | 70 | **60** |

---

## Что не трогали

Места CD, twin spam-tuning, soft-cap base 12, Уют +3%/✨, биомы/ракета/IAP, HUD redesign, новый арт.
