**One monotone axis.** A card's column is the furthest its work reached, and it never moves back. What holds a card now is a marker, never a move: a freeze, a revert, a red check.

**The columns, each with its one actor**

| Column | The fact that sets it | Who acts next |
| --- | --- | --- |
| Backlog | Open, not in the schedule: no startable label, no live run, no freeze | Nobody |
| Todo | Startable: no blocker, no live run | An agent |
| Doing | A live run holds it | The run |
| Code Complete | Finished, a pull request names the issue, not mergeable yet | An agent |
| Merging | The pull request is green, mergeable and unheld | The merger |
| Testing | The merge landed and the end-to-end pass runs on the merge commit | The pass |
| Closed | Merged into `main` and the issue closed | Nobody |
| Abandoned | Not delivered, by decision: `wontfix`, superseded, `needs-info` expired | Nobody |

**Done means merged into `main`.** A card is never Closed over an open pull request, and never Closed on a run's local landed work.

**A freeze is not a state.** `frozen:owner` (the owner is the next actor) and `frozen:dependency` (another item gates this one) are markers over the column the work reached, and they hold dispatch.

**The columns are a view over kind and status.** Kind is Bug, Task, Spec, TestCase or PR; the groups a reader filters by are a grouping over the pair, which is the totalling and hiding the pane already does.
