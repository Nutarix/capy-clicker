# Playtest Showable v1 — вердикт

**Дата:** 2026-09-22 (Europe/Minsk)  
**Билд:** balance showable v1 (P2.4 grass + permanent sinks)  
**Для:** Никита  
**Терминология:** **Семья**.

## Метод

1. Прочитаны `BALANCE_V0`, `GAMELOOP_V1`, `MULTIPLIERS_V0`, `PRESTIGE_V0`, playtest V1/V2, UX audit.  
2. Тюны в `BalanceV0` + costs декор/research (см. `BALANCE_SHOWABLE_V1.md`).  
3. Симы: `progression_sim`, `player_session_playtest_sim`, новый `showable_session_sim_test`.  
4. `flutter analyze` + полный `flutter test` — зелёные.

## Цифры (после тюна)

```
showable cozy 14′ (seed 42):
  berry@175s permanent@175s midGrassAvg≈10.6 zeroFrac≈0.04
  calls=33 boosts=51 twinMerges=8 decor=3 research=3
  goals→sunny; soft-cap ok

progression_sim 12′ (seed 42):
  berry@124s calls+boosts fork; twin ok; grass end≈42

goal-oriented ~18′ (seed 99):
  berry@35s sunny@137s great+mist@687s uyut=1 visit ok
```

## Вердикт

**Готово к показу как 12-минутная cozy-сессия.**

- ✅ Цель → earn → вилка call/boost → twin skill → wow Ягодной → permanent Уют → тизер Леса.  
- ✅ Mid-session 🌿 больше не «вечный ноль» (avg mid ~10, zeroFrac ≪ 0.35).  
- ✅ Дом/Наука не пустая витрина: ≥1 permanent типично сразу после Ягодной.  
- ✅ Twin не спамит; места CD без изменений.  
- ✅ Mist/✨ достижимы goal-oriented ~11–18′; casual может остаться на Ягодной/Солнечном без game over.

Бирка: **«showable cozy session loop»**.
