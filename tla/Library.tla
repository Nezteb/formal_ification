---------------------------- MODULE Library ----------------------------
\* One book with `Copies` copies and a first-come-first-served hold queue.
\* Set `Buggy` to TRUE to plant the bug. Every return then puts the copy back
\* on the shelf, even when someone is waiting.

EXTENDS Naturals, Sequences, FiniteSets

CONSTANTS Patrons, Copies, Buggy

VARIABLES shelf, loans, holds
vars == <<shelf, loans, holds>>

Waiting == {holds[i] : i \in DOMAIN holds}

Init ==
  /\ shelf = Copies
  /\ loans = {}
  /\ holds = <<>>

\* You can only borrow from the shelf when nobody is waiting.
Borrow(p) ==
  /\ shelf > 0
  /\ holds = <<>>
  /\ p \notin loans
  /\ shelf' = shelf - 1
  /\ loans' = loans \union {p}
  /\ UNCHANGED holds

\* You can only place a hold when no copy is on the shelf.
Hold(p) ==
  /\ shelf = 0
  /\ p \notin loans
  /\ p \notin Waiting
  /\ holds' = Append(holds, p)
  /\ UNCHANGED <<shelf, loans>>

\* If anyone is waiting, a returned copy goes straight to the head of the queue.
Return(p) ==
  /\ p \in loans
  /\ IF holds = <<>> \/ Buggy
       THEN /\ shelf' = shelf + 1
            /\ loans' = loans \ {p}
            /\ UNCHANGED holds
       ELSE /\ loans' = (loans \ {p}) \union {Head(holds)}
            /\ holds' = Tail(holds)
            /\ UNCHANGED shelf

Next == \E p \in Patrons : Borrow(p) \/ Hold(p) \/ Return(p)

\* Weak fairness on Return means anyone with a book eventually returns it.
Spec == Init /\ [][Next]_vars /\ \A p \in Patrons : WF_vars(Return(p))

-----------------------------------------------------------------------------

TypeOK ==
  /\ shelf \in 0..Copies
  /\ loans \subseteq Patrons
  /\ holds \in Seq(Patrons)

\* Copies on the shelf plus copies on loan equal copies owned.
Conservation == shelf + Cardinality(loans) = Copies

\* Nobody waits while a copy sits on the shelf.
NoShelfAndQueue == shelf > 0 => holds = <<>>

\* Everyone who places a hold eventually gets the book.
HoldsGetServed == \A p \in Patrons : (p \in Waiting) ~> (p \in loans)

=============================================================================
