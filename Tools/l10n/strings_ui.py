# Translations for SwiftUI literal keys that Xcode extracts automatically (Text("…"), Button("…"), …).
# Columns: uk, de, es, fr, it, pt-BR, ja, ko, zh-Hans, zh-Hant, tr
S = {}
def T(key, *v):
    assert len(v) == 11, key
    S[key] = v

# Keys that are pure numbers/symbols — kept untranslated.
VERBATIM = []
VERBATIM += ["%@, %@", "%lld", "%@: %@", "%@ — %@", "🌻 %lld", "🎁", "🌻", "%lld/%lld", "→ %lld 🌻", "×2", "+%lld 🌻",
             "HAMSTER", "AGES", "Balance sim", "+5k seeds", "Stage+5", "Reset", "∞"]

# Screen titles
T("Generals", "Генерали", "Generäle", "Generales", "Généraux", "Generali", "Generais", "将軍", "장군", "将军", "將軍", "Generaller")
T("Daily Quests", "Щоденні завдання", "Tagesaufgaben", "Misiones diarias", "Quêtes du jour", "Missioni giornaliere", "Missões diárias", "デイリークエスト", "일일 퀘스트", "每日任务", "每日任務", "Günlük Görevler")
T("Daily Seeds", "Щоденне насіння", "Tägliche Samen", "Semillas diarias", "Graines du jour", "Semi giornalieri", "Sementes diárias", "デイリーシード", "일일 씨앗", "每日种子", "每日種子", "Günlük Tohumlar")
T("Settings", "Налаштування", "Einstellungen", "Ajustes", "Réglages", "Impostazioni", "Ajustes", "設定", "설정", "设置", "設定", "Ayarlar")
T("Shop", "Крамниця", "Shop", "Tienda", "Boutique", "Negozio", "Loja", "ショップ", "상점", "商店", "商店", "Mağaza")
T("Upgrades", "Покращення", "Verbesserungen", "Mejoras", "Améliorations", "Potenziamenti", "Melhorias", "強化", "강화", "升级", "升級", "Geliştirmeler")
T("Heroes", "Герої", "Helden", "Héroes", "Héros", "Eroi", "Heróis", "ヒーロー", "영웅", "英雄", "英雄", "Kahramanlar")
T("Paused", "Пауза", "Pause", "Pausa", "Pause", "Pausa", "Pausado", "一時停止", "일시정지", "已暂停", "已暫停", "Duraklatıldı")

