#!/usr/bin/env bash
# The suite of render-readme.py: the readme a stranger reads is read from the definition, and a
# hand edit on either side is reported. Cases:
#   1. the shipped readme agrees with board.json, in README.md and in project-readme.md
#   2. a fact or an actor changed in the definition is caught, and the column is named
#   3. a hand edit inside a rendered block is caught, and the column is named
#   4. the two freezes stay apart, and neither is a column
#   5. the views state the grouping the API cannot set, with the manual step for each view
#   6. apply.py sends no view grouping, so the readme's claim is what the code does
#   7. this suite runs in the repository's own CI
set -euo pipefail
root=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cp -R "$root" "$tmp/repo"
work="$tmp/repo"

fail() { printf '%s\n' "$1" >&2; exit 1; }

# 1. the shipped readme is what the definition renders
python3 "$work/render-readme.py" --check

# 2. the definition is the source: a changed actor reaches the readme and is caught where it differs
python3 - "$work/board.json" <<'PY'
import json
import sys
path = sys.argv[1]
board = json.load(open(path))
for status in board["statuses"]:
    if status["name"] == "Doing":
        status["actor"] = "Nobody"
json.dump(board, open(path, "w"), indent=2)
PY
if python3 "$work/render-readme.py" --check >"$tmp/word.out" 2>&1; then
  fail 'a changed actor in the definition was not caught'
fi
grep -F 'Doing' "$tmp/word.out" >/dev/null || fail 'the difference does not name the column'

# 3. the readme is the checked side: a hand edit in a rendered block is caught
cp "$root/board.json" "$work/board.json"
python3 - "$work/README.md" <<'PY'
import sys
path = sys.argv[1]
lines = open(path).read().splitlines()
for number, line in enumerate(lines):
    if line.startswith("| Doing |"):
        lines[number] = line.rsplit("|", 2)[0] + "| The owner |"
open(path, "w").write("\n".join(lines) + "\n")
PY
if python3 "$work/render-readme.py" --check >"$tmp/hand.out" 2>&1; then
  fail 'a hand edit in the readme was not caught'
fi
grep -F 'Doing' "$tmp/hand.out" >/dev/null || fail 'the hand edit is not named by its column'
cp "$root/README.md" "$work/README.md"

# 4. both freezes are named, apart, from the definition, and no column is a marker
python3 - "$work" <<'PY'
import json
import pathlib
import sys
root = pathlib.Path(sys.argv[1])
board = json.loads((root / "board.json").read_text())
readme = (root / "README.md").read_text()
project = (root / "project-readme.md").read_text()
freeze = {entry["name"]: entry["fact"] for entry in board["freeze"]}
assert len(freeze) == 2, freeze
for name, fact in freeze.items():
    assert name in readme, name
    assert fact in readme, fact
    assert fact in project, fact
assert "the owner is the next actor" in readme and "another item gates this one" in readme, "the two reasons are collapsed"
assert "not a column" in readme, "the readme does not say a marker is not a column"
assert "not a column" in project, "the project readme does not say a marker is not a column"
for status in board["statuses"]:
    assert status["name"] not in freeze, status["name"]
PY

# 5. the grouping the API cannot set, and the manual step for each view, come from the definition
python3 - "$work" <<'PY'
import json
import pathlib
import sys
root = pathlib.Path(sys.argv[1])
board = json.loads((root / "board.json").read_text())
readme = (root / "README.md").read_text()
assert "cannot set a view's grouping" in readme, "the readme does not name the setting the API cannot set"
for view in board["views"]:
    assert view["name"] in readme, view["name"]
    if view.get("groupBy"):
        assert "Group by" in readme and view["groupBy"] in readme, view["name"]
        assert "open the view" in readme, "the manual step for %s is missing" % view["name"]
PY

# 6. the readme's claim is what the applier sends: the view write carries a name, a layout and no grouping
python3 - "$work/apply.py" <<'PY'
import re
import sys
source = open(sys.argv[1]).read()
block = source.split("CreateProjectV2ViewInput", 1)[1]
block = block.split("}", 1)[0] + source.split("createProjectV2View", 1)[1][:400]
keys = set(re.findall(r'"(projectId|name|layout|groupBy|groupedBy|filter)"\s*:', block))
assert keys == {"projectId", "name", "layout"}, keys
PY

# 7. the suite runs in the repository's own CI
grep -F 'bash ./test-readme.sh' "$root/.github/workflows/ci.yml" >/dev/null || fail 'CI does not run this suite'
