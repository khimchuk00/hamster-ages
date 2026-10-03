"""Line-for-line Python port of HamsterAges/Core (GameConfig, Cards, BattleSimulation, BattleAI).
Used to check balance where no Swift toolchain is available. Keep in sync with the Swift code.
Usage: python3 Tools/balance_port.py
"""
import random, math, sys

LANE = 1000.0; BASE_W = 70.0; MAX_Q = 5; START_FOOD = 140.0
KILL_FOOD = 0.6; KILL_XP = 1.1; LOSS_XP = 0.25; PASSIVE_XP = 2.0
SLOT_COST = 150.0; OVERTIME = 270.0; BOSS_FIRST = 45.0; BOSS_INT = 100.0; BOSS_HP = 2.5; BOSS_DMG = 1.25; TURRET_K = 7.0; SPECIAL_DELAY = 0.7; SPACING = 4.0
COST = [1, 2.4, 5.5, 12, 26]; POWER = [1, 1.15, 1.32, 1.52, 1.75]
XP_NEED = [320, 1350, 4300, 12500, None]
BASE_HP = [500, 1150, 2500, 5400, 11500]; INCOME = [3, 7, 16, 35, 76]
T_INT = [1.3, 1.1, 1.2, 0.45, 0.8]; T_SPLASH = [0, 0, 45, 0, 30]
MELEE, RANGED, HEAVY = 0, 1, 2

def era_def(i):
    c = COST[i]; p = COST[i] * POWER[i]
    units = [
        dict(cost=round(15*c), hp=60*p, dmg=14*p, ai=1.0, rng=8, spd=44, train=1.0, w=30, ranged=False, ps=0),
        dict(cost=round(25*c), hp=40*p, dmg=10*p, ai=1.25, rng=150, spd=40, train=1.3, w=30, ranged=True, ps=420),
        dict(cost=round(90*c), hp=330*p, dmg=36*p, ai=1.6, rng=120 if i >= 2 else 10, spd=30, train=2.6, w=46, ranged=i >= 2, ps=360),
    ]
    turret = dict(cost=round(80*c), dmg=TURRET_K*p, interval=T_INT[i], rng=230+i*15, ps=520, splash=T_SPLASH[i])
    return dict(units=units, turret=turret, special_dmg=70*p, special_cd=40, base=BASE_HP[i], income=INCOME[i], xp=XP_NEED[i])
ERAS = [era_def(i) for i in range(5)]

class Diff:
    def __init__(self, stage):
        s = max(1, stage) - 1; boss = stage % 5 == 0
        self.stage = max(1, stage); self.boss = boss
        self.income = min(2.6, 0.6 + 0.045*s) 
        self.stats = min(2.2, 0.8 + 0.03*s) 
        self.think = max(0.45, 1.3 - 0.05*s); self.cards = stage >= 4
        self.evolve_delay = max(0.5, 10 - 0.6*s)

def mods(**kw):
    m = dict(unitHP=1, unitDmg=1, roleDmg=[1,1,1], roleHP=[1,1,1], atkSpd=1, moveSpd=1, rRange=1, income=1,
             killFood=1, xp=1, train=1, baseHP=1, turDmg=1, turRate=1, spCd=1, spDmg=1, cost=1, steal=0,
             splash=0, recruit=None, lastStand=False, startFood=0)
    m.update(kw); return m

CARDS = [("sharpTeeth",0,True),("eagleEye",0,True),("thickFur",0,True),("chubbyCheeks",0,True),("fastLearner",0,True),
         ("fortify",0,True),("turretGrease",0,True),("seedStash",0,True),("hamsterWheel",1,True),("recruiter",1,True),
         ("vampireBite",1,True),("skyFury",1,True),("bargainBin",1,True),("berserk",1,True),("splashShot",2,False),
         ("lastStand",2,False),("giantGrowth",2,True),("warDrums",2,True)]
RW = [60, 30, 10]

def draw_cards(owned, rng, n=3, epic_boost=1.0):
    pool = [c for c in CARDS if c[2] or c[0] not in owned]; out = []
    while len(out) < n and pool:
        ws = [RW[c[1]] * (epic_boost if c[1] == 2 else 1) for c in pool]
        r = rng.random() * sum(ws); pick = len(pool) - 1
        for i, w in enumerate(ws):
            if r < w: pick = i; break
            r -= w
        out.append(pool.pop(pick))
    return out

class Unit:
    __slots__ = "id side role era x hp maxhp dmg ai rng spd w ranged ps cost cd moving boss".split()

