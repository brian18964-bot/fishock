#!/usr/bin/env python3
"""Each level's weather, from scripts/campaign.gd: its plan (fixed steps, then a mode or its own
odds), the odds of each weather at every change (GameState.weather_odds, mirrored here), about how
many changes its day has, and so the chance of seeing each at least once in a run.

    python3 tools/verify/weather_odds.py > weather.tsv

Keep the weights and modes in step with scripts/game_state.gd (WEATHER_*_WEIGHT, weather_odds).
"""
import json
import re
import sys

W = dict(FOG=0.2, STORM=0.2, FISH_RUN=0.2, DRIZZLE=0.12, SANDSTORM=0.14, SEA_FOG=0.12)
NAMES = dict(FOG="霧", DENSE_FOG="濃霧", STORM="暴雨/暴風雪", FISH_RUN="魚群", DRIZZLE="小雨", SANDSTORM="沙塵暴", SEA_FOG="海霧")
WEATHER_MEAN = 57.5  # (WEATHER_MIN_DURATION + WEATHER_MAX_DURATION) / 2


def odds(mode, theme):
    if isinstance(mode, dict):
        return dict(mode)
    o = dict(FOG=W["FOG"], STORM=W["STORM"], FISH_RUN=W["FISH_RUN"], DRIZZLE=W["DRIZZLE"])
    if mode == "mild":
        o["STORM"] = 0.0
    elif mode == "stormy":
        o = dict(FOG=0.12, STORM=0.45, FISH_RUN=0.13, DRIZZLE=0.1)
    elif mode == "foggy":
        o = dict(FOG=0.3, DENSE_FOG=0.18, STORM=0.08, FISH_RUN=0.12, DRIZZLE=0.1)
    if theme == "desert":
        o["FOG"] = o.get("FOG", 0) * 0.4
        o["DRIZZLE"] = o.get("DRIZZLE", 0) * 0.3
        o["SANDSTORM"] = W["SANDSTORM"] * (1.6 if mode == "stormy" else (0.0 if mode == "mild" else 1.0))
    elif theme.startswith("coast"):
        o["FOG"] = o.get("FOG", 0) * 0.5
        o["SEA_FOG"] = W["SEA_FOG"] * (1.8 if mode == "foggy" else 1.0)
    if theme.startswith("snow"):
        o.pop("DRIZZLE", None)
    return o


def value_at(text, i):
    """The JSON-ish value starting at text[i]: a string, or a bracketed list / dict."""
    if text[i] == '"':
        j = text.index('"', i + 1)
        return json.loads(text[i:j + 1])
    depth = 0
    for j in range(i, len(text)):
        if text[j] in "[{":
            depth += 1
        elif text[j] in "]}":
            depth -= 1
            if depth == 0:
                return json.loads(text[i:j + 1])
    raise ValueError("unbalanced")


def main():
    src = open("scripts/campaign.gd", encoding="utf-8").read()
    print("id\tname\tplan\todds_per_change\tchanges\tat_least_once")
    for m in re.finditer(r'\{"id": "(\d-\d)", "chapter": \d, "name": "([^"]+)".*?"rules": (\{.*?\}),\n', src, re.S):
        lid, name, rules = m.groups()
        wm = re.search(r'"weather": ', rules)
        val = value_at(rules, wm.end()) if wm else "random"
        theme = re.search(r'"theme": "([^"]*)"', rules).group(1)
        day = float(re.search(r'"day": ([0-9.]+)', rules).group(1))
        night_fails = '"night_fails": true' in rules
        dur = day * (1.35 if night_fails else 1.4)
        fixed, mode = [], "random"
        if isinstance(val, list):
            for step in val:
                if isinstance(step, list):
                    fixed.append(step)
                else:
                    mode = step
        else:
            mode = val
        if mode == "clear" and not fixed:
            print(f"{lid}\t{name}\tclear\t全程晴\t0\t-")
            continue
        o = odds(mode, theme)
        used = sum(float(s[1]) for s in fixed)
        n = max(0.0, (dur - used - (0 if fixed else WEATHER_MEAN)) / WEATHER_MEAN) if dur > 0 else 4.0
        seen = {k: 1 - (1 - p) ** n for k, p in o.items() if p > 0}
        for s in fixed:
            seen[s[0]] = 1.0
        plan = " → ".join(f"{NAMES.get(s[0], '晴')} {int(s[1])}s" for s in fixed)
        plan = (plan + " → " if plan else "") + (mode if isinstance(mode, str) else "自訂機率")
        per = "、".join(f"{NAMES.get(k, k)}{p * 100:.0f}%" for k, p in o.items() if p > 0)
        once = "、".join(f"{NAMES.get(k, k)}{p * 100:.0f}%" for k, p in sorted(seen.items(), key=lambda kv: -kv[1]) if k != "CLEAR")
        print(f"{lid}\t{name}\t{plan}\t{per}\t{n:.1f}\t{once}")


if __name__ == "__main__":
    sys.exit(main())
