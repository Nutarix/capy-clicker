# 005 — План: сборка для магазина

Спека: [`spec.md`](spec.md). Шаги: [`tasks.md`](tasks.md).

## Коротко

- Шрифты — файлы в `assets/google_fonts/`, `google_fonts` остаётся и берёт их оттуда; скачивание выключено в `main()` и в тестах.
- Релиз подписывается ключом из `android/key.properties`; без файла задачи `bundleRelease` / `assembleRelease` падают до сборки с понятным текстом. Отладка и тесты не меняются.
- Из ассетов уходят `app_icon.png` и `bg_forest.png`; запасной фон — `bg_warm_edge.png`.
- GitHub Actions: `ci.yml` (analyze + test) и `pages.yml` (публикует только `site/`).
- `LICENSE`, политика конфиденциальности, `store/RELEASE.md`.
- Новых зависимостей нет.

## Решения по требованиям

### Т1–Т3. Шрифты

Оставляем пакет `google_fonts`, а не объявляем шрифты в `pubspec.yaml`:

- Вид текста не меняется ни на пиксель. `google_fonts` подбирает к стилю ближайшее начертание и регистрирует его отдельной семьёй (`Nunito_800`); `copyWith(fontWeight: …)` поверх такого стиля даёт тот же файл с синтетическим утолщением. Свой `fonts:` в `pubspec` с весами вёл бы себя иначе (браузер весов движка выбирал бы настоящий файл) — текст стал бы другим.
- Спека 001 уже опирается на `GoogleFonts.config` в `test/flutter_test_config.dart` и в съёмке макетов. Без пакета слияние с 001 не соберётся.
- Пакет сам ищет в ассетах файл `Семья-Начертание.ttf` (`Nunito-ExtraBold.ttf`). Нужно только положить файлы и перечислить папку в `pubspec`.

Файлы — статические начертания с `fonts.gstatic.com`, ровно те, что пакет качал до сих пор: sha256 и длина совпадают с записанными в `google_fonts` 8.2.1. В репозитории `google/fonts` теперь лежат только переменные шрифты (`Nunito[wght].ttf`), а `google_fonts` грузит каждое начертание отдельным файлом и переменный шрифт не разложит по весам. Лицензии `OFL.txt` — из `github.com/google/fonts` (`ofl/nunito`, `ofl/pixelifysans`).

Нужные начертания — всё, что запрашивает `CozyTheme` (тест перечисляет семьи, которые реально выдаёт тема; `nunitoTextTheme` во Flutter 3.47 даёт только w400, Medium не нужен):

| Файл | Где |
|---|---|
| `Nunito-Regular.ttf` | весь `textTheme`, `contentTextStyle` диалога, запасной для Pixelify |
| `Nunito-SemiBold.ttf` | `hudChipMutedStyle` |
| `Nunito-Bold.ttf` | `TextButton`, `secondaryButtonStyle`, `hudChipStyle` |
| `Nunito-ExtraBold.ttf` | `AppBar`, `ElevatedButton`, диалог, `primaryButtonStyle` |
| `PixelifySans-Bold.ttf` | заголовок меню и главная кнопка |

Курсив не используется. ~550 КБ шрифтов.

`main()`: `GoogleFonts.config.allowRuntimeFetching = false` и `LicenseRegistry` с обоими `OFL.txt`.

Тесты: `test/flutter_test_config.dart` — байт в байт как в ветке 001 (флаг выключен), чтобы слияние прошло без конфликта. Свой тест `test/bundled_fonts_test.dart`: все стили темы грузятся из ассетов без сети, и текст меряется настоящим Nunito/Pixelify, а не тестовым шрифтом.

### Т4–Т6. Подпись

`android/app/build.gradle.kts`:

