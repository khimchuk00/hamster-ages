#!/usr/bin/env python3
"""Turns raw simulator captures into captioned App Store screenshots (6.9", 2868×1320 landscape).

  git fetch origin appstore-shots && git archive origin/appstore-shots | tar -x -C /tmp/raw
  python3 Tools/aso/make_screenshots.py /tmp/raw/raw AppStoreShots/iphone
  python3 Tools/aso/make_screenshots.py --ipad /tmp/raw/raw-ipad AppStoreShots/ipad     # 13" iPad, 2752×2064

Input:  <raw>/<lang>/{1-battle,2-cards,3-future,4-heroes,5-home,6-upgrades}.png
Output: <out>/<lang>/01.png … 06.png
"""
import os, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 2868, 1320
IPAD = False
SHOTS = ["1-battle", "2-cards", "3-future", "4-heroes", "5-home", "6-upgrades"]
FONT = "/usr/share/fonts/opentype/noto/NotoSansCJK-Black.ttc"
FONT_INDEX = {"ja": 0, "ko": 1, "zh-Hans": 2, "zh-Hant": 3}  # others use JP face (full Latin/Cyrillic)

CAPTIONS = {
    "en": ["5 AGES OF WAR", "EVERY BATTLE IS DIFFERENT", "FROM CLUBS TO LASER MECHS",
           "COLLECT LEGENDARY GENERALS", "BOSSES, SURVIVAL & DAILY CHALLENGES", "UPGRADE YOUR HAMSTER ARMY"],
    "uk": ["5 ЕПОХ ВІЙНИ", "КОЖЕН БІЙ — ІНШИЙ", "ВІД ДРЮКІВ ДО ЛАЗЕРНИХ МЕХІВ",
           "ЗБИРАЙ ЛЕГЕНДАРНИХ ГЕНЕРАЛІВ", "БОСИ, ВИЖИВАННЯ Й ЩОДЕННІ ВИКЛИКИ", "ПОКРАЩУЙ АРМІЮ ХОМ'ЯЧКІВ"],
    "de": ["5 ZEITALTER DES KRIEGES", "JEDER KAMPF IST ANDERS", "VON KEULEN ZU LASER-MECHS",
           "SAMMLE LEGENDÄRE GENERÄLE", "BOSSE, ÜBERLEBEN & TAGES-CHALLENGES", "VERBESSERE DEINE HAMSTERARMEE"],
    "es": ["5 ERAS DE GUERRA", "CADA BATALLA ES DISTINTA", "DE GARROTES A MECHAS LÁSER",
           "COLECCIONA GENERALES LEGENDARIOS", "JEFES, SUPERVIVENCIA Y DESAFÍOS DIARIOS", "MEJORA TU EJÉRCITO HÁMSTER"],
    "fr": ["5 ÂGES DE GUERRE", "CHAQUE COMBAT EST DIFFÉRENT", "DES MASSUES AUX MÉCHAS LASER",
           "COLLECTIONNE DES GÉNÉRAUX LÉGENDAIRES", "BOSS, SURVIE ET DÉFIS QUOTIDIENS", "AMÉLIORE TON ARMÉE DE HAMSTERS"],
    "it": ["5 ERE DI GUERRA", "OGNI BATTAGLIA È DIVERSA", "DALLE CLAVE AI MECH LASER",
           "COLLEZIONA GENERALI LEGGENDARI", "BOSS, SOPRAVVIVENZA E SFIDE GIORNALIERE", "POTENZIA IL TUO ESERCITO DI CRICETI"],
    "pt-BR": ["5 ERAS DE GUERRA", "CADA BATALHA É DIFERENTE", "DE PORRETES A MECHAS LASER",
              "COLECIONE GENERAIS LENDÁRIOS", "CHEFES, SOBREVIVÊNCIA E DESAFIOS DIÁRIOS", "MELHORE SEU EXÉRCITO DE HAMSTERS"],
    "ja": ["5つの時代を戦い抜け", "毎回ちがうバトル", "こん棒からレーザーメカまで",
           "伝説の将軍を集めよう", "ボス・サバイバル・デイリーチャレンジ", "ハムスター軍団を強化しよう"],
    "ko": ["5개 시대의 전쟁", "매번 다른 전투", "몽둥이에서 레이저 메카까지",
           "전설의 장군을 모으세요", "보스, 서바이벌, 일일 도전", "햄스터 군대를 강화하세요"],
    "zh-Hans": ["跨越5个时代的战争", "每一战都不一样", "从棒槌到激光机甲",
                "收集传说将军", "首领、生存与每日挑战", "强化你的仓鼠大军"],
    "zh-Hant": ["跨越5個時代的戰爭", "每一戰都不一樣", "從棒槌到雷射機甲",
                "收集傳說將軍", "首領、生存與每日挑戰", "強化你的倉鼠大軍"],
    "tr": ["5 SAVAŞ ÇAĞI", "HER SAVAŞ FARKLI", "SOPALARDAN LAZER ROBOTLARA",
           "EFSANEVİ GENERALLER TOPLA", "BOSSLAR, HAYATTA KALMA VE GÜNLÜK GÖREVLER", "HAMSTER ORDUNU GELİŞTİR"],
}

