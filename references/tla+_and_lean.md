> How does TLA+ compare/contrast with Lean?

---

## Short version

Both are formal methods tools. TLA+ is a specification language for how concurrent and distributed systems behave over time. You check a TLA+ spec by exploring every state of a small model. Lean is a general-purpose proof assistant. It is a dependently typed language where theorems and programs are the same kind of object, and its proofs hold for every case.

A common split is TLA+ to find design bugs in a small model, and Lean to prove things that must hold for every case.

## Side by side

| | TLA+ | Lean 4 |
|---|---|---|
| Creator | Leslie Lamport, about 1999 | Leonardo de Moura at Microsoft Research, 2013. Lean 4 arrived in 2021. Since 2023, the nonprofit Lean FRO has supported its development. |
| What it is | A specification language, plus PlusCal, a front end that reads like an algorithm | An interactive theorem prover and a general-purpose programming language |
| Logic | Untyped first-order logic and ZF set theory, extended with the Temporal Logic of Actions | Dependent type theory, the Calculus of Inductive Constructions. Proofs are terms, and a small kernel checks them. |
| Core object | A state machine with variables, `Init`, `Next`, and temporal formulas | A term with a type. A theorem is a type, and a proof is a term of that type. |
| Time built in | Yes. `[]`, `<>`, `~>`, fairness, stuttering steps, and refinement. | No. You encode transition systems yourself, with relations, traces, or coinduction. |
| How you check it | Model checking with TLC, which lists states, or Apalache, which uses an SMT solver up to a fixed bound | A proof script with tactics like `simp`, `omega`, and `grind`, plus `linarith` from Mathlib, checked by the kernel |
| What a result covers | The finite model you checked, for example 3 nodes and 2 values. A bug it finds is real in the model. Finding none is evidence, not proof. | Every parameter, once the proof is complete |
| What you write | The spec and a `.cfg` file. TLC searches for counterexamples itself, with no proof to write. | The model, the statement, and the proof. Tactics like `grind` can finish a goal, but you still choose the statement and any helper facts. In this repo, a person had to write the helper theorem `fixed_inv`, with `Conservation` and `0 ≤ shelf`, before `grind` could prove `never_over_lent`. |
| Nondeterminism and interleavings | Built in. Unbounded nondeterminism is normal. | You model them, with relations, monads, or an explicit operational semantics. |
| Runs as code | No. You simulate or model-check a spec. | Yes. Terms evaluate, and you can prove code correct and run it. |
| Proofs | TLAPS, a separate tool, checks proofs written in TLA+. It sends each step to Zenon, Isabelle, or an SMT solver. Zenon and Isabelle can't handle most arithmetic, so those steps need SMT. | The main purpose of the tool |
| Type checking | None in the language or TLC. Mistakes show up as model-checking errors or odd set-theory results. Apalache adds a type checker, Snowcat, that reads type annotations you write. | Dependent types catch errors while you write |
| Ecosystem | TLC, Apalache, TLAPS, the VS Code extension, and CommunityModules | Mathlib, with over 290,000 theorems and 140,000 definitions, plus Lake, Batteries, and CSLib |
| Typical users | Distributed-systems and protocol engineers at AWS (S3, DynamoDB), Azure Cosmos DB, MongoDB, and Intel | Mathematicians, programming-language researchers, and verification engineers. AWS models its Cedar policy language in Lean and proves properties about it. |

## How they differ

**They ask different questions.** A TLA+ spec asks whether any execution violates an invariant or a liveness property, under any interleaving, timing, or failure. The language is built around concurrency, with unbounded nondeterminism, stuttering, fairness, and refinement between an abstract spec and a concrete one. Lean asks whether you can build a proof of a statement. Concurrency gets no special treatment in Lean. It is one more thing to model.

**They mean different things by "verified."** TLC explores every reachable state of a finite instance. That catches most real bugs in protocol designs. A 2014 study of production failures in distributed systems, Yuan et al., "Simple Testing Can Prevent Most Critical Failures", found that almost all of them need 3 or fewer nodes to reproduce. A TLC pass still proves nothing about 100 nodes with unbounded sequence numbers. A Lean proof covers every case, and you do the work. So Lean isn't strictly better. TLC gives a result as soon as the spec and `.cfg` file exist, with no proof to write. A Lean proof gives no result until it is finished, and a false statement just fails to prove, with no trace.

**TLA+ has refinement built in.** A TLA+ user checks or proves that a detailed spec implements a simple abstract one. Lean can express the same relation between two transition systems, but you build the theory yourself. Mathlib gives Lean real analysis, algebra, and topology. TLA+ has almost no math library, and its users rarely need one.

**People use them together.** A common pattern is to model-check a TLA+ spec to find design bugs, then prove the final algorithm correct in Lean, Coq (now Rocq), Isabelle, or F\*.

## Which to use

- Use TLA+ when the thing you're checking is a design, such as a protocol, a distributed algorithm, a cache-coherence scheme, or a cloud service's consistency model. You get counterexample traces fast, and you accept "checked for N = 3."
- Use Lean when you need a proof. Examples include a math theorem, a compiler's correctness, a cryptographic algorithm's correctness, a type system's soundness, or a protocol property that must hold for any parameters. Lean also fits when the thing you're checking is code, because Lean can be that code.
- Don't use Lean to explore a concurrent design, because a failed proof doesn't give you a counterexample trace. Don't use TLA+ to prove a theorem about every system size unless you're ready for TLAPS. TLA+ has no types, so a TLAPS proof needs a type invariant you write by hand. tlapm also reports success when proof steps are skipped, unless you run it with `--strict`.
