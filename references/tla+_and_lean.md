> How does TLA+ compare/contrast with Lean?

---

## Short version

They're both formal methods tools, but they live at opposite ends of the spectrum. **TLA+ is a specification language for describing how concurrent and distributed systems behave over time, and it's normally checked by exhaustively exploring a small model.** **Lean is a general-purpose proof assistant: a dependently typed language in which theorems and programs are the same kind of object, and proofs are checked in full generality.**

So the usual division of labor is: TLA+ to find design bugs cheaply, Lean to prove things that must hold for all cases.

## Side-by-side

| | TLA+ | Lean (4) |
|---|---|---|
| **Creator / origin** | Leslie Lamport, ~1999 | Leonardo de Moura (Microsoft Research), 2013; Lean 4 ~2021, now under the Lean FRO |
| **What it is** | Specification language (plus PlusCal, an algorithm-style front end) | Interactive theorem prover *and* general-purpose programming language |
| **Logical foundation** | Untyped first-order logic + ZF set theory, extended with the Temporal Logic of Actions | Dependent type theory (Calculus of Inductive Constructions); proofs are terms, checked by a small kernel |
| **Core object** | A state machine: variables, `Init`, `Next`, plus temporal formulas | A term inhabiting a type; a theorem is a type, a proof is a term of it |
| **Native notion of time** | Yes — `[]`, `<>`, `~>`, fairness, stuttering steps, refinement | No — you encode transition systems yourself (relations, traces, coinduction) |
| **Standard verification method** | Model checking: TLC (explicit-state) or Apalache (symbolic/SMT, bounded) | Interactive proof script + tactics (`simp`, `omega`, `linarith`, `grind`), checked by the kernel |
| **Generality of result** | Holds for the finite model you checked (e.g. 3 nodes, 2 values) — a bug found is real, absence of bugs is only evidence | Holds for all parameters, if the proof is complete |
| **Automation** | High, but bounded: push a button, get a counterexample trace | Low-to-moderate: heavy automation tactics exist, but you write the proof |
| **Nondeterminism & interleavings** | First-class; unbounded nondeterminism is normal | Must be modeled (relations, monads, an explicit operational semantics) |
| **Executability** | Specs are generally not executable; you simulate or model-check them | Lean is a real programming language; terms evaluate, and code can be proved correct and run |
| **Proof support** | TLAPS exists (Zenon/Isabelle/SMT backends) but is comparatively rarely used and limited | The whole point of the tool |
| **Type checking as a safety net** | Untyped; mistakes surface as model-checking errors or weird set-theoretic nonsense | Strong dependent typing catches errors at elaboration |
| **Ecosystem** | TLC, Apalache, TLAPS, VS Code toolbox, CommunityModules (fairly small) | Mathlib (over a million lines of formalized math), Lake, Batteries, a large and fast-growing library ecosystem |
| **Typical users** | Distributed-systems and protocol engineers (AWS S3/DynamoDB, Azure Cosmos DB, MongoDB, Intel) | Mathematicians, PL researchers, and verification engineers (e.g. AWS's Cedar policy language is verified in Lean) |
| **Effort profile** | Days to write a useful spec; minutes to check | Weeks to months to learn and to complete a nontrivial proof |
| **Character** | "Lightweight" formal methods — cheap, high bug-per-hour yield | "Heavyweight" — expensive, but delivers guarantees |

## The deeper contrast

**Different question being asked.** A TLA+ spec asks *"is there any execution, under any interleaving, timing, or failure pattern, that violates my invariant or my liveness property?"* Its whole design is oriented around concurrency: unbounded nondeterminism, stuttering, fairness, refinement between an abstract spec and a concrete one. Lean asks *"can I construct a proof object of this proposition?"* — and concurrency isn't special there; it's just one more thing to model.

**Different notion of "verified."** TLC's answer is empirical in a precise sense: it explores the entire reachable state graph *of a finite instance*. That catches the overwhelming majority of real bugs in protocol designs (the classic result is that most distributed-system bugs show up at 2–3 nodes), but it doesn't prove anything about 100 nodes with unbounded sequence numbers. Lean's answer is deductive and complete, at the cost of you doing the work. This is exactly why you can't just say "Lean is strictly better" — for a Monday-morning design review of a replication protocol, a TLA+ spec is a far better use of an afternoon than a Lean development.

**Refinement vs. verification.** TLA+ has refinement mapping built into its idiom: prove (or check) that your detailed spec implements a simple abstract one. Lean can express the same thing (a simulation/refinement relation between transition systems), but you build the theory yourself. Conversely, Lean's Mathlib gives you real analysis, algebra, and topology for free — TLA+ has essentially no mathematical library, because you rarely need one.

**They compose.** The literature is full of hybrid approaches: model-check a TLA+ spec to shake out design bugs, then formalize the eventual algorithm and its correctness proof in Lean (or Coq/Rocq, Isabelle, F\*) for the guarantee. Some projects even generate or check TLA+-style obligations from proof assistants. And PlusCal's imperative style has a rough analogue in Lean's `do` notation, though the resemblance is superficial.

## Which to reach for

- **Use TLA+** when the artifact is a *design*: a protocol, a distributed algorithm, a cache-coherence scheme, a cloud service's consistency model. You want counterexample traces fast, and you're willing to accept "verified for N=3."
- **Use Lean** when you need a *proof*: a mathematical theorem, a compiler or cryptographic primitive's correctness, a type system's soundness, or a protocol property that must hold for arbitrary parameters. Also when the thing you're verifying is itself code, since Lean can be that code.
- **Don't** pick Lean to explore a concurrency design (painful, slow feedback), and don't pick TLA+ expecting a theorem about all system sizes (TLAPS can get there, but it's a steep, thinly documented climb).
