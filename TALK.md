# Talk: the last copy

The talk is for engineers of mixed experience. An LLM can write TLA+, Lean, and property tests. They only help if a human reads the property, reads the trace, and checks that the spec matches the real code.

## The scenario

A library has 1 copy of a book and 2 patrons, Socrates and Beelzebub. The buggy borrow looks at the shelf, then takes the copy in a separate step. The same check-then-act race shows up in ticket sales, inventory, bank balances, and rate limiters.

The spec, the proof, and the code match step for step:

| TLA+ (`tla/Library.tla`) | Lean (`lean/Library.lean`) | Elixir (`elixir/lib/library.ex`) |
|---|---|---|
| `shelf`, `loans` | `shelf`, `loans` | The Agent's `%{shelf:, loans:}` |
| `looked` | `looked` | A process between its `Agent.get` and its `Agent.update` |
| `Look(p)` | `Look p` | `look?/2`, an `Agent.get` |
| `Take(p)` | `Take p` | `take/2`, an `Agent.update` |
| `Borrow(p)` | `Borrow p` | `borrow/2`, one `Agent.get_and_update` |
| `Return(p)` | `Return p` | `return/2` |
| `NeverOverLent` | `never_over_lent` | The property test's name |

## Slide map

Slide 6 is the easiest to cut.

| # | Slide | On screen |
|---|---|---|
| 1 | The bug in plain words | One sentence on the point of the talk, then four lines of story, no code |
| 2 | The Elixir code | `borrow_buggy/2` next to `borrow/2` |
| 3 | The tests | The property test, then a green and a red run of the 2-patron test |
| 4 | The property, owned by a human | `NeverOverLent`, with the English sentence above it |
| 5 | The trace | TLC's 5-state trace |
| 6 | A green check that means nothing | `Conservation` passing on the buggy design, in TLC and Lean |
| 7 | Lean | Theorem statements, then `#print axioms` catching a fake proof |
| 8 | Does the spec match the code? | The mapping table above, then TLA+ `Take` next to Elixir `take/2` |
| 9 | Nothing checks the match | What happens if `borrow/2` regresses, and four ways to narrow the gap |

Three backup slides after slide 9 are for questions: "What TLA+ and Lean can and can't do", "TLA+ and Lean, symbol by symbol", and "Time and clocks".

### 1. The bug in plain words

Open with the point of the talk: "An LLM can write a spec, a proof, and the tests. None of it helps unless you can read it."

Then tell the story. Socrates sees the book on the shelf. Beelzebub sees the book on the shelf. Socrates takes it. Beelzebub takes it. The library lent out 2 copies of a book it owns 1 of.

Ask the room whether their code has a `get` followed by an `update`.

### 2. The Elixir code

Show `borrow_buggy/2` next to `borrow/2`. The buggy one calls `look?/2`, an `Agent.get`, then `take/2`, an `Agent.update`. The fixed one does both in one `Agent.get_and_update`. Both pass code review.

### 3. The tests

```elixir
property "never lends out more copies than it owns", %{borrow: borrow} do
  check all copies <- integer(1..5),
            steps <- list_of(tuple({member_of([borrow, :return]), integer(1..10)})) do
    ...
  end
end
```

StreamData tries 100 random sequences of borrows and returns by 10 patrons, for 1 to 5 copies. On the buggy code it passes, because it runs one step at a time and never puts two borrows side by side. The property is right, but the test can't reach the bad timing.

The 2-patron test runs the buggy borrow for Socrates and Beelzebub at the same time, with 1 copy. That's the size TLC checks. Show two runs of `BUGGY=1 mix test`, with the same code and the same command. One passes and one fails. On the presenter's machine, 5 of 8 runs failed and 3 passed. Whether the bug ships depends on how the scheduler happened to order two processes during that CI run.

