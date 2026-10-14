**One monotone axis.** A card's column is the furthest its work reached, and it never moves back. What holds a card now is a marker, never a move: a freeze, a revert, a red check.

**The columns, each with the fact that sets it and who acts next**

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

**The rules that hold the axis together**

<!-- begin: rules -->
- A card's column is the furthest its work reached, and it never moves back. What holds a card now is a marker, never a move.
- Done means merged into main. A card is never Closed over an open pull request, and never Closed on a run's local landed work.
- A freeze is not a state. A frozen card keeps its column.
- The columns are a view over kind and status, not a second axis.
<!-- end: rules -->

**A marker is not a column**

<!-- begin: markers -->
| Marker | The fact that sets it |
| --- | --- |
| Owner | frozen:owner - the owner is the next actor |
| Dependency | frozen:dependency - another item gates this one |

A marker is not a column: it sits beside the column the work reached and the column never moves back because of it. The two stay apart, because one names the owner as the next actor and the other names an item that gates this one.
<!-- end: markers -->
