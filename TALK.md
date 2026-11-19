# Talk: the last copy

The talk is for engineers of mixed experience. An LLM can write TLA+, Lean, and property tests. They only help if a human reads the property, reads the trace, and checks that the spec matches the real code.

## The scenario

A library has 1 copy of a book and 2 patrons, Socrates and Beelzebub. The buggy borrow looks at the shelf, then takes the copy in a separate step. The same check-then-act race shows up in ticket sales, inventory, bank balances, and rate limiters.

The spec, the proof, and the code match step for step:

| TLA+ (`tla/Library.tla`) | Lean (`lean/Library.lean`) | Elixir (`elixir/lib/library.ex`) |
|---|---|---|
| `shelf`, `loans` | `shelf`, `loans` | The Agent's `%{shelf:, loans:}` |
| `looked` | `looked` | A process between its `Agent.get` and its `Agent.update` |
| `Look(p)` | `Look p` | `look/2`, an `Agent.get` |
| `Take(p)` | `Take p` | `take/2`, an `Agent.update` |
| `Borrow(p)` | `Borrow p` | `borrow/2`, one `Agent.get_and_update` |
| `Return(p)` | `Return p` | `return/2` |
| `NeverOverLent` | `never_over_lent` | The property test's name |

## Slide map

Slide 6 is the easiest to cut.

| # | Slide | On screen |
|---|---|---|
| 1 | The bug in plain words | Four lines of story, no code |
| 2 | The Elixir code | `borrow_buggy/2` next to `borrow/2` |
| 3 | The tests | The property test, then a green and a red run of the 2-patron test |
| 4 | The property, owned by a human | `NeverOverLent`, with the English sentence above it |
| 5 | The trace | TLC's 5-step trace |
| 6 | A green check that means nothing | `Conservation` passing on the buggy design, in TLC and Lean |
| 7 | Lean | Theorem statements only |
| 8 | Does the spec match the code? | The mapping table above |

A backup slide after slide 8, "What TLA+ and Lean can and can't do", is for questions.

### 1. The bug in plain words

Socrates sees the book on the shelf. Beelzebub sees the book on the shelf. Socrates takes it. Beelzebub takes it. The library lent out 2 copies of a book it owns 1 of.

Ask the room whether their code has a `get` followed by an `update`.

### 2. The Elixir code

Show `borrow_buggy/2` next to `borrow/2`. The buggy one calls `look/2`, an `Agent.get`, then `take/2`, an `Agent.update`. The fixed one does both in one `Agent.get_and_update`. Both pass code review.

### 3. The tests

```elixir
property "never lends out more copies than it owns" do
  check all copies <- integer(1..5),
            steps <- list_of(tuple({member_of([@borrow, :return]), integer(1..10)})) do
    ...
  end
end
```

StreamData tries 100 random sequences of borrows and returns by 10 patrons, for 1 to 5 copies. On the buggy code it passes, because it runs one step at a time and never puts two borrows side by side. The property is right, but the test can't reach the bad timing.

The 2-patron test runs the buggy borrow for Socrates and Beelzebub at the same time, with 1 copy. That's exactly the size TLC checks. Show two runs of `BUGGY=1 mix test`, with the same code and the same command. One passes and one fails. On the presenter's machine, 5 of 8 runs failed and 3 passed. Whether the bug ships depends on how the scheduler happened to order two processes during that CI run.

Use these two captured runs on the slide, because you can't choose which one you get on stage. Running it live is optional, and either result makes the point.

Green on one run:

```text
> BUGGY=1 mix test
Running ExUnit with seed: 70303, max_cases: 28

..
Finished in 0.03 seconds (0.03s async, 0.00s sync)

Result: 2 passed (1 property, 1 test)
```

Red on the next:

```text
> BUGGY=1 mix test
Running ExUnit with seed: 845148, max_cases: 28

  1) test 2 patrons at once never get more than 1 copy (LibraryTest)
     test/library_test.exs:23
     Assertion with <= failed
     code:  assert MapSet.size(Library.loans(library)) <= 1
     left:  2
     right: 1
     stacktrace:
       test/library_test.exs:30: (test)

.
Finished in 0.05 seconds (0.05s async, 0.00s sync)

Result: 1/2 passed (1/1 property, 0/1 test)
Failed: 1 test
```

In both runs the property test passes, so the same output shows both points from this slide.

The sentence "never lends out more copies than it owns" appears again on every slide after this one.

### 4. The property, owned by a human

> We never lend out more copies than we own.

