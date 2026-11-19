/-!
# Library

The same model as `tla/Library.tla`, with the same names. One book with
`copies` copies. Patrons borrow it and return it. Patrons are numbers here,
and TLA+ names them `socrates` and `beelzebub`.

## Symbols

Each symbol's name, then how to type it with the Lean editor extension.

- `∧` "wedge", logical and. Type `\and`.
- `∨` "vee", logical or. Type `\or`.
- `¬` "not sign", logical not. Type `\not`.
- `→` "right arrow", implies, or "function to". Type `\to`.
- `∃` "there exists", a turned E. `∃ p, ...` means some `p` makes `...` true. Type `\ex`.
- `∈` "element of", from the Greek letter epsilon. It means "is in the list". Type `\in`.
- `∉` "not an element of". It means "is not in the list". Type `\notin`.
- `≤` "less than or equal to". Type `\le`.
- `⟨a, b⟩` "angle brackets". They build a structure or proof from its parts, in order. Type `\<` and `\>`.
- `p :: l` "cons". The list `l` with `p` added to the front.
- `s'` "s prime". The state after a step. The `'` is part of the name, like TLA+'s primes.
- `t1 <;> t2` runs tactic `t2` on every goal that `t1` leaves.
- `.init`, `.step` are short for `Reachable.init` and `Reachable.step`, when Lean can tell the type.

## Keywords

- `Nat` whole numbers from 0, `Int` integers, `List Nat` a list of `Nat`s
- `namespace X` ... `end X` groups names under `X`
- `structure` a record type with named fields
- `def` a definition. `: Prop` means it defines a true-or-false statement.
- `inductive` a type defined by the ways to build it. `Reachable` has two: `init` and `step`.
- `{ s with f := v }` a copy of `s` with field `f` changed
- `variable` declares arguments that every theorem below takes automatically
- `theorem` a statement plus its proof. Lean rejects it if the proof is wrong.
- `by` starts a proof written as tactics, which are commands that build it
- `induction h` prove it for `init`, then for each `step`
- `grind` Lean's built-in automation. The names in `[...]` are definitions it may unfold.
- `have x : T := ...` proves a step `T` and names it `x`
- `exact` finishes the proof with the given term
- `/-- ... -/` a doc comment, and `--` a line comment
-/

namespace Library

/-- `shelf` and `loans` are the Agent's state in the Elixir code. `looked` is
the patrons whose buggy borrow has done `Look` but not `Take`. -/
structure State where
  shelf : Int
  loans : List Nat
  looked : List Nat

def Init (copies : Nat) : State := { shelf := copies, loans := [], looked := [] }

/-- The buggy borrow's first step. The patron sees a copy on the shelf. -/
def Look (p : Nat) (s s' : State) : Prop :=
  s.shelf > 0 ∧ p ∉ s.loans ∧
  s' = { s with looked := p :: s.looked }

/-- The buggy borrow's second step. The patron takes the copy, without
checking the shelf again. -/
def Take (p : Nat) (s s' : State) : Prop :=
  p ∈ s.looked ∧
  s' = { shelf := s.shelf - 1, loans := p :: s.loans, looked := s.looked.erase p }

/-- The fixed borrow checks the shelf and takes the copy in one step. -/
def Borrow (p : Nat) (s s' : State) : Prop :=
  s.shelf > 0 ∧ p ∉ s.loans ∧
  s' = { s with shelf := s.shelf - 1, loans := p :: s.loans }

def Return (p : Nat) (s s' : State) : Prop :=
  p ∈ s.loans ∧
  s' = { s with shelf := s.shelf + 1, loans := s.loans.erase p }

def BuggyNext (s s' : State) : Prop := ∃ p, Look p s s' ∨ Take p s s' ∨ Return p s s'
def FixedNext (s s' : State) : Prop := ∃ p, Borrow p s s' ∨ Return p s s'

/-- The states that `next` can reach from `Init`. TLC finds these by searching.
Lean needs them written as a definition, so a proof can use induction on them. -/
inductive Reachable (copies : Nat) (next : State → State → Prop) : State → Prop
  | init : Reachable copies next (Init copies)
  | step : Reachable copies next s → next s s' → Reachable copies next s'

/-- We never lend out more copies than we own. -/
def NeverOverLent (copies : Nat) (s : State) : Prop := s.loans.length ≤ copies

/-- Copies on the shelf plus copies on loan equal copies owned. It sounds like
the right property, and it's true in both designs. -/
def Conservation (copies : Nat) (s : State) : Prop := s.shelf + s.loans.length = copies

-----------------------------------------------------------------------------

variable {copies : Nat} {s : State}

/-- The buggy design keeps `Conservation`, for any number of copies and
patrons, because the shelf goes negative while it over-lends. -/
theorem buggy_conservation (h : Reachable copies BuggyNext s) :
    Conservation copies s := by
  induction h <;> grind [Init, Conservation, BuggyNext, Look, Take, Return]

/-- Why this exists: induction on `NeverOverLent` alone fails. Knowing only
`loans ≤ copies`, Lean can't rule out a state where every copy is out but the
shelf still shows one, and a `Borrow` from there over-lends. These two facts
rule that state out. TLC never needs this, because it only visits real states. -/
theorem fixed_inv (h : Reachable copies FixedNext s) :
    Conservation copies s ∧ 0 ≤ s.shelf := by
  induction h <;> grind [Init, Conservation, FixedNext, Borrow, Return]

/-- The fixed design never over-lends, for any number of copies and patrons. -/
theorem never_over_lent (h : Reachable copies FixedNext s) :
    NeverOverLent copies s := by
  grind [fixed_inv h, NeverOverLent, Conservation]

/-- The buggy design does over-lend. Lean can't search for this the way TLC
does, so we write out TLC's 5-step trace, naming who acts at each step, and
Lean checks each step. -/
theorem buggy_over_lends : ∃ s, Reachable 1 BuggyNext s ∧ ¬ NeverOverLent 1 s := by
  have s1 : Reachable 1 BuggyNext ⟨1, [], []⟩ := .init
  have s2 : Reachable 1 BuggyNext ⟨1, [], [0]⟩ := .step s1 ⟨0, by grind [Look]⟩
  have s3 : Reachable 1 BuggyNext ⟨1, [], [1, 0]⟩ := .step s2 ⟨1, by grind [Look]⟩
  have s4 : Reachable 1 BuggyNext ⟨0, [0], [1]⟩ := .step s3 ⟨0, by grind [Take]⟩
  have s5 : Reachable 1 BuggyNext ⟨-1, [1, 0], []⟩ := .step s4 ⟨1, by grind [Take]⟩
  exact ⟨_, s5, by grind [NeverOverLent]⟩

end Library
