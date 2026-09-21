# Capy Clicker

Рабочее название: **capy-clicker**.

Казуальный портретный idle-кликер про капибар: цветы ускоряют прогресс стада,
на 100% появляется новая капибара, одинаковых можно слить в более крупную.
Камера отдаляется по мере роста стада. Есть грязевая лужа (временный ×2 к авто-прогрессу)
и редкая корзина ягод (большой burst). Offline-прогресс с soft-cap ~3 мин.

## Как запустить

Требуется [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable).

```bash
cd capy-clicker
flutter pub get
flutter run
```

Для конкретной платформы:

```bash
flutter run -d linux    # десктоп
flutter run -d chrome   # веб
flutter run -d <device> # телефон / эмулятор
```

Проверка статического анализа:

```bash
flutter analyze
```

## Что работает сейчас (Phase 1–3 / v0)

- Авто-прогресс стада (~1.5%/с) без тапов
- Тап по цветкам: +3–6% прогресса
- При 100%: спавн +1 капибары (до **12**), overflow переносится
- Несколько капибар на лугу с уровнями и разными позициями (Lv.5–6 теплее/крупнее + halo)
- Drag-merge одинакового уровня → Lv+1 + merge flash
- Камера: zoom-out в 5 шагов (1–2 / 3–5 / 6–8 / 9–11 / 12+)
- **Грязевая лужа**: перетащи капибару → анимация wallow + ×2 авто на 10 с
- **Корзина ягод**: редкий спавн, тап даёт +18–25%, потом респаун 22–38 с
- **Offline**: при запуске capped прогресс (до ~3 мин авто) + snackbar «Пока тебя не было…»
- **Утренний уют**: soft daily +25% раз в локальный день (sheet + чип), без energy-gate
- **Haptics**: light/medium на тап, merge, wallow (SFX/audioplayers отложены)
- **Декор луга**: кусты/камень unlock на стаде 3 / 6 / 9
- Первый запуск: tip overlay (merge + лужа)
- Пиксель-спрайты с прозрачным фоном (chroma-key)
- Juice: petal burst на цветке, soft cream progress bar, hills meadow
- Сохранение стада и прогресса через `shared_preferences`
- Портретная ориентация
- Store prep: [`store/README.md`](store/README.md) (icon brief + 3 screenshot captions RU/EN)

Баланс: [`docs/BALANCE_V0.md`](docs/BALANCE_V0.md).

## Портретный режим

Игра зафиксирована **только в портрете**:

- Android — `android:screenOrientation="portrait"` в `AndroidManifest.xml`
- iOS — только `UIInterfaceOrientationPortrait` в `Info.plist`
- Flutter — `SystemChrome.setPreferredOrientations` в `lib/main.dart`

## Структура

```
lib/
  main.dart
  app.dart
  features/game/
    game_screen.dart
    models/          # balance, capybara, game_state
    controllers/     # GameController (тик, spawn, merge, mud, berry, offline)
    persistence/     # shared_preferences JSON
    widgets/         # meadow, decor, flowers, capy, mud, berry, progress, tips
docs/
  BALANCE_V0.md
store/
  README.md          # icon + screenshot captions (placeholders)
assets/images/       # chroma-keyed PNG sprites
```

## Следующие шаги (вне этого пасса)

Полноценный SFX (audioplayers), IAP, Flame (по необходимости).

## Репозиторий

https://github.com/Nutarix/capy-clicker
