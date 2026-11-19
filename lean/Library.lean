/-!
# Library

This is the fixed design from `tla/Library.tla`. TLC checked 1 copy and 2
patrons. This file proves the fixed design never over-lends for any number of
copies and any sequence of borrows and returns.
-/

namespace Library

inductive Op where
  | borrow
  | giveBack

/-- `onLoan` is how many copies are out. A borrow checks and takes in one step.
Returning with nothing out stays at 0, because `Nat` subtraction stops at 0. -/
def step (copies onLoan : Nat) : Op → Nat
  | .borrow => if onLoan < copies then onLoan + 1 else onLoan
  | .giveBack => onLoan - 1

theorem never_over_lent (copies : Nat) (ops : List Op) :
    ops.foldl (step copies) 0 ≤ copies := by
  suffices ∀ n, n ≤ copies → ops.foldl (step copies) n ≤ copies from
    this 0 (Nat.zero_le copies)
  induction ops with
  | nil => intro n h; exact h
  | cons op ops ih =>
    intro n h
    apply ih
    cases op <;> simp only [step] <;> (try split) <;> omega

/-- Lean accepts this too. Its name says the library always over-lends, but its
assumption `copies < 0` can never be true, so it proves nothing. -/
theorem always_over_lends (copies : Nat) (ops : List Op) (h : copies < 0) :
    ops.foldl (step copies) 0 > copies := by
  omega

end Library