INK = (58, 42, 34)
TOP, BOTTOM = (255, 166, 77), (122, 72, 196)


def font(lang, size):
    return ImageFont.truetype(FONT, size, index=FONT_INDEX.get(lang, 0))


def background():
    bg = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(bg)
    for y in range(H):
        t = y / (H - 1)
        d.line([(0, y), (W, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(TOP, BOTTOM)))
    # soft light rays for a little depth
    rays = Image.new("L", (W, H), 0)
    rd = ImageDraw.Draw(rays)
    for i in range(9):
        x = W // 2 + (i - 4) * 420
        rd.polygon([(W // 2, -200), (x - 90, H), (x + 90, H)], fill=26)
    bg.paste(Image.new("RGB", (W, H), (255, 255, 255)), (0, 0), rays.filter(ImageFilter.GaussianBlur(30)))
    return bg


def caption(img, lang, text):
    d = ImageDraw.Draw(img)
    size = 140 if IPAD else 112
    while size > 50:
        f = font(lang, size)
        if d.textlength(text, font=f) <= W - 240:
            break
        size -= 4
    tw = d.textlength(text, font=f)
    x, y = (W - tw) / 2, 110 if IPAD else 70
    d.text((x, y + 8), text, font=f, fill=(0, 0, 0, 90), stroke_width=14, stroke_fill=(40, 20, 60))
    d.text((x, y), text, font=f, fill=(255, 255, 255), stroke_width=12, stroke_fill=INK)


def device(shot):
    if shot.height > shot.width:
        shot = shot.rotate(-90 if IPAD else 90, expand=True)
    shot = shot.convert("RGB")
    if not IPAD:
        # Trim the side margins: hides the Dynamic Island cut-out (the game keeps content out of that safe area).
        m = int(shot.width * 0.06)
        shot = shot.crop((m, 0, shot.width - m, shot.height))
    max_w, max_h = W - 260, H - (380 if IPAD else 300)
    scale = min(max_w / shot.width, max_h / shot.height)
    shot = shot.resize((int(shot.width * scale), int(shot.height * scale)), Image.LANCZOS)
    bezel = 22
    fw, fh = shot.width + 2 * bezel, shot.height + 2 * bezel
    frame = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
    fd = ImageDraw.Draw(frame)
    fd.rounded_rectangle([0, 0, fw - 1, fh - 1], radius=86, fill=(24, 18, 32, 255))
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, shot.width - 1, shot.height - 1], radius=66, fill=255)
    frame.paste(shot, (bezel, bezel), mask)
    return frame


def compose(lang, raw_dir, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    for i, name in enumerate(SHOTS):
        src = os.path.join(raw_dir, name + ".png")
        if not os.path.exists(src):
            print(f"  skip {lang}/{name} (missing)")
            continue
        img = background().convert("RGBA")
        dev = device(Image.open(src))
        x, y = (W - dev.width) // 2, H - dev.height - 40
        shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(shadow).rounded_rectangle([x + 10, y + 26, x + dev.width + 10, y + dev.height + 26],
                                                 radius=90, fill=(30, 10, 50, 150))
        img = Image.alpha_composite(img, shadow.filter(ImageFilter.GaussianBlur(24)))
        img.alpha_composite(dev, (x, y))
        caption(img, lang, CAPTIONS[lang][i])
        img.convert("RGB").save(os.path.join(out_dir, f"{i + 1:02d}.png"), optimize=True)
    print(f"  {lang}: done")


def main():
    global W, H, IPAD
    args = sys.argv[1:]
    if args and args[0] == "--ipad":
        IPAD, W, H = True, 2752, 2064
        args = args[1:]
    raw, out = args[0], args[1]
    langs = args[2:] or sorted(d for d in os.listdir(raw) if d in CAPTIONS)
    for lang in langs:
        compose(lang, os.path.join(raw, lang), os.path.join(out, lang))


if __name__ == "__main__":
    main()
