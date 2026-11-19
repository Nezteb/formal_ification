# Formal specification, formal verification, and property-based tests

This repo holds a 5-10 minute lightning talk. It models one small library, plants one bug in it, and shows what TLA+, Lean, and StreamData each say about the bug.

## The demo: a library hold queue

The library has one book with 2 copies, and 3 patrons named `ana`, `ben`, and `cy`. It follows four rules.

1. If a copy is on the shelf and nobody is waiting, you can borrow it.
2. If no copy is on the shelf, you can place a hold. Holds are first come, first served.
3. When you return a copy and someone is waiting, the copy goes straight to the head of the queue.
4. You can't borrow a book you already have, or hold a book you already have or already hold.

Every tool checks two properties. `Conservation` says copies on the shelf plus copies on loan equal copies owned. `NoShelfAndQueue` says nobody waits while a copy sits on the shelf.

The planted bug makes every return put the copy back on the shelf, even when someone is waiting. Turn it on with `Buggy = TRUE` in TLA+, `buggy: true` in Elixir, or `BUGGY=1` for the tests. `Conservation` still holds, and `cy` waits forever.

| Tool | Result | Limit |
|---|---|---|
| `tla/` TLC | The correct spec passes after checking 10 states. The buggy spec deadlocks after 6 states, and TLC prints the trace. The `HoldsGetServed` liveness property fails too. Nobody had to write `NoShelfAndQueue` to find it. | Checks every state, but only for 2 copies and 3 patrons |
| `lean/` | `Conservation ∧ NoShelfAndQueue` holds for any number of copies and patrons, after any sequence of operations | Proves it for every size, but can't express "eventually" |
| `elixir/` StreamData | With the bug, "the numbers balance" passes. "Nobody waits while a copy is on the shelf" fails and shrinks to `[borrow: :cy, borrow: :ana, hold: :ben, return: :ana]` | Runs the real code, but only checks the properties you wrote |

Property tests catch the bug only if someone wrote the right property. TLC finds it without being told what to look for. Its default deadlock check flags the stuck state, and the liveness property flags the patron who never gets the book. Lean proves the fixed version correct for every size. None of the three proves that the Elixir code matches the spec. `references/verifying_implementations.md` covers ways to close that gap.

The demo leaves out per-patron limits, hold expiry, multiple books, concurrency, and trace validation.

## Running it

Add `java@21.0.2`, `elixir@1.20.5-otp-27`, and `erlang@27.3.4.19` to `mise.toml`. `elan` installs Lean `v4.36.0` from `lean/lean-toolchain`.

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

To step through a run in Livebook, open `elixir/notebooks/library.livemd`.

### TLC flags worth knowing

`java -cp tla2tools.jar tlc2.TLC -help` prints the full list.

- `-config FILE` picks the model config. The default is `SPEC.cfg`.
- `-workers N|auto` sets the number of worker threads.
- `-deadlock` turns deadlock checking off, despite its name.
- `-difftrace` prints only what changed between states in a trace.
- `-dump dot,actionlabels FILE.dot` writes the state graph as a Graphviz file.
- `-simulate num=N -depth D` runs random traces instead of checking every state.
- `-metadir DIR` sets where TLC writes its `states/` working directory.
- `tla2sany.SANY` only parses a spec, and `pcal.trans` translates PlusCal to TLA+. Both are other main classes in the same jar.

## TODO

- [X] Set up initial TLA+/Lean/Elixir scaffolding
- [X] Implement the proof of concept , as described in `references/library_hold_queue_plan.md`
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
