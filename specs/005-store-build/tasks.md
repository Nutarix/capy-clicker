# 005 — Шаги

План: [`plan.md`](plan.md). Где можно проверить тестом — сначала тест (падает), потом код (зелёный), коммит.

## Размер

- [x] **Ш1. Запасной фон (Т9).** Тест: запасной фон — `bg_warm_edge.png` и он есть в ассетах. Код: `WorldZones.fallbackBackgroundAsset`; `bg_forest.png` из ассетов и `pubspec`; документы.
- [x] **Ш2. Иконка вне ассетов (Т8).** Удалить `assets/images/app_icon.png` и строку в `pubspec`; `store/README.md`.

## Шрифты

- [x] **Ш3. Шрифты в ассетах (Т1–Т3).** Тест `bundled_fonts_test.dart`: стили `CozyTheme` грузятся из ассетов без сети и меряются настоящим шрифтом. Код: `assets/google_fonts/` (5 `.ttf` + 2 `OFL.txt`), папка в `pubspec`, `test/flutter_test_config.dart` как в 001, `main()`: запрет скачивания и `LicenseRegistry`.

## Android

- [x] **Ш4. Подпись ключом загрузки (Т4, Т6).** `build.gradle.kts`: `key.properties` → `signingConfigs.release`; без файла `bundleRelease`/`assembleRelease` падают с текстом; без TODO. Проверка: debug-сборка без ключа, release без ключа — ошибка, release с временным ключом — подписан.
- [x] **Ш5. Память Gradle (Т7).** `-Xmx4G`.
- [x] **Ш6. Инструкция (Т5).** `store/RELEASE.md`.

## Репозиторий

- [x] **Ш7. Сборки вне git (Т11).** `.gitignore`: `*.apk`, `*.aab`, `*.ipa`; удалить `.apk.sha256`.
- [x] **Ш8. CI (Т10).** `.github/workflows/ci.yml`.
- [ ] **Ш9. Веб (Т13).** Цвета `manifest.json`, `favicon.png`, `web/icons/*` из иконки игры.
- [x] **Ш10. Политика (Т14).** `site/index.html`, `.github/workflows/pages.yml`, ссылка в `RELEASE.md`.
- [x] **Ш11. Лицензия (Т15).** `LICENSE`.

## Сдача

- [ ] **Ш12.** `flutter analyze` чисто, `flutter test` дважды зелёный, сборки: debug, release без ключа, release с временным ключом; размер `.aab` до/после.