# Battle HUD & overlays
T("FINAL AGE", "ОСТАННЯ ДОБА", "LETZTES ZEITALTER", "ÚLTIMA ERA", "ÈRE FINALE", "ERA FINALE", "ERA FINAL", "最終時代", "마지막 시대", "最终时代", "最終時代", "SON ÇAĞ")
T("EVOLVE", "ЕВОЛЮЦІЯ", "ENTWICKELN", "EVOLUCIONAR", "ÉVOLUER", "EVOLVI", "EVOLUIR", "進化", "진화", "进化", "進化", "EVRİMLEŞ")
T("XP → %@", "Досвід → %@", "EP → %@", "XP → %@", "XP → %@", "XP → %@", "XP → %@", "経験値 → %@", "경험치 → %@", "经验 → %@", "經驗 → %@", "XP → %@")
T("Sell turret (50%)", "Продати турель (50%)", "Turm verkaufen (50 %)", "Vender torreta (50%)", "Vendre la tourelle (50 %)", "Vendi torretta (50%)", "Vender torre (50%)", "タレットを売却（50%）", "포탑 판매 (50%)", "出售炮塔（50%）", "出售砲塔（50%）", "Tareti sat (%50)")
T("Cards power up your army for this battle — pick any!", "Карти посилюють твою армію на цей бій — обирай будь-яку!", "Karten stärken deine Armee für diesen Kampf – nimm eine!", "Las cartas potencian tu ejército en esta batalla: ¡elige una!", "Les cartes renforcent ton armée pour ce combat : choisis-en une !", "Le carte potenziano l'esercito per questa battaglia: scegline una!", "As cartas fortalecem seu exército nesta batalha — escolha uma!", "カードでこのバトルの軍を強化！好きなのを選ぼう", "카드는 이번 전투 동안 군대를 강화해요. 아무거나 고르세요!", "卡牌可在本场战斗中强化军队——任选一张！", "卡牌可在本場戰鬥中強化軍隊——任選一張！", "Kartlar bu savaşta ordunu güçlendirir — birini seç!")
T("Choose one upgrade for this battle", "Обери одне посилення на цей бій", "Wähle eine Verbesserung für diesen Kampf", "Elige una mejora para esta batalla", "Choisis une amélioration pour ce combat", "Scegli un potenziamento per questa battaglia", "Escolha uma melhoria para esta batalha", "このバトルの強化を1つ選ぼう", "이번 전투의 강화를 하나 고르세요", "为本场战斗选择一项强化", "為本場戰鬥選擇一項強化", "Bu savaş için bir güçlendirme seç")
T("Reroll (%lld)", "Перекинути (%lld)", "Neu würfeln (%lld)", "Cambiar (%lld)", "Relancer (%lld)", "Rilancia (%lld)", "Trocar (%lld)", "引き直し（%lld）", "다시 뽑기 (%lld)", "刷新（%lld）", "刷新（%lld）", "Yenile (%lld)")
T("Free Reroll", "Перекинути безкоштовно", "Gratis neu würfeln", "Cambio gratis", "Relance gratuite", "Rilancio gratis", "Troca grátis", "無料で引き直し", "무료 다시 뽑기", "免费刷新", "免費刷新", "Ücretsiz Yenile")
T("Owned ×%lld", "Є ×%lld", "Besitzt ×%lld", "Tienes ×%lld", "Possédé ×%lld", "Posseduta ×%lld", "Possui ×%lld", "所持 ×%lld", "보유 ×%lld", "已拥有 ×%lld", "已擁有 ×%lld", "Sahip ×%lld")
T("YOUR BASE IS FALLING!", "ТВОЯ БАЗА ПАДАЄ!", "DEINE BASIS FÄLLT!", "¡TU BASE ESTÁ CAYENDO!", "TA BASE VA TOMBER !", "LA TUA BASE STA CADENDO!", "SUA BASE ESTÁ CAINDO!", "拠点が陥落寸前！", "기지가 무너지고 있어요!", "你的基地要失守了！", "你的基地要失守了！", "ÜSSÜN DÜŞÜYOR!")
T("Watch a short video to restore 40% of your base and blast the rats at your gates.", "Переглянь коротке відео, щоб відновити 40% бази й рознести щурів біля воріт.", "Sieh dir ein kurzes Video an, um 40 % deiner Basis wiederherzustellen und die Ratten vor dem Tor wegzupusten.", "Mira un vídeo corto para restaurar el 40% de tu base y arrasar a las ratas de tus puertas.", "Regarde une courte vidéo pour restaurer 40 % de ta base et pulvériser les rats à tes portes.", "Guarda un breve video per ripristinare il 40% della base e spazzare via i ratti alle porte.", "Assista a um vídeo curto para restaurar 40% da base e explodir os ratos no seu portão.", "短い動画を見て拠点を40%回復し、門前のネズミを吹き飛ばそう。", "짧은 영상을 보고 기지를 40% 복구하고 성문 앞 쥐들을 날려버리세요.", "观看短视频，修复40%基地并轰飞门前的老鼠。", "觀看短影片，修復40%基地並轟飛門前的老鼠。", "Üssünün %40'ını onarmak ve kapındaki fareleri dağıtmak için kısa bir video izle.")
T("Give up", "Здатися", "Aufgeben", "Rendirse", "Abandonner", "Arrenditi", "Desistir", "あきらめる", "포기", "放弃", "放棄", "Pes et")
T("Loading…", "Завантаження…", "Lädt …", "Cargando…", "Chargement…", "Caricamento…", "Carregando…", "読み込み中…", "로딩 중…", "加载中…", "載入中…", "Yükleniyor…")
T("Revive", "Відродити", "Wiederbeleben", "Revivir", "Ranimer", "Rianima", "Reviver", "復活", "부활", "复活", "復活", "Dirilt")
T("Surrender", "Капітулювати", "Kapitulieren", "Rendirse", "Capituler", "Arrenditi", "Render-se", "降参", "항복", "投降", "投降", "Teslim ol")
T("Resume", "Продовжити", "Weiter", "Reanudar", "Reprendre", "Riprendi", "Continuar", "再開", "계속", "继续", "繼續", "Devam")
T("VICTORY!", "ПЕРЕМОГА!", "SIEG!", "¡VICTORIA!", "VICTOIRE !", "VITTORIA!", "VITÓRIA!", "勝利！", "승리!", "胜利！", "勝利！", "ZAFER!")
T("DEFEAT", "ПОРАЗКА", "NIEDERLAGE", "DERROTA", "DÉFAITE", "SCONFITTA", "DERROTA", "敗北", "패배", "失败", "失敗", "YENİLGİ")
T("Upgrade your hamsters and try again!", "Покращ хом'ячків і спробуй знову!", "Verbessere deine Hamster und versuch es erneut!", "¡Mejora tus hámsters e inténtalo de nuevo!", "Améliore tes hamsters et réessaie !", "Potenzia i tuoi criceti e riprova!", "Melhore seus hamsters e tente de novo!", "ハムスターを強化して再挑戦！", "햄스터를 강화하고 다시 도전하세요!", "强化你的仓鼠再来一次！", "強化你的倉鼠再來一次！", "Hamsterlerini geliştir ve tekrar dene!")
T("%lld kills", "%lld вбивств", "%lld Kills", "%lld bajas", "%lld éliminations", "%lld uccisioni", "%lld abates", "%lld撃破", "%lld 처치", "击杀%lld", "擊殺%lld", "%lld öldürme")
T("Next", "Далі", "Weiter", "Siguiente", "Suivant", "Avanti", "Próxima", "次へ", "다음", "下一关", "下一關", "Sonraki")
T("Continue", "Продовжити", "Weiter", "Continuar", "Continuer", "Continua", "Continuar", "続ける", "계속", "继续", "繼續", "Devam")
T("×2 Seeds", "×2 насіння", "×2 Samen", "×2 semillas", "×2 graines", "×2 semi", "×2 sementes", "種×2", "씨앗 ×2", "种子×2", "種子×2", "×2 Tohum")

