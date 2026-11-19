> How does TLA+ compare/contrast with Lean?

---

## Short version

Both are formal methods tools, and they sit at opposite ends. TLA+ is a specification language for how concurrent and distributed systems behave over time. You check a TLA+ spec by exploring every state of a small model. Lean is a general-purpose proof assistant. It is a dependently typed language where theorems and programs are the same kind of object, and its proofs hold for every case.

Teams usually use TLA+ to find design bugs cheaply and Lean to prove things that must hold for all cases.

## Side by side

| | TLA+ | Lean 4 |
|---|---|---|
| Creator | Leslie Lamport, about 1999 | Leonardo de Moura at Microsoft Research, 2013. Lean 4 arrived about 2021 and is now run by the Lean FRO. |
| What it is | A specification language, plus PlusCal, a front end that reads like an algorithm | An interactive theorem prover and a general-purpose programming language |
| Logic | Untyped first-order logic and ZF set theory, extended with the Temporal Logic of Actions | Dependent type theory, the Calculus of Inductive Constructions. Proofs are terms, and a small kernel checks them. |
| Core object | A state machine with variables, `Init`, `Next`, and temporal formulas | A term with a type. A theorem is a type, and a proof is a term of that type. |
| Time built in | Yes. `[]`, `<>`, `~>`, fairness, stuttering steps, and refinement. | No. You encode transition systems yourself, with relations, traces, or coinduction. |
| How you check it | Model checking with TLC, which lists states, or Apalache, which uses an SMT solver up to a fixed bound | A proof script with tactics like `simp`, `omega`, `linarith`, and `grind`, checked by the kernel |
| What a result covers | The finite model you checked, for example 3 nodes and 2 values. A bug it finds is real. Finding none is evidence, not proof. | Every parameter, once the proof is complete |
| Automation | High, but bounded. Run TLC and get a counterexample trace. | Low to moderate. Strong tactics exist, but you write the proof. |
| Nondeterminism and interleavings | Built in. Unbounded nondeterminism is normal. | You model them, with relations, monads, or an explicit operational semantics. |
| Runs as code | No. You simulate or model-check a spec. | Yes. Terms evaluate, and you can prove code correct and run it. |
| Proofs | TLAPS exists, with Zenon, Isabelle, and SMT back ends, but few people use it and it has limits | The main purpose of the tool |
| Type checking | None. Mistakes show up as model-checking errors or odd set-theory results. | Dependent types catch errors while you write |
| Ecosystem | TLC, Apalache, TLAPS, the VS Code extension, and CommunityModules. It is fairly small. | Mathlib, with over a million lines of formalized math, plus Lake, Batteries, and a large, growing set of libraries |
| Typical users | Distributed-systems and protocol engineers at AWS (S3, DynamoDB), Azure Cosmos DB, MongoDB, and Intel | Mathematicians, programming-language researchers, and verification engineers. AWS verified its Cedar policy language in Lean. |
| Effort | Days to write a useful spec, minutes to check it | Weeks to months to learn Lean and finish a nontrivial proof |
| Weight | Lightweight. It is cheap and finds many bugs per hour. | Heavyweight. It is expensive, and it gives guarantees. |

## How they differ

**They ask different questions.** A TLA+ spec asks whether any execution violates an invariant or a liveness property, under any interleaving, timing, or failure. The language is built around concurrency, with unbounded nondeterminism, stuttering, fairness, and refinement between an abstract spec and a concrete one. Lean asks whether you can build a proof of a statement. Concurrency gets no special treatment in Lean. It is one more thing to model.

**They mean different things by "verified."** TLC explores every reachable state of a finite instance. That catches most real bugs in protocol designs, since most distributed-system bugs show up with 2 or 3 nodes. It proves nothing about 100 nodes with unbounded sequence numbers. A Lean proof covers every case, and you do the work. So Lean isn't strictly better. For a design review of a replication protocol, an afternoon of TLA+ gets you more than an afternoon of Lean.

**TLA+ has refinement built in.** A TLA+ user checks or proves that a detailed spec implements a simple abstract one. Lean can express the same relation between two transition systems, but you build the theory yourself. Mathlib gives Lean real analysis, algebra, and topology. TLA+ has almost no math library, and its users rarely need one.

**People use them together.** A common pattern is to model-check a TLA+ spec to find design bugs, then prove the final algorithm correct in Lean, Coq (now Rocq), Isabelle, or F\*. Some projects generate TLA+-style proof obligations from proof assistants. PlusCal's imperative style looks a little like Lean's `do` notation, but the two work differently.

## Which to use

- Use TLA+ when the thing you're checking is a design, such as a protocol, a distributed algorithm, a cache-coherence scheme, or a cloud service's consistency model. You get counterexample traces fast, and you accept "checked for N = 3."
- Use Lean when you need a proof. Examples include a math theorem, a compiler's correctness, a cryptographic algorithm's correctness, a type system's soundness, or a protocol property that must hold for any parameters. Lean also fits when the thing you're checking is code, because Lean can be that code.
- Don't use Lean to explore a concurrent design, because the feedback is slow. Don't use TLA+ to prove a theorem about every system size. TLAPS can do it, but it is hard to learn and has thin documentation.
