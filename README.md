# Capy Clicker

Рабочее название: **capy-clicker**.

Казуальная кликер-игра про капибар: собирайте цветы на лугу, растите прогресс стада и в будущем объединяйте капибар, камеру и коллекцию. Сейчас это каркас Flutter-приложения с мок-экраном игры (портретная ориентация).

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

## Портретный режим

Игра зафиксирована **только в портрете**:

- Android — `android:screenOrientation="portrait"` в `AndroidManifest.xml`
- iOS — только `UIInterfaceOrientationPortrait` в `Info.plist`
- Flutter — `SystemChrome.setPreferredOrientations` в `lib/main.dart`

## Структура

```
lib/
  main.dart                          # точка входа, ориентация
  app.dart                           # MaterialApp
  features/game/
    game_screen.dart                 # мок игрового экрана
    widgets/
      meadow_background.dart
      progress_bar.dart
      capybara_placeholder.dart
      flower_dot.dart
```

## Следующие шаги

1. **Merge** — система слияния капибар / апгрейдов прогресса.
2. **Herd** — стадо, коллекция и слоты для нескольких капибар.
3. **Camera** — камера / видовой режим луга.

Вне скоупа текущего скелета: пиксель-арт, Flame, монетизация.

## Репозиторий

https://github.com/Nutarix/capy-clicker
