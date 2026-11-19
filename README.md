# Formal Specification, Formal Verification, and Property-Based Tests

A 5-10 minute lightning talk. One small domain, three tools, one planted bug.

## The demo: a library hold queue

One book, 2 copies, 3 patrons (`ana`, `ben`, `cy`). Four rules:

1. If a copy is on the shelf and nobody is waiting, you can borrow it.
2. If no copy is on the shelf, you can place a hold. Holds are first come, first served.
3. When you return a copy and someone is waiting, the copy goes straight to the head of the queue.
4. You can't borrow a book you already have, or hold a book you already have or already hold.

Two properties:

- **Conservation:** copies on the shelf + copies on loan = copies owned.
- **NoShelfAndQueue:** nobody waits while a copy sits on the shelf.

**The planted bug** (`Buggy` / `buggy: true` / `BUGGY=1`): returns always go back on the shelf, even when someone is waiting. Conservation still holds. `cy` waits forever.

| Tool | What it says | Strength |
|---|---|---|
| `tla/` TLC | Correct: passes (10 states). Buggy: deadlock found in 6 states, with a readable trace. The deadlock check is on by default, and the `HoldsGetServed` liveness property fails as well. We never had to ask for `NoShelfAndQueue`. | Exhaustive, but only for this small model |
| `lean/` | `Conservation ∧ NoShelfAndQueue` holds for *any* number of copies and patrons, after any sequence of operations | A proof for every size, but no notion of time |
| `elixir/` StreamData | Buggy: "numbers balance" passes. "Nobody waits while a copy is on the shelf" fails and shrinks to `[borrow: :cy, borrow: :ana, hold: :ben, return: :ana]` | Tests the real code, but only what you thought to assert |

The point for a skeptical audience: property tests catch the bug *if you write the right property*. TLC finds it without being told what to look for, because a stuck state and a starving patron both fall out of the model. Lean proves the fixed version correct for every size. None of the three proves that the Elixir code matches the spec; see `references/verifying_implementations.md`.

Deliberately left out: per-patron limits, hold expiry, multiple books, concurrency (Lab 3), and trace validation.

## Running it

Tool versions (add these to `mise.toml` yourself): `java@21.0.2`, `elixir@1.20.5-otp-27`, `erlang@27.3.4.19`. Lean comes from `elan` via `lean/lean-toolchain` (`v4.36.0`).

```fish
# TLA+ (tla2tools.jar v1.7.4, from github.com/tlaplus/tlaplus releases)
cd tla
java -XX:+UseParallelGC -cp tla2tools.jar tlc2.TLC -config Library.cfg Library.tla
java -XX:+UseParallelGC -cp tla2tools.jar tlc2.TLC -config LibraryBuggy.cfg Library.tla

# Lean
cd lean; lake build

# Elixir
cd elixir; mix deps.get; mix test
env BUGGY=1 mix test
```

Livebook: open `elixir/notebooks/library.livemd`.

### TLC flags worth knowing

`java -cp tla2tools.jar tlc2.TLC -help` prints all of them.

- `-config FILE`: model config; defaults to `SPEC.cfg`
- `-workers N|auto`: worker threads
- `-deadlock`: turns deadlock checking **off** (the name is misleading)
- `-difftrace`: prints only what changed between trace states
- `-dump dot,actionlabels FILE.dot`: writes the state graph
- `-simulate num=N -depth D`: random simulation instead of exhaustive checking
- `-metadir DIR`: where the `states/` scratch directory goes
- Other entry points: `tla2sany.SANY` (parse only), `pcal.trans` (PlusCal to TLA+)

## TODO

- [X] Set up initial TLA+/Lean/Elixir scaffolding
- [X] Implement the proof of concept (`references/library_hold_queue_plan.md` is the original sketch)
- [X] Add Livebook + Kino for demos/visuals
- [ ] Come up with high-level `SKILL.md` for formal specification/verification and property-based tests (covering TLA+/Lean specifically, with general references to property-based tests without any focus on a particular language like Elixir/TypeScript/Python)

## Links

- Formal specification (TLA+)
  - https://en.wikipedia.org/wiki/Formal_specification
  - https://en.wikipedia.org/wiki/TLA%2B
  - https://lamport.azurewebsites.net/tla/toolbox.html
  - https://lamport.azurewebsites.net/tla/tools.html
  - https://lamport.azurewebsites.net/tla/standalone-tools.html?back-link=tools.html
  - https://github.com/QuinnWilton/accord#accord
- Formal verification (Lean)
  - https://en.wikipedia.org/wiki/Formal_verification
  - https://en.wikipedia.org/wiki/Lean_(proof_assistant)
  - https://lean-lang.org/install/manual/
    - Side note: Lean has its own bootstrapped compiler! https://github.com/leanprover/lean4/blob/master/src/Std/Http/Transport.lean
  - https://www.cslib.io/
  - https://github.com/josevalim/lynx#lynx
- Property-based tests
  - https://github.com/whatyouhide/stream_data
  - https://stream-data.hexdocs.pm/ExUnitProperties.html
