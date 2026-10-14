#!/usr/bin/env python3
"""Render the readme a stranger reads from the definition, so the vocabulary is never restated by hand.

Usage:
  render-readme.py            write every block of README.md and project-readme.md from board.json
  render-readme.py --check    write nothing, print the first difference of each block and exit 1

Each block of vocabulary sits in the file between `<!-- begin: NAME -->` and `<!-- end: NAME -->`,
and this script is its only writer: the columns with the fact that sets each one and who acts next,
the rules, the markers, the fields and the views with the grouping the platform's API cannot set.
The prose around the blocks is a person's; inside them, the file says what board.json says.
"""

import argparse
import json
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
DEF = json.loads((HERE / "board.json").read_text())

# What carries each field, in a person's words. The names and the options beside it come from the definition.
CARRIES = {
    "statuses": "the axis",
    "kinds": "what the item is",
    "freeze": "the marker beside the column",
    "outcomes": "how a terminal item ended",
}
GROUPS = ("statuses", "kinds", "freeze", "outcomes")

LAYOUTS = {"TABLE_LAYOUT": "table", "BOARD_LAYOUT": "board", "ROADMAP_LAYOUT": "roadmap"}

FILES = {
    "README.md": ("columns", "rules", "markers", "fields", "views"),
    "project-readme.md": ("columns", "rules", "markers"),
}


def cell(text):
    """One table cell: a pipe in the definition would end the cell."""
    return str(text).replace("|", "\\|")


def columns_block():
    lines = ["| Column | The fact that sets it | Who acts next |", "| --- | --- | --- |"]
    for status in DEF["statuses"]:
        lines.append("| %s | %s | %s |" % tuple(cell(part) for part in (status["name"], status["fact"], status["actor"])))
    return lines


def rules_block():
    return ["- %s" % rule for rule in DEF["rules"]]


def markers_block():
    lines = ["| Marker | The fact that sets it |", "| --- | --- |"]
    for marker in DEF["freeze"]:
        lines.append("| %s | %s |" % (cell(marker["name"]), cell(marker["fact"])))
    lines += [
        "",
        "A marker is not a column: it sits beside the column the work reached and the column never moves "
        "back because of it. The two stay apart, because one names the owner as the next actor and the "
        "other names an item that gates this one.",
    ]
    return lines


def fields_block():
    names = DEF["fieldNames"]
    lines = ["| Field | Options | What carries it |", "| --- | --- | --- |"]
    for group in GROUPS:
        options = ", ".join(cell(entry["name"]) for entry in DEF[group])
        lines.append("| `%s` | %s | %s |" % (names[group], options, CARRIES[group]))
    return lines


def views_block():
    lines = ["| View | Layout | Grouping |", "| --- | --- | --- |"]
    for view in DEF["views"]:
        layout = LAYOUTS.get(view["layout"], view["layout"].lower())
        lines.append("| %s | %s | %s |" % (view["name"], layout, view.get("groupBy") or "none"))
    lines += [
        "",
        "GitHub's API cannot set a view's grouping: `createProjectV2View` takes a name and a layout and "
        "nothing else, so the applier makes the view and no grouping. A person sets each grouping once, in "
        "the interface:",
        "",
    ]
    for view in DEF["views"]:
        grouping = view.get("groupBy")
        if grouping:
            lines.append("- **%s** — open the view, then **Group by** → `%s`." % (view["name"], grouping))
        else:
            lines.append("- **%s** — nothing to set: the API makes it as it is." % view["name"])
    return lines


BLOCKS = {
    "columns": columns_block,
    "rules": rules_block,
    "markers": markers_block,
    "fields": fields_block,
    "views": views_block,
}


def rewrite(path, names, write):
    """Write (or check) one file's blocks; return one message per block that differs."""
    lines = path.read_text().splitlines()
    diffs = []
    for name in names:
        begin, end = "<!-- begin: %s -->" % name, "<!-- end: %s -->" % name
        if begin not in lines or end not in lines:
            sys.exit("%s: no `%s` / `%s` marker pair" % (path.name, begin, end))
        start, stop = lines.index(begin), lines.index(end)
        want, have = BLOCKS[name](), lines[start + 1:stop]
        if want != have:
            for number in range(max(len(want), len(have))):
                said = want[number] if number < len(want) else "(no line)"
                found = have[number] if number < len(have) else "(no line)"
                if said != found:
                    diffs.append(
                        "%s: the block %s differs from board.json: the definition says %r, the file says %r"
                        % (path.name, name, said, found)
                    )
                    break
            lines[start + 1:stop] = want
    if write:
        path.write_text("\n".join(lines) + "\n")
    return diffs


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="write nothing; report each difference and exit 1")
    args = parser.parse_args()
    diffs = []
    for file_name, names in FILES.items():
        diffs += rewrite(HERE / file_name, names, not args.check)
    if args.check:
        if diffs:
            print("\n".join(diffs), file=sys.stderr)
            return 1
        return 0
    for file_name, names in FILES.items():
        print("rendered %s: %s" % (file_name, ", ".join(names)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
