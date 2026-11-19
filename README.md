# Formal Specification, Formal Verification, and Property-Based Tests

## Temp Notes

- `LeanTest` is a tester Lean project I created using `lake new LeanTest`.

## TODO

- [~] Set up initial TLA+/Lean/Elixir scaffolding
  - [~] Figure out (and concisely document) all the various CLI options for TLA+/Lean projects (for better LLM integration/usage)
    - [X] Lean: `elan` (version manager), `lake` (build tool), `lean` (compiler)
    - [ ] TLA+: ???
- [ ] Implement `PLAN.md` proof of concept (minimal/simple/concise)
- [ ] Add Livebook + Kino for demos/visuals
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