class Side:
    def __init__(self, m):
        self.food = START_FOOD + m["startFood"]; self.xp = 0.0; self.era = 0
        self.basemax = ERAS[0]["base"] * m["baseHP"]; self.basehp = self.basemax
        self.queue = []; self.tp = 0.0; self.turrets = [[True, None, 0.0], [False, None, 0.0]]
        self.spcd = 8.0; self.m = m; self.cards = []; self.ls_used = False; self.rtimer = 0.0
        self.kills = 0; self.dmg_to_base = 0.0
    @property
    def can_evolve(self):
        need = ERAS[self.era]["xp"]; return need is not None and self.xp >= need
    @property
    def sp_max(self): return ERAS[self.era]["special_cd"] * self.m["spCd"]

def dirn(s): return 1.0 if s == 0 else -1.0
def base_front(s): return BASE_W if s == 0 else LANE - BASE_W
def spawn_x(s, w): return base_front(s) + dirn(s) * (w/2 + 2)

class Sim:
    def __init__(self, diff, pmods, seed):
        self.d = diff; self.rng = random.Random(seed)
        em = mods(unitHP=diff.stats, unitDmg=diff.stats, turDmg=diff.stats, baseHP=0.9+0.1*diff.stats,
                  income=diff.income, killFood=0.85+0.15*diff.income, xp=0.9+0.1*diff.income)
        self.s = [Side(pmods), Side(em)]
        self.units = []; self.proj = []; self.t = 0.0; self.winner = None; self.nid = 1; self.specials = []
        self.ai = {1: AI(diff.think, diff.evolve_delay, diff.cards)}; self.boss_t = BOSS_FIRST
        if diff.boss:
            epics = [c for c in CARDS if c[1] == 2 and c[0] != "lastStand"]
            self.apply(self.rng.choice(epics)[0], 1)

    def unit_cost(self, role, side): s = self.s[side]; return round(ERAS[s.era]["units"][role]["cost"] * s.m["cost"])
    def turret_cost(self, side): return ERAS[self.s[side].era]["turret"]["cost"]
    def slot_cost(self, side): return round(SLOT_COST * COST[self.s[side].era])

    def train(self, role, side):
        s = self.s[side]; c = self.unit_cost(role, side)
        if self.winner is not None or len(s.queue) >= MAX_Q or s.food < c: return False
        s.food -= c; s.queue.append((role, s.era)); return True

    def evolve(self, side):
        s = self.s[side]
        if self.winner is not None or not s.can_evolve: return False
        s.era += 1; nm = ERAS[s.era]["base"] * s.m["baseHP"]; s.basehp += nm - s.basemax; s.basemax = nm
        s.spcd = min(s.spcd, 6); return True

    def buy_turret(self, slot, side):
        s = self.s[side]; ts = s.turrets[slot]
        if self.winner is not None or self.t >= OVERTIME or not ts[0]: return False
        if ts[1] is not None and ts[1] >= s.era: return False
        refund = ERAS[ts[1]]["turret"]["cost"] * 0.5 if ts[1] is not None else 0
        c = self.turret_cost(side)
        if s.food + refund < c: return False
        s.food += refund - c; ts[1] = s.era; ts[2] = 0.3; return True

    def unlock(self, side):
        s = self.s[side]; c = self.slot_cost(side)
        if self.winner is not None or s.turrets[1][0] or s.food < c: return False
        s.food -= c; s.turrets[1][0] = True; return True

    def special(self, side):
        s = self.s[side]
        if self.winner is not None or s.spcd > 0: return False
        s.spcd = s.sp_max; self.specials.append([side, ERAS[s.era]["special_dmg"] * s.m["spDmg"], SPECIAL_DELAY]); return True

    def apply(self, cid, side):
        s = self.s[side]; m = s.m
        if cid == "sharpTeeth": m["roleDmg"][0] *= 1.25
        elif cid == "eagleEye": m["rRange"] *= 1.2; m["roleDmg"][1] *= 1.1
        elif cid == "thickFur": m["unitHP"] *= 1.2
        elif cid == "chubbyCheeks": m["income"] *= 1.3
        elif cid == "fastLearner": m["xp"] *= 1.3
        elif cid == "fortify":
            old = s.basemax; m["baseHP"] *= 1.25; s.basemax *= 1.25
            s.basehp = min(s.basemax, s.basehp + (s.basemax - old) + 0.25 * s.basemax)
        elif cid == "turretGrease": m["turDmg"] *= 1.3; m["turRate"] *= 1.15
        elif cid == "seedStash": s.food += 160 * COST[s.era]
        elif cid == "hamsterWheel": m["train"] *= 1.3
        elif cid == "recruiter": m["recruit"] = (m["recruit"] or 14.3) * 0.7
        elif cid == "vampireBite": m["steal"] += 0.2
        elif cid == "skyFury": m["spCd"] *= 0.7; m["spDmg"] *= 1.3; s.spcd *= 0.7
        elif cid == "bargainBin": m["cost"] *= 0.85
        elif cid == "berserk": m["atkSpd"] *= 1.25
        elif cid == "splashShot": m["splash"] = 0.5
        elif cid == "lastStand": m["lastStand"] = True
        elif cid == "giantGrowth": m["roleHP"][2] *= 1.4; m["roleDmg"][2] *= 1.4
        elif cid == "warDrums": m["unitDmg"] *= 1.15; m["moveSpd"] *= 1.15
        s.cards.append(cid)

    def step(self, dt):
        if self.winner is not None: return
        self.t += dt
        for side in (0, 1):
            self.economy(side, dt); self.training(side, dt); self.recruiter(side, dt); self.turrets(side, dt)
        self.update_boss(dt)
        self.update_units(dt); self.update_proj(dt); self.update_specials(dt)
        self.units = [u for u in self.units if u.hp > 0]
        for side in (0, 1):
            if self.winner is None and side in self.ai: self.ai[side].update(self, side, dt)

    def update_boss(self, dt):
        if not self.d.boss: return
        if any(u.boss and u.hp > 0 for u in self.units): return
        self.boss_t -= dt
        if self.boss_t > 0: return
        w = ERAS[self.s[1].era]["units"][2]["w"] * 1.4
        if not any(u.boss and u.hp > 0 for u in self.units) and self.clear(1, w):
            self.spawn(2, self.s[1].era, 1, True); self.boss_t = BOSS_INT

    def economy(self, side, dt):
        s = self.s[side]; s.food += ERAS[s.era]["income"] * s.m["income"] * dt
        s.xp += PASSIVE_XP * COST[s.era] * s.m["xp"] * dt; s.spcd = max(0, s.spcd - dt)

    def clear(self, side, w):
        x = spawn_x(side, w)
        return not any(u.side == side and u.hp > 0 and abs(u.x - x) < (u.w + w)/2 + 2 for u in self.units)

    def spawn(self, role, era, side, boss=False):
        st = ERAS[era]["units"][role]; m = self.s[side].m; u = Unit(); hk = BOSS_HP if boss else 1; dk = BOSS_DMG if boss else 1
        u.boss = boss; w = st["w"] * (1.4 if boss else 1)
        u.id = self.nid; self.nid += 1; u.side = side; u.role = role; u.era = era; u.x = spawn_x(side, w)
        u.maxhp = st["hp"] * m["unitHP"] * m["roleHP"][role] * hk; u.hp = u.maxhp
        u.dmg = st["dmg"] * m["unitDmg"] * m["roleDmg"][role] * dk; u.ai = st["ai"] / m["atkSpd"]
        u.rng = st["rng"] * m["rRange"] if st["ranged"] else st["rng"]; u.spd = st["spd"] * m["moveSpd"] * (0.8 if boss else 1)
        u.w = w; u.ranged = st["ranged"]; u.ps = st["ps"]; u.cost = st["cost"] * (4 if boss else 1); u.cd = 0.2; u.moving = False
        self.units.append(u)

    def training(self, side, dt):
        s = self.s[side]
        if not s.queue: return
        role, era = s.queue[0]; st = ERAS[era]["units"][role]
        s.tp = min(st["train"], s.tp + dt * s.m["train"])
        if s.tp >= st["train"] and self.clear(side, st["w"]):
            s.queue.pop(0); s.tp = 0; self.spawn(role, era, side)

    def recruiter(self, side, dt):
        s = self.s[side]; iv = s.m["recruit"]
        if iv is None: return
        s.rtimer += dt
        if s.rtimer >= iv and self.clear(side, ERAS[s.era]["units"][0]["w"]):
            s.rtimer = 0; self.spawn(0, s.era, side)

    def front(self, side):
        best = None; d = dirn(side)
        for u in self.units:
            if u.side == side and u.hp > 0 and (best is None or u.x * d > best.x * d): best = u
        return best

    def turrets(self, side, dt):
        s = self.s[side]; f = base_front(side)
        for slot, ts in enumerate(s.turrets):
            if ts[1] is None: continue
            if self.t >= OVERTIME: continue
            t = ERAS[ts[1]]["turret"]; cd = ts[2] - dt * s.m["turRate"]; ts[2] = max(0, cd)
            tgt = self.front(1 - side)
            if cd > 0 or tgt is None: continue
            if (tgt.x - f) * dirn(side) - tgt.w/2 > t["rng"]: continue
            sx = f - dirn(side) * 22
            self.proj.append(dict(side=side, x=sx, sx=sx, tid=tgt.id, tx=tgt.x, spd=t["ps"], dmg=t["dmg"]*s.m["turDmg"],
                                  splash=t["splash"], sf=0.6, src=None))
            ts[2] = t["interval"]

    def update_units(self, dt):
        for side in (0, 1):
            d = dirn(side); ebf = base_front(1 - side)
            own = sorted([u for u in self.units if u.side == side and u.hp > 0], key=lambda u: -u.x * d)
            ahead = None
            for u in own:
                if u.hp <= 0: continue
                u.cd -= dt
                foe = self.front(1 - side)
                bd = (ebf - u.x) * d - u.w/2; tgt = None; dist = bd
                if foe is not None:
                    dd = (foe.x - u.x) * d - (foe.w + u.w)/2
                    if dd <= bd: tgt = foe; dist = dd
                if dist <= u.rng:
                    u.moving = False
                    if u.cd <= 0: self.attack(u, tgt); u.cd = u.ai
                else:
                    nx = u.x + d * u.spd * dt
                    def clamp(nx, lim):
                        if (nx - lim) * d > 0: return u.x if (u.x - lim) * d > 0 else lim
                        return nx
                    if ahead is not None: nx = clamp(nx, ahead.x - d * ((ahead.w + u.w)/2 + SPACING))
                    if foe is not None: nx = clamp(nx, foe.x - d * ((foe.w + u.w)/2))
                    nx = clamp(nx, ebf - d * u.w/2)
                    u.moving = abs(nx - u.x) > 1e-4; u.x = nx
                ahead = u

    def ot(self): return 1.0 + max(0.0, self.t - OVERTIME) / 60.0 * 1.0
    def attack(self, u, tgt):
        k = self.ot()
        if u.ranged:
            m = self.s[u.side].m; sx = u.x + dirn(u.side) * u.w/2; heavy = u.role == HEAVY
            self.proj.append(dict(side=u.side, x=sx, sx=sx, tid=tgt.id if tgt else None,
                                  tx=tgt.x if tgt else base_front(1 - u.side), spd=u.ps, dmg=u.dmg * k,
                                  splash=40 if heavy else (45 if m["splash"] > 0 else 0),
                                  sf=0.5 if heavy else m["splash"], src=u.id))
        elif tgt is not None: self.damage(tgt, u.dmg * k, u.side, u.id)
        else: self.damage_base(1 - u.side, u.dmg * k, u.side)

    def find(self, uid):
        if uid is None: return None
        for u in self.units:
            if u.id == uid and u.hp > 0: return u
        return None

    def update_proj(self, dt):
        keep = []
        for p in self.proj:
            t = self.find(p["tid"])
            if t: p["tx"] = t.x
            d = 1.0 if p["tx"] >= p["x"] else -1.0; st = p["spd"] * dt
            if abs(p["tx"] - p["x"]) <= st: p["x"] = p["tx"]; self.impact(p)
            else: p["x"] += d * st; keep.append(p)
        self.proj = keep

    def impact(self, p):
        if p["tid"] is None: self.damage_base(1 - p["side"], p["dmg"], p["side"]); return
        prim = self.find(p["tid"])
        if prim is None:
            for u in self.units:
                if u.side == 1 - p["side"] and u.hp > 0 and abs(u.x - p["x"]) < u.w/2 + 10: prim = u; break
        if prim: self.damage(prim, p["dmg"], p["side"], p["src"])
        if p["splash"] > 0:
            for u in self.units:
                if u.side == 1 - p["side"] and u.hp > 0 and u is not prim and abs(u.x - p["x"]) <= p["splash"]:
                    self.damage(u, p["dmg"] * p["sf"], p["side"], p["src"])

    def update_specials(self, dt):
        keep = []
        for sp in self.specials:
            sp[2] -= dt
            if sp[2] <= 0:
                for u in self.units:
                    if u.side == 1 - sp[0] and u.hp > 0: self.damage(u, sp[1], sp[0], None)
            else: keep.append(sp)
        self.specials = keep

    def damage(self, t, amt, atk, src):
        if t.hp <= 0: return
        t.hp -= amt
        if t.hp > 0: return
        a = self.s[atk]; v = self.s[t.side]
        a.food += t.cost * KILL_FOOD * a.m["killFood"]; xp = t.cost * KILL_XP
        a.xp += xp * a.m["xp"]; a.kills += 1; v.xp += xp * LOSS_XP * v.m["xp"]
        if a.m["steal"] > 0:
            k = self.find(src)
            if k: k.hp = min(k.maxhp, k.hp + k.maxhp * a.m["steal"])

    def damage_base(self, victim, amt, atk):
        if self.winner is not None: return
        v = self.s[victim]; v.basehp -= amt; self.s[atk].dmg_to_base += amt
        if v.basehp <= 0:
            if v.m["lastStand"] and not v.ls_used: v.ls_used = True; v.basehp = v.basemax * 0.4
            else: v.basehp = 0; self.winner = atk