# Generals
T("Hamster Crate", "Хом'яча скриня", "Hamsterkiste", "Cofre hámster", "Caisse de hamster", "Cassa del criceto", "Baú de hamster", "ハムスター箱", "햄스터 상자", "仓鼠宝箱", "倉鼠寶箱", "Hamster Sandığı")
T("Rare 70% · Epic 25% · Legendary 5%", "Рідкісний 70% · Епічний 25% · Легендарний 5%", "Selten 70 % · Episch 25 % · Legendär 5 %", "Raro 70% · Épico 25% · Legendario 5%", "Rare 70 % · Épique 25 % · Légendaire 5 %", "Raro 70% · Epico 25% · Leggendario 5%", "Raro 70% · Épico 25% · Lendário 5%", "レア70%・エピック25%・レジェンド5%", "레어 70% · 에픽 25% · 전설 5%", "稀有70% · 史诗25% · 传说5%", "稀有70% · 史詩25% · 傳說5%", "Nadir %70 · Epik %25 · Efsanevi %5")
T("Free", "Безплатно", "Gratis", "Gratis", "Gratuit", "Gratis", "Grátis", "無料", "무료", "免费", "免費", "Bedava")
T("Next: %@", "Далі: %@", "Nächste Stufe: %@", "Siguiente: %@", "Suivant : %@", "Prossimo: %@", "Próximo: %@", "次：%@", "다음: %@", "下一级：%@", "下一級：%@", "Sonraki: %@")
T("Find in a crate", "Знайди у скрині", "In einer Kiste finden", "Encuéntralo en un cofre", "À trouver dans une caisse", "Trovalo in una cassa", "Encontre num baú", "箱から入手", "상자에서 획득", "从宝箱中获得", "從寶箱中獲得", "Sandıktan çıkar")
T("Equipped", "Обрано", "Ausgerüstet", "Equipado", "Équipé", "Equipaggiato", "Equipado", "装備中", "장착됨", "已装备", "已裝備", "Kuşanıldı")
T("Equip", "Обрати", "Ausrüsten", "Equipar", "Équiper", "Equipaggia", "Equipar", "装備", "장착", "装备", "裝備", "Kuşan")
T("NEW GENERAL!", "НОВИЙ ГЕНЕРАЛ!", "NEUER GENERAL!", "¡NUEVO GENERAL!", "NOUVEAU GÉNÉRAL !", "NUOVO GENERALE!", "NOVO GENERAL!", "新しい将軍！", "새 장군!", "新将军！", "新將軍！", "YENİ GENERAL!")
T("LEVEL UP!", "НОВИЙ РІВЕНЬ!", "LEVEL UP!", "¡SUBE DE NIVEL!", "NIVEAU SUPÉRIEUR !", "LIVELLO SU!", "SUBIU DE NÍVEL!", "レベルアップ！", "레벨 업!", "升级了！", "升級了！", "SEVİYE ATLADI!")
T("MAXED!", "МАКСИМУМ!", "MAXIMAL!", "¡AL MÁXIMO!", "AU MAXIMUM !", "AL MASSIMO!", "NO MÁXIMO!", "最大レベル！", "최대 레벨!", "已满级！", "已滿級！", "MAKSİMUM!")
T("Already maxed — +%lld 🌻", "Уже максимум — +%lld 🌻", "Schon maximal – +%lld 🌻", "Ya al máximo: +%lld 🌻", "Déjà au max : +%lld 🌻", "Già al massimo: +%lld 🌻", "Já no máximo — +%lld 🌻", "最大レベル済み — +%lld 🌻", "이미 최대 — +%lld 🌻", "已满级——+%lld 🌻", "已滿級——+%lld 🌻", "Zaten maksimum — +%lld 🌻")
T("Level %lld · %@", "Рівень %1$lld · %2$@", "Stufe %1$lld · %2$@", "Nivel %1$lld · %2$@", "Niveau %1$lld · %2$@", "Livello %1$lld · %2$@", "Nível %1$lld · %2$@", "レベル%1$lld・%2$@", "레벨 %1$lld · %2$@", "%1$lld级 · %2$@", "%1$lld級 · %2$@", "Seviye %1$lld · %2$@")
T("Nice!", "Клас!", "Super!", "¡Genial!", "Génial !", "Grande!", "Boa!", "やった！", "좋아요!", "太棒了！", "太棒了！", "Harika!")
T("%@ · Lv %lld", "%1$@ · рів. %2$lld", "%1$@ · Lv %2$lld", "%1$@ · Nv %2$lld", "%1$@ · Niv %2$lld", "%1$@ · Liv %2$lld", "%1$@ · Nv %2$lld", "%1$@・Lv%2$lld", "%1$@ · Lv %2$lld", "%1$@ · %2$lld级", "%1$@ · %2$lld級", "%1$@ · Sv %2$lld")

