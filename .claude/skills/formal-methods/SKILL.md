---
name: formal-methods
description: Guides writing and reviewing TLA+ specs, Lean proofs, and property-based tests so that a human owns the property, reads the counterexample trace, and checks that the spec matches the code. Use when designing or reviewing concurrent or stateful logic (check-then-act races, inventory, bookings, balances, locks, leases), when debugging flaky concurrency tests or races that pass or fail depending on the machine, when asked to write a TLA+ spec, run TLC or tlapm, prove something in Lean, write property-based or stateful tests, or review a spec or proof an LLM wrote.
---

# Formal methods that a human can own

An LLM can write a TLA+ spec, a Lean proof, and property-based tests. None of it helps unless a human reads three things:

1. **The property.** Every check tests against it. A wrong property passes and the bug ships.
2. **The trace.** A counterexample helps only once someone reads it step by step and says what happened.
3. **The spec-to-code mapping.** TLC and Lean check the spec, not the code. Nothing checks that the two match.

Apply these rules for the whole task, not only in the first reply.

## Rules

- **Get the property from the user first.** Write it as one English sentence, then as one line of TLA+ or Lean. Show both to the user and wait for approval before checking anything. Never check against a property you invented without approval.
- **See every check fail before trusting it to pass.** Run the property against a design with a known bug, or break the design on purpose. If the check stays green, the property is too weak. Tell the user, and don't report the green result as evidence.
- **Keep the model small.** Track only the state the property needs, and use the smallest constants that can show the bug, such as 2 processes and 1 resource.
- **Name everything after the code.** Each action in the spec gets the name of the code function it models. Give the user a mapping table.
- **Translate every trace.** Rewrite each counterexample as numbered plain-English steps, naming who does what. Offer it for the PR description.
- **Say what wasn't checked.** Every report names the sizes checked, the assumptions made (bounds, fairness, clock drift), and the fact that nothing checks the spec-to-code mapping.

## The running example: check-then-act

The examples below use one pattern that shows up in many domains. A client reads shared state, decides, then writes in a separate call. Another client can act in between.

| Domain | Read | Write | Property |
|---|---|---|---|
| Ticket sales | seats left | sell a seat | never sell more seats than the venue has |
| Inventory | stock count | reserve an item | never reserve more than is in stock |
| Bank account | balance | withdraw | the balance never goes below 0 |
| Rate limiter | requests this window | allow a request | never allow more than the limit per window |
| Lock or lease | current holder | acquire | at most one holder at a time |

The generic model has a pool with `Capacity` units, `available` units left, and the set of `holders`. A buggy claim checks `available > 0`, then claims in a second call. With capacity 1, two clients both see 1 unit available, and both claim it.

## The trap: a property that sounds right

| Property | English | Result on the buggy design |
|---|---|---|
| `NeverOverAllocated == Cardinality(holders) <= Capacity` | We never hand out more units than we have. | TLC fails after 4 steps |
| `Conservation == available + Cardinality(holders) = Capacity` | Units available plus units held equal capacity. | TLC passes, and Lean proves it at every size |

`Conservation` still holds when `available` is -1 and 2 clients hold units. It is bookkeeping, not the requirement. Only a human who knows the domain can tell the real requirement from an invariant that only sounds right. Watch for these shapes, which pass while the bug is still there:

- **Sums and balances that "add up".** Check whether a negative value or a double-count still satisfies them.
- **Properties about the counter, not the thing counted.** "The counter is never negative" can pass while two clients hold the same unit.
- **Properties a do-nothing system satisfies.** If a spec where nothing ever happens passes, the property says nothing about progress. Ask whether the user also needs a liveness property.

## Workflow

Copy this checklist and track progress:

```
Formal methods progress:
- [ ] 1. Property approved by the user, in English and in TLA+ or Lean
- [ ] 2. Model written, with a spec-to-code mapping table
- [ ] 3. Check fails on the buggy or broken design, and the trace is translated
- [ ] 4. Check passes on the fixed design
- [ ] 5. (Optional) Lean or TLAPS proof for every size, with no skipped steps
- [ ] 6. Property-based test on the real code, with the same property name
- [ ] 7. Report: what was checked, at what sizes, and what wasn't checked
```

