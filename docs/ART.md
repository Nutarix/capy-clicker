# Art — правила и одобренные паки

Связанные: [`VOICE.md`](VOICE.md), [`MULTIPLIERS_V0.md`](MULTIPLIERS_V0.md),
[`V1_CHECKLIST.md`](V1_CHECKLIST.md).

## Правило одобрения

Если в UI появляется что-то новое (механика, ресурс, роль, место, декор, вкладка,
экран) — Game Lead рисует soft-pixel дизайн/иконку и показывает **Никите** на
утверждение. Нельзя оставлять emoji/серые плейсхолдеры «на потом».

Терминология: всегда **Семья**, никогда «стадо».

## Пайплайн спрайтов

Исходники часто приходят с cream-фоном. Перед `assets/images/`:

1. Chroma-key cream → прозрачный фон (flood от краёв): `tool/chroma_cream.py`
2. Crop по alpha bbox, longest side ≤ 512
3. Зарегистрировать путь в `pubspec.yaml`

Так же делались `capy_lv1` / flower / mud (olive green → transparent).

## Одобренные паки

### Multipliers v0 — ✅ одобрено Никитой («супер, продолжай»)

Источник: `store/art-pack-multipliers/` (18 PNG).

| Файл в assets | UI |
|---------------|----|
| `role_nanny.png` / `role_gatherer.png` / `role_guard.png` | Таб «Роли», long-press бейдж на капи |
| `food_travka.png` / `food_yagody.png` / `food_oreshki.png` | Таб «Еда» |
| `place_pen.png` / `place_warm_stone.png` / `place_tent.png` | Маркеры мест на лугу |
| `decor_*.png` (8) | Таб «Дом» |
| `research_uyut.png` | Таб «Наука» (header + nodes) |

Все иконки **вшиты** в клиент (`assets/images/`), emoji оставлены только как
fallback для float-текста / снекбаров.

### Zone backgrounds + button kit — ✅ одобрено Никитой (уникальные BG полян)

Источник: `store/art-pack-zones/` (portrait 1080×1920 + `ui-btn-kit-strip.png`).

| Файл в assets | Поляна / биом |
|---------------|---------------|
| `bg_warm_edge.png` | Тёплая опушка (`warm_edge`) |
| `bg_berry_glade.png` | Ягодная поляна (`berry_glade`) |
| `bg_sunny_clearing.png` | Солнечный прогал (`sunny_clearing`) |
| `bg_great_meadow.png` | Большой луг (`great_meadow`) |
| `bg_misty_woods.png` | Туманный бор / `mist_edge` |
| `bg_forest.png` | **только fallback** (ошибка загрузки / неизвестный id) |

Выбор ассета: `WorldZones.backgroundAssetForMeadow(meadowId)` → `MeadowBackground`
(crossfade ~400 ms).

Кнопки: программный `CozyPixelButton` / `CozyPixelIconButton` (sage bevel /
cream outline / muted) по референсу `ui-btn-kit-strip.png` — без обязательного
9-slice. Шрифты Pixelify/Nunito из `CozyTheme`.

### Walk-cycle pack — ✅ одобрено Никитой (approved-as-shipped)

Источник: `store/art-pack-walk/` (5 PNG, cream-bg, horizontal 4-frame).

Пайплайн: `tool/slice_walk_pack.py` (chroma cream flood + island cleanup →
crop → longest ≤ 256) → `assets/images/walk/{base,lv3,nanny,gatherer,guard}_{0..3}.png`.

| Sheet | Когда |
|-------|-------|
| `base_*` | Lv1–2 без роли |
| `lv3_*` | Lv3+ без роли |
| `nanny_*` / `gatherer_*` / `guard_*` | роль Няня / Собиратель / Сторож |

Ролевой walk sheet **и есть** внешний вид роли на лугу (не только бейдж
`role_*.png`). См. [`ANIMATIONS_V0.md`](ANIMATIONS_V0.md).

### Анимации v0 — meadow life + walk frames

Idle / wander / flower sway / decor glow — procedural transforms; **walk** —
покадровый cycle на уникальных sheet’ах выше.
