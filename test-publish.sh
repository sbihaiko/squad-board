#!/usr/bin/env bash
# The suite of publish.sh: publication is a file list and a check that removes nothing it did not
# name. Cases:
#   1. a publish into an empty destination lands every named file, byte for byte
#   2. a check on a destination that already holds them prints nothing and exits 0
#   3. a named file that differs is reported as `copy <file>`, and a publish then makes it equal
#   4. a file the list does not name -- a machine's own config -- survives a check and a publish
#   5. a named file absent from the destination is reported and then copied
#   6. a publish copies the named files and nothing else
#   7. this suite runs in the repository's own CI
set -euo pipefail
root=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail() { printf '%s\n' "$1" >&2; exit 1; }

# the names this definition publishes, read from the script that names them
published=$(python3 - "$root/publish.sh" <<'PY'
import re
import sys
match = re.search(r'^PUBLISHED="([^"]+)"', open(sys.argv[1]).read(), re.M)
sys.exit("publish.sh names no PUBLISHED file list") if not match else None
print("\n".join(match.group(1).split()))
PY
)
test -n "$published" || fail 'the published file list is empty'
for f in $published; do
  test -f "$root/$f" || fail "the list names $f, which the definition does not hold"
done

# 1. every named file lands in an empty destination
mkdir "$tmp/dest"
bash "$root/publish.sh" "$tmp/dest" >"$tmp/first.out"
for f in $published; do
  test -f "$tmp/dest/$f" || fail "the publish did not copy $f"
  cmp -s "$root/$f" "$tmp/dest/$f" || fail "the published $f differs from the definition"
done

# 2. a second check finds no difference and prints nothing
: >"$tmp/check.out"
if ! bash "$root/publish.sh" --check "$tmp/dest" >"$tmp/check.out" 2>&1; then
  fail "the check reports a difference on a destination that already holds the definition: $(cat "$tmp/check.out")"
fi
test -s "$tmp/check.out" && fail "the check printed on a destination with no difference: $(cat "$tmp/check.out")" || true

# 3. a named file that differs is reported and then copied
printf '%s\n' 'edited by hand' >>"$tmp/dest/README.md"
if bash "$root/publish.sh" --check "$tmp/dest" >"$tmp/diff.out" 2>&1; then
  fail 'the check did not report the edited file'
fi
grep -F 'copy README.md' "$tmp/diff.out" >/dev/null || fail "the check does not name the file it would copy: $(cat "$tmp/diff.out")"
bash "$root/publish.sh" "$tmp/dest" >"$tmp/second.out"
cmp -s "$root/README.md" "$tmp/dest/README.md" || fail 'the publish left the edited file in place'
bash "$root/publish.sh" --check "$tmp/dest" >/dev/null 2>&1 || fail 'the check still reports a difference after a publish'

# 4. a file the list does not name survives both a check and a publish
printf '%s\n' '{"model": "a machine own setting"}' >"$tmp/dest/local-config.json"
mkdir -p "$tmp/dest/scripts/profiles"
printf '%s\n' 'a machine own profile' >"$tmp/dest/scripts/profiles/machine.sh"
bash "$root/publish.sh" "$tmp/dest" >"$tmp/third.out"
test -f "$tmp/dest/local-config.json" || fail 'the publish removed a file it did not name'
test -f "$tmp/dest/scripts/profiles/machine.sh" || fail 'the publish removed a file it did not name'
grep -F 'a machine own setting' "$tmp/dest/local-config.json" >/dev/null || fail 'the publish changed a file it did not name'
python3 - "$tmp/dest" "$published" <<'PY'
import pathlib
import sys
dest, names = pathlib.Path(sys.argv[1]), set(sys.argv[2].split())
extra = {str(p.relative_to(dest)) for p in dest.rglob("*") if p.is_file() and ".git" not in p.parts} - names
assert "local-config.json" in extra and "scripts/profiles/machine.sh" in extra, extra
PY

# 5. a named file absent from the destination is reported and then copied
rm "$tmp/dest/board.json"
if bash "$root/publish.sh" --check "$tmp/dest" >"$tmp/missing.out" 2>&1; then
  fail 'the check did not report the missing file'
fi
grep -F 'copy board.json' "$tmp/missing.out" >/dev/null || fail 'the check does not name the missing file'
bash "$root/publish.sh" "$tmp/dest" >/dev/null
cmp -s "$root/board.json" "$tmp/dest/board.json" || fail 'the publish did not restore the missing file'

# 6. only the named files are copied
python3 - "$root" "$tmp/dest" "$published" <<'PY'
import pathlib
import sys
root, dest, names = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), set(sys.argv[3].split())
landed = {str(p.relative_to(dest)) for p in dest.rglob("*") if p.is_file()}
assert names <= landed, sorted(names - landed)
for name in landed - names:
    assert name in {"local-config.json", "scripts/profiles/machine.sh"}, name
PY
test -f "$root/publish.sh" || fail 'the script that publishes is missing'

# 7. the suite runs in the repository's own CI
grep -F 'bash ./test-publish.sh' "$root/.github/workflows/ci.yml" >/dev/null || fail 'CI does not run this suite'
