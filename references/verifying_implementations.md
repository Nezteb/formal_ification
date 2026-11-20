> In both cases (using both TLA+ and Lean), what options are there for verifying that a given code implementation (using Elixir or any other language) matches the TLA+ spec / Lean proof?

---

There are four ways to check that code matches a spec. TLA+ and Lean support each one to a different degree.

## The four strategies

| Strategy | What you trust | TLA+ maturity | Lean maturity |
|---|---|---|---|
| 1. Trace validation. Log the real system, and check that the log is a legal behavior of the spec. | What you observe at runtime | 4 of 5. TLC and Apalache, used in production. | 2 of 5. You write your own checker in Lean. |
| 2. Refinement proof. Write a low-level spec of the algorithm, prove it refines the abstract spec, and link it to the code by review. | That the low-level spec matches the code | 3 of 5. TLC checks refinement, and TLAPS proves it. | 5 of 5. This is what Lean is for. |
| 3. Translate the code into the prover. A tool turns real code into the prover's logic. | The translator | 1 of 5. No such tool exists. | 3 of 5. Only for the few languages that have a translator. |
| 4. Ship the verified code. The deployed program is the program you proved. | The compiler or program logic | 1 of 5 | 4 of 5. Write or verify the code in Lean, then compile it to native code. |

## 1. Trace validation, the most used TLA+ approach

Trace validation works with any language, using the same recipe. You add logging to the code so it writes one JSON line per event (NDJSON). Then TLC runs a small validation spec that reads the log line by line. For each event, it checks that a spec action allows it and produces the logged state. If a line doesn't match, TLC reports the exact line where the code and the spec disagree.

The validation spec's `Next` action reads its own step number with `TLCGet("level")`, so you don't need an extra index variable:

```tla
Next ==
    LET level == TLCGet("level") IN
    /\ level <= Len(Trace)
    /\ Trace[level].event = "tick"
    /\ Trace[level].old_hour = hr      \* state before must match
    /\ HCnxt                           \* the real spec action
    /\ Trace[level].hour = hr'         \* state after must match
```

Two mistakes catch most people. The `CONSTANTS` in the `.cfg` file must match the code's real configuration, or validation fails for reasons unrelated to bugs. You also need a `VIEW` that includes `TLCGet("level")`, so TLC doesn't treat a repeated state as a cycle and stop early.

Trace validation finds real bugs. Markus Kuppe reports that in the Confidential Consortium Framework (CCF), it found two serious data-loss bugs from about a dozen runs. Merz and colleagues describe the general method for distributed programs. It uses vector clocks to order events when no single observer sees everything. The CCF team describes their experience in the paper "Smart Casual Verification."

Trace validation has one real weakness. A random trace rarely catches a deep bug, and trace validation only checks the runs you logged. The fix is to let the spec drive the tests as well. Take TLC or Apalache counterexamples and turn them into inputs for the real code. The CCF team did this by hand and found it easy.

Apalache adds a symbolic checker, backed by an SMT solver and limited to a fixed number of steps. It also defines the ITF trace format, a JSON format that TLC, Apalache, and Quint all write. Any language that reads JSON can read it. With ITF, replaying a model checker's counterexample against real code takes some glue code, not a research project.

### Logging the trace

- **Any language.** Log one line after each state change. Be careful about logging inside critical sections, because logging can change the program's timing. This works best for single-threaded state machines, such as parsers and protocol handlers.
- **Elixir.** The BEAM can trace a running program without code changes. Use `:dbg` or `:erlang.trace`, `Telemetry` handlers, or structured `Logger` lines written after each state change. Log the state after the change, and ideally the state before it too, with one JSON line per `GenServer.handle_call`. A single-process state machine maps directly onto a spec. For concurrent processes, you need vector clocks or a single point that orders events. The simple NDJSON recipe doesn't cover that case.
- **A cheaper first step.** PropEr, an Erlang property testing library, has a `proper_statem` module for testing a stateful process against a model state machine. From Elixir, use it through PropCheck. It is an informal version of the same idea, and a good step before writing TLA+.

Trace validation never proves the code equals the spec. It shows that the code's observed behavior is consistent with the spec, which is a weaker claim but often enough. It also assumes your mapping from events to actions is right. A wrong mapping gives false confidence.

