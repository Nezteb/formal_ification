# Formal specification, formal verification, and property-based tests

This repo holds a 5-10 minute lightning talk. An LLM can write TLA+, Lean, and property tests. They only help if a human reads the property, reads the trace, and checks that the model matches the real code. `TALK.md` has the slide map and short definitions of terms like invariant, theorem, and lemma.

## The demo: the last copy

A library has 1 copy of a book and 2 patrons, `socrates` and `beelzebub`. The buggy borrow looks at the shelf, then takes the copy in a separate step. If both patrons look before either one takes, both walk out with the book.

A human writes the property as one sentence: we never lend out more copies than we own. Every tool checks that sentence.

| Tool | Result | Limit |
|---|---|---|
| `tla/` TLC | The buggy design fails `NeverOverLent` after 4 steps. The fixed design passes. The buggy design passes `Conservation`, which sounds right but misses the bug. | Covers every ordering, but only for 1 copy and 2 patrons |
| `lean/` | The same model with the same names. Lean proves the fixed design never over-lends at every size, and proves `Conservation` for the buggy design. | Covers every size, but you write the proof, and it proves only the statement you wrote |
| `elixir/` StreamData | Random sequences of borrows and returns pass on the buggy code. | Runs the real code, one step at a time |
| `elixir/` ExUnit | Socrates and Beelzebub borrow the buggy code's 1 copy at the same time. In 8 runs, 5 failed and 3 passed. | Runs the real code, but whether it catches the race depends on scheduling |

## Running it

TLA+ needs `tla2tools.jar` v1.7.4 from the `tlaplus/tlaplus` GitHub releases, saved in `tla/`.

```sh
cd tla
java -XX:+UseParallelGC -cp tla2tools.jar tlc2.TLC -config LibraryBuggy.cfg Library.tla
java -XX:+UseParallelGC -cp tla2tools.jar tlc2.TLC -config LibraryWeak.cfg Library.tla
java -XX:+UseParallelGC -cp tla2tools.jar tlc2.TLC -config Library.cfg Library.tla
```

```sh
cd lean
lake build
```

`lake build` also prints the axioms each theorem depends on. A `sorryAx` in that output means a proof was skipped with `sorry`.

```sh
cd elixir
mix deps.get
mix test
BUGGY=1 mix test
```

## TODO

- [ ] Come up with high-level `SKILL.md` for formal specification/verification and property-based tests (covering TLA+/Lean specifically, with general references to property-based tests without any focus on a particular language like Elixir/TypeScript/Python)

## Links

- Formal specification (TLA+)
  - https://en.wikipedia.org/wiki/Formal_specification
  - https://en.wikipedia.org/wiki/TLA%2B
  - https://en.wikipedia.org/wiki/Safety_and_liveness_properties
  - https://lamport.azurewebsites.net/tla/book-02-08-08.pdf
  - https://learntla.com/core/temporal-logic.html
  - https://lamport.azurewebsites.net/tla/toolbox.html
  - https://lamport.azurewebsites.net/tla/tools.html
  - https://lamport.azurewebsites.net/tla/standalone-tools.html?back-link=tools.html
  - https://github.com/QuinnWilton/accord#accord
  - https://github.com/tlaplus/tlapm
    - TLAPS, the TLA+ proof system. Not used in the demo.
    - Latest pre-release to play with: https://github.com/tlaplus/tlapm/releases/tag/1.6.0-pre
- Formal verification (Lean)
  - https://en.wikipedia.org/wiki/Formal_verification
  - https://en.wikipedia.org/wiki/Lean_(proof_assistant)
  - https://en.wikipedia.org/wiki/Lemma_(mathematics)
  - https://lean-lang.org/install/manual/
  - https://lean-lang.org/theorem_proving_in_lean4/tactics.html
  - https://lean-lang.org/theorem_proving_in_lean4/axioms_and_computation.html
    - Side note: Lean has its own bootstrapped compiler! Example: https://github.com/leanprover/lean4/blob/master/src/Std/Http/Transport.lean
  - https://www.cslib.io/
  - https://github.com/josevalim/lynx#lynx
- Property-based tests
  - https://github.com/whatyouhide/stream_data
  - https://stream-data.hexdocs.pm/ExUnitProperties.html

## Future work

Deterministic simulation testing:
- https://antithesis.com/docs/resources/deterministic_simulation_testing/
- https://martinfowler.com/articles/deterministic-simulation-testing.html
