"""Replace each declaration in eval.odin with the same-named one from tuner output.

usage: python3 apply_tuned.py tuned.txt eval.odin
Scalars keep their trailing comments. Fails if any tuned name isn't found exactly once.
"""
import re
import sys

DECL = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s*(::|:=)")


def parse_decls(lines):
    """Map name -> (start, end) line range, end exclusive."""
    decls = {}
    i = 0
    while i < len(lines):
        m = DECL.match(lines[i])
        if not m:
            i += 1
            continue
        end = i + 1
        if lines[i].rstrip().endswith("{"):
            while lines[end].strip() != "}":
                end += 1
            end += 1
        if m.group(1) in decls:
            sys.exit(f"{m.group(1)} declared twice")
        decls[m.group(1)] = (i, end)
        i = end
    return decls


tuned_path, eval_path = sys.argv[1], sys.argv[2]
tuned = open(tuned_path).read().splitlines()
src = open(eval_path).read().splitlines()

tuned_decls = parse_decls(tuned)
src_decls = parse_decls(src)

missing = [n for n in tuned_decls if n not in src_decls]
if missing:
    sys.exit(f"Not in {eval_path}: {missing}")

# Replace from the bottom up so earlier line numbers stay valid
for name, (ts, te) in sorted(tuned_decls.items(), key=lambda kv: -src_decls[kv[0]][0]):
    ss, se = src_decls[name]
    new = tuned[ts:te]
    if te - ts == 1 and "//" in src[ss]:
        new = [new[0] + " //" + src[ss].split("//", 1)[1]]
    src[ss:se] = new

open(eval_path, "w").write("\n".join(src) + "\n")
print(f"Replaced {len(tuned_decls)} declarations")
