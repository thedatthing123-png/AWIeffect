import json
import sys

# Prints the crashing thread of an .ips crash report (JSON header line + JSON body).
raw = open(sys.argv[1], encoding="utf-8", errors="replace").read()
body = raw.split(chr(10), 1)[1] if chr(10) in raw else raw
try:
    d = json.loads(body)
except Exception:
    print(raw[:6000])
    sys.exit()
print("exception", d.get("exception"), d.get("termination", {}).get("indicator"))
print("asi", d.get("asi"))
imgs = d.get("usedImages", [])
for th in d.get("threads", []):
    if th.get("triggered"):
        for fr in th.get("frames", [])[:40]:
            im = imgs[fr.get("imageIndex", 0)] if imgs else {}
            print(im.get("name", "?"), fr.get("symbol", "?"), fr.get("symbolLocation", ""), fr.get("sourceFile", ""), fr.get("sourceLine", ""))
