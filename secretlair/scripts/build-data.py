#!/usr/bin/env python3
"""Build data.json (all Secret Lair cards, slimmed) from Scryfall's daily bulk data.

Scryfall asks apps to use bulk files instead of hammering the API
(https://scryfall.com/docs/api/rate-limits). This makes 1 API request (the bulk-data
index, limit 10/s) and 1 download from data.scryfall.io (no rate limit).
Scryfall regenerates bulk files daily, so run this at most once a day.

Usage: python3 scripts/build-data.py
"""
import gzip, json, os, sys, urllib.request
from datetime import datetime, timezone

HEADERS = {"User-Agent": "DeathriteRamenSLDDashboard/1.0 (build script)", "Accept": "application/json"}
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data.json")

def get(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS))

def slim(c):
    face = c["card_faces"][0] if "card_faces" in c and "image_uris" not in c else c
    img = face.get("image_uris") or {}
    return {
        "id": c["id"], "n": c["name"], "d": c["released_at"], "cn": c["collector_number"],
        "u": c["scryfall_uri"].split("?")[0],
        "i": face.get("illustration_id") or c.get("illustration_id") or c["id"],
        "t": c.get("type_line") or " // ".join(f.get("type_line", "") for f in c.get("card_faces", [])),
        "s": img.get("small"), "m": img.get("normal"),
    }

def main():
    index = json.load(get("https://api.scryfall.com/bulk-data"))
    entry = next(b for b in index["data"] if b["type"] == "default_cards")
    url = entry["jsonl_download_uri"]
    print(f"Downloading {url} ({entry['compressed_size'] / 1e6:.0f} MB, updated {entry['updated_at']})", file=sys.stderr)
    seen, cards = set(), []
    with gzip.GzipFile(fileobj=get(url)) as f:
        for line in f:
            if b'"set":"sld"' not in line:  # cheap prefilter before parsing JSON
                continue
            c = json.loads(line)
            if c.get("set") == "sld" and c["id"] not in seen:
                seen.add(c["id"])
                cards.append(slim(c))
    cards.sort(key=lambda c: (c["d"], c["cn"]))
    with open(OUT, "w") as out:
        json.dump({"generated": datetime.now(timezone.utc).isoformat(), "source_updated_at": entry["updated_at"], "cards": cards},
                  out, separators=(",", ":"), ensure_ascii=False)
    print(f"Wrote {len(cards)} Secret Lair cards to data.json", file=sys.stderr)

if __name__ == "__main__":
    main()
