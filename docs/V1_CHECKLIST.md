# Capy Clicker — чеклист v1 (playable)

Версия: **1.0.0+1**. Цель: готовый к прохождению playable-билд к направлению стора (без IAP).

## Что работает в v1

- Авто-прогресс стада (~1.5%/с) без тапов
- Тап по цветкам: +3–6% к прогрессу
- При 100%: спавн +1 капибары (лимит **12**), overflow переносится
- Несколько капибар на лугу с уровнями и позициями (Lv.5–6 теплее/крупнее + halo)
- Drag-merge одинакового уровня → Lv+1 + flash
- Камера zoom-out в 5 шагах (1–2 / 3–5 / 6–8 / 9–11 / 12+)
- **Грязевая лужа**: перетащи капибару → wallow + ×2 авто на 10 с
- **Корзина ягод**: редкий спавн, тап +18–25%, респаун 22–38 с
- **Offline**: capped прогресс (~3 мин авто) + snackbar «Пока тебя не было…»
- **Утренний уют**: soft daily +25% раз в локальный день (sheet + чип)
- **Haptics**: light/medium на тап, merge, wallow (мобильные)
- **Audio**: cozy BGM + soft SFX via audioplayers; mute в HUD (persist)
- Декор луга: unlock на стаде 3 / 6 / 9
- Tip overlay на первом запуске (merge + лужа)
- Пиксель-спрайты с прозрачным фоном (chroma-key)
- Juice: petal burst, cream progress bar, hills meadow
- Сохранение через `shared_preferences`
- Портретная ориентация (Android / iOS / Flutter)
- Иконка приложения: `store/icon/app_icon.png` + launcher icons
- Store prep: `store/README.md` + портретные скриншоты в `store/screenshots/`

Баланс: [`BALANCE_V0.md`](BALANCE_V0.md).

## Как запустить

Требуется Flutter SDK (в этой среде: `/home/box/flutter/bin`).

```bash
cd capy-clicker
flutter pub get
flutter analyze   # должно быть чисто
flutter run       # авто-выбор устройства
```

### Web

```bash
flutter run -d chrome
# или релизный веб-билд:
flutter build web
```

### Android

```bash
flutter run -d <android-device>
# APK / App Bundle:
flutter build apk --release
flutter build appbundle --release
```

Нужны Android SDK / эмулятор или физическое устройство. Портрет зафиксирован в `AndroidManifest.xml`.

### iOS

```bash
flutter run -d <ios-device>
flutter build ios --release
```

Нужны macOS + Xcode. Портрет зафиксирован в `Info.plist`. На Linux-боксе iOS-сборку не запускать — только исходники готовы.

### Linux (десктоп, для проверки)

```bash
flutter run -d linux
```

## Известные пробелы v1

| Тема | Статус |
|------|--------|
| IAP / монетизация | **Нет** — soft launch без покупок |
| Реальный SFX / музыка | **Нет** — только haptics на мобильных; audioplayers отложены |
| Green-screen артефакты | Спрайты chroma-keyed; при артефактах — переснять/дочистить |
| Pro / cloud agents | **N/A** — не входят в scope v1 |
| Настоящие скриншоты с устройства | В `store/screenshots/` сейчас **placeholder** кадры на базе key art + captions; заменить захватом с телефона перед сабмитом |
| Локализация UI | RU-тексты в игре / daily; полный i18n не целевой для v1 |
| Аккаунты / облачный сейв | Только локальный `shared_preferences` |
| Аналитика / crash reporting | Не подключены |

## Скриншоты для стора

Папка: [`../store/screenshots/`](../store/screenshots/)

| Файл | Слот |
|------|------|
| `01-herd-progress.png` | Стадо + прогресс (1080×1920) |
| `02-merge-mud.png` | Merge + лужа |
| `03-daily-berries.png` | Daily / ягоды |

Подписи RU/EN — в [`../store/README.md`](../store/README.md).

## Дальше после v1

1. Заменить placeholder store shots реальными кадрами с телефона (demo mode / чистый status bar).
2. Подключить SFX (audioplayers) под tap / merge / wallow / berry / daily.
3. Утвердить и внедрить IAP (если продукт одобрит монетизацию).
4. Полировка спрайтов (без «зелёного» хрома), больше juice.
5. Store listing copy финализировать (subtitle, описание, возрастной рейтинг).
6. CI: `flutter analyze` + `flutter test` на PR; релизные билды Android AAB / iOS.
7. Опционально: Flame, cloud save, аналитика — только после playable soft launch.

## Быстрый smoke перед пушем

- [x] `version: 1.0.0+1` в `pubspec.yaml`
- [x] `flutter analyze` — без замечаний
- [ ] `flutter run -d chrome` или `-d linux` — луг, тап, merge видны
- [x] `store/screenshots/` ≥ 3 портретных PNG
- [x] этот чеклист в `docs/V1_CHECKLIST.md`