### 1. Property

Ask the user for the sentence, or draft one and ask them to confirm it. Classify it:

- **Invariant.** A statement about one state that holds in every reachable state. Check it with `INVARIANT` in TLC.
- **Liveness.** "Something good eventually happens." It needs a fairness assumption (`WF_vars(A)` or `SF_vars(A)`), and TLC checks it with `PROPERTY`. Ask the user which actions are fair, because fairness is an assumption about the real system.

### 2. Model

Write the spec in TLA+ first, because TLC needs no proof. Use this shape:

```tla
---- MODULE Pool ----
EXTENDS Integers, FiniteSets
CONSTANTS Clients, Capacity
VARIABLES available, holders, checked
vars == <<available, holders, checked>>

Init == available = Capacity /\ holders = {} /\ checked = {}

\* One action per code function. Rename each to match the code.
Check(c) == available > 0 /\ c \notin holders /\ checked' = checked \union {c} /\ UNCHANGED <<available, holders>>
Claim(c) == c \in checked /\ available' = available - 1 /\ holders' = holders \union {c} /\ checked' = checked \ {c}
Release(c) == c \in holders /\ available' = available + 1 /\ holders' = holders \ {c} /\ UNCHANGED checked

Next == \E c \in Clients : Check(c) \/ Claim(c) \/ Release(c)
Spec == Init /\ [][Next]_vars

NeverOverAllocated == Cardinality(holders) <= Capacity
====
```

Model the gap between a read and a write as its own variable (`checked` above). In the code it has no variable of its own. It is a process waiting between two calls. Say so in the mapping table. The fixed design replaces `Check` and `Claim` with one action that does both, the way an atomic update, a transaction, or a compare-and-swap does in the code.

Use `Integers`, not `Naturals`, when a buggy step can push a count below 0, like `Claim` above. TLC computes `0 - 1` anyway, but `Naturals` doesn't define it, so a TLAPS proof can't use it.

### 3 and 4. Model check

Get `tla2tools.jar` from the latest stable release on `github.com/tlaplus/tlaplus/releases`. Each `.cfg` file picks one spec and one property:

```text
CONSTANTS
  Clients = {c1, c2}
  Capacity = 1
SPECIFICATION Spec
INVARIANT NeverOverAllocated
```

```sh
java -XX:+UseParallelGC -cp tla2tools.jar tlc2.TLC -config Pool.cfg Pool.tla
```

- `c1` and `c2` are model values, names TLC treats as distinct with no other meaning. Use names a reader of the trace will recognize, such as user or node names.
- A violated invariant prints `Error: Invariant NeverOverAllocated is violated.`, then the trace as numbered states, and exits non-zero.
- `-workers auto` uses every core. `-metadir <dir>` moves the `states/` directory TLC writes next to the spec. `-deadlock` turns off deadlock checking, which is on by default.
- A trace with N states has N - 1 steps. Count them that way when reporting.
- Keep a separate `.cfg` for the buggy design and for the fixed one, so both results can be re-run.

A pass covers only the constants in the `.cfg`. Report it as "no violation for 2 clients and capacity 1", not as "correct".

### 5. Proof for every size (optional)

Use a proof when the user needs the property for every size, and TLC has stopped finding bugs.

**Lean 4.** Write the transition system yourself, because Lean has no built-in notion of time:

```lean
inductive Reachable (next : State → State → Prop) : State → Prop
  | init : Reachable next Init
  | step : Reachable next s → next s s' → Reachable next s'

theorem never_over_allocated (h : Reachable FixedNext s) : NeverOverAllocated s := by
  ...
```

- The human reads only the `theorem` statement. Lean checks the proof. Show the user the statement and confirm it says what the English sentence says.
- Induction on the property alone often fails, because it can't rule out unreachable states. Strengthen it into an inductive invariant, such as `Conservation ∧ 0 ≤ available`, then derive the property from it. Tell the user which extra facts were needed.
- `grind` does case splits, unfolds the definitions listed in `[...]`, and solves linear arithmetic. Try `induction h <;> grind [Init, Next, ...]` first.
- Core Lean has no `lemma` keyword and no `linarith`. Both come from Mathlib.
- `sorry` skips a proof with only a warning, so a file can build and prove nothing. End the file with `#print axioms <theorem>` for each theorem. `lake build` then prints each theorem's axioms. The standard three are `propext`, `Classical.choice`, and `Quot.sound`. `sorryAx` in the list means some part of the proof was skipped. Report that theorem as unproved.

