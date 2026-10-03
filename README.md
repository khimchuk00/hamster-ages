# Hamster Ages

Lane-battler «Age of War»-типу з roguelite-картами та мета-прогресом. SwiftUI + SpriteKit, iOS 18+, без сторонніх залежностей та асетів.

Дизайн і ресерч — `GDD.md`.

## Запуск
1. Відкрий `HamsterAges.xcodeproj` (Xcode 16+).
2. Signing & Capabilities → обери свою Team (для запуску на iPhone).
3. Run на iPhone-симуляторі або пристрої (лише ландшафт).

## Структура
```
HamsterAges/
  App/        точка входу, RootView (навігація home ↔ battle)
  Core/       детермінована симуляція бою — без UIKit/SpriteKit
              GameConfig (епохи, юніти, турелі, баланс), Cards, BattleSimulation, BattleAI
  Battle/     BattleController (крок симуляції + HUD-знімок 10 Гц), BattleScene (рендер і ефекти),
              ArtFactory (весь арт процедурно через Core Graphics)
  Meta/       PlayerProgress, апгрейди, генерали (Generals.swift), щоденні нагороди (UserDefaults)
  Services/   AdService (заглушка під AdMob/MAX), Analytics, Sound, Store (StoreKit 2), Haptics
  UI/         HUD, туторіал, вибір карт, результат, головний, апгрейди, генерали, магазин, щоденка
Tools/SimHarness/  headless AI-vs-AI прогони для балансу
```

## CI
`.github/workflows/ios-build.yml` — на кожен push: тести логіки, збірка під iOS Simulator, запуск у симуляторі
з DEBUG-аргументами (`-demo`, `-screen battle|heroes|upgrades|quests|shop`, `-autoplay`) і скріншоти.
Логи та скріни публікуються в гілку `ci-artifacts`.

## Покупки (локально)
Edit Scheme → Run → Options → StoreKit Configuration → `HamsterAges.storekit`. Тоді магазин працює в симуляторі без App Store Connect.
Product ID: `com.valkhim.hamsterages.{removeads, starterpack, seeds.small, seeds.large}` — ті самі треба завести в App Store Connect.

## Тести логіки
`Tools/test.sh` — компілює ядро + мету без Xcode і проганяє 77 перевірок (детермінізм, економіка, еволюція, карти,
Last Stand/воскресіння, бос, овертайм, виживання, шанси скринь, ферма, квести, щоденка, скидання).
`Tools/test.sh --balance` — ще й матриця балансу. Останній прогін: ✅ 77/77 (Swift 6.0.3).

## Баланс headless
```
swiftc -O HamsterAges/Core/*.swift Tools/SimHarness/main.swift -o /tmp/hamster-sim && /tmp/hamster-sim
```
Друкує win-rate «гравця-бота» по етапах і рівнях мета-апгрейдів, середню тривалість бою та досягнуту епоху.
Крутити числа — у `Core/GameConfig.swift` (`StageDifficulty`, `makeEra`).

`Tools/balance_port.py` — ранній Python-порт (застарів, авторитетна — Swift-симуляція через `test.sh --balance`).
Поточна крива (бот-гравець): етапи 1–3 → 100%, етап 5 (перший бос) → ~55%, етап 8 без прокачки → ~10%,
з мета 3 → ~75%; етап 10 з мета 6 → ~80%; етап 20 з мета 10 → ~60%. Бої 3–6 хв: овертайм із 4:30 вимикає турелі
й розганяє урон, раптова смерть із 7:00 точить обидві бази.

## Що вже є з live-ops
- Туторіал першого бою (6 кроків, блокуючі підказки зі стрілкою на кнопку).
- Аналітика: `Services/Analytics.swift` — події під KPI з GDD; додай sink (TelemetryDeck/Firebase) у `Analytics.sinks`.
- Процедурний звук (`Services/Sound.swift`), вимикач на головному.
- StoreKit 2 (`Services/Store.swift`) + магазин, стартовий набір після 3-го бою.
- Політика interstitial: не раніше 3-го бою, раз на 2 бої, ніколи з No Ads.
- Генерали: колекція з 8 героїв, скрині, рівні за дублікати.
- Щоденні квести, idle-ферма насіння, бос Щурячий Король на кожному 5-му етапі.
- Режим «Виживання», Game Center (лідерборди + досягнення; capability у `HamsterAges.entitlements`),
  локальні нагадування, процедурна музика, екран налаштувань.

### App Store Connect — що завести
- IAP: 4 продукти (вище).
- Game Center: лідерборди `com.valkhim.hamsterages.highest_stage`, `…survival_seconds`;
  досягнення `first_win, reach_medieval, reach_future, kingslayer, stage_10, stage_25, legendary_general, all_generals`
  (префікс `com.valkhim.hamsterages.`).
- `AppLinks.privacyPolicy` у `UI/SettingsView.swift` — вставити URL політики конфіденційності.
- `PrivacyInfo.xcprivacy`, чернетка сторінки App Store — `AppStore.md`.

## Що далі (перед soft launch)
- Реальний рекламний SDK замість `StubAdService` (AdMob / AppLovin MAX) + ATT-промпт.
- Підключити аналітичний бекенд, privacy manifest.
- Музика, локалізація (String Catalog), App Store скріни й прев'ю-відео.
