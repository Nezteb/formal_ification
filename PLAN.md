(Note: this is a transcript of another LLM search engine tool I used to sketch out this lightning talk)

> What is a common everyday situation or algorithm a non-technical person might be able to understand that would make for a good case for a TLA+ spec / Lean proof?
> 
> I want some domain/scenario that I could expand upon and use as a learning exercise for students learning about TLA+/Lean. I'd also like this domain/scenario to be easily replicable with Elixir and a property-based testing library like StreamData.
> 
> I want to use this entire thing as a playground for formal specification and verification that also includes application code examples in Elixir.

---

## Pick: the library hold queue

A small town library. Three copies of a popular book. Patrons can borrow, return, or place a hold. Holds go in a queue, first come first served.

This wins because every student has stood in a queue, and because the interesting question ("did the person at the front of the line actually get the book?") is a *liveness* property, which is where TLA+ pulls ahead of everything else. The interesting Lean question ("is this queue implementation really a queue?") is a real proof, not a toy one. And the Elixir version is a GenServer with a map and a `:queue`.

### The rules, in plain words

1. A book has N copies. A patron holds at most one copy of a given book.
2. You can borrow only if a copy is free and you are at the head of that book's hold queue (or the queue is empty).
3. Returning a book hands it directly to the head of the queue if anyone is waiting.
4. Holds can be cancelled, and they expire if not claimed in time.
5. Nobody may hold more than 3 books total.

Five rules. A twelve-year-old can audit them. That is the point.

## What each tool gets to chew on

| | Library hold queue |
|---|---|
| **TLA+ invariant** | copies on loan + copies on shelf = copies owned. No patron twice in one queue. Nobody over 3 books. Head of queue is the only legal borrower. |
| **TLA+ liveness** | if you are at the head of the queue and hold a valid hold, you eventually get the book. Requires fairness, and this is where naive specs break. |
| **TLA+ refinement** | a "claim" spec (copies, queues) refined by an "expiry timer" spec that adds time. |
| **Lean** | the queue itself: two-list queue, `front ++ back.reverse`, prove it is FIFO and never loses an element. Then prove the invariant is inductive over `step`. |
| **Lean stretch** | expiry: prove that dropping an expired hold at the head never strands a copy, i.e. the copy is either reassigned or visibly available. |
| **Elixir** | one GenServer per book plus a coordinator, or one library GenServer. Command lists against a model. |
| **Elixir concurrency** | `Task.async_stream` with 10 patrons fighting over 3 copies. |

## TLA+ sketch

```tla
VARIABLES copies, shelf, loans, holds, checkedOut

Init == copies \in [Books -> Nat]
     /\ shelf = copies
     /\ loans = [b \in Books |-> <<>>]
     /\ holds = [b \in Books |-> <<>>]
     /\ checkedOut = [p \in Patrons |-> 0]

Borrow(b, p) ==
  /\ shelf[b] > 0
  /\ Len(holds[b]) = 0        \* or p is the head
  /\ checkedOut[p] < 3
  /\ shelf'   = [shelf EXCEPT ![b] = @ - 1]
  /\ loans'   = [loans EXCEPT ![b] = Append(@, p)]
  /\ checkedOut' = [checkedOut EXCEPT ![p] = @ + 1]
  /\ UNCHANGED holds

Return(b, p) ==
  /\ p \in Range(loans[b])
  /\ LET q == holds[b]
     IN IF Len(q) = 0
        THEN shelf' = [shelf EXCEPT ![b] = @ + 1]
             /\ holds' = holds
        ELSE shelf' = shelf
             /\ holds' = [holds EXCEPT ![b] = Tail(@)]
     /\ loans' = ...
```

Invariants:

```tla
Conservation == \A b \in Books :
                 shelf[b] + Len(loans[b]) = copies[b]

NoShelfAndQueue == \A b \in Books : ~(shelf[b] < copies[b] /\ Len(holds[b]) > 0)

NoDoubleHold == \A b \in Books : \A i, j \in DOMAIN holds[b] :
                 i # j => holds[b][i] # holds[b][j]

Liveness == \A b \in Books, p \in Patrons :
              (Head(holds[b]) = p /\ Fairness) ~> (p \in Range(loans[b]))
```

The `NoShelfAndQueue` invariant is the one that catches the classic bug: a copy returned while someone is waiting, but the implementation puts it back on the shelf instead of handing it over. The queue starves and nobody notices, because the numbers still balance.

## Lean sketch

Model the state as a structure, then prove the invariant is preserved by every operation. This is the exercise that teaches induction over traces.

```lean
structure Lib where
  shelf : Book → Nat
  loans : Book → List Patron
  holds : Book → List Patron
  count : Patron → Nat

def Inv (s : Lib) : Prop :=
  (∀ b, (s.loans b).Nodup) ∧
  (∀ b, (s.holds b).Nodup) ∧
  (∀ b, s.shelf b + (s.loans b).length = copies b) ∧
  (∀ p, s.count p ≤ 3)

theorem step_preserves (s : Lib) (op : Op) :
    Inv s → Inv (step s op) := by
  intro h
  cases op <;> simp [Inv, step] at * <;> omega
```

