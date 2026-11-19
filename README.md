# Formal specification, formal verification, and property-based tests

This repo holds a 5-10 minute lightning talk. An LLM can write and read TLA+ and Lean quickly. A spec only helps if the people who own the code can read it too, so the talk shows what humans have to own when they use these tools.

`TALK.md` has the slide map.

## The demo: the last copy

A library has 1 copy of a book and 2 patrons, `ana` and `ben`. The buggy borrow looks at the shelf, then takes the copy in a separate step. If both patrons look before either one takes, both walk out with the book.

The property is one sentence, and a human writes it: we never lend out more copies than we own. In TLA+ that's `NeverOverLent`.

| Tool | Result | Limit |
|---|---|---|
| `tla/` TLC | The buggy design fails `NeverOverLent` in 5 steps and ends with `shelf = -1`. The fixed design passes. The buggy design also passes `ShelfNeverOverflows`, a property that sounds right but isn't the one we care about. | Checks every interleaving, but only for 1 copy and 2 patrons |
| `lean/` | The same model with the same names. Lean proves the fixed design never over-lends, for any number of copies and patrons. It also proves `ShelfNeverOverflows` for the buggy design, the same trap TLC falls into. To show the bug itself, `buggy_over_lends` writes out TLC's trace and Lean checks it. | Proves every size, but you write the proof, and it only proves the statement you wrote |
| `elixir/` StreamData | A property test runs random sequences of borrows and returns for 1 to 5 copies. It passes on the buggy code, because it runs one operation at a time. | Runs the real code, but never interleaves two patrons |
| `elixir/` ExUnit | 50 concurrent borrows of the buggy code. The test passed 86 runs in a row before it failed once. | Runs the real code, but rarely hits the bad timing |

## Running it

`mise.toml` pins Java, Elixir, and Erlang. `elan` installs Lean `v4.36.0` from `lean/lean-toolchain`.

```fish
# TLA+ (tla2tools.jar v1.7.4, from github.com/tlaplus/tlaplus releases)
cd tla
java -XX:+UseParallelGC -cp tla2tools.jar tlc2.TLC -config LibraryBuggy.cfg Library.tla
java -XX:+UseParallelGC -cp tla2tools.jar tlc2.TLC -config LibraryWeak.cfg Library.tla
java -XX:+UseParallelGC -cp tla2tools.jar tlc2.TLC -config Library.cfg Library.tla

# Lean
cd lean; lake build

# Elixir
cd elixir; mix deps.get; mix test
env BUGGY=1 mix test test/library_test.exs:31 --repeat-until-failure 500
```

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
- [X] Implement the proof of concept, as described in `TALK.md`
- [X] Simplify the demo to the last-copy race, with one StreamData property and no Livebook
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
