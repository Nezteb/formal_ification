> In both cases (using both TLA+ and Lean), what options are there for verifying that a given code implementation (using Elixir or C or any other language) matches the TLA+ spec / Lean proof?

---

I'll check the current state of tooling for both directions, since this ecosystem moves fairly fast.Good question — this is exactly the gap where formal methods projects die, and both ecosystems have very different (and unequally mature) answers. The clean way to organize it is by *strategy*, because the same four strategies exist on both sides but with wildly different tool support.

## The four strategies

| Strategy | What you trust | TLA+ maturity | Lean maturity |
|---|---|---|---|
| **1. Trace validation** — log the real system, check the log is a legal behavior of the spec | Runtime observation | ★★★★☆ (TLC/Apalache, actively used in production) | ★★☆☆☆ (DIY: executable checker in Lean) |
| **2. Refinement proof** — write a low-level spec of the algorithm, prove it refines the abstract one; link to code by review | The low-level spec ↔ code correspondence | ★★★☆☆ (TLC refinement; TLAPS for the proof) | ★★★★★ (this is just what Lean does) |
| **3. Extract/lift the code into the prover** — mechanically translate real code into the logic | The translator | ★☆☆☆☆ (no such thing) | ★★★☆☆ (Rust only: Aeneas/Charon, hax) |
| **4. Generate/verify the code itself** — the deployed artifact is the verified artifact | The compiler / program logic | ★☆☆☆☆ | ★★★★☆ (write or verify in Lean, compile to C) |

---

## 1. Trace validation: the workhorse on the TLA+ side

This is the dominant practical answer, and it's **language-agnostic** — which is why C, Elixir, Go, and Rust all use the same recipe. You instrument the implementation to emit a log of events (NDJSON), then run TLC over a small "validation spec" that consumes the log line by line and asserts each event is a legal spec action producing the recorded state. If the trace can't be matched, TLC hands you the exact line where implementation and spec diverged.

The mechanism is a `Next` action that reads its own depth with `TLCGet("level")`, so no ghost index variable is needed:

```tla
Next ==
    LET level == TLCGet("level") IN
    /\ level <= Len(Trace)
    /\ Trace[level].event = "tick"
    /\ Trace[level].old_hour = hr      \* state before must match
    /\ HCnxt                           \* the real spec action
    /\ Trace[level].hour = hr'         \* state after must match
```

Two gotchas that bite everyone: the `.cfg` CONSTANTs must match the implementation's actual configuration, or validation fails for boring reasons, and you need a `VIEW` including `TLCGet("level")` so TLC doesn't mistake repeated states for a cycle and stop early.

**It works.** Markus Kuppe reports that in the Confidential Consortium Framework, trace validation found two significant data-loss bugs using only about a dozen executions. The broader framework for distributed programs — with vector clocks / happens-before for genuinely concurrent traces where no global observer exists — is written up by Merz and colleagues, and the CCF experience is in the "Smart Casual Verification" paper.

**The main critique**, and you should take it seriously: a randomly sampled trace has a low probability of catching deep bugs, and trace validation is explicitly not exhaustive — it checks that *this subset* of executions conforms. The fix is that the spec should also *drive* test generation: take TLC/Apalache counterexamples and turn them into implementation inputs, which the CCF team did by hand and found straightforward. There's also a Java-specific toolkit that automates the log-extraction side.

**Apalache** adds a symbolic variant (SMT-backed, bounded) and, more useful for this purpose, the **ITF** trace format — a JSON dialect that TLC, Apalache, and Quint all emit, with parsers in Rust, TypeScript, and Python. That makes "replay a model-checker counterexample against the real implementation" a language-independent plumbing problem rather than a research project.

### Doing it in Elixir or C

- **Elixir/BEAM**: you have better observability than most languages. Use `:dbg` / `:erlang.trace`, `Telemetry` handlers, or just structured `Logger` lines emitted *after* each state commit (log post-state, ideally both pre and post). One line of JSON per `GenServer.handle_call`. A `Task`-free single-process state machine maps trivially; for concurrent processes you need vector clocks or a serialization point, which the NDJSON manual explicitly flags as out of scope for the simple recipe.
- **C**: same thing with a logging macro, but you must be careful about logging from inside critical sections and about the observer perturbing timing. For single-threaded state machines (parsers, protocol FSMs, drivers) this is very effective.
- **Complementary and cheaper**: Erlang's `proper` has a `statem` module precisely for testing a stateful process against a model state machine — a lightweight, non-formal version of the same idea, and a good first step before writing TLA+.

**The honest caveat**: trace validation never proves the code equals the spec. It proves the code's *observed* behavior is *consistent with* the spec, which is a much weaker but often sufficient claim. And it silently assumes your mapping (which event means which action) is right — a wrong mapping yields false confidence.

---

## 2. Refinement: the bridge that both tools support, unequally

