# Talk: the last copy

The talk runs 5-10 minutes for engineers of mixed experience. Its point is that an LLM can write TLA+, Lean, and property tests, but they only help if a human can read the property, read the trace, and say whether the check answers the right question.

## The scenario

A library has 1 copy of a book and 2 patrons, Ana and Ben. The buggy borrow looks at the shelf, then takes the copy in a separate step. This check-then-act race also shows up in ticket sales, inventory, bank balances, and rate limiters.

## Slide map

Times add up to about 9 minutes. Slides 7 and 8 are the easiest to cut.

| # | Slide | Time | On screen |
|---|---|---|---|
| 1 | The bug in plain words | 0:45 | Four lines of story, no code |
| 2 | The Elixir code | 0:45 | `borrow_buggy/1` next to `borrow/1` |
| 3 | The example test | 0:45 | The 50-patron test and its pass streak |
| 4 | The property test | 1:00 | The StreamData property, passing on the buggy code |
| 5 | The property, owned by a human | 0:45 | `NeverOverLent`, one line, with the English sentence above it |
| 6 | The trace | 1:15 | TLC's 5-step trace |
| 7 | A green check that means nothing | 1:00 | `ShelfNeverOverflows` passing on the buggy design |
| 8 | Lean, and the same trap | 1:30 | `never_over_lent`, then `always_over_lends` |
| 9 | Take-home | 1:00 | Four bullets |

### 1. The bug in plain words

Ana sees the book on the shelf. Ben sees the book on the shelf. Ana takes it. Ben takes it. The library lent out 2 copies of a book it owns 1 of.

Ask the room whether their code has a `get` followed by an `update`.

### 2. The Elixir code

Show `borrow_buggy/1` next to `borrow/1` from `elixir/lib/library.ex`. The buggy one calls `Agent.get`, then `Agent.update`. The fixed one does both in `Agent.get_and_update`. Both look reasonable in review.

### 3. The example test

50 concurrent patrons, 1 copy. Run it with `--repeat-until-failure`. Put your own pass streak on the slide. A green test suite doesn't mean the bug is absent.

### 4. The property test

```elixir
property "never lends out more copies than it owns" do
  check all copies <- integer(1..5),
            ops <- list_of(member_of([:borrow, :give_back])) do
    ...
  end
end
```

StreamData tries 100 random sequences of borrows and returns, for 1 to 5 copies, and shrinks any failure to the shortest one. On the buggy code it passes, because it runs one operation at a time and never puts two borrows side by side. The property is right. The test can't reach the bad timing.

The same sentence, "never lends out more copies than it owns", now appears in the test. It carries through every slide after this one.

### 5. The property, owned by a human

> We never lend out more copies than we own.

```tla
NeverOverLent == Cardinality({p \in Patrons : state[p] = "has_book"}) <= Copies
```

An LLM can draft the `Look` and `Take` steps. A person who knows the domain has to write or approve this line, because it is the contract. It is the same sentence as the property test's name.

### 6. The trace

TLC checks every ordering of the steps for 1 copy and 2 patrons, and fails in 5 steps:

```text
1. shelf = 1   ana idle       ben idle
2. shelf = 1   ana saw_copy   ben idle
3. shelf = 1   ana saw_copy   ben saw_copy
4. shelf = 0   ana has_book   ben saw_copy
5. shelf = -1  ana has_book   ben has_book
```

Read it out loud. It is the same story as slide 1. This is the part to paste into the PR or show to a product manager. If nobody reads the trace, running TLC did nothing.

### 7. A green check that means nothing

Run the same buggy design against `ShelfNeverOverflows`, which says the shelf never holds more copies than we own. It sounds right. TLC passes it, and the bug is still there. A passing check is only as good as the property, and only a human can tell whether the property is the right one.

### 8. Lean, and the same trap

TLC checked 1 copy and 2 patrons. Lean proves the fixed borrow never over-lends for any number of copies:

```lean
theorem never_over_lent (copies : Nat) (ops : List Op) :
    ops.foldl (step copies) 0 ≤ copies
```

Then show `always_over_lends`, which claims the opposite. Lean accepts it too, because it assumes `copies < 0`, which can never be true for a natural number. Lean checks that the proof is valid. It doesn't check that the theorem says what you meant.

### 9. Take-home

- Write the property in one sentence in the domain's own words before anyone writes a test, spec, or proof.
- Use the same sentence everywhere. The test name, the TLA+ invariant, and the Lean theorem should all say it.
- Read the counterexample trace out loud. It is the deliverable.
- Treat a passing check with suspicion until a human has confirmed it checks the right property in a way that can reach the bug.

## Left out on purpose

These are good follow-ups, but they don't fit in 10 minutes.

- Liveness and fairness, for example "everyone on the waitlist eventually gets the book"
- Hold queues, multiple books, and per-patron limits
- Stateful property testing with interleaved commands, which StreamData doesn't support
- Trace validation, where the Elixir code writes one log line per step and TLC checks the log against the spec. `references/verifying_implementations.md` covers it.
- Refinement, and proving that the Elixir code matches the spec