```tla
NeverOverLent == Cardinality(loans) <= Copies
```

An LLM can draft the `Look` and `Take` steps. A person who knows the domain has to write or approve this line, because every check after it tests against it.

### 5. The trace

TLC tries every ordering of the steps for the same 1 copy and 2 patrons. It fails every time, in 5 steps:

```text
1. shelf = 1   loans = {}                     looked = {}
2. shelf = 1   loans = {}                     looked = {socrates}
3. shelf = 1   loans = {}                     looked = {socrates, beelzebub}
4. shelf = 0   loans = {socrates}             looked = {beelzebub}
5. shelf = -1  loans = {socrates, beelzebub}  looked = {}
```

Read it out loud. It is the same story as slide 1. Paste it into the PR so reviewers can read it too.

### 6. A green check that means nothing

`Conservation` says copies on the shelf plus copies on loan equal copies owned. It sounds like the right property, and an LLM asked for "an invariant for this library" may well write it. TLC passes it on the buggy design, and Lean proves it for the buggy design at every size. In step 5 of the trace, the shelf is at -1 and 2 copies are out, which still adds up to 1.

A passing check is only as good as its property. Only a human who knows the domain can say whether it is the right one.

### 7. Lean

TLC tries every state for 1 copy and 2 patrons. Lean proves a statement for every number of copies and patrons:

```lean
theorem never_over_lent (h : Reachable copies FixedNext s) :
    NeverOverLent copies s

theorem buggy_conservation (h : Reachable copies BuggyNext s) :
    Conservation copies s
```

The first is the guarantee we want. The second is slide 6's trap, proved at every size. Each proof is one line, `induction h <;> grind [...]`, where `grind` is Lean's built-in automation. Lean checks the proof, so a human only has to read the statement.

### 8. Does the spec match the code?

Show the mapping table. Here every spec step has a function with the same name, and a reviewer can check the mapping by reading both files. Nothing checks it automatically. If someone later changes `borrow/2` back into two Agent calls, TLC and Lean keep passing, because they check the spec, not the code.

Ways to narrow the gap, from cheapest to most work:

- Keep the spec next to the code, use the same names, and review both in the same PR.
- Use the same property in the spec and in a property test against the real code, as this demo does.
- Trace validation. The code logs each step it takes, and TLC checks that the log is a valid behavior of the spec. `references/verifying_implementations.md` covers it.
- Write the code in the prover itself, so the proved code and the shipped code are the same. Lean compiles to native code, and Lynx (in the README links) proves laws about Elixir code with Lean.

### Backup slide: what TLA+ and Lean can and can't do

Use this to answer "why both?" during questions.

**TLA+ (with the TLC model checker)**

| Can | Can't |
|---|---|
| Describe a design as states and steps, especially concurrent ones | Run. A spec isn't code, and nothing generates code from it. |
| Try every ordering of steps in a small model, with no proof to write | Cover sizes outside the model. Passing at 2 patrons is evidence, not proof. |
| Print a step-by-step trace when a property fails | Catch type mistakes. TLA+ is untyped, so a misspelled value like `"has_bok"` is just a different value, which can make a property quietly always true. |
| Check "eventually" properties, like "everyone on the waitlist gets the book" | Check that the code matches the spec |

**Lean**

| Can | Can't |
|---|---|
| Prove a property for every size, like every number of copies and patrons | Search for bugs. A false property just fails to prove, with no trace. |
| Be the program. Lean compiles to native code, so the proved code can be the shipped code. | Model time or concurrency out of the box. Here we wrote `Reachable` ourselves. |
| Type-check the model as you write it | Always write the proof for you. `grind` did here, but `fixed_inv` still needed a person to supply the stronger invariant. |
| Build on libraries of existing proofs, like Mathlib and CSLib | Check that Elixir code matches the model, unless the code is in Lean or translated into it, as Lynx does |

**Neither can** tell you whether you wrote the right property. `Conservation` passed TLC and was proved in Lean, and the bug was still there.

**In one line:** TLA+ finds design bugs quickly at small sizes. Lean proves the design at every size, and you write the proof. Start with TLA+, and reach for Lean once TLC stops finding bugs and you need the guarantee for every size.

## Left out on purpose

The talk leaves these out to keep the demo small.

- Liveness and fairness, for example "everyone on the waitlist eventually gets the book"
- Hold queues, multiple books, and per-patron limits
- Stateful property testing with interleaved commands, which StreamData doesn't support
- An example of a spec that disagrees with its code
