#!/usr/bin/env python3
"""Apply the German line rules (en-de.json) to the lucid QML tree.

Each rule maps one exact source line to its exact German replacement -
byte-exact by construction, no parsing. A rule with zero matches fails
the build loudly: upstream reworded or removed that line, so the German
rendering would silently regress. Re-express the rule from the new
upstream line (additive upkeep, same policy as the patch layer it
replaced on 2026-11-01).
"""

import json
import sys
from pathlib import Path


def main():
    if len(sys.argv) != 3:
        print(f"usage: {sys.argv[0]} <tree-root> <en-de.json>", file=sys.stderr)
        return 2
    tree = Path(sys.argv[1])
    rules = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))

    misses = []
    for rel in sorted(rules):
        path = tree / rel
        if not path.is_file():
            misses.append(f"{rel}: file missing from tree")
            continue
        table = rules[rel]
        lines = path.read_text(encoding="utf-8").split("\n")
        hits = dict.fromkeys(table, 0)
        for i, line in enumerate(lines):
            if line in hits:
                lines[i] = table[line]
                hits[line] += 1
        misses += (
            f"{rel}: no match for: {rule.strip()[:110]}" for rule, n in hits.items() if n == 0
        )
        path.write_text("\n".join(lines), encoding="utf-8")

    if misses:
        print(f"translate: {len(misses)} unmatched rule(s) - re-express them:", file=sys.stderr)
        for m in misses:
            print(f"  {m}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