## 2. Refinement, which both tools support to different degrees

To show that code matches a spec, write a second, low-level spec that describes the algorithm as the code implements it. Then prove or check that it implements the abstract spec. The remaining risk is that the low-level spec doesn't match the code, and you reduce that with code review and trace validation.

- **In TLA+**, this is the standard approach. You write `Impl` with concrete variables and steps, `Abs` with abstract ones, and a refinement mapping. Then you either model-check `Impl => Abs` with TLC, which is cheap but finite, or prove it with TLAPS. A TLAPS proof covers every size, but you write it step by step, and because TLA+ has no types, you also prove a type invariant.
- **In Lean**, you define both as transition systems, or as a `Step` relation, define a simulation relation, and prove `impl_step ⊆ abs_step ∘ R`. Lean handles this well, and the result composes and covers any parameters. The cost is that you build the theory yourself. Lean has no TLA+-style refinement library, no temporal operators, and no fairness. Here, Lean's lack of a built-in notion of time turns into real work.

## 3. Translating real code into the prover

Lean can do this and TLA+ can't, but only for the few languages that have a translator. A translator turns ordinary code, with no annotations, into a model in Lean. You then prove properties of that model in Lean. What you trust is that the translator is correct.

Most languages have no translator into Lean. Some have verification tools of their own, built on other provers, and those are worth checking before you plan on this strategy. Lean has no official semantics for most mainstream languages yet.

Elixir has one early-stage translator, Lynx, which translates compiled Erlang and Elixir code into Lean and proves laws about it. Its README warns to expect bugs and missing built-in functions. Beyond Lynx, your options are trace validation, model-based testing with PropEr or PropCheck, property tests with StreamData, and Dialyzer, plus writing the core logic in a language you can verify. StreamData has no stateful or parallel testing, so it can't check a model.

## 4. Ship the verified code

This gives the strongest guarantee of the four strategies.

- Lean 4 compiles to native code. A function you prove in Lean and compile is the function that ships. There is no second program and no translation step. What you still trust is the Lean compiler, and that the statement you proved is the one you meant. This is the normal Lean workflow.
- On the TLA+ side, the equivalent would be generating code from a spec, and nothing does that well. Apalache is a symbolic model checker that turns TLA+ into SMT constraints, not a compiler. Quint compiles to Apalache's format or to TLA+. All of these move toward checking, not toward shipped code. No compiler from TLA+ to Elixir or any other language exists, and none is likely, because TLA+ specs are untyped, nondeterministic, and not meant to run.

## A recipe for Elixir or any other language

1. Write the spec in TLA+ and model-check it with TLC. It's cheap, and it finds design bugs.
2. Add logging to the code so it writes NDJSON traces, and validate those traces with TLC against a `TraceSpec`. This is the main link between code and spec in any language, and it finds the most bugs for the effort.
3. Feed TLC or Apalache counterexamples back as test inputs for the real code, using ITF. That turns "the model found a bug" into a regression test.
4. For the parts that must be proved, such as a consensus core, a cryptographic algorithm, or a protocol invariant that must hold for any number of nodes, do one of these:
   - Write it in Lean and compile it.
   - If your language has a translator into Lean, or a verification tool of its own, use that.
5. Keep a low-level TLA+ spec next to the code for the concurrent, stateful parts. That way, the gap between spec and code is written down where reviewers can see it.

## What to watch for

- No mature tool connects TLA+ and Lean. You translate between them by hand, and nothing checks that translation. A Lean proof of `Abs` and a TLA+ spec of `Abs` don't form a chain. They are two different objects that you keep in sync by hand.
- When trace validation fails, it usually fails silently. A mapping bug, such as treating event X as action Y, lets bad traces pass. Test the validator by corrupting a trace on purpose and checking that TLC rejects it.
- Constants and configuration that drift from the code cause most false failures. They are also the most common reason teams give up on trace validation after a couple of weeks.
- The TLA+ side works better for small, concrete questions, and the Lean side works better for general ones. To check that an Elixir GenServer does what the design doc says, use trace validation. To show an algorithm is correct for any number of replicas, you need a proof, in Lean or TLAPS.