Use these two captured runs on the slide, because you can't choose which one you get on stage. Running it live is optional, and either result works for the slide.

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
     test/library_test.exs:25
     Assertion with <= failed
     code:  assert MapSet.size(Library.loans(library)) <= 1
     left:  2
     right: 1
     stacktrace:
       test/library_test.exs:32: (test)

.
Finished in 0.05 seconds (0.05s async, 0.00s sync)

Result: 1/2 passed (1/1 property, 0/1 test)
Failed: 1 test
```

In both runs the property test passes, so the two outputs also show that StreamData misses the bug.

The property test's name, "never lends out more copies than it owns", comes back on slides 4 and 7 as the TLA+ invariant and the Lean theorem.

### 4. The property, owned by a human

> We never lend out more copies than we own.

```tla
NeverOverLent == Cardinality(loans) <= Copies
```

An LLM can draft the `Look` and `Take` actions. A person who knows the domain has to write or approve this line, because every check after it tests against it.

### 5. The trace

TLC tries every ordering of the steps for the same 1 copy and 2 patrons. It fails every time, after 4 steps:

```text
1. shelf = 1   loans = {}                     looked = {}
2. shelf = 1   loans = {}                     looked = {socrates}
3. shelf = 1   loans = {}                     looked = {socrates, beelzebub}
4. shelf = 0   loans = {socrates}             looked = {beelzebub}
5. shelf = -1  loans = {socrates, beelzebub}  looked = {}
```

Read it out loud. It is the same story as slide 1. Paste it into the PR so reviewers can read it too.

### 6. A green check that means nothing

`Conservation` says copies on the shelf plus copies on loan equal copies owned. It sounds like the right property, and an LLM asked for "an invariant for this library" may write it. TLC passes it on the buggy design, and Lean proves it for the buggy design at every size. In state 5 of the trace, the shelf is at -1 and 2 copies are out, which still adds up to 1.

TLC and Lean check only the property you give them. Only a human who knows the domain can say whether it is the right one.

### 7. Lean

TLC tries every state for 1 copy and 2 patrons. Lean proves a statement for every number of copies and patrons:

```lean
theorem never_over_lent (h : Reachable copies FixedNext s) :
    NeverOverLent copies s

theorem buggy_conservation (h : Reachable copies BuggyNext s) :
    Conservation copies s
```

The first is the guarantee we want. The second is slide 6's trap, proved at every size. Each proof is one line of `grind`, Lean's built-in automation, and `never_over_lent` builds on a helper theorem, `fixed_inv`. Lean checks the proof, so a human only has to read the statement.

Check one more thing before trusting a Lean file an LLM wrote. A proof can end in `sorry`, which tells Lean "trust me." The file still builds, with only a warning. Write `#print axioms` and a theorem's name on its own line in the `.lean` file, and `lake build` lists what that theorem depends on. The end of `lean/Library.lean` has one for each theorem, so every build prints this:

```text
info: Library.lean:140:0: 'Library.never_over_lent' depends on axioms: [propext, Classical.choice, Quot.sound]
```

For comparison, here is a fake proof that isn't in the repo:

```text
theorem buggy_never_over_lent ... := by sorry
#print axioms buggy_never_over_lent
'buggy_never_over_lent' depends on axioms: [sorryAx]
```

The first list is Lean's three standard axioms, which most proofs depend on:

- `propext`: two statements that imply each other are equal.
- `Classical.choice`: if something exists, you can pick one. It also makes every statement either true or false.
- `Quot.sound`: two values that a type treats as the same are equal. Lean also uses it to show two functions are equal when they give the same output for every input.

`sorryAx` means part of the proof was skipped with `sorry`.

### 8. Does the spec match the code?

Show the mapping table, then one action next to its Elixir function:

```tla
Take(p) ==
  /\ p \in looked
  /\ shelf' = shelf - 1
  /\ loans' = loans \union {p}
  /\ looked' = looked \ {p}
```

