# Board definition

One GitHub Project definition for a repository worked by agents, applied by one command.

A card's column is **the furthest its work reached, and it never moves back**. What holds a card
now is a marker, never a move. So a block, a revert or a red check is signalled beside the column
and the flow of the columns stays drawable.

The definition stands alone: it needs `gh` and nothing else.

## The columns

| Column | The fact that sets it | Who acts next |
| --- | --- | --- |
| Backlog | Open, not in the schedule: no startable label, no live run, no freeze | Nobody |
| Todo | Startable: no blocker, no live run | An agent |
| Doing | A live run holds it | The run |
| Code Complete | Finished and a pull request names the issue; not mergeable yet | An agent |
| Merging | The pull request is green, mergeable and unheld | The merger |
| Testing | The merge landed and the end-to-end pass runs on the merge commit | The pass |
| Closed | Merged into `main` and the issue closed | Nobody |
| Abandoned | Not delivered, by decision: `wontfix`, superseded, or `needs-info` expired | Nobody |

Four rules hold the axis together:

- **A card never moves backwards.** A recomputed column lower than the card's column is never
  written. The card is the watermark; no second ledger is kept.
- **Closed means merged into `main`.** Never over an open pull request, and never on a run's own
  local landed work.
- **A freeze is not a state.** `frozen:owner` (the owner is the next actor) and
  `frozen:dependency` (another item gates this one) are markers over the column the work reached,
  and they hold dispatch. The two are never collapsed: one of them says the owner is the bottleneck.
- **The columns are a view over kind and status**, never a second axis. A reader groups the items
  by the pair and gets Open PRs, Open Bugs, Open Tasks, Open Specs, Open Test Cases and the closed
  equivalent of each — the totalling and hiding the pane already does.

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

| Field | Options | What carries it |
| --- | --- | --- |
| `Status` | the eight columns, in order | the axis |
| `Kind` | Bug, Task, Spec, TestCase, PR | what the item is |
| `Freeze` | Owner, Dependency | the marker beside the column |
| `Outcome` | Merged, Abandoned, Failed, Reverted | how a terminal item ended |

`Kind` is this board's own word, not GitHub's Issue Type: Issue Type is an organization feature,
and a user-owned repository answers `null` to it. Carry the kind with a label family or with this
field, and read it through one seam.

A pull request and an issue share one number space in GitHub, so an item key is the pair
**(kind, number)** — a bare number stops saying what it names once the view mixes the two.

## The views

`All items` is a table. `Board` is a board grouped by `Status`.

GitHub's API cannot set a view's grouping, so the group-by-kind view is made in the UI: take
`All items`, group by `Kind`, then by `Status`, and it reads as the Open PRs, Open Bugs, Open
Tasks, Open Specs and Open Test Cases groups the rules above describe.

## Files

| File | What it is |
| --- | --- |
| `board.json` | the definition: the columns, the kinds, the markers, the outcomes. One table. |
| `apply.py` | applies it, by `gh`. Host-free Python, no dependency. |
| `project-readme.md` | what the created project carries as its own readme. |

## Licence

MIT. See [LICENSE](LICENSE).
