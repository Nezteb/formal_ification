> What is a common everyday situation or algorithm a non-technical person might be able to understand that would make for a good case for a TLA+ spec / Lean proof?
>
> I want some domain/scenario I can use for a 5-10 minute lightning talk on TLA+/Lean. I'd also like it to be easy to replicate in Elixir with a property-based testing library like StreamData.

---

## Pick: the library hold queue

A small town library. One popular book, two copies. Patrons can borrow, return, or place a hold. Holds go in a queue, first come first served.

This wins because everyone has stood in a queue. The interesting question, "did the person in line actually get the book?", is a *liveness* property, which is where TLA+ pulls ahead of everything else. The Lean question, "does the invariant hold for any number of copies?", is a real proof, not a toy one. The Elixir version is a struct with a `MapSet` and a `:queue`.

### The rules, in plain words

1. If a copy is on the shelf and nobody is waiting, you can borrow it.
2. If no copy is on the shelf, you can place a hold. Holds are first come, first served.
3. When you return a copy and someone is waiting, the copy goes straight to the head of the queue.
4. You can't borrow a book you already have, or hold a book you already have or already hold.

Four rules. A twelve-year-old can audit them. That is the point.

Because of rules 1-3, the person at the head of the queue never borrows a copy themselves. A return hands it to them. So "you must be at the head of the queue to borrow" doesn't need its own rule.

## What each tool gets to chew on

| | Library hold queue |
|---|---|
| **TLA+ invariants** | `Conservation`: copies on the shelf + copies on loan = copies owned. `NoShelfAndQueue`: nobody waits while a copy sits on the shelf. |
| **TLA+ liveness** | `HoldsGetServed`: everyone who places a hold eventually gets the book. This needs weak fairness on `Return`. Without it, a patron can keep the book forever, and the property fails. |
| **Lean** | Both invariants hold after *any* sequence of operations, for *any* number of copies and patrons. That is induction over `step`. |
| **Elixir** | A plain struct, plus pure functions `borrow/2`, `hold/2`, `return/2`. A StreamData property generates command lists and checks the invariants after every step. |

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

Invariants and liveness:

```tla
Conservation    == shelf + Cardinality(loans) = Copies
NoShelfAndQueue == shelf > 0 => holds = <<>>
HoldsGetServed  == \A p \in Patrons : (p \in Waiting) ~> (p \in loans)
```

The classic bug: a copy is returned while someone is waiting, but the implementation puts it back on the shelf instead of handing it over. The queue starves and nobody notices, because the numbers still balance. `Conservation` stays true. `NoShelfAndQueue` and `HoldsGetServed` both break.

## Lean sketch

Model the state as a structure, then prove that every operation preserves the invariant. This teaches induction over traces.

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

`omega` and `simp` won't get you all the way, and that is good. The `return` case needs a small argument: if someone is waiting, then (by the invariant) the shelf is empty. Only then does the arithmetic close.

Lean has no built-in notion of time, so `HoldsGetServed` stays on the TLA+ side. That gap is worth saying out loud.

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

The property test applies a generated command list to the real code and checks the invariants after every step:

```elixir
property "nobody waits while a copy is on the shelf" do
  check all commands <- list_of(command(), max_length: 30) do
    for lib <- run(commands) do
      assert lib.shelf == 0 or :queue.is_empty(lib.holds)
    end
  end
end
```

StreamData has no built-in state machine module, so you generate command lists and apply them yourself. That is simple, and it's enough here. PropCheck has a `StateM` DSL with better shrinking of command sequences, but we avoid it over licensing concerns.

## The talk, in order

1. **Rules.** Show the four rules and the two invariants. Ask the audience whether they believe the rules are right.
2. **The planted bug.** Flip `Buggy` on. Return always puts the copy back on the shelf.
3. **TLC.** It finds the bug in 6 states, with a trace you can read out loud. Both copies are on the shelf and `cy` waits forever. We never asked about `NoShelfAndQueue`. The deadlock check and `HoldsGetServed` caught it.
4. **StreamData.** "The numbers balance" still passes. "Nobody waits while a copy is on the shelf" fails and shrinks to a 4-step counterexample. Property tests catch the bug *if you write the right property*.
5. **Lean.** The fixed version's invariants hold for every size, not just 2 copies and 3 patrons.
6. **The honest caveat.** None of these proves the Elixir code matches the spec. That is what trace validation is for (see `verifying_implementations.md`).

## Left out, on purpose

A 10-minute talk can't fit everything. These are good follow-ups:

- Multiple books, and a per-patron limit (for example, at most 3 books)
- Hold cancellation and expiry. Liveness becomes "you eventually get the book, or your hold expires."
- Refinement: a timer spec that refines the basic spec
- Lean: a two-list queue (`front ++ back.reverse`) with a proof that it really is FIFO
- Concurrency: one process per book, a coordinator that can crash, `Task.async_stream` with patrons fighting over copies
- Trace validation: emit NDJSON per operation, replay it through a `TraceSpec` in TLC

## Alternates, if the library does not fit

| Scenario | TLA+ payoff | Lean payoff | Elixir fit |
|---|---|---|---|
| **Parking garage** with entry/exit barriers and capacity counter | Capacity never exceeded, no car trapped, sensor-fault tolerance | Counter bookkeeping, or a two-counter model with a proof they agree | Struct with a counter, easy |
| **Vending machine** with coins and change | Money conservation, no free snacks, refund correctness | Coin arithmetic in `Nat`, canonical change proves with `omega` | Trivial struct, `:queue` of coins |
| **Traffic light** at a four-way junction | Never two greens, fairness between directions | State machine safety proof, quite easy, good first Lean exercise | `GenServer` plus `:timer`, fun to watch |
| **Laundromat** with N machines and tokens | Machine never double-booked, tokens conserved | Token conservation | One process per machine, `Registry` to find them |
| **Cafeteria with one cashier and a limited tray rack** | Queue liveness, tray conservation, deadlock if trays run out | Tray conservation | Nice use of `:queue` and backpressure |

The vending machine is the easiest Lean on-ramp. The parking garage has the best failure story. The library has the best liveness story, which is what makes TLA+ feel different from everything else.

## Traps worth showing

- **Fairness.** Without `WF_vars(Return(p))`, `HoldsGetServed` is false: a patron can keep the book forever. Fairness assumptions are not optional.
- **Stuttering.** A spec can always "do nothing", so `~>` and `<>` properties fail unless fairness forces progress.
- **You only catch what you assert.** A property test checks the properties you wrote, and you wrote both the code and the properties. "The numbers balance" passes on the buggy code.
- **`omega` and `simp` feel like magic until they don't.** The Lean `return` case needs a helper fact before the automation can finish.

Grug says: complexity is the enemy, so keep the rules at four, keep the state to three variables, and let the tools fight over the same small thing.