class AI:
    def __init__(self, think, evolve_delay, cards, weights=(0.48, 0.34, 0.18)):
        self.think = think; self.ed = evolve_delay; self.cards = cards; self.timer = 1.0; self.ev_at = None
        self.plan = None; self.w = list(weights)
    def update(self, sim, side, dt):
        self.timer -= dt
        if self.timer > 0: return
        self.timer = self.think * sim.rng.uniform(0.8, 1.2)
        s = sim.s[side]
        if s.can_evolve:
            if self.ev_at is None: self.ev_at = sim.t + self.ed
            if sim.t >= self.ev_at:
                sim.evolve(side); self.ev_at = None
                if self.cards:
                    c = draw_cards(s.cards, sim.rng, 3, 1.5 if sim.d.boss else 1)
                    if c: sim.apply(c[0][0], side)
        foes = [u for u in sim.units if u.side == 1 - side]
        near = sum(1 for u in foes if abs(u.x - base_front(side)) < LANE * 0.45)
        if s.spcd <= 0 and (len(foes) >= 5 or near >= 3): sim.special(side)
        tc = sim.turret_cost(side); reserve = sim.unit_cost(0, side) * 2
        for slot in (0, 1):
            ts = s.turrets[slot]
            if not ts[0]: continue
            outdated = ts[1] is None or ts[1] < s.era
            if outdated and s.food >= tc + reserve and (s.era >= 1 or (slot == 0 and s.food > tc * 1.6)):
                sim.buy_turret(slot, side); return
        if not s.turrets[1][0] and s.era >= 1 and s.food > sim.slot_cost(side) + tc * 1.5:
            sim.unlock(side); return
        if self.plan is None:
            r = sim.rng.random() * sum(self.w); self.plan = 0
            for i, w in enumerate(self.w):
                if r < w: self.plan = i; break
                r -= w
        if len(s.queue) < 3 and sim.train(self.plan, side): self.plan = None

