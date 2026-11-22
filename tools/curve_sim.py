"""Rough progression simulator for Fling for Fossils.

Models a player who trains for TRAIN_SECONDS, flings, walks out, digs, walks
home and buys the next rock/shovel as soon as they can afford it. Prints the
median minute each upgrade and zone is reached over 30 runs.

Keep the numbers below in sync with src/shared/Config (Shop, Zones, Eggs,
Dinos, Balance). Run:  python3 tools/curve_sim.py

Target shape: Fern Valley ~3 min (burst), Tar Pits ~10-15 min (slow climb),
Gold Rock breakthrough ~25-30 min, then Amber Cliffs.
"""
import math
import random
import statistics

TAPS_PER_SECOND = 3
TRAIN_SECONDS = 20
PEDESTALS = 6
STRENGTH_SCALE = 3  # Balance.StrengthScale
BASE_DISTANCE = 30  # Balance.BaseDistance
ROCKS = [(0, 2), (150, 5), (1500, 10), (55000, 60), (400000, 180), (4000000, 600)]  # (price, strength/rep)
SHOVELS = [(0, 1, 1), (300, 1.15, 1.1), (6000, 1.3, 1.25), (120000, 1.8, 1.6), (600000, 2.2, 2.2), (6000000, 2.7, 3)]
ZONES = [(120, 1), (300, 1.6), (550, 2.6), (850, 4)]  # (end distance, luck)
# (weight, luck power, incubate seconds, average income)
RARITIES = [(60, 0, 30, 1.1), (25, 0.5, 60, 3.3), (10, 1, 120, 8.5), (4, 1.25, 300, 27),
            (0.9, 1.5, 600, 95), (0.09, 1.75, 1200, 360), (0.01, 2, 1800, 1500)]
# Approximate quest/gift coin rewards: (minute, coins)
# Rebirth (Config/Rebirth): price grows x3, bonuses per rebirth
REBIRTH_PRICE, REBIRTH_GROWTH = 500000, 3
REBIRTH_STR, REBIRTH_COINS, REBIRTH_LUCK = 0.5, 0.25, 0.1
BONUSES = [(2, 175), (4, 250), (6, 550), (10, 1000), (14, 600), (15, 1000), (18, 2500), (22, 5000)]


def run(seed, minutes=45):
    rng = random.Random(seed)
    t = 0.0
    strength = coins = 0.0
    rock = shovel = 0
    dinos, incubating, log, reached, bonuses = [], [], [], set(), list(BONUSES)
    first = True
    rebirths = 0

    def advance(seconds):
        nonlocal t, coins
        for _ in range(int(seconds)):
            coins += sum(sorted(dinos, reverse=True)[:PEDESTALS]) * (1 + rebirths * REBIRTH_COINS)
            for egg in incubating[:]:
                egg[1] -= 1
                if egg[1] <= 0:
                    incubating.remove(egg)
                    dinos.append(RARITIES[egg[0]][3])
            t += 1

    while t < minutes * 60:
        strength += TRAIN_SECONDS * TAPS_PER_SECOND * ROCKS[rock][1] * (1 + rebirths * REBIRTH_STR)
        advance(TRAIN_SECONDS + 6)
        distance = min((BASE_DISTANCE + STRENGTH_SCALE * math.sqrt(strength)) * SHOVELS[shovel][1], ZONES[-1][0] - 6)
        zone = next(i for i, z in enumerate(ZONES) if distance < z[0])
        if zone not in reached:
            reached.add(zone)
            log.append((t / 60, f"zone {zone + 1}"))
        luck = ZONES[zone][1] * SHOVELS[shovel][2] * (1 + rebirths * REBIRTH_LUCK)
        if first:
            rarity, hatch, first = 2, 8, False
        else:
            weights = [w * luck ** p for w, p, _, _ in RARITIES]
            rarity = rng.choices(range(len(RARITIES)), weights)[0]
            hatch = RARITIES[rarity][2]
        advance(2.2 + distance / 24 + 1 + (distance + 90) / 18)
        while len(incubating) >= 3:
            advance(1)
        incubating.append([rarity, hatch])
        while bonuses and bonuses[0][0] <= t / 60:
            coins += bonuses.pop(0)[1]
        # Rebirth as soon as Amber Cliffs is reached and it's affordable.
        price = REBIRTH_PRICE * REBIRTH_GROWTH ** rebirths
        if 3 in reached and coins >= price:
            rebirths += 1
            coins = strength = 0
            rock = shovel = 0
            log.append((t / 60, f"rebirth {rebirths}"))
        bought = True
        while bought:
            bought = False
            if rock + 1 < len(ROCKS) and coins >= ROCKS[rock + 1][0]:
                coins -= ROCKS[rock + 1][0]
                rock += 1
                bought = True
                log.append((t / 60, f"rock {rock + 1}"))
            if shovel + 1 < len(SHOVELS) and coins >= SHOVELS[shovel + 1][0]:
                coins -= SHOVELS[shovel + 1][0]
                shovel += 1
                bought = True
                log.append((t / 60, f"shovel {shovel + 1}"))
    return log


if __name__ == "__main__":
    rows = {}
    for seed in range(30):
        for minute, event in run(seed, minutes=int(__import__("sys").argv[1]) if len(__import__("sys").argv) > 1 else 45):
            rows.setdefault(event, []).append(minute)
    for event, minutes in sorted(rows.items(), key=lambda kv: statistics.median(kv[1])):
        print(f"{event:10s} median {statistics.median(minutes):5.1f} min  ({len(minutes)}/30 runs)")
