#!/usr/bin/env python3
"""Point the shop's search/social tags at your real website address.

Usage (from the site folder):
    python3 tools/set-site-url.py https://YOUR-NAME.github.io/hygies

Rewrites the old address in index.html (canonical link, social preview,
structured data), sitemap.xml and robots.txt. The shop itself and the e-mails
it sends detect their own address automatically. Safe to run again."""
import sys, pathlib

if len(sys.argv) != 2 or not sys.argv[1].startswith("http"):
    sys.exit(__doc__)
new = sys.argv[1].rstrip("/")
root = pathlib.Path(__file__).resolve().parent.parent
marker = root / "tools" / ".current-url"
old = marker.read_text().strip() if marker.exists() else "https://hygies-81814.web.app"
count = 0
for name in ("index.html", "sitemap.xml", "robots.txt"):
    p = root / name
    t = p.read_text(encoding="utf-8")
    n = t.replace(old, new)
    if n != t:
        p.write_text(n, encoding="utf-8"); count += 1
marker.write_text(new)
print(f"Updated {count} files: {old} -> {new}")
