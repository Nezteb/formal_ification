---------------------------- MODULE Library ----------------------------
\* One book with `Copies` copies. Patrons borrow it and return it.
\* `elixir/lib/library.ex` implements each step below, with the same names.

(***************************************************************************
Symbols. TLA+ is written in ASCII. Each line shows the ASCII, the name of
the math symbol it stands for in quotes, and what it means.

  `/\`                 "wedge", and. A list of `/\` lines means all of them are true.
  `\/`                 "vee", or.
  `=`                  equals. It compares, it doesn't assign.
  `<=`  `>`            less than or equal to, greater than.
  `x'`                 "x prime", the value of `x` after the step.
  `\in`                "element of", is in the set.
  `\notin`             "not an element of", is not in the set.
  `\union`             "cup", set union. `loans \union {p}` adds `p`.
  `\`                  set difference. `looked \ {p}` removes `p`.
  `{}`  `{p}`          the empty set, and the set holding just `p`.
  `<<a, b>>`           "angle brackets", a tuple.
  `\E p \in S : ...`   "there exists", some `p` in `S` makes `...` true.
  `[][N]_vars`         "box", always. Every step is an `N` step, or leaves `vars` unchanged.
  `\*`                 a line comment.
  `(* ... *)`          a block comment, like this one.

Keywords.

  `MODULE`      names the file. `----` lines are separators, and `====` ends it.
  `EXTENDS`     imports modules. `Naturals` has numbers, `FiniteSets` has `Cardinality`, which is a set's size.
  `CONSTANTS`   values the `.cfg` file picks, like `Patrons` and `Copies`.
  `VARIABLES`   the state, which changes from step to step.
  `==`          defines a name, like `Init` or `Look(p)`.
  `UNCHANGED`   these variables keep their value this step.
  `Init`        the starting state. `Look`, `Take`, `Borrow`, `Return` are steps; these are our names, not keywords.

The `.cfg` files set `CONSTANTS`, pick the `SPECIFICATION` to run, and list
each `INVARIANT`, a property TLC checks in every state it reaches.
***************************************************************************)

EXTENDS Naturals, FiniteSets

CONSTANTS Patrons, Copies

\* `shelf` and `loans` are the Agent's state in the Elixir code.
\* `looked` is the patrons whose buggy borrow has done `Look` but not `Take`.
\* In Elixir, that's a process between its `Agent.get` and its `Agent.update`.
VARIABLES shelf, loans, looked
vars == <<shelf, loans, looked>>

Init ==
  /\ shelf = Copies
  /\ loans = {}
  /\ looked = {}

\* The buggy borrow's first step. The patron sees a copy on the shelf.
Look(p) ==
  /\ shelf > 0
  /\ p \notin loans
  /\ looked' = looked \union {p}
  /\ UNCHANGED <<shelf, loans>>

\* The buggy borrow's second step. The patron takes the copy, without
\* checking the shelf again.
Take(p) ==
  /\ p \in looked
  /\ shelf' = shelf - 1
  /\ loans' = loans \union {p}
  /\ looked' = looked \ {p}

\* The fixed borrow checks the shelf and takes the copy in one step.
Borrow(p) ==
  /\ shelf > 0
  /\ p \notin loans
  /\ shelf' = shelf - 1
  /\ loans' = loans \union {p}
  /\ UNCHANGED looked

Return(p) ==
  /\ p \in loans
  /\ shelf' = shelf + 1
  /\ loans' = loans \ {p}
  /\ UNCHANGED looked

BuggyNext == \E p \in Patrons : Look(p) \/ Take(p) \/ Return(p)
FixedNext == \E p \in Patrons : Borrow(p) \/ Return(p)

\* A spec is every behavior that starts in Init and takes Next steps.
\* TLC explores all the states these can reach.
BuggySpec == Init /\ [][BuggyNext]_vars
FixedSpec == Init /\ [][FixedNext]_vars

-----------------------------------------------------------------------------

\* We never lend out more copies than we own.
NeverOverLent == Cardinality(loans) <= Copies

\* Copies on the shelf plus copies on loan equal copies owned. It sounds like
\* the right property, and it's true in both designs. TLC passes it on the
\* buggy design, because the shelf goes to -1 and the count still adds up.
Conservation == shelf + Cardinality(loans) = Copies

=============================================================================