```elixir
defp take(library, patron) do
  Agent.update(library, fn s ->
    %{s | shelf: s.shelf - 1, loans: MapSet.put(s.loans, patron)}
  end)
end
```

Both are short, and anyone who reads Elixir can check them line by line. The `shelf` and `loans` lines match. The two `looked` lines have no Elixir line, because in the code `looked` is a process waiting between its `Agent.get` and its `Agent.update`. A reviewer has to know that to accept the match.

### 9. Nothing checks the match

Every spec action has a function with the same name, and a reviewer can check the mapping by reading both files. Nothing checks it automatically. If someone later changes `borrow/2` back into two Agent calls, TLC and Lean keep passing, because they check the spec, not the code.

Ways to narrow the gap, from cheapest to most work:

- Keep the spec next to the code, use the same names, and review both in the same PR.
- Use the same property in the spec and in a property test against the real code, as this demo does.
- Trace validation. The code logs each step it takes, and TLC checks that the log is a valid behavior of the spec. `references/verifying_implementations.md` covers it.
- Write the code in the prover itself, so the proved code and the shipped code are the same. Lean compiles to native code, and Lynx (in the README links) proves laws about Elixir code with Lean.

### Backup slide: what TLA+ and Lean can and can't do

Use this to answer "why both?" during questions.

#### TLA+, with the TLC model checker

| Can | Can't |
|---|---|
| Describe a design as states and steps, especially concurrent ones | Run. A spec isn't code, and nothing generates code from it. |
| Try every ordering of steps in a small model, with no proof to write | Cover sizes outside the model with TLC alone. Passing at 2 patrons is evidence, not proof. |
| Print a step-by-step trace when a property fails | Catch type mistakes. TLA+ is untyped, so a misspelled value like `"has_bok"` is just a different value, and a property that tests for it can pass in every state. |
| Check "eventually" properties, like "everyone on the waitlist gets the book" | Check that the code matches the spec |
| Prove a property at every size with TLAPS, a separate proof checker that reads proofs written in TLA+. This demo doesn't use it. | Make proofs as easy as model checking. A TLAPS proof needs a type invariant, since TLA+ has no types, plus the same helper facts Lean needed. `PROOF OMITTED` skips a proof step, like Lean's `sorry`, and tlapm only reports it as a failure with `--strict`. |

#### Lean

| Can | Can't |
|---|---|
| Prove a property for every size, like every number of copies and patrons | Search for bugs. A false property just fails to prove, with no trace. |
| Be the program. Lean compiles to native code, so the proved code can be the shipped code. | Model time or concurrency out of the box. Here we wrote `Reachable` ourselves. |
| Type-check the model as you write it | Always write the proof for you. `grind` did here, but `fixed_inv` still needed a person to supply the stronger invariant. |
| Build on libraries of existing proofs, like Mathlib and CSLib | Check that Elixir code matches the model, unless the code is in Lean or translated into it, as Lynx does |

Neither tool can tell you whether you wrote the right property. `Conservation` passed TLC and was proved in Lean, and the bug was still there.

TLA+ finds design bugs at small sizes, with no proof to write. Lean proves the design at every size, and you write the proof. TLAPS can prove TLA+ specs at every size too, but Lean has far more users, libraries, and automation. Start with TLA+. Use Lean once TLC stops finding bugs and you need the guarantee at every size.

### Backup slide: TLA+ and Lean, symbol by symbol

These tables cover what the two files use, plus the TLAPS keywords that match Lean's proof keywords. TLAPS rows say "Not used here". A blank cell means that file has no counterpart. The full meanings are in the glossary at the top of `tla/Library.tla` and `lean/Library.lean`.

#### Symbols

