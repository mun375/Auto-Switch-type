#!/usr/bin/env python3
"""Compare SmartSwitchKit's SyllableTable (parsed from the Swift source) with
the syllable inventory attested in McBopomofo's dictionary data.

Usage: python3 scripts/calibrate_syllables.py
Expects vendor/McBopomofo to be checked out.
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SWIFT = ROOT / "Sources/SmartSwitchKit/SyllableTable.swift"
BASE = ROOT / "vendor/McBopomofo/Source/Data/BPMFBase.txt"
MAPPINGS = ROOT / "vendor/McBopomofo/Source/Data/BPMFMappings.txt"

TONES = "ˊˇˋ˙"
INITIALS = set("ㄅㄆㄇㄈㄉㄊㄋㄌㄍㄎㄏㄐㄑㄒㄓㄔㄕㄖㄗㄘㄙ")
MEDIALS = set("ㄧㄨㄩ")
FINALS = set("ㄚㄛㄜㄝㄞㄟㄠㄡㄢㄣㄤㄥㄦ")
VALID_SYMS = INITIALS | MEDIALS | FINALS

# Bare-initial dictionary entries (the Bopomofo symbols themselves) are
# deliberately not part of the classifier's syllable inventory.
BARE_INITIAL_EXCEPTION = {f"{i}|" for i in INITIALS} - {f"{i}|" for i in "ㄓㄔㄕㄖㄗㄘㄙ"}


def collect(path, cols):
    sylls = set()
    with open(path) as f:
        for line in f:
            parts = line.rstrip("\n").split(" ")
            for c in cols(parts):
                s = "".join(ch for ch in c if ch not in TONES)
                if s and all(ch in VALID_SYMS for ch in s):
                    sylls.add(s)
    return sylls


def decompose(s):
    if s[0] in INITIALS:
        return s[0], s[1:]
    return "", s


def parse_swift_table(src):
    rimes = dict(re.findall(r'"([a-z]+)":\s*"([ㄅ-ㄩ]+)"', src))
    chart = {}
    for initial, names in re.findall(r'"([ㄅ-ㄩ]?)":\s*"([-a-z ]+)"', src):
        chart[initial] = names.split()
    ours = set()
    for initial, names in chart.items():
        for name in names:
            ours.add(f"{initial}|" if name == "-" else f"{initial}|{rimes[name]}")
    return ours


mcb = collect(BASE, lambda p: [p[1]] if len(p) > 1 else []) | collect(
    MAPPINGS, lambda p: p[1:]
)
mcb_keys = {f"{i}|{r}" for (i, r) in map(decompose, mcb)}
ours = parse_swift_table(SWIFT.read_text())

missing = sorted(mcb_keys - ours - BARE_INITIAL_EXCEPTION)
extra = sorted(ours - mcb_keys)

print(f"McBopomofo attested syllables: {len(mcb_keys)}")
print(f"  (of which bare-initial symbol entries, excluded by design: "
      f"{len(mcb_keys & BARE_INITIAL_EXCEPTION)})")
print(f"SmartSwitchKit table: {len(ours)}")
print(f"\nMISSING from our table ({len(missing)}) — real syllables we'd reject:")
for k in missing:
    print("  ", k.replace("|", " + "))
print(f"\nEXTRA in our table ({len(extra)}) — we accept but not attested:")
for k in extra:
    print("  ", k.replace("|", " + "))
print("\nOK" if not missing and not extra else "\nMISMATCH")