`omega` will not get you all the way, and that is good. The queue lemmas are the real content:

```lean
abbrev Q := List α × List α

def toList (q : Q) : List α := q.1 ++ q.2.reverse

theorem push_toList (q : Q) (x : α) :
    toList ⟨q.1, x :: q.2⟩ = toList q ++ [x] := by
  simp [toList, List.append_assoc]
```

Then show that `push` and `pop` on the two-list representation agree with `push` and `pop` on the abstract list, which is exactly the refinement obligation TLA+ asks about in prose. Students discover that "obviously correct" data structures need proofs.

## Elixir sketch

```elixir
defmodule Library do
  use GenServer

  def handle_call({:borrow, book, patron}, _from, s) do
    cond do
      s.shelf[book] == 0 -> {:reply, {:error, :none_available}, s}
      queue_head(s.holds[book]) != patron and s.holds[book] != :queue.new() ->
        {:reply, {:error, :not_your_turn}, s}
      s.count[patron] >= 3 -> {:reply, {:error, :too_many}, s}
      true -> {:reply, :ok, do_borrow(s, book, patron)}
    end
  end
end
```

The property test folds a command list over the real server and checks the invariants after each step:

```elixir
check all cmds <- list_of(command(), max_length: 60) do
  final = Enum.reduce(cmds, fresh_library(), &apply_cmd(&1, &2))
  assert final.shelf_and_loans_balance()
  assert final.no_duplicate_holds()
end
```

Two caveats worth teaching explicitly. StreamData has no built-in state machine module, so you generate command lists and fold them yourself [^1]. If you want precondition-driven generation with proper shrinking of command sequences, PropCheck wraps PropEr and gives you a `StateM` DSL with pre- and postconditions per command [^2] [^3]. The command-list-and-fold approach with StreamData is simpler and enough for the first two labs.

## The three labs, in order

**Lab 1, happy path.** Write the TLA+ spec, check the invariants at 3 books × 3 patrons × 2 copies. Run TLC. It passes. Then write the Elixir GenServer and the StreamData property. They should agree. Nothing surprising yet. Good.

**Lab 2, the planted bug.** Hand students a version whose `Return` puts the copy on the shelf even when the hold queue is non-empty. Sequential property tests *pass*, because the model in the test was written by the same person who wrote the bug, or because the generator rarely produces return-while-queued. TLC finds it in seven states with a counterexample trace you can read out loud. This is the single most valuable hour of the course.

**Lab 3, concurrency.** Make the Elixir version distributed: one process per book, a coordinator that can crash and restart. Now `Task.async_stream` with ten patrons and three copies finds a lost-update in milliseconds. Then point out that this only explored a handful of schedules out of thousands, and that TLC enumerated all of them at small N. Then do trace validation: emit NDJSON per operation, replay through a `TraceSpec` in TLC. That is where the previous discussion lands.

## Alternates, if the library does not fit

| Scenario | TLA+ payoff | Lean payoff | Elixir fit |
|---|---|---|---|
| **Parking garage** with entry/exit barriers and capacity counter | Capacity never exceeded, no car trapped, sensor-fault tolerance | Counter bookkeeping, or a two-counter model with a proof they agree | GenServer per barrier plus a lot counter, easy |
| **Vending machine** with coins and change | Money conservation, no free snacks, refund correctness | Coin arithmetic in `Nat`, canonical change proves with `omega` | Trivial GenServer, `:queue` of coins |
| **Traffic light** at a four-way junction | Never two greens, fairness between directions | State machine safety proof, quite easy, good first Lean exercise | `GenServer` plus `:timer`, fun to watch |
| **Laundromat** with N machines and tokens | Machine never double-booked, tokens conserved | Token conservation plus a fairness liveness proof | One process per machine, `Registry` to find them |
| **Cafeteria with one cashier and a limited tray rack** | Queue liveness, tray conservation, deadlock if trays run out | Deadlock-freedom as a theorem | Nice use of `:queue` and backpressure |

The vending machine is the easiest Lean on-ramp. The parking garage has the best failure story. The library has the best liveness story, which is the thing that makes TLA+ feel different from everything else students have seen.

## Traps to plant on purpose

- **Fairness.** Without `WF` on borrow and return, the liveness property is false and students learn why fairness assumptions are not optional. Let them hit it.
- **Stuttering.** Students will write `Next` in a way that lets the state freeze and wonder why `<>` properties fail.
- **The model and the code share a bug.** The library lab makes this vivid. A property test only checks agreement between two things you wrote, and you wrote both.
- **`omega` and `simp` feel like magic until they do not.** Have one Lean exercise where the automation fails and induction plus a helper lemma is required. The queue `pop` lemma is a good candidate.

Grug says: complexity is the enemy, so keep the rules at five, keep the state to three maps, and let the tools fight over the same small thing.