# Home
T("Hamsters vs rats, from the Stone Age to the stars", "Хом'ячки проти щурів — від кам'яної доби до зірок", "Hamster gegen Ratten – von der Steinzeit bis zu den Sternen", "Hámsters contra ratas, de la Edad de Piedra a las estrellas", "Hamsters contre rats, de l'âge de pierre aux étoiles", "Criceti contro ratti, dall'età della pietra alle stelle", "Hamsters contra ratos, da Idade da Pedra às estrelas", "ハムスター対ネズミ、石器時代から星の彼方へ", "햄스터 대 쥐, 석기 시대부터 우주까지", "仓鼠大战老鼠，从石器时代打到星辰大海", "倉鼠大戰老鼠，從石器時代打到星辰大海", "Hamsterler fareler karşı: Taş Devri'nden yıldızlara")
T("STARTER PACK", "СТАРТОВИЙ НАБІР", "STARTERPAKET", "PACK DE INICIO", "PACK DE DÉMARRAGE", "PACCHETTO INIZIALE", "PACOTE INICIAL", "スターターパック", "스타터 팩", "新手礼包", "新手禮包", "BAŞLANGIÇ PAKETİ")
T("BOSS", "БОС", "BOSS", "JEFE", "BOSS", "BOSS", "CHEFE", "ボス", "보스", "首领", "首領", "BOSS")
T("Rat army strength %lld%%", "Сила щурячої армії %lld%%", "Stärke der Rattenarmee %lld %%", "Fuerza del ejército rata %lld%%", "Force de l'armée des rats %lld %%", "Forza dell'esercito dei ratti %lld%%", "Força do exército de ratos %lld%%", "ネズミ軍の強さ %lld%%", "쥐 군대 전력 %lld%%", "鼠军强度%lld%%", "鼠軍強度%lld%%", "Fare ordusu gücü %%%lld")
T("BATTLE", "У БІЙ", "KAMPF", "BATALLA", "COMBAT", "BATTAGLIA", "BATALHA", "バトル", "전투", "开战", "開戰", "SAVAŞ")
T("Spend seeds here!", "Витрачай насіння тут!", "Samen hier ausgeben!", "¡Gasta semillas aquí!", "Dépense tes graines ici !", "Spendi i semi qui!", "Gaste sementes aqui!", "ここで種を使おう！", "여기서 씨앗을 쓰세요!", "在这里花种子！", "在這裡花種子！", "Tohumları burada harca!")
T("Free hero crate!", "Безплатна скриня героїв!", "Gratis-Heldenkiste!", "¡Cofre de héroe gratis!", "Caisse de héros gratuite !", "Cassa eroe gratis!", "Baú de herói grátis!", "ヒーロー箱が無料！", "무료 영웅 상자!", "免费英雄宝箱！", "免費英雄寶箱！", "Bedava kahraman sandığı!")
T("Daily Challenge unlocks after Stage %lld", "Щоденний виклик відкриється після етапу %lld", "Tägliche Herausforderung ab Stufe %lld", "El desafío diario se desbloquea tras la fase %lld", "Défi quotidien débloqué après le niveau %lld", "La sfida giornaliera si sblocca dopo il livello %lld", "O desafio diário libera após a fase %lld", "デイリーチャレンジはステージ%lldクリア後に解放", "일일 도전은 %lld단계 이후 열려요", "通过第%lld关后解锁每日挑战", "通過第%lld關後解鎖每日挑戰", "Günlük Meydan Okuma %lld. bölümden sonra açılır")
T("SURVIVAL", "ВИЖИВАННЯ", "ÜBERLEBEN", "SUPERVIVENCIA", "SURVIE", "SOPRAVVIVENZA", "SOBREVIVÊNCIA", "サバイバル", "서바이벌", "生存", "生存", "HAYATTA KAL")
T("DAILY", "ЩОДЕННИЙ", "TÄGLICH", "DIARIO", "QUOTIDIEN", "GIORNALIERA", "DIÁRIO", "デイリー", "일일", "每日", "每日", "GÜNLÜK")
T("Lv %lld/%lld", "Рів. %lld/%lld", "Lv %lld/%lld", "Nv %lld/%lld", "Niv %lld/%lld", "Liv %lld/%lld", "Nv %lld/%lld", "Lv %lld/%lld", "Lv %lld/%lld", "%lld/%lld级", "%lld/%lld級", "Sv %lld/%lld")
T("MAX", "МАКС", "MAX", "MÁX", "MAX", "MAX", "MÁX", "MAX", "MAX", "满级", "滿級", "MAKS")
T("Come back every day — the streak resets if you miss one.", "Заходь щодня — серія обнулиться, якщо пропустиш день.", "Komm jeden Tag zurück – verpasst du einen, beginnt die Serie neu.", "Vuelve cada día: la racha se reinicia si faltas uno.", "Reviens chaque jour : la série repart à zéro si tu en manques un.", "Torna ogni giorno: la serie si azzera se ne salti uno.", "Volte todo dia — a sequência zera se você faltar um.", "毎日来よう。1日休むと連続記録がリセット。", "매일 오세요. 하루라도 빠지면 연속 기록이 초기화돼요.", "每天回来——断签一天连签就会重置。", "每天回來——斷簽一天連簽就會重置。", "Her gün gel — bir gün kaçırırsan seri sıfırlanır.")
T("Come back tomorrow!", "Повертайся завтра!", "Komm morgen wieder!", "¡Vuelve mañana!", "Reviens demain !", "Torna domani!", "Volte amanhã!", "また明日！", "내일 다시 오세요!", "明天再来！", "明天再來！", "Yarın tekrar gel!")
T("Awesome!", "Супер!", "Klasse!", "¡Genial!", "Super !", "Fantastico!", "Show!", "最高！", "멋져요!", "太棒了！", "太棒了！", "Süper!")
T("Claim", "Забрати", "Abholen", "Reclamar", "Récupérer", "Riscatta", "Resgatar", "受け取る", "받기", "领取", "領取", "Al")
T("Close", "Закрити", "Schließen", "Cerrar", "Fermer", "Chiudi", "Fechar", "閉じる", "닫기", "关闭", "關閉", "Kapat")
T("Day %lld", "День %lld", "Tag %lld", "Día %lld", "Jour %lld", "Giorno %lld", "Dia %lld", "%lld日目", "%lld일차", "第%lld天", "第%lld天", "%lld. Gün")
T("→ 🎁 Crate", "→ 🎁 Скриня", "→ 🎁 Kiste", "→ 🎁 Cofre", "→ 🎁 Caisse", "→ 🎁 Cassa", "→ 🎁 Baú", "→ 🎁 箱", "→ 🎁 상자", "→ 🎁 宝箱", "→ 🎁 寶箱", "→ 🎁 Sandık")
T("CLAIM", "ЗАБРАТИ", "ABHOLEN", "RECLAMAR", "RÉCUPÉRER", "RISCATTA", "RESGATAR", "受け取る", "받기", "领取", "領取", "AL")

