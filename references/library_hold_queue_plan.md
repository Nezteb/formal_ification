> What is a common everyday situation or algorithm a non-technical person might be able to understand that would make for a good case for a TLA+ spec / Lean proof?
>
> I want some domain/scenario I can use for a 5-10 minute lightning talk on TLA+/Lean. I'd also like it to be easy to replicate in Elixir with a property-based testing library like StreamData.

---

## Pick: the library hold queue

A small town library has one popular book with two copies. Patrons can borrow a copy, return it, or place a hold. Holds go in a queue, first come first served.

Everyone has stood in a queue, so the audience needs no setup. The interesting question is whether the person in line ever gets the book. That is a liveness property. TLA+ has operators for "eventually" and checks them automatically. Tests can't check it, and Lean has no built-in support for it. The Lean question is whether the invariant holds for any number of copies, which takes a real induction proof. The Elixir version is a struct with a `MapSet` and a `:queue`.

### The rules, in plain words

1. If a copy is on the shelf and nobody is waiting, you can borrow it.
2. If no copy is on the shelf, you can place a hold. Holds are first come, first served.
3. When you return a copy and someone is waiting, the copy goes straight to the head of the queue.
4. You can't borrow a book you already have, or hold a book you already have or already hold.

The rules are short enough that anyone in the audience can check them by reading.

Rules 1-3 mean the person at the head of the queue never borrows from the shelf. A return hands the copy to them. So "you must be at the head of the queue to borrow" doesn't need its own rule.

## What each tool checks

| | Library hold queue |
|---|---|
| TLA+ invariants | `Conservation` says copies on the shelf plus copies on loan equal copies owned. `NoShelfAndQueue` says nobody waits while a copy sits on the shelf. |
| TLA+ liveness | `HoldsGetServed` says everyone who places a hold eventually gets the book. It needs weak fairness on `Return`. Without fairness, a patron can keep the book forever and the property fails. |
| Lean | Both invariants hold after any sequence of operations, for any number of copies and patrons. The proof is induction over `step`. |
| Elixir | A plain struct with pure functions `borrow/2`, `hold/2`, and `return/2`. A StreamData property generates command lists and checks the invariants after every step. |

## TLA+ sketch

```tla
CONSTANTS Patrons, Copies, Buggy
VARIABLES shelf, loans, holds

Borrow(p) ==
  /\ shelf > 0
  /\ holds = <<>>
  /\ p \notin loans
  /\ shelf' = shelf - 1
  /\ loans' = loans \union {p}
  /\ UNCHANGED holds

Return(p) ==
  /\ p \in loans
  /\ IF holds = <<>> \/ Buggy
       THEN /\ shelf' = shelf + 1
            /\ loans' = loans \ {p}
            /\ UNCHANGED holds
       ELSE /\ loans' = (loans \ {p}) \union {Head(holds)}
            /\ holds' = Tail(holds)
            /\ UNCHANGED shelf
```

These are the invariants and the liveness property. `Waiting` is the set of patrons in `holds`.

```tla
Conservation    == shelf + Cardinality(loans) = Copies
NoShelfAndQueue == shelf > 0 => holds = <<>>
HoldsGetServed  == \A p \in Patrons : (p \in Waiting) ~> (p \in loans)
```

The planted bug is a common one. Someone returns a copy while a patron is waiting, and the code puts the copy back on the shelf instead of handing it over. The patron waits forever, and the counts still add up. `Conservation` stays true, while `NoShelfAndQueue` and `HoldsGetServed` both fail.

## Lean sketch

The state is a structure. The proof shows that every operation preserves the invariant, and then uses induction over the list of operations.

```lean
structure Lib where
  shelf : Nat
  loans : List Patron
  holds : List Patron

def Inv (copies : Nat) (s : Lib) : Prop :=
  s.shelf + s.loans.length = copies ∧ (s.shelf > 0 → s.holds = [])

theorem step_preserves (copies : Nat) (s : Lib) (op : Op) :
    Inv copies s → Inv copies (step s op)

theorem reachable_inv (copies : Nat) (ops : List Op) :
    Inv copies (ops.foldl step ⟨copies, [], []⟩)
```

`omega` and `simp` can't finish the `return` case alone. That case first needs one fact from the invariant. If someone is waiting, the shelf is empty. After that, `omega` closes the arithmetic. The case is a useful example of automation needing help.

