# Выпуск в Google Play

Как собрать подписанный `.aab` и выложить его на внутреннее тестирование. Ключ и пароли создаёт и хранит Никита; в репозиторий они не попадают.

## 0. Что нельзя менять

- `applicationId` — `com.nutarix.capy_clicker` (`android/app/build.gradle.kts`). После первой загрузки в Google Play его поменять нельзя: другой id — другое приложение.
- Ключ загрузки. Потеряли — сброс только через поддержку Google Play, с задержкой. Храните файл ключа и пароли в двух местах (например, менеджер паролей + флешка).

## 1. Ключ загрузки (один раз)

Нужен `keytool` из JDK 17+. На Windows он есть в Android Studio. PowerShell:

```powershell
mkdir $env:USERPROFILE\keys
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkeypair -v `
  -keystore $env:USERPROFILE\keys\capy-upload.jks -storetype PKCS12 `
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

macOS / Linux:

```bash
mkdir -p ~/keys
keytool -genkeypair -v -keystore ~/keys/capy-upload.jks -storetype PKCS12 \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

`keytool` спросит пароль и имя/организацию (можно «Nikita Kiselev», «Nutarix», страна `RU` или любая). В PKCS12 у ключа тот же пароль, что у хранилища.

Файл ключа держите **вне репозитория**. `*.jks` и `*.keystore` в git всё равно не попадут (`android/.gitignore`), но лучше не класть его в проект совсем.

## 2. `android/key.properties` (на каждой машине, где собираете релиз)

Создайте файл `android/key.properties`:

```properties
storeFile=C:/Users/<имя>/keys/capy-upload.jks
storePassword=<пароль>
keyAlias=upload
keyPassword=<тот же пароль>
```

- Путь — абсолютный, с прямыми слэшами `/` даже на Windows (обратный `\` в этом формате — спецсимвол).
- Файл в `android/.gitignore`. Проверка: `git status` его не показывает.

Без этого файла `flutter build appbundle --release` и `flutter build apk --release` сразу падают с текстом `Release signing key not found: android/key.properties is missing…`. Это нарочно: отладочным ключом релиз не подписывается. Отладочные сборки (`flutter run`, `flutter build apk --debug`) и тесты ключ не требуют.

## 3. Версия

В `pubspec.yaml`:

```yaml
version: 1.0.8+9
```

- До `+` — версия для людей (`versionName`).
- После `+` — номер сборки (`versionCode`). Google Play принимает файл, только если номер **больше**, чем у любой уже загруженной сборки. Поднимайте его перед каждой загрузкой, даже если версия для людей та же.

## 4. Сборка

```bash
flutter build appbundle --release
```

Файл: `build/app/outputs/bundle/release/app-release.aab`.

Проверить, что подписан вашим ключом (SHA-1 совпадает с `keytool -list -v -keystore …`):

```bash
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
```

Если сборка не начинается:

- `Plugin [id: 'com.android.application', version: …] was not found` — Gradle запущен на старой Java (нужна 17+). Укажите Java из Android Studio: `flutter config --jdk-dir "C:\Program Files\Android\Android Studio\jbr"` или переменная `JAVA_HOME`.
- `Building with plugins requires symlink support` (Windows без режима разработчика) — включите режим разработчика или выключите для этой команды настольные платформы (PowerShell):

  ```powershell
  $env:FLUTTER_LINUX='false'; $env:FLUTTER_WINDOWS='false'; flutter build appbundle --release
  ```

## 5. Google Play Console

Первый раз:

1. «Создать приложение»: название «Grow! Capy!», язык по умолчанию — русский, игра, бесплатно.
2. **Подписание приложений Google Play (Play App Signing)** — включить (для новых приложений включено по умолчанию; выбрать «ключ, созданный Google»). Ваш ключ — только ключ загрузки, итоговую подпись ставит Google. Если ключ загрузки потеряется, его можно сбросить через поддержку.
3. Раздел «Контент приложения»:
   - Политика конфиденциальности — ссылка из п. 6.
   - Безопасность данных: игра **не собирает и не передаёт** данные (нет сети, аккаунтов, рекламы, аналитики; шрифты внутри игры).
   - Реклама: нет. Целевая аудитория и возрастной рейтинг — по анкетам.

Каждый выпуск на внутреннее тестирование:

1. «Тестирование» → «Внутреннее тестирование» → «Создать выпуск».
2. Загрузить `app-release.aab`, написать, что нового.
3. Список тестировщиков (адреса Google-аккаунтов) — во вкладке «Тестировщики»; оттуда же ссылка-приглашение.
4. «Сохранить» → «Проверить выпуск» → «Начать развёртывание».

## 6. Политика конфиденциальности (GitHub Pages)

Страница — `site/privacy/index.html`; workflow `.github/workflows/pages.yml` публикует только папку `site/`.

Один раз:

1. Адрес для вопросов на странице — `nk.kiselev.work@gmail.com`. Сменили адрес — поправьте оба места в `site/privacy/index.html`.
2. GitHub → репозиторий → Settings → Pages → Build and deployment → Source: **GitHub Actions**.
3. Actions → Pages → Run workflow (или любой push в `main`, меняющий `site/`).

Ссылка для консоли Google Play:

**https://nutarix.github.io/capy-clicker/privacy/**

Изменили политику — поменяйте дату «Действует с» / «Effective» на странице.