# Quests & farm
T("Open", "Відкрити", "Öffnen", "Abrir", "Ouvrir", "Apri", "Abrir", "開ける", "열기", "打开", "打開", "Aç")
T("Complete all 3 → free Hamster Crate", "Виконай усі 3 → безплатна Хом'яча скриня", "Alle 3 erledigen → gratis Hamsterkiste", "Completa las 3 → cofre hámster gratis", "Termine les 3 → caisse de hamster gratuite", "Completa tutte e 3 → cassa del criceto gratis", "Complete as 3 → baú de hamster grátis", "3つ全部クリア → ハムスター箱が無料", "3개 모두 완료 → 무료 햄스터 상자", "完成全部3个 → 免费仓鼠宝箱", "完成全部3個 → 免費倉鼠寶箱", "3'ünü de tamamla → bedava Hamster Sandığı")
T("New quests every day at midnight", "Нові завдання щодня опівночі", "Jeden Tag um Mitternacht neue Aufgaben", "Nuevas misiones cada día a medianoche", "Nouvelles quêtes chaque jour à minuit", "Nuove missioni ogni giorno a mezzanotte", "Novas missões todo dia à meia-noite", "毎日0時に新しいクエスト", "매일 자정에 새 퀘스트", "每天午夜刷新任务", "每天午夜刷新任務", "Her gece yarısı yeni görevler")
T("Collect", "Зібрати", "Ernten", "Recoger", "Récolter", "Raccogli", "Coletar", "回収", "수확", "收取", "收取", "Topla")
T("SEED FARM", "НАСІННЄВА ФЕРМА", "SAATFARM", "GRANJA DE SEMILLAS", "FERME À GRAINES", "FATTORIA DI SEMI", "FAZENDA DE SEMENTES", "シードファーム", "씨앗 농장", "种子农场", "種子農場", "TOHUM ÇİFTLİĞİ")

