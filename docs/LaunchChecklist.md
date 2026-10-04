# Hamster Ages — чекліст запуску (що робить Вал)

Код готовий; нижче лише те, що потребує акаунтів, грошей або рук.

## 1. App Store Connect — покупки (In-App Purchases)
| Product ID | Тип | Ціна | Що дає |
|---|---|---|---|
| `com.valkhim.hamsterages.removeads` | Non-consumable | $2.99 | без interstitial |
| `com.valkhim.hamsterages.starterpack` | Non-consumable | $1.99 | 3 000 🌻 + 2 скрині (оффер 72 год) |
| `com.valkhim.hamsterages.seeds.small` | Consumable | $0.99 | 1 200 🌻 |
| `com.valkhim.hamsterages.seeds.large` | Consumable | $4.99 | 8 000 🌻 |
| `com.valkhim.hamsterages.seeds.medium` | Consumable | $9.99 | 20 000 🌻 |
| `com.valkhim.hamsterages.seeds.huge` | Consumable | $19.99 | 45 000 🌻 |
| `com.valkhim.hamsterages.pass` | Consumable | $4.99 | Gold Pass на сезон |
| `com.valkhim.hamsterages.piggy` | Consumable | $2.99 | розбити скарбничку (до 6 000 🌻) |

Перша покупка насіння подвоюється в грі — у описі покупок про це не пиши (бонус керується кодом).

## 2. Game Center
- Лідерборди: `…highest_stage` (High→Low), `…survival_seconds` (High→Low), **`…daily_fastest`** — *recurring*, скидання щодня 00:00 UTC, сортування Low→High, формат «час у секундах».
- Досягнення: `first_win, reach_medieval, reach_future, kingslayer, stage_10, stage_25, legendary_general, all_generals, hard_win, card_set` (префікс `com.valkhim.hamsterages.`).

## 3. Capabilities у Xcode
- Game Center, iCloud → Key-value storage (вже в `HamsterAges.entitlements`). Якщо Xcode свариться — Signing & Capabilities → «+ Capability».

## 4. Реклама й аналітика
- AdMob: App ID + 2 ad units (Rewarded, Interstitial) → `HamsterAges-Info.plist` і `Services/AdMob.swift` (`AdConfig`). GDPR-повідомлення в Privacy & messaging.
- Аналітика: TelemetryDeck або Firebase → додати sink у `Analytics.sinks` (події вже пишуться: tutorial_step, battle_start/end, ad_shown, purchase, stance, share_tapped…).
- Remote config: `config/remote.json` у репо (raw GitHub) — частота реклами, тривалість оффера, ліміт безкоштовного насіння.

## 5. In-App Events (до 10 одночасно, кожна ≤ 31 день)
**Новий сезон Hamster Pass** (кожні 28 днів, з 2026-01-05)
- EN: *New Season: Hamster Pass* — "20 tiers of seeds, hero crates and a brand-new fur skin. Free track for everyone, Gold track for champions."
- UK: *Новий сезон Hamster Pass* — «20 рівнів насіння, скринь з героями і нове хутро. Безкоштовна доріжка для всіх, золота — для чемпіонів.»

**Weekend Seed Festival** (щосуботи–неділі)
- EN: *Seed Festival* — "All weekend: +50% seeds from every battle. Grab your hamsters and harvest!"
- UK: *Фестиваль насіння* — «Усі вихідні: +50% насіння з кожного бою. Клич хом'яків — і на жнива!»

**Rat King Rush** (разовий, під Hard-режим)
- EN: *Rat King Rush* — "Replay cleared chapters on Hard: tougher rats, every elite, double seeds."
- UK: *Навала Щурячого короля* — «Перепройди розділи на Важкому: сильніші щури, вся еліта, подвійне насіння.»

## 6. Сторінка в App Store
- Підзаголовок: перевір через Apple Ads → Search popularity варіанти «Stone Age to Future War» / «Evolve Your Army Through Time».
- Скріни: workflow «App Store screenshots» → гілка `appstore-shots` → `python3 Tools/aso/make_screenshots.py …` (див. шапку скрипта).
- Featuring nomination «App Launch» щонайменше за 3 тижні до релізу + публічне TestFlight-посилання. Історія: соло-розробник з України, весь арт і музика процедурні, 12 мов, офлайн.

## 7. Що купити / замовити
- Іконка + key art у ілюстратора (одне сердите/героїчне обличчя хом'яка в обладунках, 2–3 альтернативні іконки для PPO).
- Пакет SFX ударів/«пуфів»/вигуків — заміна процедурних звуків у `Services/Sound.swift` (рандомізація висоти вже є).

## 8. Перед релізом — плейтест
- 5–10 живих людей, перші 5 хвилин: де відвалюються, чи зрозумілі накази й еліта.
- Бот-харнес (`Tools/test.sh --balance`) показує: «кілька важких + турелі» перемагає частіше за змішану армію. Перевірити на людях, чи це реальна проблема.
