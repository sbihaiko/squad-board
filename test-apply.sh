#!/usr/bin/env bash
set -euo pipefail

source_root=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cp -R "$source_root" "$tmp/repo"
root="$tmp/repo"

mkdir "$tmp/bin"
cat >"$tmp/bin/gh" <<'GH'
#!/usr/bin/env python3
import json
import os
import sys

args = sys.argv[1:]
payload = sys.stdin.read()
with open(os.environ["GH_LOG"], "a") as log:
    log.write(json.dumps({"args": args, "payload": payload}) + "\n")
fixture = json.load(open(os.environ["GH_FIXTURE"]))
if args[:2] == ["project", "view"]:
    print(json.dumps(fixture["project"]))
elif args[:2] == ["project", "item-list"]:
    print(json.dumps(fixture.get("items", {"items": []})))
elif args[:2] == ["api", "graphql"]:
    query = json.loads(payload)["query"]
    if "fields(first:" in query:
        data = {"node": {"fields": {"nodes": fixture["fields"]}}}
    elif "views(first:" in query:
        data = {"node": {"views": {"nodes": fixture["views"]}}}
    else:
        data = {}
    print(json.dumps({"data": data}))
GH
chmod +x "$tmp/bin/gh"

fixture() {
  python3 - "$root" "$tmp/fixture.json" "$@" <<'PY'
import json
import pathlib
import sys
root, target, mode = sys.argv[1:4]
board = json.load(open(pathlib.Path(root) / "board.json"))
project = {"id": "P1", "number": 1, "url": "https://example.test/1"}
if mode == "settled":
    project.update({"shortDescription": board["board"]["description"], "readme": (pathlib.Path(root) / "project-readme.md").read_text()})
fields = []
if mode in {"settled", "carried", "added"}:
    for group, field_name in (("statuses", "Status"), ("kinds", "Kind"), ("freeze", "Freeze"), ("outcomes", "Outcome")):
        options = []
        source = board[group]
        if mode == "added" and group == "statuses":
            source = source[:-1]
        for number, entry in enumerate(source, 1):
            options.append({"id": f"{group}-{number}", "name": entry["name"], "color": entry["color"], "description": entry.get("fact", "")})
        fields.append({"id": f"field-{group}", "name": field_name, "options": options})
if mode == "carried":
    fields[0]["options"].append({"id": "old", "name": "Retired", "color": "GRAY", "description": ""})
views = [{"name": view["name"]} for view in board["views"]] if mode in {"settled", "carried", "added"} else []
items = {"items": [{"status": {"name": "Retired"}}]} if mode == "carried" else {"items": []}
json.dump({"project": project, "fields": fields, "views": views, "items": items}, open(target, "w"))
PY
}

run() {
  : >"$tmp/log"
  PATH="$tmp/bin:$PATH" GH_LOG="$tmp/log" GH_FIXTURE="$tmp/fixture.json" python3 "$root/apply.py" --owner example --project 1 "$@"
}

writes() {
  python3 - "$tmp/log" <<'PY'
import json
import sys
for call in map(json.loads, open(sys.argv[1])):
    args = call["args"]
    payload = call["payload"]
    if args[:2] == ["project", "edit"] or "mutation(" in payload:
        print(json.dumps(call))
PY
}

expect_no_writes() {
  local found
  found=$(writes)
  if test -n "$found"; then
    printf '%s\n%s\n' 'expected no write request' "$found" >&2
    return 1
  fi
}

fixture empty
run >"$tmp/first.out"
python3 - "$root" "$tmp/log" <<'PY'
import json
import sys
board = json.load(open(sys.argv[1] + "/board.json"))
calls = list(map(json.loads, open(sys.argv[2])))
payloads = [call["payload"] for call in calls]
for group in ("statuses", "kinds", "freeze", "outcomes"):
    for entry in board[group]:
        assert entry["name"] in "\n".join(payloads), entry["name"]
for view in board["views"]:
    assert view["name"] in "\n".join(payloads), view["name"]
assert sum("createProjectV2Field" in payload for payload in payloads) == 4
assert sum("createProjectV2View" in payload for payload in payloads) == 2
assert all("singleSelectOptions" in payload for payload in payloads if "createProjectV2Field" in payload)
PY

fixture settled
run >"$tmp/second.out"
expect_no_writes

after=$(python3 - "$tmp/fixture.json" <<'PY'
import json
import sys
print(json.dumps(json.load(open(sys.argv[1]))["fields"], sort_keys=True))
PY
)
test -n "$after"

fixture empty
run --dry-run >"$tmp/dry.out"
expect_no_writes
grep -F 'dry run: nothing written' "$tmp/dry.out"

python3 - "$root/board.json" <<'PY'
import json
import sys
path = sys.argv[1]
board = json.load(open(path))
board["statuses"] = [entry for entry in board["statuses"] if entry["name"] != "Retired"]
json.dump(board, open(path, "w"), indent=2)
PY
fixture carried
if run >"$tmp/refusal.out" 2>&1; then
  printf '%s\n' 'expected the carried option to be refused' >&2
  exit 1
fi
grep -F 'Retired (1)' "$tmp/refusal.out"
run --force Retired >"$tmp/forced.out"
grep -F 'updateProjectV2Field' "$tmp/log" >/dev/null

python3 - "$root/board.json" <<'PY'
import json
import sys
path = sys.argv[1]
board = json.load(open(path))
board["statuses"].append({"name": "Later", "color": "GRAY", "fact": "A later state"})
json.dump(board, open(path, "w"), indent=2)
PY
fixture added
run >"$tmp/added.out"
python3 - "$tmp/log" <<'PY'
import json
import sys
calls = list(map(json.loads, open(sys.argv[1])))
updates = [json.loads(call["payload"]) for call in calls if "updateProjectV2Field" in call["payload"]]
assert len(updates) == 1
options = updates[0]["variables"]["input"]["singleSelectOptions"]
assert options[-1]["name"] == "Later"
assert all(option["id"].startswith("statuses-") for option in options[:-1])
assert "id" not in options[-1]
PY

test -f "$source_root/.github/workflows/ci.yml"
grep -F 'bash ./test-apply.sh' "$source_root/.github/workflows/ci.yml"

for forbidden in "$(git -C "$source_root" config --get remote.origin.url | cut -d/ -f4)" "$(basename "$(git -C "$source_root" config --get remote.origin.url)" .git)" "$(git -C "$source_root" config --get user.name)"; do
  [ -n "$forbidden" ] || continue   # an unset value (no user.name on a CI runner) would match every line
  if git -C "$source_root" grep -n -F "$forbidden" -- . ':!test-apply.sh'; then
    printf '%s\n' 'repository or person text found' >&2
    exit 1
  fi
done

if git -C "$source_root" grep -n -E 'gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]+' -- . ':!test-apply.sh'; then
  printf '%s\n' 'credential-shaped text found' >&2
  exit 1
fi