# Settings
T("Reset all progress?", "Скинути весь прогрес?", "Gesamten Fortschritt zurücksetzen?", "¿Reiniciar todo el progreso?", "Réinitialiser toute la progression ?", "Azzerare tutti i progressi?", "Reiniciar todo o progresso?", "全ての進行状況をリセットしますか？", "모든 진행 상황을 초기화할까요?", "重置全部进度？", "重設全部進度？", "Tüm ilerleme sıfırlansın mı?")
T("Sound effects", "Звукові ефекти", "Soundeffekte", "Efectos de sonido", "Effets sonores", "Effetti sonori", "Efeitos sonoros", "効果音", "효과음", "音效", "音效", "Ses efektleri")
T("Music", "Музика", "Musik", "Música", "Musique", "Musica", "Música", "音楽", "음악", "音乐", "音樂", "Müzik")
T("Vibration", "Вібрація", "Vibration", "Vibración", "Vibrations", "Vibrazione", "Vibração", "振動", "진동", "振动", "震動", "Titreşim")
T("Reminders", "Нагадування", "Erinnerungen", "Recordatorios", "Rappels", "Promemoria", "Lembretes", "リマインダー", "알림", "提醒", "提醒", "Hatırlatıcılar")
T("Restoring…", "Відновлення…", "Wird wiederhergestellt …", "Restaurando…", "Restauration…", "Ripristino…", "Restaurando…", "復元中…", "복원 중…", "正在恢复…", "正在恢復…", "Geri yükleniyor…")
T("Restore Purchases", "Відновити покупки", "Käufe wiederherstellen", "Restaurar compras", "Restaurer les achats", "Ripristina acquisti", "Restaurar compras", "購入を復元", "구매 복원", "恢复购买", "恢復購買", "Satın alımları geri yükle")
T("Privacy Choices", "Налаштування приватності", "Datenschutzoptionen", "Opciones de privacidad", "Choix de confidentialité", "Scelte sulla privacy", "Opções de privacidade", "プライバシーの選択", "개인정보 선택", "隐私选项", "隱私選項", "Gizlilik Seçimleri")
T("Privacy Policy", "Політика конфіденційності", "Datenschutzerklärung", "Política de privacidad", "Politique de confidentialité", "Informativa sulla privacy", "Política de privacidade", "プライバシーポリシー", "개인정보 처리방침", "隐私政策", "隱私權政策", "Gizlilik Politikası")
T("Support", "Підтримка", "Support", "Soporte", "Assistance", "Assistenza", "Suporte", "サポート", "지원", "支持", "支援", "Destek")
T("Reset Progress", "Скинути прогрес", "Fortschritt zurücksetzen", "Reiniciar progreso", "Réinitialiser la progression", "Azzera progressi", "Reiniciar progresso", "進行状況をリセット", "진행 초기화", "重置进度", "重設進度", "İlerlemeyi sıfırla")
T("Reset everything", "Скинути все", "Alles zurücksetzen", "Reiniciar todo", "Tout réinitialiser", "Azzera tutto", "Reiniciar tudo", "全てリセット", "모두 초기화", "全部重置", "全部重設", "Her şeyi sıfırla")
T("Stages, seeds, upgrades and generals will be lost. Purchases can be restored.", "Етапи, насіння, покращення й генерали буде втрачено. Покупки можна відновити.", "Stufen, Samen, Verbesserungen und Generäle gehen verloren. Käufe können wiederhergestellt werden.", "Se perderán las fases, semillas, mejoras y generales. Las compras se pueden restaurar.", "Niveaux, graines, améliorations et généraux seront perdus. Les achats peuvent être restaurés.", "Livelli, semi, potenziamenti e generali andranno persi. Gli acquisti si possono ripristinare.", "Fases, sementes, melhorias e generais serão perdidos. As compras podem ser restauradas.", "ステージ、種、強化、将軍は失われます。購入は復元できます。", "단계, 씨앗, 강화, 장군이 사라져요. 구매는 복원할 수 있어요.", "关卡、种子、升级和将军都将丢失。购买项目可以恢复。", "關卡、種子、升級和將軍都將遺失。購買項目可以恢復。", "Bölümler, tohumlar, geliştirmeler ve generaller silinecek. Satın alımlar geri yüklenebilir.")

# Shop
T("Starter Pack", "Стартовий набір", "Starterpaket", "Pack de inicio", "Pack de démarrage", "Pacchetto iniziale", "Pacote inicial", "スターターパック", "스타터 팩", "新手礼包", "新手禮包", "Başlangıç Paketi")
T("BEST VALUE", "НАЙВИГІДНІШЕ", "BESTER WERT", "MEJOR VALOR", "MEILLEURE OFFRE", "MIGLIOR AFFARE", "MELHOR VALOR", "一番お得", "최고 가성비", "最超值", "最超值", "EN İYİ FİYAT")
T("Seed Bag", "Мішок насіння", "Samenbeutel", "Bolsa de semillas", "Sac de graines", "Sacchetto di semi", "Saco de sementes", "種の袋", "씨앗 주머니", "种子袋", "種子袋", "Tohum Kesesi")
T("1,200 🌻", "1 200 🌻", "1.200 🌻", "1200 🌻", "1 200 🌻", "1200 🌻", "1.200 🌻", "1,200 🌻", "1,200 🌻", "1200 🌻", "1200 🌻", "1.200 🌻")
T("Seed Barrel", "Бочка насіння", "Samenfass", "Barril de semillas", "Tonneau de graines", "Barile di semi", "Barril de sementes", "種の樽", "씨앗 통", "种子桶", "種子桶", "Tohum Fıçısı")
T("8,000 🌻", "8 000 🌻", "8.000 🌻", "8000 🌻", "8 000 🌻", "8000 🌻", "8.000 🌻", "8,000 🌻", "8,000 🌻", "8000 🌻", "8000 🌻", "8.000 🌻")
T("+33%", "+33%", "+33 %", "+33%", "+33 %", "+33%", "+33%", "+33%", "+33%", "+33%", "+33%", "+%33")
T("No Ads", "Без реклами", "Keine Werbung", "Sin anuncios", "Sans pub", "Niente pubblicità", "Sem anúncios", "広告なし", "광고 제거", "去广告", "去廣告", "Reklamsız")
T("Removes interstitials forever", "Назавжди прибирає міжекранну рекламу", "Entfernt Vollbildwerbung für immer", "Elimina los anuncios intersticiales para siempre", "Supprime les pubs plein écran pour toujours", "Rimuove per sempre le pubblicità a schermo intero", "Remove anúncios intersticiais para sempre", "インタースティシャル広告を永久に削除", "전면 광고를 영구 제거", "永久移除插屏广告", "永久移除插頁廣告", "Ara reklamları sonsuza dek kaldırır")