**TLAPS.** It proves TLA+ specs at every size, but needs a hand-written type invariant (`TypeOK`), because TLA+ is untyped. By default, `tlapm` reports "All obligations proved" even when steps are missing or say `PROOF OMITTED`. Always run:

```sh
tlapm --strict --cache-dir "$TMPDIR/tlacache" Pool.tla
```

`--strict` fails on omitted steps. `--summary` lists them. `--cache-dir` keeps tlapm from writing `.tlacache` into the working directory.

### 6. Property-based test on the real code

Use the same property, with the same name, against the real code. This is the cheapest link between spec and code.

- A plain generator runs operations one at a time, so it never interleaves two processes. On a race it passes, and the bug is still there. Tell the user when that applies.
- For races, use parallel or stateful testing, which generates interleavings or schedules:

| Language | Library | Feature |
|---|---|---|
| Erlang | PropEr | `proper_statem:parallel_commands/1` and `run_parallel_commands/2` |
| Elixir | PropCheck, a wrapper for PropEr | `PropCheck.StateM` with the same two functions |
| JavaScript, TypeScript | fast-check | `fc.scheduler()` |
| Python | Hypothesis | `RuleBasedStateMachine` |

**Writing the parallel test.**

- A parallel test needs a model: the expected state, the next state after each call, and the expected result of each call. It passes only if some one-at-a-time order of the parallel calls explains every result. The model is another copy of the spec, so show it to the user next to the property.
- Keep the model much simpler than the code, or it becomes a second implementation. Keep the sizes small, such as 1 resource and 2 clients, and track only the state the property needs. Add features one at a time after that. Each new one is tested together with the rest, with no new tests to write.
- Have the model check the error results too, such as an "unavailable" error when nothing is left. A model that only checks successful calls misses wrong errors.
- Measure what the generator produces. Use `collect` with a true/false value, such as whether both parallel branches call the write, to count the test cases that can expose the bug. `classify` with a single category always reports 100%, so it can't show this. If the `true` share is near 0%, fix the generator before trusting a pass. A good generator finds trouble within 100 test cases.
- The race doesn't happen on every run, so shrinking can stop early and leave extra steps in the counterexample. Trim them by hand when translating the trace.
- If a parallel test never finds a known race, PropEr's docs suggest adding `:erlang.yield()` between the read and the write in the code under test. Other languages have a similar call to give up the CPU. Say so if you add it, because it changes how often the race happens in every other test too.

**When a race test passes.**

- A plain concurrent test (start N processes at once, then assert) passes or fails depending on scheduling. Run it many times and report the counts, such as "failed 5 of 8 runs". One green run is not evidence.
- The result can also depend on the machine. A 1-CPU CI runner may run each process to completion and never hit the race. Run the test with the runtime limited to 1 CPU too. On the BEAM, that's `ELIXIR_ERL_OPTIONS="+S 1"`.
- To make a race failure reproducible, suggest deterministic simulation testing. The test controls the clock, thread scheduling, network, and randomness from one seed, so rerunning the same seed replays the same interleaving. It usually takes design work, so suggest it to the user rather than building it.

### 7. Report

Use this structure:

```markdown
**Property:** [English sentence], approved by [user].
**Result:** [Fails on the buggy design after N steps / no violation for SIZES / proved for every size].
**Trace:** [Numbered plain-English steps, if any].
**Mapping:** [Spec action -> code function table].
**Not checked:** [Sizes outside the model, assumptions, and the spec-to-code mapping].
```

## Closing the spec-to-code gap

If someone later splits an atomic update in the code back into a read and a write, TLC and Lean keep passing. Offer these options to the user, from cheapest to most work:

1. Keep the spec next to the code, with the same names, and review both in the same PR.
2. Test the same property against the real code (step 6).
3. Trace validation. The code logs each step, and TLC checks that the log is a behavior the spec allows.
4. Prove the code itself. Write it in Lean, which compiles to native code, so the proved code is the shipped code. Or, if the code's language has a translator into Lean, prove properties of the translated code. Then what you trust is the translator.

