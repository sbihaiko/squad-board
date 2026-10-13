#!/usr/bin/env python3
"""Apply the squad board definition (board.json) to a GitHub Project (v2).

Usage:
  apply.py --owner <login> [--title "Squad Board"] [--project <number>] [--dry-run]

With no --project a new project is created; with --project that project is
updated. The run is idempotent: a second run changes nothing.

A status option that is dropped while cards still carry it is refused unless
--force is given, so a vocabulary change never silently empties a column.
"""

import argparse
import json
import pathlib
import subprocess
import sys

HERE = pathlib.Path(__file__).resolve().parent
DEF = json.loads((HERE / "board.json").read_text())
NAMES = DEF["fieldNames"]
GROUPS = [
    ("statuses", NAMES["statuses"]),
    ("kinds", NAMES["kinds"]),
    ("freeze", NAMES["freeze"]),
    ("outcomes", NAMES["outcomes"]),
]


def gh(args, payload=None):
    proc = subprocess.run(
        ["gh", *args],
        input=json.dumps(payload) if payload is not None else None,
        capture_output=True,
        text=True,
    )
    if proc.returncode:
        sys.exit("gh %s failed: %s" % (" ".join(args), proc.stderr.strip()))
    return json.loads(proc.stdout) if proc.stdout.strip() else None


def graphql(query, variables):
    data = gh(["api", "graphql", "--input", "-"], {"query": query, "variables": variables})
    if data.get("errors"):
        sys.exit("graphql: %s" % json.dumps(data["errors"]))
    return data["data"]


FIELDS_Q = """
query($id: ID!) {
  node(id: $id) {
    ... on ProjectV2 {
      fields(first: 60) {
        nodes {
          __typename
          ... on ProjectV2Field { id name }
          ... on ProjectV2SingleSelectField { id name options { id name } }
          ... on ProjectV2IterationField { id name }
        }
      }
    }
  }
}"""


def fields(project_id):
    return graphql(FIELDS_Q, {"id": project_id})["node"]["fields"]["nodes"]


def options_of(entries, existing):
    """The option list to write, keeping the id of an option that survives by name."""
    by_name = {o["name"]: o["id"] for o in existing}
    out = []
    for entry in entries:
        option = {"name": entry["name"], "color": entry["color"], "description": entry.get("fact", "")}
        if entry["name"] in by_name:
            option["id"] = by_name[entry["name"]]
        out.append(option)
    return out


def carried(field_name, owner, number):
    """How many items carry each option of one field, read from the item list."""
    try:
        listing = gh(
            ["project", "item-list", str(number), "--owner", owner, "--format", "json", "--limit", "2000"]
        )
    except SystemExit:
        return None
    key = field_name.lower()
    counts = {}
    for item in listing.get("items", []):
        value = item.get(key)
        if isinstance(value, dict):
            value = value.get("name")
        if value:
            counts[value] = counts.get(value, 0) + 1
    return counts


def set_field(project_id, field, entries, owner, number, force, dry):
    wanted = {e["name"] for e in entries}
    dropped = [o["name"] for o in field.get("options", []) if o["name"] not in wanted]
    if dropped:
        counts = carried(field["name"], owner, number)
        if counts is None and not force:
            sys.exit(
                "%s: cannot read the item list to check the dropped option(s) %s; pass --force to drop them"
                % (field["name"], ", ".join(dropped))
            )
        held = {name: counts.get(name, 0) for name in dropped} if counts else {}
        if counts and any(held.values()) and not force:
            sys.exit(
                "%s: %s still carry a card; move those cards first, or pass --force"
                % (field["name"], ", ".join("%s (%d)" % (n, c) for n, c in held.items() if c))
            )
    print("  %s: %d option(s)%s" % (field["name"], len(entries), " [dry-run]" if dry else ""))
    if dry:
        return
    graphql(
        """
        mutation($input: UpdateProjectV2FieldInput!) {
          updateProjectV2Field(input: $input) {
            projectV2Field { ... on ProjectV2SingleSelectField { id } }
          }
        }""",
        {"input": {"fieldId": field["id"], "singleSelectOptions": options_of(entries, field.get("options", []))}},
    )


def make_field(project_id, name, entries, dry):
    print("  + %s: %d option(s)%s" % (name, len(entries), " [dry-run]" if dry else ""))
    if dry:
        return
    graphql(
        """
        mutation($input: CreateProjectV2FieldInput!) {
          createProjectV2Field(input: $input) {
            projectV2Field { ... on ProjectV2SingleSelectField { id } }
          }
        }""",
        {
            "input": {
                "projectId": project_id,
                "dataType": "SINGLE_SELECT",
                "name": name,
                "singleSelectOptions": [
                    {"name": e["name"], "color": e["color"], "description": e.get("fact", "")} for e in entries
                ],
            }
        },
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--owner", required=True, help="the user or organization that owns the project")
    parser.add_argument("--title", default=DEF["board"]["title"])
    parser.add_argument("--project", type=int, help="an existing project number to update")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--force", action="store_true", help="drop a status option that cards still carry")
    args = parser.parse_args()

    if args.project:
        found = gh(["project", "view", str(args.project), "--owner", args.owner, "--format", "json"])
        project = {"id": found["id"], "number": found["number"], "url": found["url"]}
    else:
        print("creating the project %r for %s" % (args.title, args.owner))
        if args.dry_run:
            return
        made = gh(
            ["project", "create", "--owner", args.owner, "--title", args.title, "--format", "json"]
        )
        project = {"id": made["id"], "number": made["number"], "url": made["url"]}

    print("project %s (%s)" % (project["number"], project["url"]))
    by_name = {f["name"]: f for f in fields(project["id"])}

    for key, field_name in GROUPS:
        entries = DEF[key]
        if field_name in by_name:
            set_field(project["id"], by_name[field_name], entries, args.owner, project["number"], args.force, args.dry_run)
        else:
            make_field(project["id"], field_name, entries, args.dry_run)

    print("  description and readme")
    if not args.dry_run:
        readme = (HERE / "project-readme.md")
        gh(
            [
                "project", "edit", str(project["number"]), "--owner", args.owner,
                "--description", DEF["board"]["description"],
                "--readme", readme.read_text() if readme.exists() else "",
            ]
        )

    have = {
        v["name"]
        for v in graphql(
            'query($id: ID!) { node(id: $id) { ... on ProjectV2 { views(first: 20) { nodes { name } } } } }',
            {"id": project["id"]},
        )["node"]["views"]["nodes"]
    }
    for view in DEF["views"]:
        if view["name"] in have:
            print("  = view %r" % view["name"])
            continue
        print("  + view %r (%s)" % (view["name"], view["layout"]))
        if not args.dry_run:
            graphql(
                """
                mutation($input: CreateProjectV2ViewInput!) {
                  createProjectV2View(input: $input) { projectV2View { number } }
                }""",
                {"input": {"projectId": project["id"], "name": view["name"], "layout": view["layout"]}},
            )

    if not args.dry_run:
        print("done: %s" % project["url"])
    else:
        print("dry run: nothing written")


if __name__ == "__main__":
    main()