def UK(key, one, few, many):
    v = list(S[key]); v[0] = {"one": one, "few": few, "many": many, "other": many}; S[key] = tuple(v)

UK("%lld kills", "%lld вбивство", "%lld вбивства", "%lld вбивств")

VERBATIM += ["· %@"]
# Hamster Pass
T("Hamster Pass", "Хом'ячий пропуск", "Hamster-Pass", "Pase Hámster", "Passe Hamster", "Pass Criceto", "Passe Hamster", "ハムスターパス", "햄스터 패스", "仓鼠通行证", "倉鼠通行證", "Hamster Pası")
T("HAMSTER PASS", "ХОМ'ЯЧИЙ ПРОПУСК", "HAMSTER-PASS", "PASE HÁMSTER", "PASSE HAMSTER", "PASS CRICETO", "PASSE HAMSTER", "ハムスターパス", "햄스터 패스", "仓鼠通行证", "倉鼠通行證", "HAMSTER PASI")
T("Season %lld · %lld days left", "Сезон %1$lld · залишилось днів: %2$lld", "Saison %1$lld · noch %2$lld Tage", "Temporada %1$lld · quedan %2$lld días", "Saison %1$lld · %2$lld jours restants", "Stagione %1$lld · %2$lld giorni rimasti", "Temporada %1$lld · faltam %2$lld dias", "シーズン%1$lld・残り%2$lld日", "시즌 %1$lld · %2$lld일 남음", "第%1$lld赛季 · 剩余%2$lld天", "第%1$lld賽季 · 剩餘%2$lld天", "Sezon %1$lld · %2$lld gün kaldı")
T("Tier %lld/%lld", "Рівень %lld/%lld", "Stufe %lld/%lld", "Nivel %lld/%lld", "Palier %lld/%lld", "Livello %lld/%lld", "Nível %lld/%lld", "ティア%lld/%lld", "단계 %lld/%lld", "等级 %lld/%lld", "等級 %lld/%lld", "Kademe %lld/%lld")
T("FREE", "БЕЗПЛАТНО", "GRATIS", "GRATIS", "GRATUIT", "GRATIS", "GRÁTIS", "無料", "무료", "免费", "免費", "ÜCRETSİZ")
T("GOLD", "ЗОЛОТО", "GOLD", "ORO", "OR", "ORO", "OURO", "ゴールド", "골드", "黄金", "黃金", "ALTIN")
T("Gold Pass active", "Золотий пропуск активний", "Gold-Pass aktiv", "Pase Oro activo", "Passe Or actif", "Pass Oro attivo", "Passe Ouro ativo", "ゴールドパス有効", "골드 패스 활성", "黄金通行证已激活", "黃金通行證已啟用", "Altın Pas aktif")
T("Unlock Gold Pass", "Відкрити Золотий пропуск", "Gold-Pass freischalten", "Desbloquear Pase Oro", "Débloquer le Passe Or", "Sblocca il Pass Oro", "Liberar Passe Ouro", "ゴールドパスを解放", "골드 패스 잠금 해제", "解锁黄金通行证", "解鎖黃金通行證", "Altın Pas'ı Aç")
T("Skins", "Образи", "Skins", "Aspectos", "Looks", "Aspetti", "Visuais", "スキン", "스킨", "皮肤", "造型", "Görünümler")
T("Earn pass XP by winning battles, clearing quests and challenges.", "Досвід пропуску дають перемоги, завдання та виклики.", "Pass-EP gibt es für Siege, Aufgaben und Herausforderungen.", "Gana XP del pase ganando batallas, misiones y desafíos.", "Gagne de l'XP de passe avec les victoires, quêtes et défis.", "Ottieni XP del pass vincendo battaglie, missioni e sfide.", "Ganhe XP do passe vencendo batalhas, missões e desafios.", "バトル勝利・クエスト・チャレンジでパス経験値を獲得。", "전투 승리, 퀘스트, 도전으로 패스 경험치를 얻으세요.", "赢得战斗、完成任务和挑战可获得通行证经验。", "贏得戰鬥、完成任務和挑戰可獲得通行證經驗。", "Pas XP'sini savaş kazanarak, görev ve meydan okumaları bitirerek kazan.")

