#!/usr/bin/env python3
"""Localized App Store metadata. Validates App Store limits and writes AppStoreLocalized.md.
Limits: name 30, subtitle 30, keywords 100 (comma-separated, no spaces needed), promo text 170."""
import os

L = {}
def M(loc, name, subtitle, keywords, promo):
    L[loc] = dict(name=name, subtitle=subtitle, keywords=keywords, promo=promo)

M("en-US", "Hamster Ages: Army Evolution", "Lane battles through history",
  "tower,defense,td,caveman,castle,tank,war,age,stick,idle,rts,hero,base,epic,cute,strategy,offline",
  "Lead your hamster army from the Stone Age to the stars! Pick evolution cards, collect legendary generals and crush the rat empire in fast 4-minute battles.")
M("uk", "Hamster Ages: Армія хом'яків", "Битви крізь епохи історії",
  "стратегія,війна,оборона,башта,замок,танк,печера,лицар,герой,база,еволюція,тд,бій,рицар,мила,офлайн",
  "Веди армію хом'ячків від кам'яної доби до зірок! Обирай карти еволюції, збирай легендарних генералів і громи щурячу імперію в 4-хвилинних боях.")
M("de-DE", "Hamster Ages: Armee-Evolution", "Schlachten durch alle Epochen",
  "turm,verteidigung,td,steinzeit,burg,panzer,krieg,zeitalter,schlacht,strategie,held,basis,offline,süß",
  "Führe deine Hamsterarmee von der Steinzeit bis zu den Sternen! Wähle Evolutionskarten, sammle legendäre Generäle und zerschlage das Rattenreich.")
M("es-ES", "Hamster Ages: Ejército épico", "Batallas por toda la historia",
  "torre,defensa,td,cavernícola,castillo,tanque,guerra,era,estrategia,héroe,base,evolución,offline",
  "¡Lleva a tu ejército de hámsters de la Edad de Piedra a las estrellas! Elige cartas de evolución, reúne generales legendarios y aplasta al imperio rata.")
M("es-MX", "Hamster Ages: Ejército épico", "Batallas por toda la historia",
  "torre,defensa,td,cavernícola,castillo,tanque,guerra,era,estrategia,héroe,base,evolución,offline",
  "¡Lleva a tu ejército de hámsters de la Edad de Piedra a las estrellas! Elige cartas de evolución, reúne generales legendarios y aplasta al imperio rata.")
M("fr-FR", "Hamster Ages : Armée épique", "Batailles à travers l'histoire",
  "tour,défense,td,préhistoire,château,tank,guerre,âge,stratégie,héros,base,évolution,horsligne",
  "Mène ton armée de hamsters de l'âge de pierre aux étoiles ! Choisis des cartes d'évolution, collectionne des généraux légendaires et écrase l'empire des rats.")
M("it", "Hamster Ages: Esercito epico", "Battaglie attraverso la storia",
  "torre,difesa,td,cavernicolo,castello,carro,guerra,era,strategia,eroe,base,evoluzione,offline",
  "Guida il tuo esercito di criceti dall'età della pietra alle stelle! Scegli carte evoluzione, colleziona generali leggendari e schiaccia l'impero dei ratti.")
M("pt-BR", "Hamster Ages: Exército épico", "Batalhas através da história",
  "torre,defesa,td,homem,caverna,castelo,tanque,guerra,era,estratégia,herói,base,evolução,offline",
  "Leve seu exército de hamsters da Idade da Pedra às estrelas! Escolha cartas de evolução, colecione generais lendários e esmague o império dos ratos.")
M("ja", "ハムスターエイジ：進化する軍団", "歴史を駆け抜けるレーンバトル",
  "タワーディフェンス,防衛,原始人,城,戦車,戦争,時代,ストラテジー,ヒーロー,基地,進化,オフライン,かわいい,放置",
  "ハムスター軍団を率いて石器時代から宇宙へ！進化カードを選び、伝説の将軍を集め、4分の熱いバトルでネズミ帝国を倒そう。")
M("ko", "햄스터 에이지: 진화하는 군대", "역사를 가로지르는 라인 배틀",
  "타워디펜스,방어,원시인,성,탱크,전쟁,시대,전략,영웅,기지,진화,오프라인,귀여운,디펜스",
  "햄스터 군대를 이끌고 석기 시대부터 우주까지! 진화 카드를 고르고 전설의 장군을 모아 4분짜리 전투로 쥐 제국을 무너뜨리세요.")
M("zh-Hans", "仓鼠时代：军团进化", "穿越历史的兵线对战",
  "塔防,防御,原始人,城堡,坦克,战争,时代,策略,英雄,基地,进化,离线,可爱,休闲",
  "率领仓鼠大军从石器时代打到星辰大海！挑选进化卡牌，收集传说将军，在4分钟的激战中击溃鼠族帝国。")
M("zh-Hant", "倉鼠時代：軍團進化", "穿越歷史的兵線對戰",
  "塔防,防禦,原始人,城堡,坦克,戰爭,時代,策略,英雄,基地,進化,離線,可愛,休閒",
  "率領倉鼠大軍從石器時代打到星辰大海！挑選進化卡牌，收集傳說將軍，在4分鐘的激戰中擊潰鼠族帝國。")
M("tr", "Hamster Ages: Ordu Evrimi", "Tarih boyunca şerit savaşları",
  "kule,savunma,td,mağara,kale,tank,savaş,çağ,strateji,kahraman,üs,evrim,çevrimdışı,sevimli",
  "Hamster ordunu Taş Devri'nden yıldızlara taşı! Evrim kartlarını seç, efsanevi generalleri topla ve 4 dakikalık savaşlarda fare imparatorluğunu ez.")

LIMITS = dict(name=30, subtitle=30, keywords=100, promo=170)

def main():
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    out = ["# Hamster Ages — локалізовані метадані App Store", "",
           "Згенеровано `Tools/aso/listing.py` (перевіряє ліміти). Ключові слова не повторюють слова з назви й підзаголовка.", ""]
    for loc, m in L.items():
        for k, lim in LIMITS.items():
            if len(m[k]) > lim:
                raise SystemExit(f"{loc}.{k} is {len(m[k])}/{lim}: {m[k]}")
        out += [f"## {loc}", "| Поле | Текст | Довжина |", "|---|---|---|"]
        for k, lim in LIMITS.items():
            out.append(f"| {k} | {m[k]} | {len(m[k])}/{lim} |")
        out.append("")
    open(os.path.join(root, "AppStoreLocalized.md"), "w").write("\n".join(out))
    print(f"ok: {len(L)} locales")

if __name__ == "__main__":
    main()
