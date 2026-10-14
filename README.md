# Board definition

One GitHub Project definition for a repository worked by agents, applied by one command.

A card's column is **the furthest its work reached, and it never moves back**. What holds a card
now is a marker, never a move. So a block, a revert or a red check is signalled beside the column
and the flow of the columns stays drawable.

The definition stands alone: it needs `gh` and nothing else. Everything below that names the
vocabulary is rendered from `board.json` by `render-readme.py`, and the suite checks this file
against the definition, so the two cannot drift apart in silence.

## The columns

<!-- begin: columns -->
| Column | The fact that sets it | Who acts next |
| --- | --- | --- |
| Backlog | Open, not in the schedule: no startable label, no live run, no freeze | Nobody |
| Todo | Startable: no blocker, no live run | An agent |
| Doing | A live run holds it | The run |
| Code Complete | Finished and a pull request names the issue; not mergeable yet | An agent |
| Merging | The pull request is green, mergeable and unheld | The merger |
| Testing | The merge landed and the end-to-end pass runs on the merge commit | The pass |
| Closed | Merged into main and the issue closed | Nobody |
| Abandoned | Not delivered, by decision: wontfix, superseded, or needs-info expired | Nobody |
<!-- end: columns -->

These rules hold the axis together:

<!-- begin: rules -->
- A card's column is the furthest its work reached, and it never moves back. What holds a card now is a marker, never a move.
- Done means merged into main. A card is never Closed over an open pull request, and never Closed on a run's local landed work.
- A freeze is not a state. A frozen card keeps its column.
- The columns are a view over kind and status, not a second axis.
<!-- end: rules -->

## What a marker is not

<!-- begin: markers -->
| Marker | The fact that sets it |
| --- | --- |
| Owner | frozen:owner - the owner is the next actor |
| Dependency | frozen:dependency - another item gates this one |

A marker is not a column: it sits beside the column the work reached and the column never moves back because of it. The two stay apart, because one names the owner as the next actor and the other names an item that gates this one.
<!-- end: markers -->

The markers are carried as labels, `frozen:owner` and `frozen:dependency`: a card carrying one is
held where it is, and its column keeps the value the work reached.

## Apply it

You need `gh`, authenticated, with the `project` scope:

```sh
gh auth refresh -s project
```

Create a project and put the definition in it:

```sh
./apply.py --owner <your-login>
```

Update a project you already have:

```sh
./apply.py --owner <your-login> --project <number>
```

See what a run would change, and change nothing:

```sh
./apply.py --owner <your-login> --project <number> --dry-run
```

The run is idempotent: a second run changes nothing, and the option ids stay the same, so no card
loses its value.

A status option that would be dropped while cards still carry it is **refused**, naming the counts.
Pass `--force <option-name>` only after the cards have moved. This is what keeps a vocabulary change from
silently emptying a column.

## The fields

<!-- begin: fields -->
| Field | Options | What carries it |
| --- | --- | --- |
| `Status` | Backlog, Todo, Doing, Code Complete, Merging, Testing, Closed, Abandoned | the axis |
| `Kind` | Bug, Task, Spec, TestCase, PR | what the item is |
| `Freeze` | Owner, Dependency | the marker beside the column |
| `Outcome` | Merged, Abandoned, Failed, Reverted | how a terminal item ended |
<!-- end: fields -->

`Kind` is this board's own word, not GitHub's Issue Type: Issue Type is an organization feature,
and a user-owned repository answers `null` to it. Carry the kind with a label family or with this
field, and read it through one seam.

A pull request and an issue share one number space in GitHub, so an item key is the pair
**(kind, number)** — a bare number stops saying what it names once the view mixes the two.

## The views

<!-- begin: views -->
| View | Layout | Grouping |
| --- | --- | --- |
| All items | table | none |
| Board | board | Status |

GitHub's API cannot set a view's grouping: `createProjectV2View` takes a name and a layout and nothing else, so the applier makes the view and no grouping. A person sets each grouping once, in the interface:

- **All items** — nothing to set: the API makes it as it is.
- **Board** — open the view, then **Group by** → `Status`.
<!-- end: views -->

The kind grouping is a reader's own: group `All items` by `Kind` and then by `Status`, and it reads
as the Open PRs, Open Bugs, Open Tasks, Open Specs and Open Test Cases groups the rules describe.

## Publish it

`publish.sh [--check] <destination>` copies the files this definition ships into a destination —
another checkout, or a copy a repository pins. Publication is a file list: the names in the script
are the names copied, and a file the destination already holds is never removed, so a machine's own
settings, a profile or a local cache survive a publish. `--check` changes nothing, prints one
`copy <file>` line per difference and exits 1; with no difference it prints nothing and exits 0.

```sh
./publish.sh --check ../a-copy-of-this-definition
./publish.sh ../a-copy-of-this-definition
```

## Files

| File | What it is |
| --- | --- |
| `board.json` | the definition: the columns, the kinds, the markers, the outcomes. One table. |
| `apply.py` | applies it, by `gh`. Host-free Python, no dependency. |
| `render-readme.py` | writes the vocabulary of this file and of `project-readme.md` from `board.json` |
| `project-readme.md` | what the created project carries as its own readme |
| `publish.sh` | copies the shipped files to a destination, as a named file list |
| `test-apply.sh` | the suite of the applier |
| `test-readme.sh` | the suite of the readme: it says what the definition says |
| `test-publish.sh` | the suite of the publish: it removes nothing it did not name |

## Licence

MIT. See [LICENSE](LICENSE).