Lean has no built-in notion of time, so `HoldsGetServed` is only checked in TLA+. The talk should say so.

## Elixir sketch

```elixir
def return(lib, patron) do
  if patron in lib.loans do
    loans = MapSet.delete(lib.loans, patron)

    case :queue.out(lib.holds) do
      {{:value, next}, rest} when not lib.buggy ->
        {:ok, %{lib | loans: MapSet.put(loans, next), holds: rest}}

      _ ->
        {:ok, %{lib | shelf: lib.shelf + 1, loans: loans}}
    end
  else
    {:error, :not_borrowed}
  end
end
```

The property test runs a generated command list against the real code and checks the invariants after every step.

```elixir
property "nobody waits while a copy is on the shelf" do
  check all commands <- list_of(command(), max_length: 30) do
    for lib <- run(commands) do
      assert lib.shelf == 0 or :queue.is_empty(lib.holds)
    end
  end
end
```

StreamData has no state machine module, so the test generates command lists and applies them itself. That approach is short and works for this demo. PropCheck has a `StateM` DSL that shrinks command sequences better, but we don't use it because of licensing concerns.

## The talk, in order

1. Show the four rules and the two invariants. Ask the audience whether the rules look right.
2. Turn on the planted bug. Every return now puts the copy back on the shelf.
3. Run TLC. It finds the bug in 6 states and prints a trace you can read out loud. Both copies are on the shelf and `cy` waits forever. Nobody wrote `NoShelfAndQueue` to find this. The deadlock check and `HoldsGetServed` caught it.
4. Run StreamData. "The numbers balance" still passes. "Nobody waits while a copy is on the shelf" fails and shrinks to a 4-step counterexample. Property tests catch the bug only if someone wrote the right property.
5. Show the Lean proof. The fixed version's invariants hold for every size, not just 2 copies and 3 patrons.
6. State the limit. None of these tools proves that the Elixir code matches the spec. Trace validation is the usual way to check that, as covered in `verifying_implementations.md`.

## Left out on purpose

These ideas don't fit in 10 minutes but would make good follow-ups.

- Multiple books, and a per-patron limit such as at most 3 books
- Hold cancellation and expiry. Liveness would become "you eventually get the book, or your hold expires."
- A refinement step, where a spec with timers refines the basic spec
- A Lean two-list queue, `front ++ back.reverse`, with a proof that it is first in, first out
- Concurrency, with one process per book, a coordinator that can crash, and `Task.async_stream` running patrons against each other
- Trace validation, where the code writes one NDJSON line per operation and TLC replays the log through a `TraceSpec`

## Alternates, if the library does not fit

| Scenario | TLA+ checks | Lean proves | Elixir version |
|---|---|---|---|
| Parking garage with entry and exit barriers and a capacity counter | Capacity is never exceeded, no car is trapped, and sensor faults are tolerated | The counter bookkeeping, or that two counters agree | A struct with a counter |
| Vending machine with coins and change | Money is conserved, no snack is free, and refunds are correct | Coin arithmetic in `Nat`. `omega` proves canonical change. | A struct with a `:queue` of coins |
| Traffic light at a four-way junction | Two directions are never green at once, and each direction gets a turn | Safety of the state machine. This is a good first Lean exercise. | A `GenServer` with `:timer` |
| Laundromat with N machines and tokens | No machine is double-booked, and tokens are conserved | Token conservation | One process per machine, found through `Registry` |
| Cafeteria with one cashier and a limited tray rack | The queue moves, trays are conserved, and running out of trays deadlocks | Tray conservation | A `:queue` with backpressure |

The vending machine is the easiest place to start with Lean. The parking garage has the most dramatic failure. The library is the best fit for liveness, and liveness is what TLA+ adds over tests and proofs.

## Traps worth showing

- **Fairness.** Without `WF_vars(Return(p))`, `HoldsGetServed` fails, because a patron can keep the book forever.
- **Stuttering.** A TLA+ spec always allows a step that changes nothing. So `~>` and `<>` properties fail unless a fairness condition forces progress.
- **You only catch what you assert.** A property test checks only the properties you wrote. You also wrote the code, so you may share the bug's blind spot. "The numbers balance" passes on the buggy code.
- **Automation has limits.** `omega` and `simp` can't finish the Lean `return` case without a helper fact.

Keep the rules at four and the state at three variables. Every tool checks the same small model.
