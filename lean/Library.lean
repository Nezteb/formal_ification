/-!
# Library hold queue

Same model as `tla/Library.tla`: one book, a fixed number of copies, a FIFO
hold queue. TLC checked 3 patrons and 2 copies. Here we prove the invariant for
*any* number of patrons and copies.
-/

namespace Library

abbrev Patron := Nat

structure Lib where
  shelf : Nat
  loans : List Patron
  holds : List Patron

inductive Op where
  | borrow (p : Patron)
  | hold (p : Patron)
  | ret (p : Patron)

/-- One step. Illegal operations leave the state unchanged. -/
def step (s : Lib) : Op → Lib
  | .borrow p =>
    if s.shelf > 0 ∧ s.holds = [] ∧ p ∉ s.loans
    then { s with shelf := s.shelf - 1, loans := p :: s.loans }
    else s
  | .hold p =>
    if s.shelf = 0 ∧ p ∉ s.loans ∧ p ∉ s.holds
    then { s with holds := s.holds ++ [p] }
    else s
  | .ret p =>
    if p ∈ s.loans then
      match s.holds with
      | [] => { s with shelf := s.shelf + 1, loans := s.loans.erase p }
      | h :: rest => { s with loans := h :: s.loans.erase p, holds := rest }
    else s

/-- `Conservation` and `NoShelfAndQueue` from the TLA+ spec. -/
def Inv (copies : Nat) (s : Lib) : Prop :=
  s.shelf + s.loans.length = copies ∧ (s.shelf > 0 → s.holds = [])

theorem init_inv (copies : Nat) : Inv copies ⟨copies, [], []⟩ := by
  simp [Inv]

theorem step_preserves (copies : Nat) (s : Lib) (op : Op) :
    Inv copies s → Inv copies (step s op) := by
  intro ⟨hcons, hqueue⟩
  cases op with
  | borrow p =>
    simp only [step]
    split
    · next h =>
      refine ⟨?_, fun _ => h.2.1⟩
      simp only [List.length_cons]; omega
    · exact ⟨hcons, hqueue⟩
  | hold p =>
    simp only [step]
    split
    · next h => exact ⟨hcons, fun hpos => absurd h.1 (Nat.pos_iff_ne_zero.mp hpos)⟩
    · exact ⟨hcons, hqueue⟩
  | ret p =>
    simp only [step]
    split
    · next hmem =>
      have hlen := List.length_erase_of_mem hmem
      have hpos := List.length_pos_of_mem hmem
      split
      · next hholds =>
        refine ⟨?_, fun _ => hholds⟩
        simp only; omega
      · next h rest hholds =>
        -- Someone is waiting, so the shelf must be empty.
        have hshelf : s.shelf = 0 := by
          cases Nat.eq_zero_or_pos s.shelf with
          | inl h0 => exact h0
          | inr hp => simp [hqueue hp] at hholds
        refine ⟨?_, fun hp => absurd hshelf (Nat.pos_iff_ne_zero.mp hp)⟩
        simp only [List.length_cons]; omega
    · exact ⟨hcons, hqueue⟩

/-- Every reachable state satisfies the invariant, for any sequence of ops. -/
theorem reachable_inv (copies : Nat) (ops : List Op) :
    Inv copies (ops.foldl step ⟨copies, [], []⟩) := by
  suffices ∀ s, Inv copies s → Inv copies (ops.foldl step s) from
    this _ (init_inv copies)
  induction ops with
  | nil => intro s h; exact h
  | cons op ops ih => intro s h; exact ih _ (step_preserves copies s op h)

end Library