def meta_mods(l):
    return mods(baseHP=1+0.08*l, startFood=20*l, income=1+0.05*l, unitHP=1+0.05*l, unitDmg=1+0.05*l,
                xp=1+0.05*l, turDmg=1+0.06*l)

def run(stage, meta, games, think=0.9, dt=1/20):
    wins = 0; mins = 0; eras = 0; eras_e = 0
    for g in range(games):
        sim = Sim(Diff(stage), meta_mods(meta), stage*1000 + meta*100 + g + 1)
        sim.ai[0] = AI(think, 1.5, True)
        c = draw_cards(sim.s[0].cards, sim.rng)
        if c: sim.apply(c[0][0], 0)
        while sim.winner is None and sim.t < 1200: sim.step(dt)
        wins += sim.winner == 0; mins += sim.t / 60; eras += sim.s[0].era; eras_e += sim.s[1].era
    return wins/games, mins/games, eras/games, eras_e/games

MATRIX = [(1,0),(2,0),(3,0),(5,0),(6,0),(8,0),(8,3),(10,3),(10,6),(15,6),(15,10),(20,10),(25,14)]
if __name__ == "__main__":
    games = int(sys.argv[1]) if len(sys.argv) > 1 else 12
    print("stage meta | win% | avg min | p.era | e.era")
    for st, me in MATRIX:
        w, m, e, ee = run(st, me, games)
        print(f"{st:5d} {me:4d} | {w*100:4.0f} | {m:7.1f} | {e:5.1f} | {ee:5.1f}", flush=True)