VERBATIM += ["%@ 🌻", "%lld 🌻 · %lld/%lld"]
T("Screen shake", "Тряска екрана", "Bildschirmwackeln", "Vibración de pantalla", "Tremblement d'écran", "Tremolio schermo", "Tremor de tela", "画面の揺れ", "화면 흔들림", "屏幕震动", "畫面震動", "Ekran sarsıntısı")
T("RAT KING", "ЩУРЯЧИЙ КОРОЛЬ", "RATTENKÖNIG", "REY RATA", "ROI DES RATS", "RE DEI RATTI", "REI RATO", "ネズミの王", "쥐왕", "鼠王", "鼠王", "FARE KRAL")
T("XP %lld%% → %@", "Досвід %lld%% → %@", "EP %lld %% → %@", "XP %lld%% → %@", "XP %lld %% → %@", "XP %lld%% → %@", "XP %lld%% → %@", "経験値 %lld%% → %@", "경험치 %lld%% → %@", "经验 %lld%% → %@", "經驗 %lld%% → %@", "XP %%%lld → %@")
T("First purchase bonus: double seeds on any seed pack!", "Бонус першої покупки: подвійне насіння в будь-якому наборі!", "Erstkaufbonus: doppelte Samen in jedem Paket!", "Bono de primera compra: ¡semillas dobles en cualquier paquete!", "Bonus du premier achat : graines doublées sur n'importe quel pack !", "Bonus primo acquisto: semi doppi in qualsiasi pacchetto!", "Bônus da primeira compra: sementes em dobro em qualquer pacote!", "初回購入ボーナス：どの種パックも2倍！", "첫 구매 보너스: 모든 씨앗 팩 2배!", "首充奖励：任意种子包双倍！", "首儲獎勵：任意種子包雙倍！", "İlk alım bonusu: her tohum paketinde çift tohum!")
T("×5 VALUE", "×5 ВИГОДА", "×5 WERT", "×5 VALOR", "×5 VALEUR", "×5 VALORE", "×5 VALOR", "5倍お得", "5배 가치", "5倍超值", "5倍超值", "×5 DEĞER")
T("Seed Cart", "Віз насіння", "Samenkarren", "Carro de semillas", "Chariot de graines", "Carretto di semi", "Carroça de sementes", "種の荷車", "씨앗 수레", "种子推车", "種子推車", "Tohum Arabası")
T("Seed Silo", "Силос насіння", "Samensilo", "Silo de semillas", "Silo de graines", "Silo di semi", "Silo de sementes", "種のサイロ", "씨앗 저장고", "种子粮仓", "種子糧倉", "Tohum Silosu")
T("POPULAR", "ПОПУЛЯРНЕ", "BELIEBT", "POPULAR", "POPULAIRE", "POPOLARE", "POPULAR", "人気", "인기", "热门", "熱門", "POPÜLER")
T("Free Seeds", "Безплатне насіння", "Gratis-Samen", "Semillas gratis", "Graines gratuites", "Semi gratis", "Sementes grátis", "無料の種", "무료 씨앗", "免费种子", "免費種子", "Bedava Tohum")
T("Map", "Мапа", "Karte", "Mapa", "Carte", "Mappa", "Mapa", "マップ", "지도", "地图", "地圖", "Harita")
T("Can your hamsters do better?", "А твої хом'яки зможуть краще?", "Schaffen deine Hamster das besser?", "¿Tus hámsteres pueden hacerlo mejor?", "Tes hamsters feront-ils mieux ?", "I tuoi criceti sanno fare di meglio?", "Seus hamsters conseguem fazer melhor?", "君のハムスターはもっとやれる？", "네 햄스터들은 더 잘할 수 있을까?", "你的仓鼠能做得更好吗？", "你的倉鼠能做得更好嗎？", "Senin hamsterların daha iyisini yapabilir mi?")
T("Share", "Поділитися", "Teilen", "Compartir", "Partager", "Condividi", "Compartilhar", "シェア", "공유", "分享", "分享", "Paylaş")
VERBATIM += ["HAMSTER AGES"]
T("Piggy Bank", "Скарбничка", "Sparschwein", "Hucha", "Tirelire", "Salvadanaio", "Cofrinho", "ブタの貯金箱", "돼지 저금통", "存钱罐", "撲滿", "Kumbara")
T("FULL", "ПОВНА", "VOLL", "LLENA", "PLEINE", "PIENO", "CHEIO", "満タン", "가득", "已满", "已滿", "DOLU")
VERBATIM += ["%lld★"]
T("TIP", "ПОРАДА", "TIPP", "CONSEJO", "ASTUCE", "SUGGERIMENTO", "DICA", "ヒント", "팁", "提示", "提示", "İPUCU")
T("Army", "Армія", "Armee", "Ejército", "Armée", "Esercito", "Exército", "軍隊", "군대", "军队", "軍隊", "Ordu")
T("Lv %lld", "Рів. %lld", "St. %lld", "Nv %lld", "Niv %lld", "Liv %lld", "Nv %lld", "Lv%lld", "Lv %lld", "%lld级", "%lld級", "Sv %lld")