| Meaning | TLA+ | Lean |
|---|---|---|
| and | `/\` | `∧` |
| or | `\/` | `∨` |
| not | | `¬` |
| implies, or "function to" | | `→` |
| equals | `=` | `=` |
| less than or equal to, greater than | `<=`, `>` | `≤`, `>` |
| there exists | `\E p \in S : ...` | `∃ p, ...` |
| is in | `\in`, for a set | `∈`, for a list |
| is not in | `\notin`, for a set | `∉`, for a list |
| add `p` | `loans \union {p}` | `p :: loans` |
| remove `p` | `looked \ {p}` | `looked.erase p` |
| empty | `{}`, an empty set | `[]`, an empty list |
| the value after a step | `x'`, an operator | `s'`, just a name |
| build from parts | `<<a, b>>`, a tuple | `⟨a, b⟩`, a structure or proof |
| every step follows the rules | `[][N]_vars` | `Reachable`, which we wrote ourselves |
| run a tactic on every goal | | `<;>` |
| short name for a constructor | | `.init`, `.step` |
| line comment | `\*` | `--` |
| block or doc comment | `(* ... *)` | `/-- ... -/` |

#### Keywords

| Meaning | TLA+ | Lean |
|---|---|---|
| group the file's definitions | `MODULE Library` ... `====` | `namespace Library` ... `end Library` |
| use another module | `EXTENDS Naturals, FiniteSets` | |
| numbers | `Naturals` | `Nat`, `Int` |
| how many | `Cardinality(loans)` | `loans.length` |
| values picked from outside | `CONSTANTS`, set in the `.cfg` file | parameters like `(copies : Nat)`, and `variable` |
| the state | `VARIABLES` | `structure State` |
| define a name | `==` | `def ... :=` |
| keep the rest of the state the same | `UNCHANGED` | `{ s with f := v }` |
| a type built from cases | | `inductive` |
| the property to check | `INVARIANT` in the `.cfg` file | the statement of a `theorem` |
| prove it | `THEOREM` and `PROOF`, with TLAPS. Not used here. | `by`, `induction`, `grind`, `have`, `exact` |
| skip a proof step | `PROOF OMITTED`, with TLAPS. Not used here. | `sorry` |
| find skipped steps | `tlapm --strict` or `tlapm --summary`, with TLAPS. Not used here. | `#print axioms` |

### Backup slide: time and clocks

The demo has no clock, but real application logic often does. Examples are a hold that expires after 3 days, a lease timeout, or comparing timestamps from two servers. Neither tool reads a real clock. Both treat time as data in the model.

| | TLA+ | Lean |
|---|---|---|
| What "time" means by default | A behavior is a sequence of states, and each step moves it forward. `[][Next]_vars` in our spec already says "always". | Nothing built in. You define steps yourself, like `Reachable`, or a trace as a function from step number to state. |
| "Always" and "eventually" | Built-in operators. `[]` always, `<>` eventually, `~>` leads to. | You write them out. "Always" is "for every step `n`", and "eventually" is "for some step `n`". |
| Making progress | Fairness conditions, `WF` and `SF`, rule out behaviors where an action stays possible forever but never happens. TLC can check "eventually" properties with them. | No fairness library. You state the progress assumption yourself and use it in the proof. |
| Clock time, like "expires after 3 days" | Add a `now` variable and a `Tick` action that increases it. TLC needs a bound, like "`now` stays under 10", so the model stays finite. | Add a `now` field and a `Tick` action that increases it. A proof can cover any amount of time, with no bound. |
| Clocks on different machines | Give each machine its own clock variable, and let them drift apart by any amount up to a bound. TLC tries every ordering of their steps. Logical clocks, like Lamport or vector clocks, are common in specs. | Same model, but the proof covers any number of machines and any amount of drift within the bound. |

Both tools share one limit. If the model says "clocks drift by at most 1 second," every result assumes that. If the real servers drift by 5 seconds, the check or proof says nothing about them. A human has to decide that bound and keep it true in production, the same way a human owns `NeverOverLent`.

## Terms

Short definitions of the terms the talk and the files use, with an example from this repo where there is one.

