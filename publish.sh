#!/usr/bin/env bash
# usage: publish.sh [--check] <destination>   Copies the files this definition ships into a destination.
#
# Publication is a FILE LIST, never a mirror. The names below are the names copied, and this step
# removes nothing at all: a file the destination already holds -- a machine's own settings, a
# profile, a local cache -- is not a name this list carries, so no run touches it. A name this list
# retires stops being copied and its file stays where it is.
#
# --check changes nothing, prints one `copy <file>` line per difference and exits 1; with no
# difference it prints nothing and exits 0. A publish prints one line per file copied and a count.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
check=""; dest=""
for a in "$@"; do case "$a" in --check) check=1;; *) dest=$a;; esac; done
[ -n "$dest" ] || { echo "publish: no destination; usage: publish.sh [--check] <destination>" >&2; exit 2; }

PUBLISHED="LICENSE README.md board.json apply.py project-readme.md render-readme.py publish.sh test-apply.sh test-readme.sh test-publish.sh .github/workflows/ci.yml"

rc=0; copied=0
for f in $PUBLISHED; do
  [ -f "$here/$f" ] || { echo "publish: the definition holds no $f" >&2; exit 2; }
  if [ -f "$dest/$f" ] && cmp -s "$here/$f" "$dest/$f"; then continue; fi
  if [ -n "$check" ]; then echo "copy $f"; rc=1; continue; fi
  mkdir -p "$dest/$(dirname "$f")"
  cp -p "$here/$f" "$dest/$f"
  echo "publish: copied $f"
  copied=$((copied + 1))
done
[ -n "$check" ] && exit $rc
echo "publish: $copied file(s) copied to $dest, nothing removed"
