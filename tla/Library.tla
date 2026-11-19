---------------------------- MODULE Library ----------------------------
\* One book with `Copies` copies. Patrons borrow it and return it.

EXTENDS Naturals, FiniteSets

CONSTANTS Patrons, Copies

\* `shelf` is how many copies are on the shelf.
\* `state[p]` is "idle", "saw_copy", or "has_book".
VARIABLES shelf, state

Init ==
  /\ shelf = Copies
  /\ state = [p \in Patrons |-> "idle"]

\* The buggy borrow takes two steps. First the patron sees a copy on the shelf.
Look(p) ==
  /\ state[p] = "idle"
  /\ shelf > 0
  /\ state' = [state EXCEPT ![p] = "saw_copy"]
  /\ UNCHANGED shelf

\* Later the patron takes it, without checking the shelf again.
Take(p) ==
  /\ state[p] = "saw_copy"
  /\ shelf' = shelf - 1
  /\ state' = [state EXCEPT ![p] = "has_book"]

\* The fixed borrow checks the shelf and takes the copy in one step.
Borrow(p) ==
  /\ state[p] = "idle"
  /\ shelf > 0
  /\ shelf' = shelf - 1
  /\ state' = [state EXCEPT ![p] = "has_book"]

Return(p) ==
  /\ state[p] = "has_book"
  /\ shelf' = shelf + 1
  /\ state' = [state EXCEPT ![p] = "idle"]

BuggyNext == \E p \in Patrons : Look(p) \/ Take(p) \/ Return(p)
FixedNext == \E p \in Patrons : Borrow(p) \/ Return(p)

-----------------------------------------------------------------------------

\* We never lend out more copies than we own.
NeverOverLent == Cardinality({p \in Patrons : state[p] = "has_book"}) <= Copies

\* The shelf never holds more copies than we own. This sounds right, and TLC
\* passes it on the buggy design. It isn't the property we care about.
ShelfNeverOverflows == shelf <= Copies

=============================================================================
