---------------------------- MODULE Library ----------------------------
\* One book with `Copies` copies. Patrons borrow it and return it.
\* `elixir/lib/library.ex` implements each action below, with the same names.

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
  `EXTENDS`     imports modules. `Integers` has numbers, including negative ones. `FiniteSets` has `Cardinality`, which is a set's size.
  `CONSTANTS`   values the `.cfg` file picks, like `Patrons` and `Copies`.
  `VARIABLES`   the state, which changes from step to step.
  `==`          defines a name, like `Init` or `Look(p)`.
  `UNCHANGED`   these variables keep their value this step.
  `Init`        describes the starting state. `Look`, `Take`, `Borrow`, `Return` are actions; these are our names, not keywords.

The `.cfg` files set `CONSTANTS`, pick the `SPECIFICATION` to run, and list
each `INVARIANT`, a property TLC checks in every state it reaches.

This file has no proofs. TLC checks it by trying every state. TLAPS, a
separate tool, can check proofs written in TLA+ with `THEOREM` and `PROOF`,
the way Lean does. `PROOF OMITTED` skips a proof step, like Lean's `sorry`.
***************************************************************************)

EXTENDS Integers, FiniteSets

CONSTANTS Patrons, Copies

\* `shelf` and `loans` are the Agent's state in the Elixir code.
\* `looked` is the patrons whose buggy borrow has done `Look` but not `Take`.
\* In Elixir, that's a process between its `Agent.get` and its `Agent.update`.
\* Because `looked` is a set, each patron has at most one borrow in progress.
\* The code doesn't enforce this. To allow more, make `looked` a count per
\* patron. It starts at `[p \in Patrons |-> 0]`, `Look` adds 1, and `Take`
\* subtracts 1. The fixed `Borrow` needs no change, because it is one step.
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

\* A spec allows every behavior that starts in Init where each step is a
\* Next step or leaves vars unchanged. TLC explores all the states these reach.
BuggySpec == Init /\ [][BuggyNext]_vars
FixedSpec == Init /\ [][FixedNext]_vars

-----------------------------------------------------------------------------

\* We never lend out more copies than we own.
NeverOverLent == Cardinality(loans) <= Copies

\* Copies on the shelf plus copies on loan equal copies owned. It sounds like
\* the right property, and it's true in both designs. TLC passes it on the
\* buggy design, because the shelf goes to -1 and the count still adds up.
Conservation == shelf + Cardinality(loans) = Copies

(***************************************************************************
How to extend this spec with TLAPS. TLC checks `NeverOverLent` for the sizes
in `Library.cfg`. A TLAPS proof would cover every size, like
`never_over_lent` in `lean/Library.lean`. The outline follows the Lean proof:

  EXTENDS TLAPS, FiniteSetTheorems
  ASSUME Copies \in Nat /\ IsFiniteSet(Patrons)

  TypeOK == shelf \in Int /\ loans \subseteq Patrons
  Inv    == TypeOK /\ Conservation /\ shelf >= 0   \* Lean's `fixed_inv`

  THEOREM FixedSpec => []NeverOverLent
    <1>1. Init => Inv
    <1>2. Inv /\ [FixedNext]_vars => Inv'
    <1>3. Inv => NeverOverLent
    <1>4. QED BY <1>1, <1>2, <1>3, PTL DEF FixedSpec

tlapm proves the `QED` step from the three steps above it, but steps `<1>1`
to `<1>3` still need proofs of their own. TLAPS needs two things Lean didn't.
`TypeOK` says `shelf` is a number, because TLA+ has no types. The `ASSUME`
line says `Copies` is a number and `Patrons` is finite. For `BuggySpec`,
step `<1>2` is false, because `Take` can push the shelf below 0.

By default, tlapm reports "All obligations proved" even when a step has no
proof or says `PROOF OMITTED`. Run `tla/tlapm/bin/tlapm --strict` to count
those steps as failures.
***************************************************************************)

=============================================================================