- `android/key.properties` есть → `signingConfigs.release` из `storeFile`, `storePassword`, `keyAlias`, `keyPassword`; пустое поле или нет файла ключа → `GradleException` с именем поля.
- Файла нет → `release` без подписи, а `gradle.taskGraph.whenReady` роняет сборку, если в графе есть `bundleRelease` / `assembleRelease`. Падение сразу, до компиляции, с текстом «нет android/key.properties, см. store/RELEASE.md». `assembleDebug`, `flutter test`, `flutter run` (debug) не затронуты.
- Шаблонные TODO убраны, у `applicationId` комментарий: менять нельзя после первой загрузки.

`store/RELEASE.md`: `keytool`, формат `key.properties`, Play App Signing, версия в `pubspec.yaml`, `flutter build appbundle --release`, внутреннее тестирование, включение GitHub Pages и ссылка на политику.

### Т7. Gradle

`-Xmx4G -XX:MaxMetaspaceSize=2G` (было 8G/4G). Хватает для сборки этого проекта; на машине с 8 ГБ не съедает всё.

### Т8, Т9. Размер

- `assets/images/app_icon.png` удалить (файл и строку в `pubspec`). Иконка — только `store/icon/app_icon.png`; поправить `store/README.md`.
- `WorldZones.fallbackBackgroundAsset = 'assets/images/bg_warm_edge.png'` — первая поляна, всегда в сборке. `bg_forest.png` удалить. Тест в `zones_buttons_test.dart` — сначала. Документы (`ART.md`, `WORLD_ZONES.md`, `PLAYTEST_ZONES_BUTTONS.md`, `MENU_DESIGN.md`) — заменить упоминание.

### Т10. CI

`.github/workflows/ci.yml`: `pull_request` и `push` в `main`; `ubuntu-latest`; `subosito/flutter-action@v2` с `flutter-version: 3.47.6`, `channel: stable`, `cache: true`; `flutter pub get`, `flutter analyze`, `flutter test`.

`test/playtest_mockup_shots_test.dart` нужен шрифт из `/tmp` и пути другой машины — в CI падает. Спека 001 переносит его в `tool/`. Здесь файл не трогаем (иначе конфликт с переносом), а CI передаёт `flutter test` список тестов без него: `find test -name '*_test.dart' ! -name playtest_mockup_shots_test.dart`. После слияния 001 фильтр просто ничего не отсекает.

### Т11. Порядок

`.gitignore`: `*.apk`, `*.aab`, `*.ipa`. Удалить `store/GrowCapy-1.0.1+2-arm64-v8a.apk.sha256`. `key.properties`, `*.jks`, `*.keystore` уже в `android/.gitignore`.

### Т13. Веб

`flutter_launcher_icons` с секцией `web` (`generate: true`, фон `#FFF8EC`, тема `#6B9B4A`): `favicon.png`, `web/icons/*` из `store/icon/app_icon.png`, цвета в `manifest.json`. Android/iOS иконки после прогона — если изменились, откатить (их не трогаем).

### Т14. Политика

`site/privacy/index.html` — одна статичная страница, RU и EN, без скриптов и внешних ресурсов; `site/index.html` ведёт на неё. Ссылка: `https://nutarix.github.io/capy-clicker/privacy/`. Контакт — `nk.kiselev.work@gmail.com`.

`.github/workflows/pages.yml`: `push` в `main` с `paths: site/**` и `workflow_dispatch`; `actions/configure-pages`, `actions/upload-pages-artifact` (`path: site`), `actions/deploy-pages`.

### Т15. Лицензия

`LICENSE` в корне: All rights reserved, Никита Киселев (Nutarix), 2026; строка о шрифтах (SIL OFL 1.1) и пакетах Dart/Flutter.

## Проверка

- `flutter analyze` — без замечаний; `flutter test` (без съёмки макетов) — дважды зелёный.
- `flutter build apk --debug` — собирается без ключа.
- `flutter build appbundle --release` без `key.properties` — падает с нашим текстом.
- С временным ключом вне репозитория — подписанный `.aab`; размер до/после.