The structural answer to "does the code match the spec" is: **write a second, low-level spec that is a faithful description of the algorithm as implemented, then prove or check that it implements the abstract one.** The residual risk is localized to one hand-written artifact (low-level spec ↔ code), which you attack with code review plus trace validation.

- **In TLA+**: this is idiomatic. You write `Impl` with concrete variables and steps, `Abs` with abstract ones, a refinement mapping, and either model-check `Impl => Abs` with TLC (cheap, finite) or prove it with **TLAPS** (a real theorem, but TLAPS is thin on documentation and rarely used in industry).
- **In Lean**: you'd define both as transition systems (or a relational `Step` predicate), define a simulation/refinement relation, and prove `impl_step ⊆ abs_step ∘ R`. Lean is genuinely good at this, and you get compositionality and arbitrary parameters. The cost is that you're building the theory rather than importing it — Lean has no TLA+-style refinement library, no temporal operators, no fairness. This is where the "Lean has no native notion of time" gap from earlier becomes concrete work.

---

## 3. Lifting actual code into the prover

This is where Lean has capabilities TLA+ simply lacks, but almost entirely for **Rust**:

- **Aeneas + Charon**: Charon compiles Rust to an intermediate representation (LLBC); Aeneas translates that to a pure functional model in a proof assistant. Backends exist for **Lean**, F\*, Coq, and HOL4. The workflow is: write ordinary Rust with no annotations, translate automatically, prove properties of the generated model in Lean. It handles real code, not a toy subset, and Lean's own site now documents it as a use case.
- **hax**: an alternative Rust→Lean (and F\*) extraction path. A 2026 experience report describes a pipeline taking *production* Rust cryptographic code to machine-checked Lean 4 proofs, combining Charon/Aeneas or hax with spec libraries from the verified zkEVM work.

**For C there is no Lean-native story.** The mature C program logics live elsewhere: CN (separation-logic refinement types for C, built on a realistic ISO C semantics, aimed at predictable automation), RefinedC, VST, and Gillian in Coq, Frama-C/ACSL with Why3, VeriFast, CBMC. There's even work on translation validation *for CN* itself. People are actively asking for official Lean semantics for mainstream languages (there's an open proposal for C#), which tells you the current state: not there yet.

**For Elixir there is essentially nothing.** No formal BEAM semantics in Lean, no extraction pipeline. Realistically your options are trace validation, `proper`/`StreamData` model-based testing, and possibly Dialyzer plus a hand-written core in a verifiable language.

---

## 4. Make the verified artifact the deployed artifact

The strongest guarantee, and the reason people put up with Lean's learning curve:

- **Lean 4 compiles to C, then to native code.** So a function proved in Lean and compiled is the same function that ships — no extraction gap, no "the model was correct but the code wasn't." This is the default Lean workflow and is the closest thing to a real solution to the "code matches proof" problem: you eliminate the second program.
- From the TLA+ side the analogous move is **code generation**, and it's weak. Apalache is a symbolic *model checker* translating TLA+ to SMT constraints, not a compiler; Quint transpiles to Apalache IR/TLA+ — all inward, toward checking, not outward toward shipping code. There is no credible TLA+→C or TLA+→Elixir compiler, and you shouldn't expect one, because TLA+ specs are untyped, nondeterministic, and non-executable by design.

---

## A practical recipe for your case

Given "Elixir or C or anything else," the realistic layering is:

1. **Spec in TLA+**, model-check with TLC. Cheap, finds design bugs.
2. **Instrument the implementation** to emit NDJSON traces; **validate traces** with TLC against a `TraceSpec`. This is your primary, language-agnostic link between code and spec, and it's where you get the best bug-per-hour return.
3. **Feed TLC/Apalache counterexamples back** as test inputs against the real code (ITF → your test harness) — this converts "the model found a bug" into a regression test.
4. **For the parts that must be *proved*** — a consensus core, a crypto primitive, a protocol invariant that must hold for all node counts — either:
   - move that component to **Rust** and use Aeneas/hax → Lean, or
   - write it directly in **Lean** and compile it, or
   - for C, use **CN/Frama-C/VST** rather than trying to force Lean.
5. Keep a **low-level TLA+ spec** next to the code for the concurrent/stateful parts, so the abstraction gap is documented and reviewable rather than implicit.

## What to watch out for

- **Nobody has a mature TLA+↔Lean bridge.** You will hand-translate between them, and that translation is itself unverified. Don't let a Lean proof of `Abs` plus a TLA+ spec of `Abs` create the illusion of a chain — the two `Abs`s are two different objects maintained by hand.
- **Trace validation's failure mode is silence.** A mapping bug (event X treated as action Y) makes bad traces pass. Validate the validator by deliberately corrupting a trace and confirming rejection.
- **Constants and configuration drift** are the most common false failures, and the most common cause of people abandoning the setup after week two.
- **The TLA+ side scales down better; the Lean side scales up better.** For "does my Elixir GenServer do what the design doc says," trace validation is the answer. For "is this algorithm correct for any number of replicas," only the Lean side will get you there.