## Choosing a tool

| Need | Use |
|---|---|
| Find design bugs in concurrent or distributed logic | TLA+ with TLC. No proof to write, and it prints a trace. |
| A guarantee for every size | Lean. You write the proof. |
| A TLA+ spec proved for every size | TLAPS, if the team accepts writing a type invariant |
| Check the real code | Property-based tests, and parallel or stateful ones for races |

Start with TLA+. Move to Lean once TLC stops finding bugs and the user needs every size.

## Time and clocks

Neither tool reads a clock. Model time as a variable (`now`) and a `Tick` action that increases it. TLC needs a bound, such as "`now` stays under 10". Clock drift between machines is a bound too, such as "at most 1 second". Every result assumes those bounds. Ask the user to confirm each bound, and list it under "Not checked" in the report. For a property test on real code, pass the current time in as a parameter or swap in a fake clock, so the test controls when time moves and can shrink it.

## Terms

Use these as TLA+ defines them, because readers who know the field will notice mistakes.

- **State.** A value for every variable.
- **Step.** A pair of states, before and after.
- **Action.** A formula that says which steps are allowed, such as `Claim(c)`. Call spec definitions actions, not steps.
- **Behavior.** An infinite sequence of states. A stopped system repeats its last state forever (stuttering steps).
- **Trace.** A finite sequence of states, such as the start of a behavior. TLC prints one when an invariant fails.
- **Counterexample.** A trace that breaks a property. It is a real bug in the model. Whether the code has it depends on the mapping.
- **Safety property.** Something bad never happens. A finite trace can break one. Every invariant is a safety property.
- **Liveness property.** Something good eventually happens. No finite trace can break one.

## Troubleshooting

- **TLC fails with a temp-file or permission error in a sandbox.** Add `-Djava.io.tmpdir="$TMPDIR"` before `-cp`.
- **tlapm fails in a sandbox.** It calls `ps` to manage its back-end provers. Ask the user to run it, or run it outside the sandbox with their approval.
- **TLC reports `Deadlock reached`.** A state has no next step. Usually an action is missing, such as `Release`. Add it. Use `-deadlock` only when stopping is correct behavior, and say so in the report.
- **TLC passes, but the user expected a failure.** Re-check the property against step 3 of the workflow. A property that is too weak is the most common cause.
- **TLC runs too long.** Shrink the constants. Most failures in production distributed systems need 3 or fewer nodes to reproduce.

## References

- TLA+
  - https://lamport.azurewebsites.net/tla/tla.html
  - https://lamport.azurewebsites.net/tla/book-02-08-08.pdf
  - https://learntla.com/core/temporal-logic.html
  - https://github.com/tlaplus/tlaplus/releases
  - https://github.com/tlaplus/tlaplus/blob/master/general/docs/current-tools.md
  - https://github.com/tlaplus/tlapm
  - https://foundation.tlapl.us/
- Lean
  - https://lean-lang.org/install/manual/
  - https://lean-lang.org/theorem_proving_in_lean4/tactics.html
  - https://lean-lang.org/theorem_proving_in_lean4/axioms_and_computation.html
  - https://lean-lang.org/doc/reference/latest/Axioms/
  - https://lean-lang.org/doc/reference/latest/The--grind--tactic/
- Property-based tests
  - https://proper-testing.github.io/apidocs/proper_statem.html
  - https://propcheck.hexdocs.pm/PropCheck.StateM.html
  - https://fast-check.dev/docs/advanced/race-conditions/
  - https://hypothesis.readthedocs.io/en/latest/stateful.html
  - https://medium.com/@jlouis666/quickcheck-advice-c357efb4e7e6
- Deterministic simulation testing
  - https://martinfowler.com/articles/deterministic-simulation-testing.html
  - https://antithesis.com/docs/resources/deterministic_simulation_testing/
- Background
  - https://en.wikipedia.org/wiki/Safety_and_liveness_properties
  - https://lamport.azurewebsites.net/tla/formal-methods-amazon.pdf
  - https://www.usenix.org/conference/osdi14/technical-sessions/presentation/yuan
  - https://arxiv.org/abs/2404.16075
