/-!
# Library

The same model as `tla/Library.tla`, with the same names. One book with
`copies` copies. Patrons borrow it and return it. TLA+ names patrons `ana` and
`ben`. Here patrons are numbered from 0.
-/

namespace Library

inductive Status where
  | idle
  | sawCopy
  | hasBook
  deriving DecidableEq

/-- `shelf` is how many copies are on the shelf. `status[p]` is patron `p`'s status. -/
structure World where
  shelf : Int
  status : List Status

def Init (copies patrons : Nat) : World :=
  { shelf := copies, status := List.replicate patrons .idle }

/-- The buggy borrow takes two steps. First the patron sees a copy on the shelf. -/
def Look (p : Nat) (w w' : World) : Prop :=
  w.status[p]? = some .idle ∧
  w.shelf > 0 ∧
  w' = { w with status := w.status.set p .sawCopy }

/-- Later the patron takes it, without checking the shelf again. -/
def Take (p : Nat) (w w' : World) : Prop :=
  w.status[p]? = some .sawCopy ∧
  w' = { shelf := w.shelf - 1, status := w.status.set p .hasBook }

/-- The fixed borrow checks the shelf and takes the copy in one step. -/
def Borrow (p : Nat) (w w' : World) : Prop :=
  w.status[p]? = some .idle ∧
  w.shelf > 0 ∧
  w' = { shelf := w.shelf - 1, status := w.status.set p .hasBook }

def Return (p : Nat) (w w' : World) : Prop :=
  w.status[p]? = some .hasBook ∧
  w' = { shelf := w.shelf + 1, status := w.status.set p .idle }

def BuggyNext (w w' : World) : Prop := ∃ p, Look p w w' ∨ Take p w w' ∨ Return p w w'
def FixedNext (w w' : World) : Prop := ∃ p, Borrow p w w' ∨ Return p w w'

/-- The worlds `next` can reach from `Init`. TLC finds these by searching.
Here they are a definition we can do induction on. -/
inductive Reachable (copies patrons : Nat) (next : World → World → Prop) : World → Prop
  | init : Reachable copies patrons next (Init copies patrons)
  | step : Reachable copies patrons next w → next w w' → Reachable copies patrons next w'

/-- How many patrons have the book. -/
def onLoan (w : World) : Nat := w.status.count .hasBook

/-- We never lend out more copies than we own. -/
def NeverOverLent (copies : Nat) (w : World) : Prop := onLoan w ≤ copies

/-- The shelf never holds more copies than we own. This sounds right, and Lean
proves it for the buggy design. It isn't the property we care about. -/
def ShelfNeverOverflows (copies : Nat) (w : World) : Prop := w.shelf ≤ copies

-----------------------------------------------------------------------------

/-- Copies on the shelf plus copies on loan equal copies owned. TLC never needs
this. Lean does, because `NeverOverLent` alone isn't strong enough to carry
through a proof by induction. -/
def Conservation (copies : Nat) (w : World) : Prop := w.shelf + onLoan w = copies

variable {copies patrons : Nat} {w : World}

/-- Changing one patron's status changes the loan count by at most one. -/
theorem count_set {l : List Status} {p : Nat} {s s' : Status} (h : l[p]? = some s) :
    (l.set p s').count .hasBook + (if s = .hasBook then 1 else 0) =
      l.count .hasBook + (if s' = .hasBook then 1 else 0) := by
  obtain ⟨hp, hs⟩ := List.getElem?_eq_some_iff.mp h
  rw [List.count_set hp, hs]
  cases s
  case hasBook =>
    have : 0 < l.count .hasBook :=
      List.count_pos_iff.mpr (by rw [← hs]; exact List.getElem_mem hp)
    cases s' <;> simp <;> omega
  all_goals cases s' <;> simp

theorem init_conservation : Conservation copies (Init copies patrons) := by
  simp [Conservation, onLoan, Init, List.count_replicate]

/-- The buggy design keeps `Conservation` too. The count adds up even while it
over-lends, because the shelf goes negative. -/
theorem buggy_conservation (h : Reachable copies patrons BuggyNext w) :
    Conservation copies w := by
  induction h with
  | init => exact init_conservation
  | step _ hnext ih =>
    obtain ⟨p, ⟨hs, -, rfl⟩ | ⟨hs, rfl⟩ | ⟨hs, rfl⟩⟩ := hnext
    · have := count_set (s' := .sawCopy) hs
      simp [Conservation, onLoan] at *; omega
    · have := count_set (s' := .hasBook) hs
      simp [Conservation, onLoan] at *; omega
    · have := count_set (s' := .idle) hs
      simp [Conservation, onLoan] at *; omega

/-- The fixed design keeps `Conservation`, and its shelf never goes below 0. -/
theorem fixed_inv (h : Reachable copies patrons FixedNext w) :
    Conservation copies w ∧ 0 ≤ w.shelf := by
  induction h with
  | init => exact ⟨init_conservation, by simp [Init]⟩
  | step _ hnext ih =>
    obtain ⟨p, ⟨hs, hpos, rfl⟩ | ⟨hs, rfl⟩⟩ := hnext
    · have := count_set (s' := .hasBook) hs
      simp [Conservation, onLoan] at *; omega
    · have := count_set (s' := .idle) hs
      simp [Conservation, onLoan] at *; omega

-----------------------------------------------------------------------------

/-- The fixed design never over-lends, for any number of copies and patrons. -/
theorem never_over_lent (h : Reachable copies patrons FixedNext w) :
    NeverOverLent copies w := by
  have := fixed_inv h
  simp only [NeverOverLent, Conservation] at *
  omega

/-- The buggy design passes the weak property, for any number of copies and patrons. -/
theorem shelf_never_overflows (h : Reachable copies patrons BuggyNext w) :
    ShelfNeverOverflows copies w := by
  have := buggy_conservation h
  simp only [ShelfNeverOverflows, Conservation] at *
  omega

/-- The buggy design does over-lend. Lean can't search for this the way TLC
does. We write out the same 5-step trace TLC prints, and Lean checks each step.
Patron 0 is Ana and patron 1 is Ben. -/
theorem buggy_over_lends :
    ∃ w, Reachable 1 2 BuggyNext w ∧ ¬ NeverOverLent 1 w := by
  -- 1. shelf = 1, Ana idle, Ben idle
  have s1 : Reachable 1 2 BuggyNext ⟨1, [.idle, .idle]⟩ := .init
  -- 2. Ana looks.
  have s2 : Reachable 1 2 BuggyNext ⟨1, [.sawCopy, .idle]⟩ :=
    .step s1 ⟨0, .inl ⟨rfl, by decide, rfl⟩⟩
  -- 3. Ben looks.
  have s3 : Reachable 1 2 BuggyNext ⟨1, [.sawCopy, .sawCopy]⟩ :=
    .step s2 ⟨1, .inl ⟨rfl, by decide, rfl⟩⟩
  -- 4. Ana takes.
  have s4 : Reachable 1 2 BuggyNext ⟨0, [.hasBook, .sawCopy]⟩ :=
    .step s3 ⟨0, .inr (.inl ⟨rfl, rfl⟩)⟩
  -- 5. Ben takes. The shelf is at -1 and 2 copies are out.
  have s5 : Reachable 1 2 BuggyNext ⟨-1, [.hasBook, .hasBook]⟩ :=
    .step s4 ⟨1, .inr (.inl ⟨rfl, rfl⟩)⟩
  exact ⟨_, s5, by simp [NeverOverLent, onLoan]⟩

end Library
