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
