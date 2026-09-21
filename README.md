# Grow! Capy!

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

## Что работает сейчас (v1 playable)

- Авто-прогресс стада (~2%/с) без тапов + видимый shimmer / «+X%/с»
- Тап по цветкам: +3–6% прогресса
- При 100%: спавн +1 капибары (до **12**), overflow переносится
- Несколько капибар на лугу с уровнями и разными позициями (Lv.5–6 теплее/крупнее + halo)
- Drag-merge одинакового уровня → Lv+1 + merge flash
- Камера / поляны: «Солнечные поляны» (sticky unlock) + fit zoom
- HUD: «стадо N/12» отдельно от «поляна: …»; floating «+N%» на тапы
- **Грязевая лужа**: перетащи капибару → анимация wallow + ×2 авто на 10 с
- **Корзина ягод**: редкий спавн, тап даёт +18–25%, потом респаун 22–38 с
- **Offline**: при запуске capped прогресс (до ~3 мин авто) + snackbar «Пока тебя не было…»
- **Утренний уют**: soft daily +25% раз в локальный день (sheet + чип), без energy-gate
- **Haptics**: light/medium на тап, merge, wallow
- **Главное меню**: full-bleed forest title screen (без phone frame); large top wordmark + tagline;
  capy в нижней трети; «Играть»/«Продолжить» pill + «Заново»; mute corner; из игры — «меню»
  (дизайн: [`docs/MENU_DESIGN.md`](docs/MENU_DESIGN.md))
- **Audio**: soft cozy BGM (loop ~0.30) + gentle SFX (flower/berry/merge/wallow/glade);
  mute в HUD/меню, preference в `shared_preferences`; web — BGM после первого жеста
- **Декор луга**: кусты/камень unlock на стаде 3 / 6 / 9
- Первый запуск: tip overlay (merge + лужа)
- Пиксель-спрайты с прозрачным фоном (chroma-key)
- Juice: petal burst на цветке, soft cream progress bar, hills meadow
- Сохранение стада и прогресса через `shared_preferences`
- Портретная ориентация
- Store prep: [`store/README.md`](store/README.md) + портретные placeholder-скрины в [`store/screenshots/`](store/screenshots/)
- Чеклист v1 (RU): [`docs/V1_CHECKLIST.md`](docs/V1_CHECKLIST.md)

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
  app.dart           # root state: menu ↔ game + shared GameAudio
  features/menu/
    main_menu_screen.dart
  features/game/
    game_screen.dart
    models/          # balance, capybara, game_state
    controllers/     # GameController (тик, spawn, merge, mud, berry, offline)
    persistence/     # shared_preferences JSON
    audio/           # GameAudio (audioplayers BGM+SFX, mute persist)
    widgets/         # meadow, decor, flowers, capy, mud, berry, progress, tips
docs/
  BALANCE_V0.md
  MENU_DESIGN.md     # title screen refs + layout rules
  V1_CHECKLIST.md    # что в v1, как запускать, пробелы, next
store/
  README.md          # icon + screenshot captions
  icon/app_icon.png
  screenshots/       # 01–03 portrait 1080×1920 (placeholders)
assets/images/       # chroma-keyed PNG sprites
assets/audio/        # original procedural WAV (tool/gen_audio.py)
```

## Audio

Пакет: [`audioplayers`](https://pub.dev/packages/audioplayers). Ассеты — **оригинальные** procedural WAV
(`python3 tool/gen_audio.py` → `assets/audio/`), не копирайтный материал.

| Слот | Файл | Громкость по умолчанию |
|---|---|---|
| BGM loop | `bgm_cozy.wav` | **0.30** |
| SFX | `sfx_flower/berry/merge/wallow/glade.wav` | **0.55** |

Mute-чип в HUD («звук» / «звук выкл») пишет `capy_clicker_audio_muted_v1` и глушит **и** BGM, **и** SFX.

### Web quirk

Браузеры блокируют autoplay: BGM стартует / resume только после **первого user gesture**
(тап цветка, ягоды, merge, wallow или mute). На mobile/desktop BGM пробует стартовать в `init`.

В тестах: `GameAudio.forceSilent = true` или `GameAudio.disabled()`.

## Следующие шаги (после v1)

См. [`docs/V1_CHECKLIST.md`](docs/V1_CHECKLIST.md): реальные store shots, IAP (если одобрят), полировка спрайтов.

## Репозиторий

https://github.com/Nutarix/capy-clicker