#### Modeling

- **Specification, or spec.** A precise description of what a system should do. `tla/Library.tla` is ours.
- **Model.** A simplified version of the system that keeps only the parts that matter. Ours tracks `shelf`, `loans`, and `looked`, and nothing about book titles or due dates.
- **State.** A value for every variable, such as `shelf = 1, loans = {}, looked = {}`.
- **Step.** A pair of states, one before and one after. Slide 5's trace has 5 states, so it has 4 steps.
- **Action.** A rule that says which steps are allowed. It relates the old state to the new one, written `shelf` and `shelf'` in TLA+, and `s` and `s'` in Lean. `Look`, `Take`, `Borrow`, and `Return` are actions.
- **Behavior.** An infinite sequence of states. A system that stops is a behavior that repeats its last state forever. These repeats are called stuttering steps, and `[][Next]_vars` allows them.
- **Trace.** A finite run of states, such as the start of a behavior. TLC prints a trace when an invariant fails.
- **Reachable state.** A state that some behavior arrives at, starting from `Init`. TLC visits every one, and Lean's `Reachable` defines them.

#### Properties

- **Property.** A statement about behaviors. A spec has a property if every behavior the spec allows has it.
- **Invariant.** A statement about a single state that is true in every reachable state. `NeverOverLent` and `Conservation` are invariants.
- **Safety property.** "Something bad never happens." If a behavior breaks one, a finite trace shows it. Every invariant is a safety property.
- **Liveness property.** "Something good eventually happens", such as "everyone on the waitlist gets the book". No finite trace can break one, because the good thing could still happen later. The demo has none.
- **Weak fairness.** An assumption that if an action stays possible from some point on, it eventually happens. TLA+ writes it `WF_vars(A)`.
- **Strong fairness.** An assumption that if an action keeps becoming possible, even with gaps, it eventually happens. TLA+ writes it `SF_vars(A)`. Liveness properties usually need weak or strong fairness, because without it a behavior can stutter forever.

#### Checking and proving

- **Model checking.** Trying every reachable state of a small model. TLC is a model checker.
- **Counterexample.** A trace that breaks a property. It is a real bug in the model. Whether the code has the same bug depends on how well the model matches the code.
- **Proof.** An argument that a statement holds in every case, written in steps a tool can check. Lean and TLAPS check proofs.
- **Theorem.** A statement that has been proved. `never_over_lent` is a theorem.
- **Lemma.** A theorem proved mainly to help prove another one. The difference is only in why you wrote it. `fixed_inv` is a lemma for `never_over_lent`. Core Lean has no `lemma` keyword, so this repo writes `theorem` for both. Mathlib, a Lean library, adds `lemma` as another name for `theorem`. TLA+ accepts `LEMMA` and `COROLLARY` as other names for `THEOREM`.
- **Axiom.** A statement accepted without proof. `propext` is one of Lean's standard axioms, and `sorryAx` is the axiom behind every `sorry`. TLA+ writes axioms with `AXIOM` or `ASSUME`.
- **Induction.** A way to prove something holds in every reachable state. Prove it for `Init`, then prove that every step keeps it true.
- **Inductive invariant.** An invariant strong enough that "true before a step" proves "true after the step". `NeverOverLent` alone isn't one. `fixed_inv`'s two facts together are.
- **Tactic.** An instruction inside a Lean proof that tells Lean how to build the proof, such as `induction` or `grind`.
- **Proof obligation.** One small statement a proof tool has to prove. tlapm splits a proof into obligations and reports how many it proved.

## Left out on purpose

The talk leaves these out to keep the demo small.

- A working liveness and fairness check, such as "everyone on the waitlist eventually gets the book". The time and clocks backup slide covers the idea.
- Hold queues, multiple books, and per-patron limits
- Stateful property testing with interleaved commands, which StreamData doesn't support
- An example of a spec that disagrees with its code
